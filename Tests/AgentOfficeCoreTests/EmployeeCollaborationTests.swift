import Foundation
import XCTest

@testable import AgentOfficeCore

/// Two different third-party runtimes, so a collaboration genuinely crosses
/// providers rather than reusing one driver twice.
private struct ScriptedRuntimeDriver: RuntimeDriver {
  let kind: RuntimeDriverKind
  let version = 1
  let declaredCapabilities: Set<RuntimeCapability> = [.planning, .execution, .review]
  let answer: String

  func availability() async -> RuntimeAvailability { .available }

  func openSession(employeeID: String, bindingID: String, sessionID: String) async throws
    -> any RuntimeSession
  {
    ScriptedSession(
      sessionID: sessionID, bindingID: bindingID, employeeID: employeeID, answer: answer)
  }
}

private actor SessionLedger {
  static let shared = SessionLedger()
  private var employees: [String] = []
  func note(_ employeeID: String) { employees.append(employeeID) }
  func recorded() -> [String] { employees }
  func reset() { employees = [] }
}

private struct ScriptedSession: RuntimeSession {
  let sessionID: String
  let bindingID: String
  let employeeID: String
  let answer: String

  func run(_ turn: RuntimeTurn) async throws -> RuntimeTurnResult {
    guard turn.employeeID == employeeID else {
      throw RuntimeSessionError.employeeMismatch(expected: employeeID, found: turn.employeeID)
    }
    await SessionLedger.shared.note(employeeID)
    return RuntimeTurnResult(
      output: EmployeeWorkOutput(
        title: "Consultation", summary: answer, content: turn.work.outcome))
  }

  func interrupt() async {}
  func stop() async {}
}

final class EmployeeCollaborationTests: XCTestCase {
  private let niaDriver = RuntimeDriverKind("test.nia-runtime")
  private let theoDriver = RuntimeDriverKind("test.theo-runtime")

  override func setUp() async throws {
    try await super.setUp()
    await SessionLedger.shared.reset()
  }

  // MARK: - Fixtures

