import Foundation

/// How long an approval lasts. None of these become a durable grant.
public enum RuntimeApprovalScope: String, Codable, Sendable, CaseIterable {
  case once
  case occurrence
  case commitment
}

/// What a runtime is asking for.
public enum RuntimeAccessNeed: Codable, Sendable, Equatable {
  /// Permission to invoke a tool or external capability.
  case capability(id: String, action: String)
  /// A question whose answer is required to continue safely.
  case question(prompt: String)

  public var capabilityID: String? {
    if case .capability(let id, _) = self { return id }
    return nil
  }

  public var isQuestion: Bool {
    if case .question = self { return true }
    return false
  }
}

/// Where a request came from, and therefore what it may be resolved against.
public struct RuntimeAccessOrigin: Codable, Sendable, Equatable {
  public var employeeID: String
  public var bindingID: String
  public var sessionID: String
  public var commitmentID: String
  public var occurrenceID: String?

  public init(
    employeeID: String,
    bindingID: String,
    sessionID: String,
    commitmentID: String,
    occurrenceID: String? = nil
  ) {
    self.employeeID = employeeID
    self.bindingID = bindingID
    self.sessionID = sessionID
    self.commitmentID = commitmentID
    self.occurrenceID = occurrenceID
  }
}

/// What a runtime says about the action it wants to take.
///
/// Redaction happens here, when the context is built, rather than when it is
/// displayed — a credential must not reach a receipt written before anyone
/// renders it.
public struct RuntimeAccessContext: Codable, Sendable, Equatable {
  /// Sanitized. Never the raw arguments a runtime proposed.
  public var inputSummary: String
  public var riskNote: String
  /// References to configured connections. Never credential values.
  public var connectionHandles: [String]
  /// What the provider suggested the owner should do. Recorded, never applied.
  public var providerSuggestedAlwaysAllow: Bool

  public init(
    inputSummary: String = "",
    riskNote: String = "",
    connectionHandles: [String] = [],
    providerSuggestedAlwaysAllow: Bool = false
  ) {
    self.inputSummary = RuntimeSecretRedaction.redact(inputSummary)
    self.riskNote = RuntimeSecretRedaction.redact(riskNote)
    self.connectionHandles = connectionHandles
    self.providerSuggestedAlwaysAllow = providerSuggestedAlwaysAllow
  }

  public static let empty = RuntimeAccessContext()
}

/// One runtime request for permission or for a human answer.
public struct RuntimeAccessRequest: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var origin: RuntimeAccessOrigin
  public var need: RuntimeAccessNeed
  public var context: RuntimeAccessContext
  public var requestedScope: RuntimeApprovalScope
  public var createdAt: Date
  public var expiresAt: Date

  public init(
    id: String = UUID().uuidString,
    origin: RuntimeAccessOrigin,
    need: RuntimeAccessNeed,
    context: RuntimeAccessContext = .empty,
    requestedScope: RuntimeApprovalScope = .once,
    createdAt: Date = Date(),
    expiresAfter: TimeInterval = 300
  ) {
    self.id = id
    self.origin = origin
    self.need = need
    self.context = context
    self.requestedScope = requestedScope
    self.createdAt = createdAt
    self.expiresAt = createdAt.addingTimeInterval(expiresAfter)
  }

  public var inputSummary: String { context.inputSummary }
  public var connectionHandles: [String] { context.connectionHandles }
  public var providerSuggestedAlwaysAllow: Bool { context.providerSuggestedAlwaysAllow }

  public func hasExpired(at now: Date) -> Bool { now >= expiresAt }

  /// A request with no capability, no question, or a blank one, is malformed.
  public var isMalformed: Bool {
    switch need {
    case .capability(let id, let action):
      id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .question(let prompt):
      prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
}

/// How a request was settled.
public enum RuntimeAccessResolution: Codable, Sendable, Equatable {
  case denied(reason: String)
  case answered(String)
  case allowed(scope: RuntimeApprovalScope)
  case contractRevisionRequested(reason: String)

  public var isAllowed: Bool {
    if case .allowed = self { return true }
    return false
  }

  public var deniedReason: String? {
    if case .denied(let reason) = self { return reason }
    return nil
  }
}

/// Redacts secret-shaped content so it cannot enter a request, receipt, or log.
public enum RuntimeSecretRedaction {
  static let placeholder = "[redacted]"

  private static let patterns = [
    #"sk-[A-Za-z0-9_\-]{8,}"#,
    #"(?i)bearer\s+[A-Za-z0-9._\-]{8,}"#,
    #"(?i)(api[_\- ]?key|secret|password|token)\s*[:=]\s*\S+"#,
    #"gh[pousr]_[A-Za-z0-9]{8,}"#,
  ]

  public static func redact(_ text: String) -> String {
    var result = text
    for pattern in patterns {
      guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
      result = expression.stringByReplacingMatches(
        in: result,
        range: NSRange(result.startIndex..., in: result),
        withTemplate: placeholder
      )
    }
    return result
  }
}
