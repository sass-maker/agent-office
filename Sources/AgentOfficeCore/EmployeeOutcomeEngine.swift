import Foundation

/// The parts of a run the host decides rather than the engine.
///
/// Grouped because they answer the same question — what the surrounding app has
/// already settled — and neither is something the engine may invent for itself.
public struct EmployeeOutcomeRunOptions: Sendable {
  /// Whether the engine writes intermediate state to disk. `false` when the
  /// caller applies the whole result through the command boundary instead.
  public var persistsTransitions: Bool
  /// What the permission broker allows right now. `nil` uses the employee's own
  /// grants, which is what callers that predate the broker expect.
  public var authorizedCapabilities: Set<String>?

  public init(persistsTransitions: Bool = true, authorizedCapabilities: Set<String>? = nil) {
    self.persistsTransitions = persistsTransitions
    self.authorizedCapabilities = authorizedCapabilities
  }
}

public struct EmployeeOutcomeEngine: Sendable {
  public static let maximumTickets = 4

  public init() {}

  private struct RunContext: Sendable {
    let runner: any EmployeeRunner
    let store: LocalOrganizationStore
    let now: Date
    let persistsTransitions: Bool
    let authorizedCapabilities: Set<String>?
    /// The runtime this commitment resolved to, decided once per run and then
    /// read everywhere instead of being re-derived from organization-wide state.
    let selection: ResolvedRuntimeSelection
    /// The local feedback the recurring duty that owns this commitment read.
    /// `nil` for every commitment no duty owns, which is most of them.
    ///
    /// The whole snapshot rather than only its `<feedback_source>` blocks,
    /// because the labels the work is handed are the same labels its brief is
    /// later required to cite.
    let feedback: FeedbackInputSnapshot?
  }

