import Foundation

public enum ResearchAssignmentRunError: LocalizedError, Equatable {
  case notRunnable
  case permissionRequired
  case missingEmployee
  case missingSourceReference
  case incompleteBrief

  public var errorDescription: String? {
    switch self {
    case .notRunnable:
      "This research assignment is not ready to run."
    case .permissionRequired:
      "Nia needs the read-only web research grant before starting this assignment."
    case .missingEmployee:
      "Nia or Mira is missing from this organization."
    case .missingSourceReference:
      "The research run returned no source URL, so it was not accepted as researched work."
    case .incompleteBrief:
      "The research brief is missing findings, sources, uncertainty, or recommended next actions."
    }
  }
}

public enum ResearchEvidenceVerifier {
  public static func hasRequiredSections(_ content: String) -> Bool {
    let headings = content.split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { $0.hasPrefix("#") }
    return ["findings", "sources", "uncertainty", "recommended next actions"].allSatisfy {
      required in
      headings.contains { $0.contains(required) }
    }
  }

  public static func containsSourceURL(_ content: String) -> Bool {
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    guard
      let sourcesIndex = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
          .localizedCaseInsensitiveContains("sources") && $0.hasPrefix("#")
      })
    else { return false }

    let sourceLines = lines.dropFirst(sourcesIndex + 1).prefix { line in
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      return !trimmed.hasPrefix("#")
    }
    return
      sourceLines
      .flatMap { $0.split(whereSeparator: { $0.isWhitespace }) }
      .contains { token in
        let value = token.trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}.,;\"'"))
        guard let components = URLComponents(string: value),
          let scheme = components.scheme?.lowercased(),
          scheme == "https" || scheme == "http"
        else { return false }
        return components.host?.isEmpty == false
      }
  }
}

public struct ResearchAssignmentEngine: Sendable {
  public init() {}

  private struct ResearchContext: Sendable {
    let assignmentID: String
    let researcher: Employee
    let assistant: Employee
    let usesWebResearch: Bool
    let store: LocalOrganizationStore
  }

