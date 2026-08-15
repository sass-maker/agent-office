import Foundation

/// Who is asking the organization to change.
///
/// Authority is decided from the actor, never from the command payload, so a
/// runtime cannot widen its own permissions by describing itself differently.
public enum OrganizationActor: Codable, Sendable, Equatable {
  case owner(id: String)
  case employeeRuntime(employeeID: String, sessionID: String?)

  public var id: String {
    switch self {
    case .owner(let id): id
    case .employeeRuntime(let employeeID, _): employeeID
    }
  }

  public var isOwner: Bool {
    if case .owner = self { return true }
    return false
  }
}

/// The consequential change a command asks for.
public enum OrganizationCommandPayload: Codable, Sendable, Equatable {
  /// The owner asks an employee to own an outcome.
  case assignEmployeeOutcome(AssignEmployeeOutcome)
  /// An employee runtime hands finished work back to the organization.
  case applyEmployeeRunResult(EmployeeOutcomeRunResult)

  public struct AssignEmployeeOutcome: Codable, Sendable, Equatable {
    public var employeeID: String
    public var outcome: String
    public var context: String
    public var acceptanceCriteria: [String]
    public var priority: EmployeeOutcomePriority

    public init(
      employeeID: String,
      outcome: String,
      context: String,
      acceptanceCriteria: [String] = [],
      priority: EmployeeOutcomePriority = .normal
    ) {
      self.employeeID = employeeID
      self.outcome = outcome
      self.context = context
      self.acceptanceCriteria = acceptanceCriteria
      self.priority = priority
    }
  }

  /// Stable event type recorded in the journal.
  public var eventType: String {
    switch self {
    case .assignEmployeeOutcome: "employee-outcome.assigned"
    case .applyEmployeeRunResult: "employee-outcome.run-result-applied"
    }
  }
}

/// A consequential change, addressed to the organization by one actor.
public struct OrganizationCommand: Codable, Sendable, Equatable {
  public var id: String
  public var actor: OrganizationActor
  public var payload: OrganizationCommandPayload
  /// Stable across retries of the same intent. Two submissions sharing a key
  /// are the same command, and the second one applies nothing.
  public var idempotencyKey: String
  /// Groups every command and event belonging to one owner intent.
  public var correlationID: String
  /// The event this command was caused by, when it is a follow-on.
  public var causationID: String?
  public var issuedAt: Date

  public init(
    id: String = UUID().uuidString,
    actor: OrganizationActor,
    payload: OrganizationCommandPayload,
    idempotencyKey: String,
    correlationID: String? = nil,
    causationID: String? = nil,
    issuedAt: Date = Date()
  ) {
    self.id = id
    self.actor = actor
    self.payload = payload
    self.idempotencyKey = idempotencyKey
    self.correlationID = correlationID ?? id
    self.causationID = causationID
    self.issuedAt = issuedAt
  }
}

/// What an accepted command produced.
public struct OrganizationCommandResult: Sendable, Equatable {
  public var eventID: String
  public var sequence: Int
  /// Identifiers the command created, in creation order.
  public var producedIDs: [String]
  /// True when the command had already been accepted under this idempotency
  /// key and nothing was applied a second time.
  public var wasAlreadyApplied: Bool

  public init(eventID: String, sequence: Int, producedIDs: [String], wasAlreadyApplied: Bool) {
    self.eventID = eventID
    self.sequence = sequence
    self.producedIDs = producedIDs
    self.wasAlreadyApplied = wasAlreadyApplied
  }

  /// The commitment a command created, when it created one.
  public var commitmentID: String? { producedIDs.first }
}

public enum OrganizationCommandError: LocalizedError, Equatable {
  case unauthorizedActor(actor: String, commandType: String)
  case actorMismatch(claimed: String, actual: String)
  case rejected(reason: String)

  public var errorDescription: String? {
    switch self {
    case .unauthorizedActor(let actor, let commandType):
      "\(actor) is not authorized to run \(commandType). The command was not applied."
    case .actorMismatch(let claimed, let actual):
      "A runtime acting as \(claimed) tried to submit work for \(actual). The command was not applied."
    case .rejected(let reason):
      reason
    }
  }
}
