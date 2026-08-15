import Foundation

/// What a binding resolves to: a usable driver, or a named reason it is not.
public enum RuntimeResolution: Sendable {
  case resolved(any RuntimeDriver)
  case unavailable(RuntimeUnavailableShadow)

  public var driver: (any RuntimeDriver)? {
    if case .resolved(let driver) = self { return driver }
    return nil
  }

  public var shadow: RuntimeUnavailableShadow? {
    if case .unavailable(let shadow) = self { return shadow }
    return nil
  }
}

/// An employee whose runtime cannot be used, kept visible instead of being
/// silently replaced by a different runtime.
public struct RuntimeUnavailableShadow: Sendable, Equatable {
  public enum Cause: Sendable, Equatable {
    case driverNotInstalled(RuntimeDriverKind)
    case driverOlderThanBinding(installed: Int, required: Int)
    case misconfigured(String)
    case unhealthy(String)
  }

  public var employeeID: String
  public var bindingID: String
  public var driverKind: RuntimeDriverKind
  public var cause: Cause

  public init(
    employeeID: String, bindingID: String, driverKind: RuntimeDriverKind, cause: Cause
  ) {
    self.employeeID = employeeID
    self.bindingID = bindingID
    self.driverKind = driverKind
    self.cause = cause
  }

  /// Owner-readable explanation. The employee is intact; only its runtime is not.
  public var reason: String {
    switch cause {
    case .driverNotInstalled(let kind):
      "The ‘\(kind.rawValue)’ runtime is not installed on this Mac, so this employee cannot work yet."
    case .driverOlderThanBinding(let installed, let required):
      "This employee is bound to runtime contract version \(required); the installed runtime supports version \(installed). Update Office OS."
    case .misconfigured(let detail):
      "This employee's runtime is not configured correctly: \(detail)"
    case .unhealthy(let detail):
      "This employee's runtime is not responding: \(detail)"
    }
  }
}

/// Resolves runtime bindings to drivers.
///
/// Resolution failure is reported per employee. One driver being missing or
/// unhealthy never affects an employee bound to a different driver, and never
/// substitutes a different runtime for the one the owner chose.
public actor RuntimeDriverRegistry {
  private var drivers: [RuntimeDriverKind: any RuntimeDriver] = [:]

  public init(drivers: [any RuntimeDriver] = []) {
    for driver in drivers { self.drivers[driver.kind] = driver }
  }

  public func register(_ driver: any RuntimeDriver) {
    drivers[driver.kind] = driver
  }

  public func unregister(_ kind: RuntimeDriverKind) {
    drivers[kind] = nil
  }

  public var registeredKinds: Set<RuntimeDriverKind> { Set(drivers.keys) }

  public func driver(for kind: RuntimeDriverKind) -> (any RuntimeDriver)? { drivers[kind] }

  public func resolve(_ binding: RuntimeBinding) async -> RuntimeResolution {
    func shadow(_ cause: RuntimeUnavailableShadow.Cause) -> RuntimeResolution {
      .unavailable(
        RuntimeUnavailableShadow(
          employeeID: binding.employeeID,
          bindingID: binding.id,
          driverKind: binding.driverKind,
          cause: cause
        ))
    }

    guard let driver = drivers[binding.driverKind] else {
      return shadow(.driverNotInstalled(binding.driverKind))
    }
    guard driver.version >= binding.driverVersion else {
      return shadow(
        .driverOlderThanBinding(installed: driver.version, required: binding.driverVersion))
    }
    do {
      try driver.validate(binding.configuration)
    } catch {
      return shadow(.misconfigured(error.localizedDescription))
    }
    if case .unavailable(let reason) = await driver.availability() {
      return shadow(.unhealthy(reason))
    }
    return .resolved(driver)
  }
}
