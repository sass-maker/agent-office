import Foundation

public struct EmployeeOutcomeEngine: Sendable {
  public static let maximumTickets = 4

  public init() {}

  private struct RunContext: Sendable {
    let runner: any EmployeeRunner
    let store: LocalOrganizationStore
    let now: Date
    let persistsTransitions: Bool
    let authorizedCapabilities: Set<String>?
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
    persistsTransitions: Bool = true,
    authorizedCapabilities: Set<String>? = nil
  ) async -> OrganizationState {
    var state = input
    guard var outcome = state.employeeOutcome(outcomeID),
      !outcome.status.isTerminal,
      outcome.status != .delivered,
      outcome.status != .proposed,
      let employee = state.employee(outcome.assigneeID)
    else { return input }

    let ctx = RunContext(
      runner: runner, store: store, now: now,
      persistsTransitions: persistsTransitions,
      authorizedCapabilities: authorizedCapabilities
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

    if state.tasks[taskIndex].kind == .research,
      state.executionMode == .localCodex,
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
      operation: operation(for: state.tasks[taskIndex].kind),
      employee: employee,
      task: state.tasks[taskIndex],
      organizationName: state.name,
      outcome: outcome.outcome,
      productBrief: state.productBrief,
      context: await context(for: outcome, in: state, store: ctx.store),
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
    let output = try await ctx.runner.perform(request)
    let content = output.content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !content.isEmpty else { throw CodexRunnerError.emptyOutput }

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

  private func context(
    for outcome: EmployeeOutcome,
    in state: OrganizationState,
    store: LocalOrganizationStore
  ) async -> String {
    var sections = [outcome.context].filter { !$0.isEmpty }
    for artifactID in outcome.artifactIDs {
      guard let artifact = state.artifacts.first(where: { $0.id == artifactID }),
        let content = try? await store.readArtifact(relativePath: artifact.relativePath)
      else { continue }
      sections.append("Prior ticket artifact — \(artifact.title):\n\(content)")
    }
    return sections.joined(separator: "\n\n")
  }

  private func operation(for kind: TaskKind) -> WorkOperation {
    switch kind {
    case .research: .research
    case .draft: .draft
    case .report: .report
    case .analysis: .analysis
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
