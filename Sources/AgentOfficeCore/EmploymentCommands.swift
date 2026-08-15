import Foundation

/// A consequential decision the owner makes about employment itself.
///
/// Separate from commitment supervision because these change who works here,
/// not what a hired employee is doing.
public enum EmploymentDecision: Codable, Sendable, Equatable {
  case hire(packageID: String, version: String?)
  case pause(employeeID: String)
  case resume(employeeID: String)
  case retire(employeeID: String)

  public var eventType: String {
    switch self {
    case .hire: "employment.hired"
    case .pause: "employment.paused"
    case .resume: "employment.resumed"
    case .retire: "employment.retired"
    }
  }

  public var employeeID: String? {
    switch self {
    case .hire: nil
    case .pause(let id), .resume(let id), .retire(let id): id
    }
  }
}

extension OrganizationState {
  /// Applies an employment decision, returning any identifier it produced.
  ///
  /// The records it writes derive their identifiers from the employee, the kind
  /// of decision, and the timestamp, so a journalled decision replays exactly.
  mutating func apply(_ decision: EmploymentDecision, now: Date) throws -> [String] {
    switch decision {
    case .hire(let packageID, let version):
      return [try hireEmployee(packageID: packageID, version: version, now: now)]
    case .pause(let employeeID):
      try pauseEmployee(employeeID, now: now)
      return []
    case .resume(let employeeID):
      try resumeEmployee(employeeID, now: now)
      return []
    case .retire(let employeeID):
      try retireEmployee(employeeID, now: now)
      return []
    }
  }
}