  public func start(
    _ input: OrganizationState,
    outcomeID: String,
    now: Date = Date()
  ) -> OrganizationState {
    var state = input
    guard let outcome = state.employeeOutcome(outcomeID),
      [.queued, .waiting, .failed, .approved, .revision].contains(outcome.status),
      let employeeIndex = state.employees.firstIndex(where: { $0.id == outcome.assigneeID }),
      state.employees[employeeIndex].effectiveEmploymentState == .hired
    else { return input }

    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .planning
      value.planStatus = value.taskIDs.isEmpty ? .drafting : .approved
      value.helpRequest = nil
      value.attemptCount += 1
      value.outcomeRevision = value.effectiveRevision + 1
    }
    state.employees[employeeIndex].status = .planning
    state.employees[employeeIndex].currentTaskID = nil
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: outcome.assigneeID,
        kind: .progress,
        message: "I’m planning the smallest useful set of tickets for this outcome.",
        createdAt: now
      ))
    return state
  }

  /// Runs a commitment.
  ///
  /// `authorizedCapabilities` is what the permission broker allows right now.
  /// When it is nil the employee's own grants are used, which is what callers
  /// that predate the broker expect.
  public func run(
    _ input: OrganizationState,
    outcomeID: String,
    runner: any EmployeeRunner,
    store: LocalOrganizationStore,
    now: Date = Date(),
    runtimeHealth: RuntimeHealthSnapshot = .practiceOnly,
    options: EmployeeOutcomeRunOptions = .init()
  ) async -> OrganizationState {
    var state = input
    guard var outcome = state.employeeOutcome(outcomeID),
      !outcome.status.isTerminal,
      outcome.status != .delivered,
      outcome.status != .proposed,
      let employee = state.employee(outcome.assigneeID)
    else { return input }

    // Which runtime this employee runs on is decided by the seven-rule policy
    // before any work is attempted. A refusal is a real outcome: the commitment
    // waits with the reason on it, and no runner is invoked, because handing the
    // work to whatever runner happened to be passed in is exactly the silent
    // substitution rule 7 forbids.
    let resolution = state.resolveRuntime(
      for: employee.id, health: runtimeHealth, commitmentID: outcomeID)
    guard let selection = resolution.selection else {
      return blockForRuntime(
        state, outcomeID: outcomeID, employeeID: employee.id,
        refusal: resolution.refusal, now: now)
    }
    pinRuntime(selection, to: outcomeID, state: &state, now: now)
    outcome = state.employeeOutcome(outcomeID) ?? outcome

    // A commitment a recurring duty owns reads the local feedback inbox before
    // any work starts, and the occurrence records exactly what was read. The
    // coverage the owner sees is the point: an unread inbox must never look
    // like an analyzed one.
    let feedback = await captureDutyInputs(
      outcome: outcome, store: store, state: &state, now: now)

    // A feedback review with no feedback to review has nothing to say. The
    // coverage just recorded on the occurrence is honest about that; a brief
    // written on top of it would not be, because it would read as a reading
    // that never happened. This waits rather than fails: nothing went wrong
    // with the work, and the owner adds a file and resumes.
    if let feedback, feedback.files.isEmpty {
      return blockForOwner(
        state,
        outcomeID: outcomeID,
        employeeID: employee.id,
        reason: CustomerVoiceDutyError.emptyInbox.localizedDescription,
        blockerID: "\(outcomeID)-feedback-inbox",
        blockerTitle: "\(employee.name) has no feedback to review",
        now: now
      )
    }

    let ctx = RunContext(
      runner: runner, store: store, now: now,
      persistsTransitions: options.persistsTransitions,
      authorizedCapabilities: options.authorizedCapabilities,
      selection: selection,
      feedback: feedback
    )

    do {
      if outcome.taskIDs.isEmpty {
        try await createAndApplyPlan(
          outcome: &outcome, outcomeID: outcomeID, employee: employee,
          state: &state, ctx: ctx
        )
        if outcome.status == .proposed { return state }
      }

      for taskID in outcome.taskIDs {
        let result = try await processTask(
          taskID: taskID, outcomeID: outcomeID, outcome: outcome,
          employee: employee, state: &state, ctx: ctx
        )
        if let returnState = result { return returnState }
      }

      let finishedOutcome = state.employeeOutcome(outcomeID) ?? outcome
      let allDone = finishedOutcome.taskIDs.allSatisfy { state.task($0)?.status == .done }
      guard allDone else { return state }

      completeDelivery(
        outcomeID: outcomeID, finishedOutcome: finishedOutcome,
        employee: employee, state: &state, now: now
      )
      return state
    } catch is CancellationError {
      return input
    } catch {
      return fail(
        state, outcomeID: outcomeID, employeeID: employee.id, error: error, now: now
      )
    }
  }

  private func createAndApplyPlan(
    outcome: inout EmployeeOutcome,
    outcomeID: String,
    employee: Employee,
    state: inout OrganizationState,
    ctx: RunContext
  ) async throws {
    let plan = try await createPlan(
      outcome: outcome, employee: employee, state: state,
      runner: ctx.runner, store: ctx.store, now: ctx.now,
      authorizedCapabilities: ctx.authorizedCapabilities
    )
    try apply(plan: plan, to: outcomeID, state: &state, now: ctx.now)
    outcome = state.employeeOutcome(outcomeID) ?? outcome
    if ctx.persistsTransitions { try await ctx.store.save(state) }
  }

  private func processTask(
    taskID: String,
    outcomeID: String,
    outcome: EmployeeOutcome,
    employee: Employee,
    state: inout OrganizationState,
    ctx: RunContext
  ) async throws -> OrganizationState? {
    guard let taskIndex = state.tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
    if state.tasks[taskIndex].status == .done { return nil }

    let dependenciesComplete = state.tasks[taskIndex].dependencyIDs.allSatisfy { dependencyID in
      state.task(dependencyID)?.status == .done
    }
    guard dependenciesComplete else { return nil }

    // Real web research needs real permission. Whether the work is real is a
    // property of the resolved runtime, not of an organization-wide mode: a
    // rehearsal reaches no network, and every non-rehearsal does.
    if state.tasks[taskIndex].kind == .research,
      !ctx.selection.isRehearsal,
      !employee.capabilityGrants.contains("web-research")
    {
      return blockForHelp(
        state,
        outcomeID: outcomeID,
        taskID: taskID,
        employeeID: employee.id,
        request:
          "I need read-only web research permission to complete ‘\(state.tasks[taskIndex].title)’. Grant that capability or ask me to revise the plan.",
        now: ctx.now
      )
    }

    state.tasks[taskIndex].status = .doing
    state.tasks[taskIndex].updatedAt = ctx.now
    state.setEmployee(employee.id, status: .working, taskID: taskID)
    _ = state.updateEmployeeOutcome(outcomeID, now: ctx.now) { $0.status = .working }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: employee.id,
        kind: .started,
        message: "I started ticket \(state.tasks[taskIndex].title).",
        createdAt: ctx.now
      ))
    if ctx.persistsTransitions { try await ctx.store.save(state) }

    let request = EmployeeWorkRequest(
      operation: operation(for: state.tasks[taskIndex].kind, feedback: ctx.feedback),
      employee: employee,
      task: state.tasks[taskIndex],
      organizationName: state.name,
      outcome: outcome.outcome,
      productBrief: state.productBrief,
      context: await context(
        for: outcome, in: state, store: ctx.store, feedback: ctx.feedback?.promptContext),
      memory: state.recentMemoryContext(for: employee.id),
      skills: state.assignedSkills(employeeID: employee.id).filter {
        outcome.selectedSkillIDs.contains($0.id)
      },
      capabilityGrants: ctx.authorizedCapabilities.map { Array($0).sorted() }
        ?? employee.capabilityGrants,
      workspaceURL: ctx.store.employeeHomeURL(employeeID: employee.id)
    )
    try FileManager.default.createDirectory(
      at: request.workspaceURL, withIntermediateDirectories: true)

    // Whether this ticket is real web research is a property of the resolved
    // runtime and the grant the request actually carries, so a rehearsal can
    // never record that a capability was exercised.
    let usesWebResearch = !ctx.selection.isRehearsal && request.canUseWebResearch
    let (output, content) = try await performTicketWork(
      request,
      usesWebResearch: usesWebResearch,
      state: &state,
      ctx: ctx
    )

    let kind = artifactKind(for: state.tasks[taskIndex].kind)
    let artifactID = "\(taskID)-artifact"
    let relativePath = LocalOrganizationStore.artifactPath(
      employeeID: employee.id,
      taskID: taskID,
      kind: kind
    )
    try await ctx.store.writeArtifact(relativePath: relativePath, content: content)
    if !state.artifacts.contains(where: { $0.id == artifactID }) {
      state.artifacts.append(
        Artifact(
          id: artifactID,
          title: output.title,
          kind: kind,
          relativePath: relativePath,
          authorID: employee.id,
          taskID: taskID,
          createdAt: ctx.now,
          evidenceBasis: output.evidenceBasis
        ))
    }
    if usesWebResearch {
      state.appendCapabilityEvent(
        .succeeded, capability: "web-research", employeeID: employee.id, taskID: taskID,
        detail: "Research evidence was saved to \(relativePath).", now: ctx.now)
    }
    state.tasks[taskIndex].status = .done
    state.tasks[taskIndex].updatedAt = ctx.now
    if !state.tasks[taskIndex].artifactIDs.contains(artifactID) {
      state.tasks[taskIndex].artifactIDs.append(artifactID)
    }
    _ = state.updateEmployeeOutcome(outcomeID, now: ctx.now) { value in
      if !value.artifactIDs.contains(artifactID) { value.artifactIDs.append(artifactID) }
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: employee.id,
        kind: .progress,
        message: "I finished \(state.tasks[taskIndex].title) and saved \(output.title).",
        createdAt: ctx.now
      ))
    if ctx.persistsTransitions { try await ctx.store.save(state) }
    return nil
  }

  private func completeDelivery(
    outcomeID: String,
    finishedOutcome: EmployeeOutcome,
    employee: Employee,
    state: inout OrganizationState,
    now: Date
  ) {
    let artifactCount = finishedOutcome.artifactIDs.count
    let summary =
      "Delivered \(finishedOutcome.taskIDs.count) tickets and \(artifactCount) local artifact\(artifactCount == 1 ? "" : "s"). Review the work and decide the next outcome."
    let evidenceBasis = Array(
      Set(
        finishedOutcome.artifactIDs.compactMap { artifactID in
          state.artifacts.first { $0.id == artifactID }?.evidenceBasis
        })
    ).sorted().joined(separator: ", ")
    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .delivered
      value.helpRequest = nil
      value.deliverySummary = summary
      value.deliveries =
        value.effectiveDeliveries + [
          OutcomeDelivery(
            summary: summary,
            artifactIDs: value.artifactIDs,
            evidenceBasis: evidenceBasis,
            limitations: "No external write or publishing was attempted.",
            recommendedNextAction:
              "Review the artifacts, then accept the delivery or request one bounded revision.",
            deliveredByEmployeeID: employee.id,
            createdAt: now
          )
        ]
      value.outcomeRevision = value.effectiveRevision + 1
    }
    state.setEmployee(employee.id, status: .resting, taskID: nil)
    state.knowledge?.memoryEntries.append(
      EmployeeMemoryEntry(
        id: UUID().uuidString,
        employeeID: employee.id,
        authorID: employee.id,
        dayNumber: state.dayNumber,
        summary:
          "Owned ‘\(finishedOutcome.outcome)’ using \(finishedOutcome.selectedSkillIDs.joined(separator: ", ")) and delivered \(artifactCount) artifacts.",
        sourceArtifactID: finishedOutcome.artifactIDs.last,
        createdAt: now
      ))
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: employee.id,
        kind: .completed,
        message: "I delivered the outcome. \(summary)",
        createdAt: now
      ))
  }

  private func createPlan(
    outcome: EmployeeOutcome,
    employee: Employee,
    state: OrganizationState,
    runner: any EmployeeRunner,
    store: LocalOrganizationStore,
    now: Date,
    authorizedCapabilities: Set<String>?
  ) async throws -> EmployeeWorkOutput {
    let planTask = WorkTask(
      id: "\(outcome.id)-plan",
      title: "Plan \(outcome.outcome)",
      detail: "Choose assigned skills and create one to four sequential tickets.",
      kind: .analysis,
      status: .doing,
      assigneeID: employee.id,
      reviewerID: nil,
      dependencyIDs: [],
      artifactIDs: [],
      revisionCount: 0,
      maxRevisions: 0,
      updatedAt: now
    )
    return try await runner.perform(
      EmployeeWorkRequest(
        operation: .plan,
        employee: employee,
        task: planTask,
        organizationName: state.name,
        outcome: outcome.outcome,
        productBrief: state.productBrief,
        context: outcome.context,
        memory: state.recentMemoryContext(for: employee.id),
        skills: state.assignedSkills(employeeID: employee.id),
        capabilityGrants: authorizedCapabilities.map { Array($0).sorted() }
          ?? employee.capabilityGrants,
        workspaceURL: store.employeeHomeURL(employeeID: employee.id)
      ))
  }

  private func apply(
    plan: EmployeeWorkOutput,
    to outcomeID: String,
    state: inout OrganizationState,
    now: Date
  ) throws {
    guard let outcome = state.employeeOutcome(outcomeID),
      (1...Self.maximumTickets).contains(plan.proposedTasks.count)
    else { throw EmployeeOutcomeError.invalidPlan }

    let assigned = Set(state.assignedSkills(employeeID: outcome.assigneeID).map(\.id))
    let proposed = Set(plan.selectedSkillIDs + plan.proposedTasks.flatMap(\.skillIDs))
    guard proposed.isSubset(of: assigned) else { throw EmployeeOutcomeError.invalidPlan }
    var selected = Array(proposed)
    if assigned.contains("communication"), !selected.contains("communication") {
      selected.append("communication")
    }
    guard !selected.isEmpty else { throw EmployeeOutcomeError.noAssignedSkills }

    var previousTaskID: String?
    var taskIDs: [String] = []
    for (index, proposal) in plan.proposedTasks.enumerated() {
      let title = proposal.title.trimmingCharacters(in: .whitespacesAndNewlines)
      let detail = proposal.detail.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty, !detail.isEmpty else { throw EmployeeOutcomeError.invalidPlan }
      let taskID = "\(outcomeID)-task-\(index + 1)"
      taskIDs.append(taskID)
      state.tasks.append(
        WorkTask(
          id: taskID,
          title: title,
          detail: detail,
          kind: proposal.kind,
          status: index == 0 ? .ready : .waiting,
          assigneeID: outcome.assigneeID,
          reviewerID: nil,
          dependencyIDs: previousTaskID.map { [$0] } ?? [],
          artifactIDs: [],
          revisionCount: 0,
          maxRevisions: 0,
          updatedAt: now,
          accountableEmployeeID: outcome.assigneeID,
          requiredSkillIDs: proposal.skillIDs,
          requiredConnectionIDs: proposal.skillIDs.flatMap {
            state.skill($0)?.requiredConnectionIDs ?? []
          },
          workRevision: 0
        ))
      previousTaskID = taskID
    }
    let requiresReview = state.workingContract(for: outcome.assigneeID)?.reviewPolicy == .always
    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.selectedSkillIDs = selected.sorted()
      value.taskIDs = taskIDs
      value.planStatus = requiresReview ? .proposed : .approved
      value.status = requiresReview ? .proposed : .approved
      value.outcomeRevision = value.effectiveRevision + 1
    }
    if state.employeeOutcome(outcomeID)?.status == .proposed {
      if let employeeIndex = state.employees.firstIndex(where: { $0.id == outcome.assigneeID }) {
        state.employees[employeeIndex].status = .waiting
        state.employees[employeeIndex].currentTaskID = nil
      }
      state.knowledge?.supervisionEvents.append(
        SupervisionEvent(
          kind: .planProposed, actorID: outcome.assigneeID, employeeID: outcome.assigneeID,
          outcomeID: outcomeID,
          message: "Proposed a \(taskIDs.count)-ticket plan for owner review.", createdAt: now))
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: outcome.assigneeID,
        kind: .progress,
        message:
          "I created \(taskIDs.count) tickets and selected \(selected.compactMap { state.skill($0)?.name }.sorted().joined(separator: ", ")).",
        createdAt: now
      ))
  }

  /// Pins the resolved runtime to the commitment and records the model and the
  /// rule that chose it. Rules 5 and 6.
  ///
  /// A commitment that is already pinned keeps its pin: the resolver has already
  /// preserved it, and rewriting it here would let a later contract edit move
  /// work that is mid-flight.
  private func pinRuntime(
    _ selection: ResolvedRuntimeSelection,
    to outcomeID: String,
    state: inout OrganizationState,
    now: Date
  ) {
    guard state.employeeOutcome(outcomeID)?.runtime == nil else { return }
    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.runtime = CommitmentRuntime(
        kind: selection.driverKind.rawValue,
        modelName: selection.model.recordedName,
        selectionRule: selection.rule.rawValue
      )
    }
  }

  /// Stops a commitment because it has no runtime to run on.
  ///
  /// Waiting rather than failing, because nothing went wrong with the work: the
  /// owner can install a runtime, name a different one, or deliberately choose a
  /// rehearsal, and the commitment resumes.
  private func blockForRuntime(
    _ input: OrganizationState,
    outcomeID: String,
    employeeID: String,
    refusal: RuntimeSelectionRefusal?,
    now: Date
  ) -> OrganizationState {
    blockForOwner(
      input,
      outcomeID: outcomeID,
      employeeID: employeeID,
      reason: refusal?.reason
        ?? "No runtime could be selected for this employee, so nothing was run.",
      blockerID: "\(outcomeID)-runtime",
      blockerTitle: "\(input.employee(employeeID)?.name ?? "This employee") has no runtime",
      now: now
    )
  }

  /// Stops a commitment before any work is attempted, because something only
  /// the owner can supply is missing.
  ///
  /// Waiting rather than failing, because nothing went wrong with the work: the
  /// owner supplies what is missing and the commitment resumes.
  private func blockForOwner(
    _ input: OrganizationState,
    outcomeID: String,
    employeeID: String,
    reason: String,
    blockerID: String,
    blockerTitle: String,
    now: Date
  ) -> OrganizationState {
    var state = input
    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .waiting
      value.helpRequest = reason
      value.outcomeRevision = value.effectiveRevision + 1
    }
    // A blocker is attached to a ticket, so one is raised only when the
    // commitment has a ticket to attach it to. When it does not, the
    // commitment's own help request is the honest surface and inventing a
    // ticket id to hang a blocker on would be worse than not having one.
    if let index = state.blockers.firstIndex(where: { $0.id == blockerID }) {
      state.blockers[index].detail = reason
      state.blockers[index].resolved = false
    } else if let taskID = state.employeeOutcome(outcomeID)?.taskIDs.first {
      state.blockers.append(
        Blocker(
          id: blockerID,
          title: blockerTitle,
          detail: reason,
          employeeID: employeeID,
          taskID: taskID,
          createdAt: now,
          resolved: false
        ))
    }
    state.setEmployee(employeeID, status: .blocked, taskID: nil)
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: employeeID,
        kind: .blocked,
        message: reason,
        createdAt: now
      ))
    return state
  }

  private func blockForHelp(
    _ input: OrganizationState,
    outcomeID: String,
    taskID: String,
    employeeID: String,
    request: String,
    now: Date
  ) -> OrganizationState {
    var state = input
    if let taskIndex = state.tasks.firstIndex(where: { $0.id == taskID }) {
      state.tasks[taskIndex].status = .blocked
      state.tasks[taskIndex].updatedAt = now
    }
    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .waiting
      value.helpRequest = request
    }
    state.setEmployee(employeeID, status: .blocked, taskID: taskID)
    let blockerID = "\(outcomeID)-help"
    if let blockerIndex = state.blockers.firstIndex(where: { $0.id == blockerID }) {
      state.blockers[blockerIndex].detail = request
      state.blockers[blockerIndex].resolved = false
    } else {
      state.blockers.append(
        Blocker(
          id: blockerID,
          title: "\(state.employee(employeeID)?.name ?? "Employee") needs your help",
          detail: request,
          employeeID: employeeID,
          taskID: taskID,
          createdAt: now,
          resolved: false
        ))
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: employeeID,
        kind: .blocked,
        message: request,
        createdAt: now
      ))
    return state
  }

  private func fail(
    _ input: OrganizationState,
    outcomeID: String,
    employeeID: String,
    error: Error,
    now: Date
  ) -> OrganizationState {
    var state = input
    let detail = error.localizedDescription
    let waitsForRuntime: Bool
    if let runnerError = error as? CodexRunnerError, case .unavailable = runnerError {
      waitsForRuntime = true
    } else {
      waitsForRuntime = false
    }
    _ = state.updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = waitsForRuntime ? .waiting : .failed
      value.helpRequest = "I could not continue: \(detail)"
    }
    if let currentTaskID = state.employee(employeeID)?.currentTaskID,
      let taskIndex = state.tasks.firstIndex(where: { $0.id == currentTaskID })
    {
      state.tasks[taskIndex].status = .blocked
      state.tasks[taskIndex].updatedAt = now
    }
    state.setEmployee(
      employeeID, status: .blocked, taskID: state.employee(employeeID)?.currentTaskID)
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: employeeID,
        kind: .blocked,
        message: "I could not continue. \(detail)",
        createdAt: now
      ))
    return state
  }

  /// Runs one ticket on the resolved runtime and returns output that is allowed
  /// to become an artifact.
  ///
  /// The capability the work exercises is announced before the runtime is
  /// called and its outcome recorded after, so an interrupted or refused run is
  /// still attributed rather than silently dropped.
  private func performTicketWork(
    _ request: EmployeeWorkRequest,
    usesWebResearch: Bool,
    state: inout OrganizationState,
    ctx: RunContext
  ) async throws -> (output: EmployeeWorkOutput, content: String) {
    let employee = request.employee
    let taskID = request.task.id
    if usesWebResearch {
      // Written before the work, so an interrupted run still shows that the
      // capability was exercised rather than only appearing once it succeeded.
      state.appendCapabilityEvent(
        .started, capability: "web-research", employeeID: employee.id, taskID: taskID,
        detail: "\(employee.name) started permitted web research.", now: ctx.now)
      if ctx.persistsTransitions { try await ctx.store.save(state) }
    }
    do {
      let output = try await ctx.runner.perform(request)
      let content = output.content.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !content.isEmpty else { throw CodexRunnerError.emptyOutput }
      try verifyEvidence(content, operation: request.operation, ctx: ctx)
      return (output, content)
    } catch {
      if usesWebResearch {
        state.appendCapabilityEvent(
          Self.failureEvent(for: error), capability: "web-research", employeeID: employee.id,
          taskID: taskID, detail: error.localizedDescription, now: ctx.now)
      }
      throw error
    }
  }

  /// Reads the local feedback inbox for a commitment a recurring duty owns.
  ///
  /// The references and exclusions are recorded on the occurrence before any
  /// work runs, so the coverage the duty history reports is what was read
  /// rather than a claim about it. Returns `nil` when no duty owns the
  /// commitment, and when the inbox itself could not be read — an unreadable
  /// inbox is not the same as an empty one, and inventing an empty capture
  /// would report coverage that was never measured.
  private func captureDutyInputs(
    outcome: EmployeeOutcome,
    store: LocalOrganizationStore,
    state: inout OrganizationState,
    now: Date
  ) async -> FeedbackInputSnapshot? {
    guard outcome.effectiveSource == .recurringResponsibility,
      let occurrenceID = outcome.sourceID,
      state.dutyOccurrence(occurrenceID) != nil,
      let snapshot = try? await store.captureFeedbackSnapshot()
    else { return nil }
    _ = state.updateDutyOccurrence(occurrenceID, now: now) { value in
      value.includedInputs = snapshot.references
      value.excludedInputs = snapshot.exclusions
    }
    return snapshot
  }

  /// Refuses work whose claimed evidence cannot be checked.
  ///
  /// Real research is accepted only when it carries the required sections and
  /// at least one reachable `http(s)` URL under its own Sources heading. A real
  /// Customer Voice brief is accepted only when it carries its own required
  /// sections and cites at least one of the feedback labels it was handed.
  /// Non-empty output is evidence of neither. A rehearsal reaches no network
  /// and analyzes nothing, so nothing there is verified.
  private func verifyEvidence(
    _ content: String,
    operation: WorkOperation,
    ctx: RunContext
  ) throws {
    guard !ctx.selection.isRehearsal else { return }
    switch operation {
    case .research:
      guard ResearchEvidenceVerifier.hasRequiredSections(content) else {
        throw ResearchAssignmentRunError.incompleteBrief
      }
      guard ResearchEvidenceVerifier.containsSourceURL(content) else {
        throw ResearchAssignmentRunError.missingSourceReference
      }
    case .customerVoice:
      guard CustomerVoiceEvidenceVerifier.hasRequiredSections(content) else {
        throw CustomerVoiceDutyError.incompleteBrief
      }
      guard
        CustomerVoiceEvidenceVerifier.containsValidSourceLabel(
          content, references: ctx.feedback?.references ?? [])
      else { throw CustomerVoiceDutyError.missingSourceLabel }
    case .plan, .analysis, .draft, .revise, .review, .report:
      return
    }
  }

  /// A runtime that was never there did not fail at research; it was missing.
  private static func failureEvent(for error: Error) -> CapabilityEventKind {
    if case .unavailable? = error as? CodexRunnerError { return .unavailable }
    return .failed
  }

  private func context(
    for outcome: EmployeeOutcome,
    in state: OrganizationState,
    store: LocalOrganizationStore,
    feedback: String?
  ) async -> String {
    var sections = [outcome.context].filter { !$0.isEmpty }
    if let feedback { sections.append(feedback) }
    for artifactID in outcome.artifactIDs {
      guard let artifact = state.artifacts.first(where: { $0.id == artifactID }),
        let content = try? await store.readArtifact(relativePath: artifact.relativePath)
      else { continue }
      sections.append("Prior ticket artifact — \(artifact.title):\n\(content)")
    }
    return sections.joined(separator: "\n\n")
  }

  /// What operation a ticket runs as.
  ///
  /// An analysis ticket on a commitment that captured the feedback inbox is the
  /// Customer Voice review itself: it is the only work handed
  /// `<feedback_source>` blocks, and the only work the citation rule is about.
  /// Naming it here is what reaches both the structured brief instruction in
  /// the runner and the `[F1]` check, the same way #72 keyed the research brief
  /// off the ticket's kind rather than off a spelling of its identifier.
  private func operation(for kind: TaskKind, feedback: FeedbackInputSnapshot?) -> WorkOperation {
    if kind == .analysis, feedback != nil { return .customerVoice }
    switch kind {
    case .research: return .research
    case .draft: return .draft
    case .report: return .report
    case .analysis: return .analysis
    }
  }

  private func artifactKind(for kind: TaskKind) -> ArtifactKind {
    switch kind {
    case .research: .research
    case .draft: .draft
    case .report: .report
    case .analysis: .analysis
    }
  }

}
