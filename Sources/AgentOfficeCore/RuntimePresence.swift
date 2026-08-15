import Foundation

/// Whether an employee's runtime is alive, and what it is doing.
///
/// Deliberately not derived from work state: a commitment can look busy while
/// the process that was working on it no longer exists.
public enum RuntimePresenceState: String, Codable, Sendable, CaseIterable {
  case starting
  case working
  case idle
  case waiting
  /// The heartbeat aged past its timeout. Nothing is assumed about the work.
  case unreachable
  case stopped

  public var isAlive: Bool {
    switch self {
    case .starting, .working, .idle, .waiting: true
    case .unreachable, .stopped: false
    }
  }
}

/// One runtime session, tracked separately from the employee that owns it.
public struct RuntimeSessionPresence: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var employeeID: String
  public var bindingID: String
  public var commitmentID: String?
  public var state: RuntimePresenceState
  public var startedAt: Date
  public var lastHeartbeatAt: Date
  public var endedAt: Date?
  public var note: String?

  public init(
    id: String,
    employeeID: String,
    bindingID: String,
    commitmentID: String? = nil,
    startedAt: Date,
    state: RuntimePresenceState = .starting,
    note: String? = nil
  ) {
    self.id = id
    self.employeeID = employeeID
    self.bindingID = bindingID
    self.commitmentID = commitmentID
    self.state = state
    self.startedAt = startedAt
    self.lastHeartbeatAt = startedAt
    self.endedAt = nil
    self.note = note
  }

  public func hasStaleHeartbeat(now: Date, timeout: TimeInterval) -> Bool {
    state.isAlive && now.timeIntervalSince(lastHeartbeatAt) > timeout
  }
}

extension OrganizationState {
  /// How long a session may go without a heartbeat before it counts as lost.
  public static let runtimeHeartbeatTimeout: TimeInterval = 90

  public var runtimeSessions: [RuntimeSessionPresence] { knowledge?.runtimeSessions ?? [] }

  public func runtimeSession(_ id: String) -> RuntimeSessionPresence? {
    runtimeSessions.first { $0.id == id }
  }

  public func liveRuntimeSessions(for employeeID: String) -> [RuntimeSessionPresence] {
    runtimeSessions.filter { $0.employeeID == employeeID && $0.state.isAlive }
  }

  @discardableResult
  public mutating func registerRuntimeSession(_ presence: RuntimeSessionPresence)
    -> RuntimeSessionPresence
  {
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    if let index = knowledge?.runtimeSessions.firstIndex(where: { $0.id == presence.id }) {
      knowledge?.runtimeSessions[index] = presence
    } else {
      knowledge?.runtimeSessions.append(presence)
    }
    return presence
  }

  /// Records that a session is still alive, and what it is doing.
  @discardableResult
  public mutating func recordRuntimeHeartbeat(
    sessionID: String, state: RuntimePresenceState = .working, at now: Date
  ) -> Bool {
    guard let index = knowledge?.runtimeSessions.firstIndex(where: { $0.id == sessionID })
    else { return false }
    knowledge?.runtimeSessions[index].lastHeartbeatAt = now
    knowledge?.runtimeSessions[index].state = state
    if state.isAlive { knowledge?.runtimeSessions[index].endedAt = nil }
    return true
  }

  @discardableResult
  public mutating func endRuntimeSession(
    sessionID: String, at now: Date, reason: String? = nil
  ) -> Bool {
    guard let index = knowledge?.runtimeSessions.firstIndex(where: { $0.id == sessionID })
    else { return false }
    knowledge?.runtimeSessions[index].state = .stopped
    knowledge?.runtimeSessions[index].endedAt = now
    knowledge?.runtimeSessions[index].note = reason
    return true
  }

  /// Marks sessions whose heartbeat has aged out as unreachable, and blocks the
  /// work they were doing.
  ///
  /// Deterministic and idempotent. It never completes, retries, or deletes
  /// anything: losing a runtime is a decision for the owner, and the honest
  /// intermediate state is "blocked because the runtime went away".
  @discardableResult
  public mutating func reconcileRuntimePresence(
    now: Date, timeout: TimeInterval = OrganizationState.runtimeHeartbeatTimeout
  ) -> [String] {
    guard knowledge != nil else { return [] }
    var lost: [String] = []
    for index in knowledge!.runtimeSessions.indices {
      let session = knowledge!.runtimeSessions[index]
      guard session.hasStaleHeartbeat(now: now, timeout: timeout) else { continue }
      knowledge!.runtimeSessions[index].state = .unreachable
      knowledge!.runtimeSessions[index].note =
        "The runtime stopped responding. Nothing was completed on its behalf."
      lost.append(session.id)
      blockWork(for: session, now: now)
    }
    return lost
  }

  /// Stops sessions that never ended, which is what a reopen always means: a
  /// process cannot outlive the app that hosted it.
  @discardableResult
  public mutating func stopOrphanedRuntimeSessions(now: Date) -> [String] {
    guard knowledge != nil else { return [] }
    var stopped: [String] = []
    for index in knowledge!.runtimeSessions.indices {
      let session = knowledge!.runtimeSessions[index]
      guard session.state.isAlive else { continue }
      knowledge!.runtimeSessions[index].state = .stopped
      knowledge!.runtimeSessions[index].endedAt = now
      knowledge!.runtimeSessions[index].note =
        "This session did not survive the app closing. Its work was not completed."
      stopped.append(session.id)
      blockWork(for: session, now: now)
    }
    return stopped
  }

  // MARK: - Internals

  private mutating func blockWork(for session: RuntimeSessionPresence, now: Date) {
    guard let commitmentID = session.commitmentID,
      let outcome = employeeOutcome(commitmentID),
      !outcome.status.isTerminal,
      outcome.status != .delivered
    else { return }
    _ = updateEmployeeOutcome(commitmentID, now: now) { value in
      value.status = .waiting
      value.helpRequest =
        "\(session.employeeID)'s runtime went away before this finished. Nothing was delivered; decide whether to resume it."
      value.outcomeRevision = value.effectiveRevision + 1
    }
    if let employeeIndex = employees.firstIndex(where: { $0.id == session.employeeID }) {
      employees[employeeIndex].status = .blocked
      employees[employeeIndex].currentTaskID = nil
    }
  }
}
