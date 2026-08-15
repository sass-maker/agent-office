import Foundation

/// Where a runtime event came from. Validated so one session cannot emit
/// evidence attributed to another.
public struct RuntimeEventOrigin: Codable, Sendable, Equatable {
  public var employeeID: String
  public var bindingID: String
  public var sessionID: String
  public var commitmentID: String?
  public var correlationID: String

  public init(
    employeeID: String,
    bindingID: String,
    sessionID: String,
    commitmentID: String? = nil,
    correlationID: String
  ) {
    self.employeeID = employeeID
    self.bindingID = bindingID
    self.sessionID = sessionID
    self.commitmentID = commitmentID
    self.correlationID = correlationID
  }
}

/// Normalized evidence about what a runtime did.
///
/// This is not organization history. Only the organization journal is
/// authoritative; a runtime that wants to change the organization proposes a
/// command, which is validated and journalled like any other.
public struct RuntimeEvent: Codable, Sendable, Equatable, Identifiable {
  public enum Kind: String, Codable, Sendable {
    case sessionOpened
    case sessionClosed
    case turnStarted
    case turnFinished
    case toolInvoked
    case assistantOutput
    case runtimeRequest
    case usage
    case error
  }

  public var id: String
  public var kind: Kind
  public var origin: RuntimeEventOrigin
  public var occurredAt: Date
  /// Short, owner-readable summary. Provider-native payloads stay in raw
  /// diagnostics so prompts and arguments never become normalized evidence.
  public var summary: String

  public init(
    id: String = UUID().uuidString,
    kind: Kind,
    origin: RuntimeEventOrigin,
    occurredAt: Date = Date(),
    summary: String
  ) {
    self.id = id
    self.kind = kind
    self.origin = origin
    self.occurredAt = occurredAt
    self.summary = summary
  }

  public var employeeID: String { origin.employeeID }
  public var bindingID: String { origin.bindingID }
  public var sessionID: String { origin.sessionID }
  public var commitmentID: String? { origin.commitmentID }
  public var correlationID: String { origin.correlationID }
}

public enum RuntimeEventError: LocalizedError, Equatable {
  case foreignOrigin(expectedBinding: String, expectedSession: String)

  public var errorDescription: String? {
    switch self {
    case .foreignOrigin(let binding, let session):
      "A runtime event claimed an origin other than binding \(binding) session \(session) and was rejected."
    }
  }
}

/// Collects a session's normalized events and refuses any that claim to come
/// from somewhere else.
public struct RuntimeEventLog: Sendable {
  public let bindingID: String
  public let sessionID: String
  private(set) public var events: [RuntimeEvent] = []

  public init(bindingID: String, sessionID: String) {
    self.bindingID = bindingID
    self.sessionID = sessionID
  }

  public mutating func record(_ event: RuntimeEvent) throws {
    guard event.bindingID == bindingID, event.sessionID == sessionID else {
      throw RuntimeEventError.foreignOrigin(
        expectedBinding: bindingID, expectedSession: sessionID)
    }
    events.append(event)
  }
}

/// A change a runtime wants made to the organization.
///
/// The runtime cannot apply this itself. The caller submits it through the
/// organization command boundary, where authority and idempotency are decided.
public struct ProposedOrganizationCommand: Sendable, Equatable {
  public var payload: OrganizationCommandPayload
  public var employeeID: String
  public var sessionID: String
  public var correlationID: String
  public var idempotencyKey: String

  public init(
    payload: OrganizationCommandPayload,
    employeeID: String,
    sessionID: String,
    correlationID: String,
    idempotencyKey: String
  ) {
    self.payload = payload
    self.employeeID = employeeID
    self.sessionID = sessionID
    self.correlationID = correlationID
    self.idempotencyKey = idempotencyKey
  }

  /// Turns the proposal into a command attributed to the employee runtime that
  /// made it. Authority is still decided by the processor.
  public func command() -> OrganizationCommand {
    OrganizationCommand(
      actor: .employeeRuntime(employeeID: employeeID, sessionID: sessionID),
      payload: payload,
      idempotencyKey: idempotencyKey,
      correlationID: correlationID
    )
  }
}