  public func start(
    _ input: OrganizationState,
    assignmentID: String,
    now: Date = Date()
  ) -> OrganizationState {
    guard let assignment = input.researchAssignment(assignmentID),
      assignment.status == .queued,
      let researcher = input.employee(assignment.assigneeID),
      let assistant = input.employee(assignment.reviewerID)
    else { return input }

    var state = input
    let usesWebResearch = state.executionMode == .localCodex
    if usesWebResearch && !state.hasCapability("web-research", employeeID: researcher.id) {
      markWaiting(
        assignmentID,
        reason: ResearchAssignmentRunError.permissionRequired.localizedDescription,
        state: &state,
        now: now
      )
      return state
    }

    _ = state.updateResearchAssignment(assignmentID, now: now) { value in
      value.status = .researching
      value.blockingReason = nil
      value.attemptCount += 1
    }
    state.workdayStatus = .active
    state.setEmployee(researcher.id, status: .working, taskID: assignmentID)
    state.setEmployee(assistant.id, status: .planning, taskID: assignmentID)
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: researcher.id,
        kind: .started,
        message: "Nia started the owner-directed research assignment.",
        createdAt: now
      ))
    if usesWebResearch {
      appendCapabilityEvent(
        kind: .started,
        assignmentID: assignmentID,
        actorID: researcher.id,
        detail: "Nia started permitted web research for the owner-directed assignment.",
        state: &state,
        now: now
      )
    }
    return state
  }

  public func run(
    _ input: OrganizationState,
    assignmentID: String,
    runner: any EmployeeRunner,
    store: LocalOrganizationStore,
    now: Date = Date()
  ) async -> OrganizationState {
    guard let originalAssignment = input.researchAssignment(assignmentID),
      originalAssignment.status == .queued || originalAssignment.status == .researching
    else { return input }

    var state =
      originalAssignment.status == .queued
      ? start(input, assignmentID: assignmentID, now: now)
      : input
    guard let assignment = state.researchAssignment(assignmentID),
      assignment.status == .researching,
      let researcher = state.employee(assignment.assigneeID),
      let assistant = state.employee(assignment.reviewerID)
    else { return state }

    let usesWebResearch = state.executionMode == .localCodex

    let task = WorkTask(
      id: assignmentID,
      title: "Research: \(assignment.outcome)",
      detail: assignment.context.isEmpty
        ? "Investigate the owner's outcome and return a cited research brief."
        : assignment.context,
      kind: .research,
      status: .doing,
      assigneeID: researcher.id,
      reviewerID: assistant.id,
      dependencyIDs: [],
      artifactIDs: [],
      revisionCount: 0,
      maxRevisions: 0,
      updatedAt: now
    )
    let request = EmployeeWorkRequest(
      operation: .research,
      employee: researcher,
      task: task,
      organizationName: state.name,
      outcome: assignment.outcome,
      productBrief: state.productBrief,
      context: assignment.context,
      memory: state.recentMemoryContext(for: researcher.id),
      skills: state.assignedSkills(employeeID: researcher.id),
      capabilityGrants: researcher.capabilityGrants,
      workspaceURL: store.employeeHomeURL(employeeID: researcher.id)
    )

    do {
      try FileManager.default.createDirectory(
        at: request.workspaceURL, withIntermediateDirectories: true)
      let output = try await runner.perform(request)
      try Task.checkCancellation()

      let evidenceBasis = usesWebResearch ? "permitted-web-research" : "synthetic-demo"
      if usesWebResearch {
        guard ResearchEvidenceVerifier.hasRequiredSections(output.content) else {
          throw ResearchAssignmentRunError.incompleteBrief
        }
        guard ResearchEvidenceVerifier.containsSourceURL(output.content) else {
          throw ResearchAssignmentRunError.missingSourceReference
        }
      }

      return try await completeResearch(
        assignment: assignment,
        output: output,
        evidenceBasis: evidenceBasis,
        ctx: ResearchContext(
          assignmentID: assignmentID, researcher: researcher,
          assistant: assistant, usesWebResearch: usesWebResearch, store: store
        ),
        state: &state
      )
    } catch is CancellationError {
      return handleCancellation(
        assignmentID: assignmentID, assistantID: assistant.id, state: &state)
    } catch {
      return handleFailure(
        assignmentID: assignmentID,
        researcherID: researcher.id,
        usesWebResearch: usesWebResearch,
        error: error,
        state: &state
      )
    }
  }

  private func completeResearch(
    assignment: ResearchAssignment,
    output: EmployeeWorkOutput,
    evidenceBasis: String,
    ctx: ResearchContext,
    state: inout OrganizationState
  ) async throws -> OrganizationState {
    let completedAt = Date()
    let brief = Artifact(
      id: UUID().uuidString,
      title: output.title,
      kind: .research,
      relativePath: LocalOrganizationStore.artifactPath(
        employeeID: ctx.researcher.id,
        taskID: ctx.assignmentID,
        kind: .research
      ),
      authorID: ctx.researcher.id,
      taskID: ctx.assignmentID,
      createdAt: completedAt,
      sourceArtifactIDs: [],
      evidenceBasis: evidenceBasis
    )
    let evidenceNotice =
      ctx.usesWebResearch
      ? "This brief used the owner's permitted web-research capability."
      : "This is a synthetic rehearsal. No web research was performed."
    let briefContent = """
      > Evidence basis: `\(evidenceBasis)`
      > \(evidenceNotice)

      \(output.content)
      """
    try await ctx.store.writeArtifact(relativePath: brief.relativePath, content: briefContent)

    let delivery = Artifact(
      id: UUID().uuidString,
      title: "Mira's delivery — \(assignment.outcome)",
      kind: .report,
      relativePath: LocalOrganizationStore.artifactPath(
        employeeID: ctx.assistant.id,
        taskID: ctx.assignmentID,
        kind: .report
      ),
      authorID: ctx.assistant.id,
      taskID: ctx.assignmentID,
      createdAt: completedAt,
      sourceArtifactIDs: [brief.id],
      evidenceBasis: evidenceBasis
    )
    let deliveryContent = """
      # Research delivery

      ## Assignment
      \(assignment.outcome)

      ## Delivered by
      Nia completed the research and Mira prepared this handoff for the owner.

      ## Evidence
      - Basis: `\(evidenceBasis)`
      - Research brief: `\(brief.relativePath)`

      ## Nia's summary
      \(output.summary)

      ## Your next decision
      Read the brief, decide which finding matters most, and use a new assignment for any follow-up research.
      """
    try await ctx.store.writeArtifact(relativePath: delivery.relativePath, content: deliveryContent)

    state.artifacts.append(contentsOf: [brief, delivery])
    state.knowledge?.memoryEntries.append(
      EmployeeMemoryEntry(
        id: UUID().uuidString,
        employeeID: ctx.researcher.id,
        authorID: ctx.researcher.id,
        dayNumber: state.dayNumber,
        summary: output.summary,
        sourceArtifactID: brief.id,
        createdAt: completedAt
      ))
    _ = state.updateResearchAssignment(ctx.assignmentID, now: completedAt) { value in
      value.status = .delivered
      value.blockingReason = nil
      value.evidenceBasis = evidenceBasis
      value.briefArtifactID = brief.id
      value.deliveryArtifactID = delivery.id
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: ctx.researcher.id,
        kind: .handoff,
        message: "Nia delivered the research brief to Mira.",
        createdAt: completedAt
      ))
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: ctx.assistant.id,
        kind: .completed,
        message: "Mira left the verified research delivery on your desk.",
        createdAt: completedAt
      ))
    if ctx.usesWebResearch {
      appendCapabilityEvent(
        kind: .succeeded,
        assignmentID: ctx.assignmentID,
        actorID: ctx.researcher.id,
        detail: "Cited research was verified and saved to \(brief.relativePath).",
        state: &state,
        now: completedAt
      )
    }
    state.restAIEmployees()
    state.workdayStatus = .resting
    return state
  }

  private func handleCancellation(
    assignmentID: String,
    assistantID: String,
    state: inout OrganizationState
  ) -> OrganizationState {
    let stoppedAt = Date()
    _ = state.updateResearchAssignment(assignmentID, now: stoppedAt) { value in
      value.status = .queued
      value.blockingReason = "The run stopped before delivery. It is ready to resume."
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: assistantID,
        kind: .stopped,
        message: "Mira kept Nia's interrupted research ready to resume.",
        createdAt: stoppedAt
      ))
    state.restAIEmployees()
    state.workdayStatus = .resting
    return state
  }

  private func handleFailure(
    assignmentID: String,
    researcherID: String,
    usesWebResearch: Bool,
    error: Error,
    state: inout OrganizationState
  ) -> OrganizationState {
    let failedAt = Date()
    let waitsForRuntime: Bool
    if let codexError = error as? CodexRunnerError, case .unavailable = codexError {
      waitsForRuntime = true
    } else {
      waitsForRuntime = false
    }
    _ = state.updateResearchAssignment(assignmentID, now: failedAt) { value in
      value.status = waitsForRuntime ? .waiting : .failed
      value.blockingReason = error.localizedDescription
    }
    if usesWebResearch {
      appendCapabilityEvent(
        kind: waitsForRuntime ? .unavailable : .failed,
        assignmentID: assignmentID,
        actorID: researcherID,
        detail: error.localizedDescription,
        state: &state,
        now: failedAt
      )
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: researcherID,
        kind: .blocked,
        message: "Nia could not deliver the research: \(error.localizedDescription)",
        createdAt: failedAt
      ))
    state.restAIEmployees()
    state.workdayStatus = .resting
    return state
  }

  private func markWaiting(
    _ assignmentID: String,
    reason: String,
    state: inout OrganizationState,
    now: Date
  ) {
    _ = state.updateResearchAssignment(assignmentID, now: now) { value in
      value.status = .waiting
      value.blockingReason = reason
    }
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "nia",
        kind: .blocked,
        message: reason,
        createdAt: now
      ))
  }

  private func appendCapabilityEvent(
    kind: CapabilityEventKind,
    assignmentID: String,
    actorID: String,
    detail: String,
    state: inout OrganizationState,
    now: Date
  ) {
    state.knowledge?.capabilityEvents.append(
      CapabilityEvent(
        id: UUID().uuidString,
        capability: "web-research",
        employeeID: "nia",
        taskID: assignmentID,
        actorID: actorID,
        kind: kind,
        detail: detail,
        createdAt: now
      ))
  }
}
