import Foundation

/// Which runtime software, at which contract version.
public struct RuntimeDriverIdentity: Codable, Sendable, Equatable {
  public var kind: RuntimeDriverKind
  /// Contract version this was created against. A host whose driver is older
  /// reports incompatibility instead of running.
  public var version: Int

  public init(kind: RuntimeDriverKind, version: Int) {
    self.kind = kind
    self.version = version
  }
}

/// Where a runtime session left off. Opaque to Office OS and never employee
/// memory.
public struct RuntimeResumeState: Codable, Sendable, Equatable {
  public var cursor: String
  public var sessionID: String?

  public init(cursor: String, sessionID: String? = nil) {
    self.cursor = cursor
    self.sessionID = sessionID
  }
}

/// What an employee ran on before its current binding.
public struct RuntimeBindingProvenance: Codable, Sendable, Equatable {
  public var driver: RuntimeDriverIdentity
  public var boundAt: Date
  public var unboundAt: Date
  public var reason: String

  public init(driver: RuntimeDriverIdentity, boundAt: Date, unboundAt: Date, reason: String) {
    self.driver = driver
    self.boundAt = boundAt
    self.unboundAt = unboundAt
    self.reason = reason
  }
}

/// Which runtime an employee currently runs on.
///
/// Deliberately separate from employee identity, package, working contract, and
/// model choice: replacing the runtime an employee works through must never
/// replace the employee or erase what it has done.
public struct RuntimeBinding: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var employeeID: String
  public var driver: RuntimeDriverIdentity
  public var configuration: RuntimeConfiguration
  public var boundAt: Date
  /// Prior runtimes this employee worked through, oldest first.
  public var provenance: [RuntimeBindingProvenance]
  public var resume: RuntimeResumeState?

  public init(
    id: String = UUID().uuidString,
    employeeID: String,
    driver: RuntimeDriverIdentity,
    configuration: RuntimeConfiguration = .empty,
    boundAt: Date = Date(),
    provenance: [RuntimeBindingProvenance] = [],
    resume: RuntimeResumeState? = nil
  ) {
    self.id = id
    self.employeeID = employeeID
    self.driver = driver
    self.configuration = configuration
    self.boundAt = boundAt
    self.provenance = provenance
    self.resume = resume
  }

  public var driverKind: RuntimeDriverKind { driver.kind }
  public var driverVersion: Int { driver.version }

  /// Moves to another runtime, keeping what came before as provenance.
  public func rebound(
    to driver: RuntimeDriverIdentity,
    configuration: RuntimeConfiguration = .empty,
    reason: String,
    now: Date = Date()
  ) -> RuntimeBinding {
    var next = self
    next.provenance.append(
      RuntimeBindingProvenance(
        driver: self.driver, boundAt: boundAt, unboundAt: now, reason: reason))
    next.driver = driver
    next.configuration = configuration
    next.boundAt = now
    // A cursor belongs to the runtime that issued it.
    next.resume = nil
    return next
  }
}

extension OrganizationState {
  public var runtimeBindings: [RuntimeBinding] { knowledge?.runtimeBindings ?? [] }

  public func runtimeBinding(for employeeID: String) -> RuntimeBinding? {
    runtimeBindings.first { $0.employeeID == employeeID }
  }

  /// The binding an employee should run on, derived from its working contract's
  /// execution provider when nothing has been bound explicitly.
  ///
  /// Organizations written before runtime bindings existed get this instead of
  /// a migration that rewrites their state.
  public func effectiveRuntimeBinding(for employeeID: String, now: Date = Date()) -> RuntimeBinding
  {
    if let existing = runtimeBinding(for: employeeID) { return existing }
    let provider = workingContract(for: employeeID)?.executionProvider
    return RuntimeBinding(
      id: "binding-\(employeeID)",
      employeeID: employeeID,
      driver: RuntimeDriverIdentity(
        kind: provider == .localCodex ? .localCodex : .demo, version: 1),
      boundAt: now
    )
  }

  @discardableResult
  public mutating func setRuntimeBinding(_ binding: RuntimeBinding) -> Bool {
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    if let index = knowledge?.runtimeBindings.firstIndex(where: {
      $0.employeeID == binding.employeeID
    }) {
      knowledge?.runtimeBindings[index] = binding
    } else {
      knowledge?.runtimeBindings.append(binding)
    }
    return true
  }

  /// Records where a session finished so the next one can resume.
  @discardableResult
  public mutating func recordRuntimeResume(
    employeeID: String, sessionID: String?, cursor: String?
  ) -> Bool {
    guard var binding = runtimeBinding(for: employeeID) else { return false }
    binding.resume = cursor.map { RuntimeResumeState(cursor: $0, sessionID: sessionID) }
    return setRuntimeBinding(binding)
  }
}
