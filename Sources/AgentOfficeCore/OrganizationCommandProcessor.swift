import Foundation

/// The one path a consequential organization change travels, whether the owner
/// or an employee runtime asked for it.
///
/// The processor owns attribution, ordering, idempotency, and history. It does
/// not own validation: every command applies through the same domain mutating
/// function the app already calls, so there is exactly one set of rules.
public struct OrganizationCommandProcessor: Sendable {
  public let journal: OrganizationJournal

  public init(journal: OrganizationJournal) {
    self.journal = journal
  }

  /// Applies a command and records it, or returns the recorded result when this
  /// idempotency key was already accepted.
  @discardableResult
  public func submit(
    _ command: OrganizationCommand,
    to state: inout OrganizationState
  ) throws -> OrganizationCommandResult {
    if let recorded = try journal.recordedEvent(idempotencyKey: command.idempotencyKey) {
      return OrganizationCommandResult(
        eventID: recorded.id,
        sequence: recorded.sequence,
        producedIDs: recorded.producedIDs,
        wasAlreadyApplied: true
      )
    }

    try Self.authorize(command)

    var candidate = state
    let application = try Self.apply(
      command.payload,
      identifierSeed: command.id,
      now: command.issuedAt,
      to: &candidate
    )

    let event = try journal.append(
      { sequence in
        OrganizationEvent(
          id: command.id,
          sequence: sequence,
          schemaVersion: OrganizationJournal.schemaVersion,
          type: command.payload.eventType,
          actor: command.actor,
          occurredAt: command.issuedAt,
          correlationID: command.correlationID,
          causationID: command.causationID,
          idempotencyKey: command.idempotencyKey,
          entities: application.entities,
          payload: command.payload,
          producedIDs: application.producedIDs
        )
      },
      now: command.issuedAt
    )

    candidate.journalSequence = event.sequence
    state = candidate
    return OrganizationCommandResult(
      eventID: event.id,
      sequence: event.sequence,
      producedIDs: application.producedIDs,
      wasAlreadyApplied: false
    )
  }

  /// Rebuilds state from a snapshot plus the events recorded after it.
  ///
  /// Replay reuses the same handlers as live application, so a handler cannot
  /// drift from the history it wrote.
  public func replay(
    from snapshot: OrganizationState,
    events: [OrganizationEvent]
  ) throws -> OrganizationState {
    var state = snapshot
    for event in events {
      _ = try Self.apply(
        event.payload,
        identifierSeed: event.id,
        now: event.occurredAt,
        to: &state
      )
      state.journalSequence = event.sequence
    }
    return state
  }

  /// Rebuilds state from a snapshot plus everything the journal recorded after
  /// the sequence that snapshot corresponds to.
  public func replayFromJournal(startingAt snapshot: OrganizationState) throws -> OrganizationState
  {
    let events = try journal.events(after: snapshot.journalSequence ?? 0)
    return try replay(from: snapshot, events: events)
  }

  private static func decisionMessage(_ receipt: RuntimeDecisionReceipt) -> String {
    let subject = receipt.capabilityID ?? "a question"
    switch receipt.resolution {
    case .allowed(let scope):
      return "You allowed \(subject) for \(receipt.employeeID) (\(scope.rawValue))."
    case .denied(let reason):
      return "You refused \(subject) for \(receipt.employeeID): \(reason)"
    case .answered:
      return "You answered \(receipt.employeeID)'s question."
    case .contractRevisionRequested:
      return "\(receipt.employeeID) needs a working-contract revision for \(subject)."
    }
  }

  // MARK: - Authority

  private static func authorize(_ command: OrganizationCommand) throws {
    switch command.payload {
    case .assignEmployeeOutcome:
      guard command.actor.isOwner else {
        throw OrganizationCommandError.unauthorizedActor(
          actor: command.actor.id, commandType: command.payload.eventType)
      }
    case .applyEmployeeRunResult(let result):
      guard case .employeeRuntime(let employeeID, _) = command.actor else {
        throw OrganizationCommandError.unauthorizedActor(
          actor: command.actor.id, commandType: command.payload.eventType)
      }
      guard employeeID == result.employeeID else {
        throw OrganizationCommandError.actorMismatch(
          claimed: employeeID, actual: result.employeeID)
      }
    case .recordRuntimeDecision, .superviseCommitment, .decideEmployment,
      .reviseWorkingContract:
      // Supervision and authority are the owner's. A runtime cannot approve
      // itself, accept its own delivery, answer its own help request, or widen
      // its own contract, skills, connections or grants.
      guard command.actor.isOwner else {
        throw OrganizationCommandError.unauthorizedActor(
          actor: command.actor.id, commandType: command.payload.eventType)
      }
    }
  }

  // MARK: - Application

  private struct Application {
    var producedIDs: [String] = []
    var entities: [OrganizationEntityReference] = []
  }

  private static func apply(
    _ payload: OrganizationCommandPayload,
    identifierSeed: String,
    now: Date,
    to state: inout OrganizationState
  ) throws -> Application {
    switch payload {
    case .assignEmployeeOutcome(let request):
      let outcomeID = try state.createEmployeeOutcome(
        employeeID: request.employeeID,
        outcome: request.outcome,
        context: request.context,
        acceptanceCriteria: request.acceptanceCriteria,
        priority: request.priority,
        now: now,
        identifierSeed: identifierSeed
      )
      return Application(
        producedIDs: [outcomeID],
        entities: [.employee(request.employeeID), .commitment(outcomeID)]
      )

    case .applyEmployeeRunResult(let result):
      try state.apply(result)
      var entities: [OrganizationEntityReference] = [
        .employee(result.employeeID), .commitment(result.outcomeID),
      ]
      entities.append(contentsOf: result.tasks.map { .task($0.id) })
      entities.append(contentsOf: result.artifacts.map { .artifact($0.id) })
      return Application(producedIDs: [], entities: entities)

    case .recordRuntimeDecision(let receipt):
      // The decision is history, not a state mutation: authority itself lives
      // in contracts and grants, which this deliberately does not touch.
      state.activity.append(
        Activity(
          id: "runtime-decision-\(receipt.requestID)",
          actorID: "owner",
          kind: .approved,
          message: Self.decisionMessage(receipt),
          createdAt: now
        ))
      return Application(
        producedIDs: [],
        entities: [.employee(receipt.employeeID), .commitment(receipt.commitmentID)]
      )

    case .superviseCommitment(let decision):
      let assigneeID = state.employeeOutcome(decision.commitmentID)?.assigneeID
      try state.apply(decision, now: now)
      var entities: [OrganizationEntityReference] = [.commitment(decision.commitmentID)]
      if let assigneeID { entities.append(.employee(assigneeID)) }
      return Application(producedIDs: [], entities: entities)

    case .decideEmployment(let decision):
      let produced = try state.apply(decision, now: now)
      let employeeIDs = (produced + [decision.employeeID].compactMap { $0 })
      return Application(
        producedIDs: produced,
        entities: employeeIDs.map { .employee($0) }
      )

    case .reviseWorkingContract(let revision):
      try state.apply(revision, now: now)
      // The connections the contract declares are named too, so the owner can
      // read how a connection came to be part of somebody's work.
      return Application(
        producedIDs: [],
        entities: [.employee(revision.employeeID)]
          + revision.declaredConnectionIDs.map { .connection($0) }
      )
    }
  }
}
