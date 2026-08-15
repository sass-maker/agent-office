import Foundation
import XCTest

@testable import AgentOfficeCore

final class RuntimePresenceTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_000)

  private func organization() -> OrganizationState {
    var state = LocalOrganizationStore.migrated(.seeded(now: start), now: start)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    return state
  }

  private func session(
    id: String = "session-1",
    employeeID: String = "theo",
    commitmentID: String? = nil,
    at now: Date? = nil
  ) -> RuntimeSessionPresence {
    RuntimeSessionPresence(
      id: id,
      employeeID: employeeID,
      bindingID: "binding-\(employeeID)",
      commitmentID: commitmentID,
      startedAt: now ?? start
    )
  }

  // MARK: - Registration and lifecycle

  func testRegisteringASessionLeavesTheEmployeeAlone() {
    var state = organization()
    let employeeBefore = state.employee("theo")
    let contractBefore = state.workingContract(for: "theo")

    state.registerRuntimeSession(session())

    XCTAssertEqual(state.runtimeSessions.count, 1)
    XCTAssertEqual(state.runtimeSession("session-1")?.state, .starting)
    XCTAssertEqual(state.employee("theo"), employeeBefore)
    XCTAssertEqual(state.workingContract(for: "theo"), contractBefore)
  }

  func testTwoSessionsForOneEmployeeAreTrackedSeparately() {
    var state = organization()
    state.registerRuntimeSession(session(id: "session-1"))
    state.registerRuntimeSession(session(id: "session-2"))

    XCTAssertEqual(state.liveRuntimeSessions(for: "theo").count, 2)
    XCTAssertEqual(Set(state.runtimeSessions.map(\.id)), ["session-1", "session-2"])
  }

  func testHeartbeatRecordsWhatTheSessionIsActuallyDoing() {
    var state = organization()
    state.registerRuntimeSession(session())

    XCTAssertTrue(
      state.recordRuntimeHeartbeat(
        sessionID: "session-1", state: .waiting, at: start.addingTimeInterval(30)))

    XCTAssertEqual(state.runtimeSession("session-1")?.state, .waiting)
    XCTAssertEqual(
      state.runtimeSession("session-1")?.lastHeartbeatAt, start.addingTimeInterval(30))
  }

  func testGracefulEndKeepsTheSessionsHistory() {
    var state = organization()
    state.registerRuntimeSession(session())

    XCTAssertTrue(
      state.endRuntimeSession(
        sessionID: "session-1", at: start.addingTimeInterval(60), reason: "Finished the turn."))

    let stored = state.runtimeSession("session-1")
    XCTAssertEqual(stored?.state, .stopped)
    XCTAssertEqual(stored?.endedAt, start.addingTimeInterval(60))
    XCTAssertEqual(stored?.startedAt, start)
    XCTAssertEqual(stored?.note, "Finished the turn.")
  }

  // MARK: - Reconciliation

  func testStaleHeartbeatBecomesUnreachable() {
    var state = organization()
    state.registerRuntimeSession(session())

    let lost = state.reconcileRuntimePresence(now: start.addingTimeInterval(600), timeout: 90)

    XCTAssertEqual(lost, ["session-1"])
    XCTAssertEqual(state.runtimeSession("session-1")?.state, .unreachable)
  }

  func testFreshHeartbeatIsNotConsideredLost() {
    var state = organization()
    state.registerRuntimeSession(session())
    _ = state.recordRuntimeHeartbeat(sessionID: "session-1", at: start.addingTimeInterval(580))

    let lost = state.reconcileRuntimePresence(now: start.addingTimeInterval(600), timeout: 90)

    XCTAssertTrue(lost.isEmpty)
    XCTAssertEqual(state.runtimeSession("session-1")?.state, .working)
  }

  func testReconciliationIsIdempotent() {
    var state = organization()
    state.registerRuntimeSession(session())

    let first = state.reconcileRuntimePresence(now: start.addingTimeInterval(600), timeout: 90)
    let second = state.reconcileRuntimePresence(now: start.addingTimeInterval(900), timeout: 90)

    XCTAssertEqual(first, ["session-1"])
    XCTAssertTrue(second.isEmpty)
  }

  // MARK: - Consequences for work

  func testLostRuntimeBlocksWorkWithoutTouchingEmployment() throws {
    var state = organization()
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "", now: start)
    _ = state.updateEmployeeOutcome(commitmentID, now: start) { $0.status = .working }
    state.registerRuntimeSession(session(commitmentID: commitmentID))

    _ = state.reconcileRuntimePresence(now: start.addingTimeInterval(600), timeout: 90)

    // The commitment is blocked and explained, not completed or deleted.
    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.status, .waiting)
    XCTAssertTrue(outcome.helpRequest?.contains("runtime went away") == true)
    XCTAssertEqual(outcome.outcome, "Draft the launch note")

    // Employment is untouched.
    XCTAssertEqual(state.employee("theo")?.effectiveEmploymentState, .hired)
    XCTAssertEqual(state.employee("theo")?.status, .blocked)
  }

  func testLostRuntimeNeverFabricatesADelivery() throws {
    var state = organization()
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft", context: "", now: start)
    _ = state.updateEmployeeOutcome(commitmentID, now: start) { $0.status = .working }
    state.registerRuntimeSession(session(commitmentID: commitmentID))

    _ = state.reconcileRuntimePresence(now: start.addingTimeInterval(600), timeout: 90)

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertNotEqual(outcome.status, .delivered)
    XCTAssertNil(outcome.deliverySummary)
    XCTAssertTrue(outcome.effectiveDeliveries.isEmpty)
  }

  func testADeliveredCommitmentIsNotReopenedByRuntimeLoss() throws {
    var state = organization()
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft", context: "", now: start)
    _ = state.updateEmployeeOutcome(commitmentID, now: start) { value in
      value.status = .delivered
      value.deliverySummary = "Delivered one artifact."
    }
    state.registerRuntimeSession(session(commitmentID: commitmentID))

    _ = state.reconcileRuntimePresence(now: start.addingTimeInterval(600), timeout: 90)

    XCTAssertEqual(state.employeeOutcome(commitmentID)?.status, .delivered)
  }

  // MARK: - Reopening

  func testReopeningStopsSessionsThatNeverEnded() throws {
    var state = organization()
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft", context: "", now: start)
    _ = state.updateEmployeeOutcome(commitmentID, now: start) { $0.status = .working }
    state.registerRuntimeSession(session(commitmentID: commitmentID))
    _ = state.recordRuntimeHeartbeat(sessionID: "session-1", at: start)

    let stopped = state.stopOrphanedRuntimeSessions(now: start.addingTimeInterval(5))

    XCTAssertEqual(stopped, ["session-1"])
    XCTAssertEqual(state.runtimeSession("session-1")?.state, .stopped)
    XCTAssertTrue(
      state.runtimeSession("session-1")?.note?.contains("did not survive") == true)
    XCTAssertEqual(state.employeeOutcome(commitmentID)?.status, .waiting)
    XCTAssertEqual(state.employee("theo")?.effectiveEmploymentState, .hired)
  }

  func testLoadingAnOrganizationStopsOrphanedSessions() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-presence-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var state = organization()
    state.registerRuntimeSession(session())
    _ = state.recordRuntimeHeartbeat(sessionID: "session-1", at: start)
    try await store.save(state)

    let loaded = try await store.loadOrCreate()

    XCTAssertEqual(loaded.runtimeSession("session-1")?.state, .stopped)
  }

  func testPresenceSurvivesEncodingAndDecoding() throws {
    var state = organization()
    state.registerRuntimeSession(session(commitmentID: "commitment-1"))
    _ = state.recordRuntimeHeartbeat(sessionID: "session-1", state: .idle, at: start)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(OrganizationState.self, from: try encoder.encode(state))

    XCTAssertEqual(decoded.runtimeSession("session-1")?.state, .idle)
    XCTAssertEqual(decoded.runtimeSession("session-1")?.commitmentID, "commitment-1")
  }
}
