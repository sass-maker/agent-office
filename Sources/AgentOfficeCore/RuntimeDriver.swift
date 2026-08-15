import Foundation

/// A stable identity for a kind of agent runtime, independent of any employee.
public struct RuntimeDriverKind: RawRepresentable, Codable, Sendable, Hashable {
  public var rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(_ rawValue: String) { self.rawValue = rawValue }

  public static let demo = RuntimeDriverKind("office.demo")
  public static let localCodex = RuntimeDriverKind("office.local-codex")
}

/// Optional facilities a driver may support.
///
/// The host asks rather than assumes, so a driver that is not chat-based,
/// process-based, or resumable is still a first-class runtime.
public enum RuntimeCapability: String, Codable, Sendable, CaseIterable {
  case planning
  case execution
  case review
  case interruption
  case resumption
  case toolInvocation
}

/// A configuration value a driver needs.
///
/// Secrets are referenced, never carried. Nothing in the runtime layer reads a
/// secret; resolving a reference is a deliberate owner handoff.
public enum RuntimeConfigurationValue: Codable, Sendable, Equatable {
  case literal(String)
  case secretReference(String)

  public var isSecretReference: Bool {
    if case .secretReference = self { return true }
    return false
  }
}

public struct RuntimeConfiguration: Codable, Sendable, Equatable {
  public var version: Int
  public var values: [String: RuntimeConfigurationValue]

  public init(version: Int = 1, values: [String: RuntimeConfigurationValue] = [:]) {
    self.version = version
    self.values = values
  }

  public static let empty = RuntimeConfiguration()
}

public enum RuntimeConfigurationError: LocalizedError, Equatable {
  case secretValueSuppliedDirectly(field: String)
  case missingRequiredField(String)
  case unsupportedConfigurationVersion(found: Int, supported: Int)

  public var errorDescription: String? {
    switch self {
    case .secretValueSuppliedDirectly(let field):
      "‘\(field)’ must be a reference to a stored secret, not the secret itself."
    case .missingRequiredField(let field):
      "This runtime needs ‘\(field)’ before it can be used."
    case .unsupportedConfigurationVersion(let found, let supported):
      "This runtime was configured for version \(found); the installed driver understands version \(supported)."
    }
  }
}

/// Whether a driver can be used right now, and why not when it cannot.
public enum RuntimeAvailability: Sendable, Equatable {
  case available
  case unavailable(reason: String)

  public var isAvailable: Bool { self == .available }

  public var reason: String? {
    if case .unavailable(let reason) = self { return reason }
    return nil
  }
}

public enum RuntimeSessionError: LocalizedError, Equatable {
  case staleResumeCursor
  case interrupted
  case unsupportedCapability(RuntimeCapability)
  case employeeMismatch(expected: String, found: String)

  public var errorDescription: String? {
    switch self {
    case .staleResumeCursor:
      "The saved runtime position is no longer valid. The next attempt starts a fresh session."
    case .interrupted:
      "The runtime was interrupted before it finished this turn."
    case .unsupportedCapability(let capability):
      "This runtime does not support \(capability.rawValue)."
    case .employeeMismatch(let expected, let found):
      "This runtime session belongs to \(expected) and cannot run work for \(found)."
    }
  }
}

/// What a driver needs in order to run one turn of a commitment.
public struct RuntimeTurn: Sendable {
  public var employeeID: String
  public var bindingID: String
  public var sessionID: String
  public var commitmentID: String
  public var correlationID: String
  public var work: EmployeeWorkRequest
  /// Opaque driver position from a previous session, when resuming.
  public var resumeCursor: String?

  public init(
    employeeID: String,
    bindingID: String,
    sessionID: String,
    commitmentID: String,
    correlationID: String,
    work: EmployeeWorkRequest,
    resumeCursor: String? = nil
  ) {
    self.employeeID = employeeID
    self.bindingID = bindingID
    self.sessionID = sessionID
    self.commitmentID = commitmentID
    self.correlationID = correlationID
    self.work = work
    self.resumeCursor = resumeCursor
  }
}

/// What one turn produced.
public struct RuntimeTurnResult: Sendable {
  public var output: EmployeeWorkOutput
  /// Normalized, ordered evidence about the turn. Not organization history.
  public var events: [RuntimeEvent]
  /// Opaque position to resume from, when the driver supports resumption.
  public var resumeCursor: String?
  /// Provider-native diagnostics, kept separate from normalized evidence and
  /// never treated as organization truth.
  public var rawDiagnostics: String?

  public init(
    output: EmployeeWorkOutput,
    events: [RuntimeEvent] = [],
    resumeCursor: String? = nil,
    rawDiagnostics: String? = nil
  ) {
    self.output = output
    self.events = events
    self.resumeCursor = resumeCursor
    self.rawDiagnostics = rawDiagnostics
  }
}

/// One driver's working session for a single employee and commitment.
public protocol RuntimeSession: Sendable {
  var sessionID: String { get }
  var bindingID: String { get }
  func run(_ turn: RuntimeTurn) async throws -> RuntimeTurnResult
  func interrupt() async
  func stop() async
}

/// The contract an agent runtime implements to be employable.
public protocol RuntimeDriver: Sendable {
  var kind: RuntimeDriverKind { get }
  /// Host-facing contract version. A binding requiring a newer version is
  /// reported as incompatible rather than run against a mismatched contract.
  var version: Int { get }
  var declaredCapabilities: Set<RuntimeCapability> { get }
  /// Configuration fields whose values must be secret references.
  var secretConfigurationFields: Set<String> { get }
  var requiredConfigurationFields: Set<String> { get }

  func availability() async -> RuntimeAvailability
  func openSession(employeeID: String, bindingID: String, sessionID: String) async throws
    -> any RuntimeSession
}

extension RuntimeDriver {
  public var secretConfigurationFields: Set<String> { [] }
  public var requiredConfigurationFields: Set<String> { [] }

  public func supports(_ capability: RuntimeCapability) -> Bool {
    declaredCapabilities.contains(capability)
  }

  /// Rejects configuration that embeds a secret value or omits a required field.
  public func validate(_ configuration: RuntimeConfiguration) throws {
    guard configuration.version <= version else {
      throw RuntimeConfigurationError.unsupportedConfigurationVersion(
        found: configuration.version, supported: version)
    }
    for field in secretConfigurationFields {
      if let value = configuration.values[field], !value.isSecretReference {
        throw RuntimeConfigurationError.secretValueSuppliedDirectly(field: field)
      }
    }
    for field in requiredConfigurationFields where configuration.values[field] == nil {
      throw RuntimeConfigurationError.missingRequiredField(field)
    }
  }
}
