import Foundation
import XCTest

@testable import AgentOfficeCore

final class ScheduledWorkDispatchTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func fixture() throws -> (
    state: OrganizationState, occurrenceID: String, commitmentID: String
  ) {
    var state = LocalOrganizationStore.migrated(.seeded(now: start), now: start)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the weekly note", context: "", now: start)
    state.addSchedulePolicy(
      SchedulePolicy(
        id: "policy-1",
        employeeID: "theo",
        subject: .commitment(commitmentID),
        plan: SchedulePlan(
          recurrence: .oneTime, firstStart: start, expectedDuration: 900, flexibility: 600,
          timeZoneIdentifier: "UTC"),
        createdAt: start
      ))
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start.addingTimeInterval(-1),
      through: start.addingTimeInterval(60))
    return (state, try XCTUnwrap(created.first).id, commitmentID)
  }

  // MARK: - Due windows

  func testAnOpenWindowIsDue() throws {
    let context = try fixture()
    XCTAssertEqual(
      context.state.dueOccurrences(now: start.addingTimeInterval(60)).map(\.id),
      [context.occurrenceID])
  }

  func testAWindowThatHasNotOpenedIsNotDue() throws {
    let context = try fixture()
    XCTAssertTrue(context.state.dueOccurrences(now: start.addingTimeInterval(-60)).isEmpty)
  }

  func testAWindowPastItsFlexibilityIsNotDue() throws {
    let context = try fixture()
    XCTAssertTrue(context.state.dueOccurrences(now: start.addingTimeInterval(5_000)).isEmpty)
  }

  func testAnOccurrenceThatAlreadyRanIsNotDueAgain() throws {
    var context = try fixture()
    try context.state.startOccurrence(context.occurrenceID, at: start)
    XCTAssertTrue(context.state.dueOccurrences(now: start.addingTimeInterval(60)).isEmpty)
  }

  // MARK: - Dispatch

  func testDispatchRecordsTheActualStart() throws {
    var context = try fixture()

    let outcome = context.state.beginScheduledWork(
      context.occurrenceID, now: start.addingTimeInterval(30), sessionID: "session-1",
      runtimeKind: "office.demo")

    XCTAssertEqual(
      outcome, .dispatched(occurrenceID: context.occurrenceID, commitmentID: context.commitmentID))
    let stored = try XCTUnwrap(context.state.scheduledOccurrence(context.occurrenceID))
    XCTAssertEqual(stored.status, .running)
    XCTAssertEqual(stored.actual?.startedAt, start.addingTimeInterval(30))
    XCTAssertEqual(stored.actual?.runtimeSessionID, "session-1")
    XCTAssertEqual(stored.window.start, start, "the planned window is untouched")
  }

  func testAFinishedCommitmentIsNotStarted() throws {
    var context = try fixture()
    _ = context.state.updateEmployeeOutcome(context.commitmentID, now: start) {
      $0.status = .accepted
    }

    let outcome = context.state.beginScheduledWork(
      context.occurrenceID, now: start.addingTimeInterval(30))

    guard case .skippedNotReady(_, let reason) = outcome else {
      return XCTFail("a finished commitment must not be started, got \(outcome)")
    }
    XCTAssertTrue(reason.contains("no longer open"))
    XCTAssertNil(context.state.scheduledOccurrence(context.occurrenceID)?.actual)
  }

  func testAnUnhiredEmployeeIsNotStarted() throws {
    var context = try fixture()
    if let index = context.state.employees.firstIndex(where: { $0.id == "theo" }) {
      context.state.employees[index].employmentState = .paused
    }

    let outcome = context.state.beginScheduledWork(
      context.occurrenceID, now: start.addingTimeInterval(30))

    guard case .skippedNotReady(_, let reason) = outcome else {
      return XCTFail("a paused employee must not be started, got \(outcome)")
    }
    XCTAssertTrue(reason.contains("not currently hired"))
  }

  // MARK: - Completion

  func testADeliveredCommitmentProducesAChangedReceipt() throws {
    var context = try fixture()
    _ = context.state.beginScheduledWork(context.occurrenceID, now: start)
    _ = context.state.updateEmployeeOutcome(context.commitmentID, now: start) {
      $0.status = .delivered
      $0.deliverySummary = "Filed the weekly note."
      $0.artifactIDs = ["artifact-1"]
    }

    let receipt = try XCTUnwrap(
      context.state.completeScheduledWork(
        context.occurrenceID, now: start.addingTimeInterval(300), reason: "Weekly note"))

    XCTAssertEqual(receipt.result.kind, .changed)
    XCTAssertEqual(receipt.result.evidenceIDs, ["artifact-1"])
    XCTAssertEqual(context.state.scheduledOccurrence(context.occurrenceID)?.status, .delivered)
    XCTAssertEqual(receipt.observedDuration, 300)
  }

  func testARunThatChangedNothingIsQuietRatherThanDelivered() throws {
    var context = try fixture()
    _ = context.state.beginScheduledWork(context.occurrenceID, now: start)

    let receipt = try XCTUnwrap(
      context.state.completeScheduledWork(
        context.occurrenceID, now: start.addingTimeInterval(120), reason: "Weekly note"))

    XCTAssertEqual(receipt.result.kind, .quiet)
    XCTAssertEqual(context.state.scheduledOccurrence(context.occurrenceID)?.status, .quiet)
    XCTAssertTrue(receipt.result.kind.isHonestSuccess)
  }

  func testABlockedCommitmentProducesABlockedReceipt() throws {
    var context = try fixture()
    _ = context.state.beginScheduledWork(context.occurrenceID, now: start)
    _ = context.state.updateEmployeeOutcome(context.commitmentID, now: start) {
      $0.status = .waiting
      $0.helpRequest = "I need the source list."
    }

    let receipt = try XCTUnwrap(
      context.state.completeScheduledWork(
        context.occurrenceID, now: start.addingTimeInterval(60), reason: "Weekly note"))

    XCTAssertEqual(receipt.result.kind, .blocked)
    XCTAssertEqual(receipt.result.summary, "I need the source list.")
  }

  func testCompletingSomethingThatNeverStartedSaysSo() throws {
    var context = try fixture()

    let receipt = try XCTUnwrap(
      context.state.completeScheduledWork(
        context.occurrenceID, now: start.addingTimeInterval(60), reason: "Weekly note"))

    XCTAssertEqual(receipt.result.kind, .neverRan)
    XCTAssertEqual(context.state.scheduledOccurrence(context.occurrenceID)?.status, .missed)
    XCTAssertNil(receipt.observedDuration)
  }

  func testCompletingTwiceDoesNotRewriteTheFirstReceipt() throws {
    var context = try fixture()
    _ = context.state.beginScheduledWork(context.occurrenceID, now: start)
    let first = try XCTUnwrap(
      context.state.completeScheduledWork(
        context.occurrenceID, now: start.addingTimeInterval(120), reason: "Weekly note"))

    let second = context.state.completeScheduledWork(
      context.occurrenceID, now: start.addingTimeInterval(600), reason: "Weekly note")

    XCTAssertNil(second)
    XCTAssertEqual(context.state.runReceipt(forOccurrence: context.occurrenceID), first)
  }
}
