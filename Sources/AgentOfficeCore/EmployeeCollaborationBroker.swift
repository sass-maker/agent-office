import Foundation

/// What a collaboration produced.
public struct CollaborationOutcome: Sendable, Equatable {
  public var requestID: String
  public var correlationID: String
  public var respondingEmployeeID: String
  public var summary: String
  /// True when this returned a previously recorded result instead of running
  /// the target again.
  public var wasAlreadyCompleted: Bool
}

/// Runs bounded, one-hop collaboration between employees on different runtimes.
///
/// The target always runs itself: its own binding, its own contract, its own
/// attribution. The source can ask, and can propose, but cannot borrow authority
/// or move accountability.
public actor EmployeeCollaborationBroker {
  public static let maximumHops = 1

  private let registry: RuntimeDriverRegistry
  private var completed: [String: CollaborationOutcome] = [:]

  public init(registry: RuntimeDriverRegistry) {
    self.registry = registry
  }

  /// Everything that must hold before any work runs.
  ///
  /// Evaluated in one place so a rejected collaboration never opens a session
  /// or spends a turn.
  public func guardRequest(
    _ request: CollaborationRequest,
    organization: OrganizationState,
    now: Date
  ) -> CollaborationRejection? {
    if request.targetEmployeeID == request.sourceEmployeeID { return .selfCall }
    if !request.offeredCapabilities.isEmpty {
      return .borrowedCapabilities(request.offeredCapabilities)
    }
    if request.chain.contains(request.targetEmployeeID) {
      return .cycle(employeeID: request.targetEmployeeID)
    }
    if request.chain.count >= Self.maximumHops {
      return .depthExceeded(maximum: Self.maximumHops)
    }
    if now >= request.budget.deadline { return .expired }
    if request.budget.turns <= 0 { return .exhaustedTurnBudget }
    guard let outcome = organization.employeeOutcome(request.context.commitmentID),
      !outcome.status.isTerminal
    else { return .missingCommitment }

    let directory = organization.collaborationDirectory(
      for: request.sourceEmployeeID, commitmentID: request.context.commitmentID)
    guard let target = directory.first(where: { $0.id == request.targetEmployeeID }) else {
      return .targetNotVisible(request.targetEmployeeID)
    }
    guard target.isAvailable else {
      return .targetUnavailable(reason: target.availabilityNote)
    }
    return nil
  }

  /// Asks the target a bounded question, in the target's own runtime, and
  /// records the answer against the source's commitment.
  public func consult(
    _ request: CollaborationRequest,
    organization: inout OrganizationState,
    now: Date = Date()
  ) async throws -> CollaborationOutcome {
    if let existing = completed[request.correlationID] {
      var replayed = existing
      replayed.wasAlreadyCompleted = true
      return replayed
    }
    guard case .consultation(let question) = request.operation else {
      throw CollaborationRejection.missingCommitment
    }
    if let rejection = guardRequest(request, organization: organization, now: now) {
      throw rejection
    }

    // The target runs on its own binding, never the source's session.
    let binding = organization.effectiveRuntimeBinding(for: request.targetEmployeeID, now: now)
    switch await registry.resolve(binding) {
    case .unavailable(let shadow):
      throw CollaborationRejection.targetUnavailable(reason: shadow.reason)
    case .resolved(let driver):
      let session = try await driver.openSession(
        employeeID: request.targetEmployeeID,
        bindingID: binding.id,
        sessionID: "collaboration-\(request.id)"
      )
      let answer = try await session.run(
        RuntimeTurn(
          employeeID: request.targetEmployeeID,
          bindingID: binding.id,
          sessionID: session.sessionID,
          commitmentID: request.context.commitmentID,
          correlationID: request.correlationID,
          work: try consultationWork(
            question: question, request: request, organization: organization)
        )
      )
      await session.stop()

      let summary = answer.output.summary
      try record(
        message:
          "\(organization.employee(request.targetEmployeeID)?.name ?? request.targetEmployeeID) answered a consultation: \(summary)",
        request: request, organization: &organization, now: now)
      let outcome = CollaborationOutcome(
        requestID: request.id,
        correlationID: request.correlationID,
        respondingEmployeeID: request.targetEmployeeID,
        summary: summary,
        wasAlreadyCompleted: false
      )
      completed[request.correlationID] = outcome
      return outcome
    }
  }

  /// Records a proposal for review. Nothing about assignment, ownership, or
  /// accountability changes here — that stays with the owner's existing flow.
  public func proposeDelegation(
    _ request: CollaborationRequest,
    organization: inout OrganizationState,
    now: Date = Date()
  ) throws -> CollaborationOutcome {
    if let existing = completed[request.correlationID] {
      var replayed = existing
      replayed.wasAlreadyCompleted = true
      return replayed
    }
    guard case .delegationProposal(let commitmentID, let reason) = request.operation else {
      throw CollaborationRejection.missingCommitment
    }
    if let rejection = guardRequest(request, organization: organization, now: now) {
      throw rejection
    }

    let sourceName =
      organization.employee(request.sourceEmployeeID)?.name
      ?? request.sourceEmployeeID
    let targetName =
      organization.employee(request.targetEmployeeID)?.name
      ?? request.targetEmployeeID
    let summary =
      "\(sourceName) proposed moving \(commitmentID) to \(targetName): \(reason). This needs your decision; nothing has moved."
    try record(message: summary, request: request, organization: &organization, now: now)

    let outcome = CollaborationOutcome(
      requestID: request.id,
      correlationID: request.correlationID,
      respondingEmployeeID: request.targetEmployeeID,
      summary: summary,
      wasAlreadyCompleted: false
    )
    completed[request.correlationID] = outcome
    return outcome
  }

  // MARK: - Internals

  /// The work a target receives: the question and permitted references only.
  private func consultationWork(
    question: String,
    request: CollaborationRequest,
    organization: OrganizationState
  ) throws -> EmployeeWorkRequest {
    guard let target = organization.employee(request.targetEmployeeID),
      let outcome = organization.employeeOutcome(request.context.commitmentID)
    else { throw CollaborationRejection.missingCommitment }

    let task = WorkTask(
      id: "consultation-\(request.id)",
      title: "Consultation for \(outcome.outcome)",
      detail: question,
      kind: .analysis,
      status: .ready,
      assigneeID: target.id,
      reviewerID: nil,
      dependencyIDs: [],
      artifactIDs: request.context.artifactIDs,
      revisionCount: 0,
      maxRevisions: 1,
      updatedAt: Date(timeIntervalSince1970: 0)
    )
    return EmployeeWorkRequest(
      operation: .analysis,
      employee: target,
      task: task,
      organizationName: organization.name,
      outcome: question,
      context: request.context.note,
      skills: organization.assignedSkills(employeeID: target.id),
      capabilityGrants: organization.workingContract(for: target.id)?.capabilityGrants ?? [],
      workspaceURL: URL(fileURLWithPath: NSTemporaryDirectory())
    )
  }

  /// Collaboration lands in the records the organization already inspects.
  private func record(
    message: String,
    request: CollaborationRequest,
    organization: inout OrganizationState,
    now: Date
  ) throws {
    guard organization.employeeOutcome(request.context.commitmentID) != nil else {
      throw CollaborationRejection.missingCommitment
    }
    _ = organization.updateEmployeeOutcome(request.context.commitmentID, now: now) { value in
      value.managementMessages =
        value.effectiveManagementMessages + [
          OutcomeManagementMessage(
            id: "collaboration-\(request.id)",
            actorID: request.targetEmployeeID,
            message: message,
            createdAt: now
          )
        ]
    }
    organization.activity.append(
      Activity(
        id: "collaboration-activity-\(request.id)",
        actorID: request.sourceEmployeeID,
        kind: .handoff,
        message: message,
        createdAt: now
      ))
  }
}
