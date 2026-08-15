import Foundation
import XCTest

@testable import AgentOfficeCore

final class KnowledgeRetrievalTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_000)

  private func organization() throws -> (state: OrganizationState, commitmentID: String) {
    var state = LocalOrganizationStore.migrated(.seeded(now: start), now: start)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    state.knowledge?.productBrief = "Willow Studio publishes evidence-led launch notes."
    state.knowledge?.memoryEntries = [
      EmployeeMemoryEntry(
        id: "memory-theo", employeeID: "theo", authorID: "theo", dayNumber: 1,
        summary: "Theo learned the launch-note house style.", sourceArtifactID: nil,
        createdAt: start),
      EmployeeMemoryEntry(
        id: "memory-nia", employeeID: "nia", authorID: "nia", dayNumber: 1,
        summary: "Nia keeps a private list of house style sources.", sourceArtifactID: nil,
        createdAt: start),
    ]
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the house style launch note", context: "",
      now: start)
    return (state, commitmentID)
  }

  // MARK: - Scope

  func testAnotherEmployeesMemoryIsNeverReturned() throws {
    let fixture = try organization()

    let results = fixture.state.searchKnowledge("house style", asEmployee: "theo")

    XCTAssertTrue(results.contains { $0.id == "memory-theo" })
    XCTAssertFalse(
      results.contains { $0.id == "memory-nia" }, "a coworker's memory is out of scope")
  }

  func testOwnCommitmentIsReturnedWithItsReason() throws {
    let fixture = try organization()

    let results = fixture.state.searchKnowledge(
      "launch note", asEmployee: "theo", commitmentID: fixture.commitmentID)

    let commitment = try XCTUnwrap(results.first { $0.id == fixture.commitmentID })
    XCTAssertEqual(commitment.provenance.sourceKind, "commitment")
    XCTAssertEqual(
      commitment.provenance.visibleBecause, "This is the commitment being worked on.")
  }

  func testAnotherEmployeesCommitmentIsNotReturned() throws {
    var fixture = try organization()
    _ = try fixture.state.createEmployeeOutcome(
      employeeID: "nia", outcome: "Research house style sources", context: "", now: start)

    let results = fixture.state.searchKnowledge("house style", asEmployee: "theo")

    XCTAssertFalse(results.contains { $0.title.contains("Research house style") })
  }

  func testOrganizationContextIsSharedWithEveryone() throws {
    let fixture = try organization()

    let results = fixture.state.searchKnowledge("evidence-led", asEmployee: "nia")

    let brief = try XCTUnwrap(results.first { $0.id == "product-brief" })
    XCTAssertEqual(
      brief.provenance.visibleBecause, "Organization context is shared with every employee.")
  }

  // MARK: - Provenance

  func testEveryResultCarriesProvenance() throws {
    let fixture = try organization()

    let results = fixture.state.searchKnowledge("house style", asEmployee: "theo")

    XCTAssertFalse(results.isEmpty)
    for result in results {
      XCTAssertFalse(result.provenance.sourceKind.isEmpty)
      XCTAssertFalse(result.provenance.sourceID.isEmpty)
      XCTAssertFalse(result.provenance.visibleBecause.isEmpty)
    }
  }

  func testNoMatchReturnsNothingRatherThanAnUnsourcedAnswer() throws {
    let fixture = try organization()

    XCTAssertTrue(
      fixture.state.searchKnowledge("quarterly revenue forecast", asEmployee: "theo").isEmpty)
    XCTAssertTrue(fixture.state.searchKnowledge("   ", asEmployee: "theo").isEmpty)
  }

  // MARK: - History

  func testHistoryReturnsRetainedEventsInSequenceOrder() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-history-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = OrganizationJournal(
      fileURL: directory.appendingPathComponent("journal.jsonl"))
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = try organization().state

    let assignment = try processor.submit(
      OrganizationCommand(
        id: "command-1",
        actor: .owner(id: "owner"),
        payload: .assignEmployeeOutcome(
          .init(employeeID: "theo", outcome: "Write it", context: "")),
        idempotencyKey: "assign-1",
        issuedAt: start
      ),
      to: &state)
    let commitmentID = try XCTUnwrap(assignment.commitmentID)

    let history = try OrganizationHistoryService(journal: journal)
      .history(of: .commitment(commitmentID))

    XCTAssertEqual(history.map(\.sequence), [1])
    XCTAssertEqual(history.first?.actorID, "owner")
    XCTAssertEqual(history.first?.type, "employee-outcome.assigned")
  }

  func testHistoryOfSomethingWithNoEventsIsEmpty() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-history-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = OrganizationJournal(
      fileURL: directory.appendingPathComponent("journal.jsonl"))

    let history = try OrganizationHistoryService(journal: journal)
      .history(of: .commitment("never-existed"))

    XCTAssertTrue(history.isEmpty)
  }

  // MARK: - Flow evidence

  func testAPhaseThatNeverHappenedIsUnknownRatherThanZero() throws {
    let fixture = try organization()

    let evidence = try XCTUnwrap(
      fixture.state.flowEvidence(forCommitment: fixture.commitmentID))

    guard case .unknown(let reason) = evidence.timeBlocked else {
      return XCTFail("a commitment that was never blocked must not report zero blocked time")
    }
    XCTAssertEqual(reason, "This commitment was never recorded as blocked.")
    XCTAssertNil(evidence.timeBlocked.seconds)
  }

  func testMeasuredTimingNamesWhatItCameFrom() throws {
    var fixture = try organization()
    let taskID = "task-help"
    _ = fixture.state.updateEmployeeOutcome(fixture.commitmentID, now: start) {
      $0.status = .waiting
      $0.helpRequest = "I need a source."
      $0.taskIDs = [taskID]
    }
    fixture.state.blockers.append(
      Blocker(
        id: "blocker-1", title: "Theo needs your help", detail: "I need a source.",
        employeeID: "theo", taskID: taskID, createdAt: start, resolved: false))
    try fixture.state.replyToOutcome(
      fixture.commitmentID, message: "Use the internal archive.", actorID: "owner",
      now: start.addingTimeInterval(600))

    let evidence = try XCTUnwrap(
      fixture.state.flowEvidence(forCommitment: fixture.commitmentID))

    guard case .measured(let seconds, let basis) = evidence.timeBlocked else {
      return XCTFail("a recorded block and reply should be measurable")
    }
    XCTAssertEqual(seconds, 600)
    XCTAssertEqual(basis, "recorded blocker to owner reply")
    XCTAssertGreaterThan(evidence.derivedFromRecordCount, 0)
  }

  func testFlowEvidenceForAnUnknownCommitmentIsNil() throws {
    let fixture = try organization()
    XCTAssertNil(fixture.state.flowEvidence(forCommitment: "never-existed"))
  }
}