  private func organization() throws -> (state: OrganizationState, commitmentID: String) {
    var state = LocalOrganizationStore.migrated(
      .seeded(now: Date(timeIntervalSince1970: 1_000)), now: Date(timeIntervalSince1970: 1_000))
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    // Theo owns the commitment and runs on one runtime; Nia advises from another.
    state.setRuntimeBinding(
      RuntimeBinding(
        id: "binding-theo", employeeID: "theo",
        driver: RuntimeDriverIdentity(kind: theoDriver, version: 1)))
    state.setRuntimeBinding(
      RuntimeBinding(
        id: "binding-nia", employeeID: "nia",
        driver: RuntimeDriverIdentity(kind: niaDriver, version: 1)))
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "")
    return (state, commitmentID)
  }

  private func registry() -> RuntimeDriverRegistry {
    RuntimeDriverRegistry(drivers: [
      ScriptedRuntimeDriver(kind: niaDriver, answer: "Three sources agree on the claim."),
      ScriptedRuntimeDriver(kind: theoDriver, answer: "Theo should not be answering this."),
    ])
  }

  private func request(
    commitmentID: String,
    operation: CollaborationOperation = .consultation(question: "Which sources back this claim?"),
    source: String = "theo",
    target: String = "nia",
    chain: [String] = [],
    correlationID: String = "collaboration-1",
    deadline: Date = Date(timeIntervalSince1970: 9_000),
    turnBudget: Int = 1,
    offeredCapabilities: [String] = []
  ) -> CollaborationRequest {
    CollaborationRequest(
      id: "request-1",
      correlationID: correlationID,
      source: CollaborationSource(
        employeeID: source,
        sessionID: "session-source",
        chain: chain,
        offeredCapabilities: offeredCapabilities
      ),
      targetEmployeeID: target,
      operation: operation,
      context: CollaborationContext(commitmentID: commitmentID, note: "Launch note claims."),
      budget: CollaborationBudget(deadline: deadline, turns: turnBudget)
    )
  }

  private var now: Date { Date(timeIntervalSince1970: 2_000) }

  // MARK: - Directory

  func testDirectoryExcludesTheRequesterAndUnhiredCoworkers() throws {
    var fixture = try organization()
    try fixture.state.pauseEmployee("nia", now: now)

    let directory = fixture.state.collaborationDirectory(
      for: "theo", commitmentID: fixture.commitmentID)

    XCTAssertFalse(directory.contains { $0.id == "theo" })
    XCTAssertFalse(directory.contains { $0.id == "nia" })
    XCTAssertTrue(directory.allSatisfy { $0.supportedOperations.contains("consultation") })
  }

  func testDirectoryMarksABusyCoworkerUnavailableWithASafeReason() throws {
    var fixture = try organization()
    let niaCommitment = try fixture.state.createEmployeeOutcome(
      employeeID: "nia", outcome: "Research the market", context: "")
    _ = fixture.state.updateEmployeeOutcome(niaCommitment) { $0.status = .working }

    let entry = fixture.state.collaborationDirectory(
      for: "theo", commitmentID: fixture.commitmentID
    ).first { $0.id == "nia" }

    XCTAssertEqual(entry?.isAvailable, false)
    XCTAssertTrue(entry?.availabilityNote.contains("own commitment") == true)
  }

  func testDirectoryIsEmptyForSomeoneElsesCommitment() throws {
    let fixture = try organization()
    XCTAssertTrue(
      fixture.state.collaborationDirectory(for: "nia", commitmentID: fixture.commitmentID).isEmpty)
  }

  // MARK: - Consultation across two runtimes

  func testConsultationRunsOnTheTargetsOwnRuntimeAndIsRecorded() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    let outcome = try await broker.consult(
      request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)

    XCTAssertEqual(outcome.respondingEmployeeID, "nia")
    XCTAssertEqual(outcome.summary, "Three sources agree on the claim.")
    XCTAssertFalse(outcome.wasAlreadyCompleted)

    // The target ran itself. The source's runtime never answered for it.
    let sessions = await SessionLedger.shared.recorded()
    XCTAssertEqual(sessions, ["nia"])

    let messages =
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveManagementMessages ?? []
    XCTAssertEqual(messages.count, 1)
    XCTAssertEqual(messages[0].actorID, "nia")
    XCTAssertTrue(messages[0].message.contains("Three sources agree"))
    XCTAssertTrue(fixture.state.activity.contains { $0.actorID == "theo" && $0.kind == .handoff })
  }

  func testConsultationDoesNotMoveTheWork() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    _ = try await broker.consult(
      request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)

    XCTAssertEqual(fixture.state.employeeOutcome(fixture.commitmentID)?.assigneeID, "theo")
    XCTAssertEqual(
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveAccountableEmployeeID, "theo")
  }

  func testTargetReceivesOnlyTheQuestionAndPermittedReferences() async throws {
    var fixture = try organization()
    fixture.state.activity.append(
      Activity(
        id: "unrelated", actorID: "maya", kind: .progress,
        message: "Unrelated organization history that must not travel.",
        createdAt: Date(timeIntervalSince1970: 500)))
    let broker = EmployeeCollaborationBroker(registry: registry())

    let outcome = try await broker.consult(
      request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)

    // The scripted session echoes the outcome it was handed as content.
    XCTAssertFalse(outcome.summary.contains("Unrelated organization history"))
    let messages =
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveManagementMessages ?? []
    XCTAssertFalse(messages.contains { $0.message.contains("Unrelated organization history") })
  }

  // MARK: - Proposals

  func testDelegationProposalIsRecordedButChangesNothing() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    let outcome = try await broker.proposeDelegation(
      request(
        commitmentID: fixture.commitmentID,
        operation: .delegationProposal(
          commitmentID: fixture.commitmentID, reason: "Nia has the sources")),
      organization: &fixture.state, now: now)

    XCTAssertTrue(outcome.summary.contains("nothing has moved"))
    XCTAssertEqual(fixture.state.employeeOutcome(fixture.commitmentID)?.assigneeID, "theo")
    let sessions = await SessionLedger.shared.recorded()
    XCTAssertTrue(sessions.isEmpty, "a proposal must not run anyone's runtime")
    let messages =
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveManagementMessages ?? []
    XCTAssertEqual(messages.count, 1)
  }

  // MARK: - Containment

  func testSelfCallIsRejected() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    await assertRejects(
      try await broker.consult(
        request(commitmentID: fixture.commitmentID, target: "theo"),
        organization: &fixture.state, now: now),
      .selfCall)
    let sessions = await SessionLedger.shared.recorded()
    XCTAssertTrue(sessions.isEmpty)
  }

  func testSecondHopIsRejected() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    await assertRejects(
      try await broker.consult(
        request(commitmentID: fixture.commitmentID, chain: ["maya"]),
        organization: &fixture.state, now: now),
      .depthExceeded(maximum: 1))
  }

  func testCycleIsRejected() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    await assertRejects(
      try await broker.consult(
        request(commitmentID: fixture.commitmentID, target: "nia", chain: ["nia"]),
        organization: &fixture.state, now: now),
      .cycle(employeeID: "nia"))
  }

  func testBorrowedCapabilitiesAreRejected() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    await assertRejects(
      try await broker.consult(
        request(commitmentID: fixture.commitmentID, offeredCapabilities: ["web-research"]),
        organization: &fixture.state, now: now),
      .borrowedCapabilities(["web-research"]))
    let sessions = await SessionLedger.shared.recorded()
    XCTAssertTrue(sessions.isEmpty)
  }

  func testExpiredRequestIsRejected() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    await assertRejects(
      try await broker.consult(
        request(commitmentID: fixture.commitmentID, deadline: Date(timeIntervalSince1970: 1_500)),
        organization: &fixture.state, now: now),
      .expired)
  }

  func testExhaustedTurnBudgetIsRejected() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    await assertRejects(
      try await broker.consult(
        request(commitmentID: fixture.commitmentID, turnBudget: 0),
        organization: &fixture.state, now: now),
      .exhaustedTurnBudget)
  }

  func testBusyTargetIsRejectedWithItsReason() async throws {
    var fixture = try organization()
    let niaCommitment = try fixture.state.createEmployeeOutcome(
      employeeID: "nia", outcome: "Research the market", context: "")
    _ = fixture.state.updateEmployeeOutcome(niaCommitment) { $0.status = .working }
    let broker = EmployeeCollaborationBroker(registry: registry())

    do {
      _ = try await broker.consult(
        request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)
      XCTFail("a busy target must not be forced")
    } catch let rejection as CollaborationRejection {
      guard case .targetUnavailable(let reason) = rejection else {
        return XCTFail("expected an availability rejection, got \(rejection)")
      }
      XCTAssertTrue(reason.contains("own commitment"))
    }
  }

  func testMissingRuntimeIsReportedRatherThanSubstituted() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(
      registry: RuntimeDriverRegistry(drivers: [
        ScriptedRuntimeDriver(kind: theoDriver, answer: "wrong runtime")
      ]))

    do {
      _ = try await broker.consult(
        request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)
      XCTFail("a missing runtime must not fall back to another employee's driver")
    } catch let rejection as CollaborationRejection {
      guard case .targetUnavailable(let reason) = rejection else {
        return XCTFail("expected an availability rejection, got \(rejection)")
      }
      XCTAssertTrue(reason.contains("test.nia-runtime"))
    }
  }

  // MARK: - Idempotency

  func testRepeatedCorrelationIdentifierReturnsTheFirstResult() async throws {
    var fixture = try organization()
    let broker = EmployeeCollaborationBroker(registry: registry())

    let first = try await broker.consult(
      request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)
    let second = try await broker.consult(
      request(commitmentID: fixture.commitmentID), organization: &fixture.state, now: now)

    XCTAssertFalse(first.wasAlreadyCompleted)
    XCTAssertTrue(second.wasAlreadyCompleted)
    XCTAssertEqual(second.summary, first.summary)
    let sessions = await SessionLedger.shared.recorded()
    XCTAssertEqual(sessions, ["nia"], "a retry must not run the target twice")
    let messages =
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveManagementMessages ?? []
    XCTAssertEqual(messages.count, 1)
  }

  // MARK: - Helpers

  private func assertRejects(
    _ expression: @autoclosure () async throws -> CollaborationOutcome,
    _ expected: CollaborationRejection,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    do {
      _ = try await expression()
      XCTFail("expected \(expected)", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? CollaborationRejection, expected, file: file, line: line)
    }
  }
}
