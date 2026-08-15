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
    }
  }
}
