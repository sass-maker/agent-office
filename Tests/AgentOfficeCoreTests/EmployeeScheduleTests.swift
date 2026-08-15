import Foundation
import XCTest

@testable import AgentOfficeCore

final class EmployeeScheduleTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func organization() -> OrganizationState {
    LocalOrganizationStore.migrated(.seeded(now: start), now: start)
  }

  private func weeklyPolicy(
    id: String = "policy-1",
    firstStart: Date? = nil,
    duration: TimeInterval = 900,
    flexibility: TimeInterval = 600
  ) -> SchedulePolicy {
    SchedulePolicy(
      id: id,
      employeeID: "iris",
      subject: .recurringResponsibility("customer-voice-weekly"),
      plan: SchedulePlan(
        recurrence: .everyDays(7),
        firstStart: firstStart ?? start,
        expectedDuration: duration,
        flexibility: flexibility,
        timeZoneIdentifier: "UTC"
      ),
      createdAt: start
    )
  }

  // MARK: - Policies

  func testPolicyPointsAtExistingWorkWithoutChangingIt() throws {
    var state = organization()
    let dutiesBefore = state.knowledge?.employeeDuties

    state.addSchedulePolicy(weeklyPolicy())

    XCTAssertEqual(state.schedulePolicies.count, 1)
    XCTAssertEqual(
      state.schedulePolicy("policy-1")?.subject, .recurringResponsibility("customer-voice-weekly"))
    XCTAssertEqual(state.schedulePolicy("policy-1")?.plan.timeZoneIdentifier, "UTC")
    XCTAssertEqual(state.knowledge?.employeeDuties, dutiesBefore)
  }

  func testEmployeeWithoutAScheduleStillReceivesOwnerAssignedWork() throws {
    var state = organization()
    XCTAssertTrue(state.schedulePolicies.isEmpty)

    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "", now: start)

    XCTAssertNotNil(state.employeeOutcome(commitmentID))
  }

  func testPausedPolicyGeneratesNothingButIsRetained() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    try state.setSchedulePolicyPaused("policy-1", true)

    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 30))

    XCTAssertTrue(created.isEmpty)
    XCTAssertNotNil(state.schedulePolicy("policy-1"))
  }

  // MARK: - Occurrence generation

  func testGenerationIsIdempotent() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let horizon = start.addingTimeInterval(60 * 60 * 24 * 21)

    let first = try state.generateOccurrences(forPolicy: "policy-1", from: start, through: horizon)
    let second = try state.generateOccurrences(forPolicy: "policy-1", from: start, through: horizon)

    XCTAssertEqual(first.count, 4, "day 0, 7, 14 and 21")
    XCTAssertTrue(second.isEmpty)
    XCTAssertEqual(state.scheduledOccurrences.count, 4)
    XCTAssertEqual(Set(state.scheduledOccurrences.map(\.id)).count, 4)
  }

  func testGenerationAfterAClockChangeCreatesNoDuplicate() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let horizon = start.addingTimeInterval(60 * 60 * 24 * 14)
    _ = try state.generateOccurrences(forPolicy: "policy-1", from: start, through: horizon)
    let before = state.scheduledOccurrences.map(\.id).sorted()

    // The wall clock jumps backwards; regeneration must re-derive, not duplicate.
    _ = try state.generateOccurrences(
      forPolicy: "policy-1", from: start.addingTimeInterval(-3_600), through: horizon)

    XCTAssertEqual(state.scheduledOccurrences.map(\.id).sorted(), before)
  }

  func testRegenerationDoesNotResetACompletedOccurrence() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let horizon = start.addingTimeInterval(60 * 60 * 24 * 14)
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: horizon)
    let first = try XCTUnwrap(created.first)
    try state.startOccurrence(first.id, at: start.addingTimeInterval(60))
    _ = try state.finishOccurrence(
      first.id,
      result: ReceiptResult(kind: .changed, summary: "Filed three customer notes."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(600)
    )

    _ = try state.generateOccurrences(forPolicy: "policy-1", from: start, through: horizon)

    XCTAssertEqual(state.scheduledOccurrence(first.id)?.status, .delivered)
    XCTAssertNotNil(state.runReceipt(forOccurrence: first.id))
  }

  func testOneTimePolicyProducesASingleOccurrence() throws {
    var state = organization()
    state.addSchedulePolicy(
      SchedulePolicy(
        id: "policy-once",
        employeeID: "theo",
        subject: .commitment("employee-outcome-abc"),
        plan: SchedulePlan(
          recurrence: .oneTime, firstStart: start, timeZoneIdentifier: "UTC"),
        createdAt: start
      ))

    let created = try state.generateOccurrences(
      forPolicy: "policy-once", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 90))

    XCTAssertEqual(created.count, 1)
    XCTAssertEqual(created.first?.window.start, start)
  }

  // MARK: - Planned versus actual

  func testPlannedAndActualAreKeptApart() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let occurrence = try XCTUnwrap(created.first)

    let lateStart = start.addingTimeInterval(300)
    try state.startOccurrence(
      occurrence.id, at: lateStart, sessionID: "session-1", runtimeKind: "office.demo")
    _ = try state.finishOccurrence(
      occurrence.id,
      result: ReceiptResult(kind: .changed, summary: "Filed three customer notes."),
      reason: "Weekly customer voice",
      endedAt: lateStart.addingTimeInterval(420)
    )

    let stored = try XCTUnwrap(state.scheduledOccurrence(occurrence.id))
    XCTAssertEqual(stored.window.start, start, "the planned window is unchanged")
    XCTAssertEqual(stored.actual?.startedAt, lateStart)
    XCTAssertEqual(stored.actual?.duration, 420)
    XCTAssertEqual(stored.actual?.runtimeSessionID, "session-1")
  }

  func testAPassedWindowBecomesMissedWithNoActualTimes() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let occurrence = try XCTUnwrap(created.first)

    let missed = state.reconcileMissedOccurrences(now: start.addingTimeInterval(10_000))

    XCTAssertEqual(missed, [occurrence.id])
    XCTAssertEqual(state.scheduledOccurrence(occurrence.id)?.status, .missed)
    XCTAssertNil(state.scheduledOccurrence(occurrence.id)?.actual)
  }

  func testReconciliationIsIdempotentAndRunsNothing() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    _ = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 14))

    let first = state.reconcileMissedOccurrences(now: start.addingTimeInterval(60 * 60 * 24 * 30))
    let second = state.reconcileMissedOccurrences(now: start.addingTimeInterval(60 * 60 * 24 * 30))

    XCTAssertFalse(first.isEmpty)
    XCTAssertTrue(second.isEmpty, "reconciling again must change nothing")
    XCTAssertTrue(state.runReceipts.isEmpty, "reconciliation must not fabricate receipts")
  }

  func testAnOccurrenceInsideItsFlexibilityIsNotMissedYet() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy(flexibility: 3_600))
    _ = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))

    let missed = state.reconcileMissedOccurrences(now: start.addingTimeInterval(1_800))

    XCTAssertTrue(missed.isEmpty)
  }

  // MARK: - Receipts

  func testQuietRunIsDistinctFromFailureAndFromNeverRunning() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 14))
    let quiet = try XCTUnwrap(created.first)
    let neverRan = try XCTUnwrap(created.last)

    try state.startOccurrence(quiet.id, at: start)
    let quietReceipt = try state.finishOccurrence(
      quiet.id,
      result: ReceiptResult(kind: .quiet, summary: "No new customer notes this week."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(120)
    )
    let neverRanReceipt = try state.finishOccurrence(
      neverRan.id,
      result: ReceiptResult(kind: .neverRan, summary: "The runtime was unavailable."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(240)
    )

    XCTAssertEqual(state.scheduledOccurrence(quiet.id)?.status, .quiet)
    XCTAssertTrue(quietReceipt.result.kind.isHonestSuccess)
    XCTAssertEqual(quietReceipt.headline, "Ran and found nothing to change.")
    XCTAssertNotNil(quietReceipt.observedDuration)

    XCTAssertEqual(state.scheduledOccurrence(neverRan.id)?.status, .missed)
    XCTAssertFalse(neverRanReceipt.result.kind.isHonestSuccess)
    XCTAssertEqual(neverRanReceipt.headline, "Never started, so nothing was observed.")
    XCTAssertNil(neverRanReceipt.observedDuration)
  }

  func testReceiptRecordsUnknownUsageRatherThanZero() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let occurrence = try XCTUnwrap(created.first)
    try state.startOccurrence(occurrence.id, at: start, runtimeKind: "office.local-codex")

    let receipt = try state.finishOccurrence(
      occurrence.id,
      result: ReceiptResult(kind: .changed, summary: "Filed two notes."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(300)
    )

    XCTAssertEqual(receipt.result.usage, .unknown)
    XCTAssertEqual(receipt.work.runtimeKind, "office.local-codex")
    XCTAssertEqual(receipt.work.employeeID, "iris")
    XCTAssertEqual(receipt.scheduledWindow.start, start)
  }

  func testFinishingAnAlreadyFinishedOccurrenceIsRejected() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let occurrence = try XCTUnwrap(created.first)
    try state.startOccurrence(occurrence.id, at: start)
    _ = try state.finishOccurrence(
      occurrence.id,
      result: ReceiptResult(kind: .changed, summary: "Done."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(60)
    )

    XCTAssertThrowsError(
      try state.finishOccurrence(
        occurrence.id,
        result: ReceiptResult(kind: .failed, summary: "Rewriting history."),
        reason: "Weekly customer voice",
        endedAt: start.addingTimeInterval(120))
    ) { error in
      XCTAssertEqual(error as? ScheduleError, .occurrenceAlreadyFinished(occurrence.id))
    }
  }

  // MARK: - Owner control

  func testSkippingAFutureOccurrenceKeepsItsReasonAndLeavesOthersAlone() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 14))
    let skipped = try XCTUnwrap(created.first)

    try state.skipOccurrence(skipped.id, reason: "Away this week.")

    XCTAssertEqual(state.scheduledOccurrence(skipped.id)?.status, .skipped)
    XCTAssertEqual(state.scheduledOccurrence(skipped.id)?.note, "Away this week.")
    XCTAssertTrue(
      created.dropFirst().allSatisfy { state.scheduledOccurrence($0.id)?.status == .scheduled })
  }

  func testEditingAPolicyLeavesCompletedOccurrencesUntouched() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let occurrence = try XCTUnwrap(created.first)
    try state.startOccurrence(occurrence.id, at: start)
    _ = try state.finishOccurrence(
      occurrence.id,
      result: ReceiptResult(kind: .changed, summary: "Filed notes."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(300)
    )
    let receiptBefore = state.runReceipt(forOccurrence: occurrence.id)

    // The owner reshapes the policy afterwards.
    state.addSchedulePolicy(
      weeklyPolicy(firstStart: start.addingTimeInterval(86_400), duration: 1_800))

    XCTAssertEqual(state.scheduledOccurrence(occurrence.id)?.window.start, start)
    XCTAssertEqual(state.scheduledOccurrence(occurrence.id)?.window.duration, 900)
    XCTAssertEqual(state.runReceipt(forOccurrence: occurrence.id), receiptBefore)
  }

  func testMovingAndCancellingApplyOnlyToUnfinishedOccurrences() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 14))
    let moved = try XCTUnwrap(created.first)
    let cancelled = try XCTUnwrap(created.last)

    try state.moveOccurrence(moved.id, to: start.addingTimeInterval(7_200))
    try state.cancelOccurrence(cancelled.id, reason: "Not needed this cycle.")

    XCTAssertEqual(
      state.scheduledOccurrence(moved.id)?.window.start, start.addingTimeInterval(7_200))
    XCTAssertEqual(state.scheduledOccurrence(cancelled.id)?.status, .cancelled)
    XCTAssertThrowsError(try state.moveOccurrence(cancelled.id, to: start))
  }

  // MARK: - Persistence

  func testSchedulesSurviveEncodingAndDecoding() throws {
    var state = organization()
    state.addSchedulePolicy(weeklyPolicy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let occurrence = try XCTUnwrap(created.first)
    try state.startOccurrence(occurrence.id, at: start)
    _ = try state.finishOccurrence(
      occurrence.id,
      result: ReceiptResult(
        kind: .quiet, summary: "Nothing new.", usage: .observed(description: "1 turn")),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(90)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(OrganizationState.self, from: try encoder.encode(state))

    XCTAssertEqual(decoded.schedulePolicies.count, 1)
    XCTAssertEqual(decoded.scheduledOccurrence(occurrence.id)?.status, .quiet)
    XCTAssertEqual(
      decoded.runReceipt(forOccurrence: occurrence.id)?.result.usage,
      .observed(description: "1 turn"))
  }

  func testOrganizationWrittenBeforeSchedulesDecodesWithNone() throws {
    let legacy = """
      {"schemaVersion":1,"id":"org","name":"Willow Studio","outcome":"","workdayStatus":"resting",
      "executionMode":"demo","dayNumber":1,"employees":[],"goals":[],"tasks":[],"blockers":[],
      "artifacts":[],"activity":[],"lastSavedAt":"2026-08-15T00:00:00Z",
      "knowledge":{"productBrief":""}}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let state = try decoder.decode(OrganizationState.self, from: Data(legacy.utf8))

    XCTAssertTrue(state.schedulePolicies.isEmpty)
    XCTAssertTrue(state.scheduledOccurrences.isEmpty)
    XCTAssertTrue(state.runReceipts.isEmpty)
  }
}

final class WorkCalendarTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func organization() -> OrganizationState {
    LocalOrganizationStore.migrated(.seeded(now: start), now: start)
  }

  private func policy(
    id: String = "policy-1", catchUp: ScheduleCatchUpPolicy = .leaveMissed
  ) -> SchedulePolicy {
    SchedulePolicy(
      id: id,
      employeeID: "iris",
      subject: .recurringResponsibility("customer-voice-weekly"),
      plan: SchedulePlan(
        recurrence: .everyDays(7), firstStart: start, expectedDuration: 900, flexibility: 600,
        timeZoneIdentifier: "UTC"),
      createdAt: start,
      catchUp: catchUp
    )
  }

  // MARK: - Projection

  func testDaysProjectOccurrencesWithStatusAndActualRun() throws {
    var state = organization()
    state.addSchedulePolicy(policy())
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60 * 60 * 24 * 8))
    let first = try XCTUnwrap(created.first)
    try state.startOccurrence(
      first.id, at: start.addingTimeInterval(60), runtimeKind: "office.demo")
    _ = try state.finishOccurrence(
      first.id,
      result: ReceiptResult(kind: .quiet, summary: "No new notes."),
      reason: "Weekly customer voice",
      endedAt: start.addingTimeInterval(300)
    )

    let days = state.calendarDays(
      from: start.addingTimeInterval(-60), through: start.addingTimeInterval(60 * 60 * 24 * 9),
      timeZoneIdentifier: "UTC")

    XCTAssertEqual(days.count, 2, "one block on day 0 and one on day 7")
    let block = try XCTUnwrap(days.first?.blocks.first)
    XCTAssertEqual(block.employeeName, "Iris")
    XCTAssertEqual(block.status, .quiet)
    XCTAssertEqual(block.statusLabel, "Ran, nothing to change")
    XCTAssertTrue(block.didActuallyRun)
    XCTAssertEqual(block.receiptHeadline, "Ran and found nothing to change.")
  }

  func testProjectionInventsNothingWhenNoPolicyExists() {
    let state = organization()

    let days = state.calendarDays(
      from: start, through: start.addingTimeInterval(60 * 60 * 24 * 30))

    XCTAssertTrue(days.isEmpty)
  }

  func testAScheduledBlockIsNotReportedAsHavingRun() throws {
    var state = organization()
    state.addSchedulePolicy(policy())
    _ = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))

    let days = state.calendarDays(
      from: start.addingTimeInterval(-60), through: start.addingTimeInterval(60),
      timeZoneIdentifier: "UTC")

    let block = try XCTUnwrap(days.first?.blocks.first)
    XCTAssertFalse(block.didActuallyRun)
    XCTAssertNil(block.receiptHeadline)
    XCTAssertEqual(block.statusLabel, "Scheduled")
  }

  // MARK: - Catch-up

  func testLeaveMissedCreatesNoReplacement() throws {
    var state = organization()
    state.addSchedulePolicy(policy(catchUp: .leaveMissed))
    _ = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let before = state.scheduledOccurrences.count

    let rescheduled = state.applyCatchUpPolicies(now: start.addingTimeInterval(10_000))

    XCTAssertTrue(rescheduled.isEmpty)
    XCTAssertEqual(state.scheduledOccurrences.count, before)
    XCTAssertEqual(state.scheduledOccurrences.first?.status, .missed)
  }

  func testRescheduleMovesTheWindowWithoutRunningAnything() throws {
    var state = organization()
    state.addSchedulePolicy(policy(catchUp: .rescheduleToNextWindow))
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))
    let missedID = try XCTUnwrap(created.first).id
    let now = start.addingTimeInterval(10_000)

    let rescheduled = state.applyCatchUpPolicies(now: now)

    XCTAssertEqual(rescheduled, ["\(missedID)-catchup"])
    XCTAssertEqual(state.scheduledOccurrence(missedID)?.status, .missed)
    let replacement = try XCTUnwrap(state.scheduledOccurrence("\(missedID)-catchup"))
    XCTAssertEqual(replacement.status, .scheduled)
    XCTAssertGreaterThanOrEqual(replacement.window.start, now)
    XCTAssertNil(replacement.actual, "nothing may run as part of catching up")
    XCTAssertTrue(state.runReceipts.isEmpty)
  }

  func testRepeatedReconciliationCreatesNoSecondReplacement() throws {
    var state = organization()
    state.addSchedulePolicy(policy(catchUp: .rescheduleToNextWindow))
    _ = try state.generateOccurrences(
      forPolicy: "policy-1", from: start, through: start.addingTimeInterval(60))

    let first = state.applyCatchUpPolicies(now: start.addingTimeInterval(10_000))
    let second = state.applyCatchUpPolicies(now: start.addingTimeInterval(20_000))

    XCTAssertEqual(first.count, 1)
    XCTAssertTrue(second.isEmpty, "a replacement is never itself rescheduled")
    XCTAssertEqual(state.scheduledOccurrences.filter { $0.replacesOccurrenceID != nil }.count, 1)
  }

  func testPolicyWrittenBeforeCatchUpExistedDefaultsToLeavingMissed() throws {
    let legacy = """
      {"id":"policy-legacy","employeeID":"iris",
      "subject":{"recurringResponsibility":{"_0":"customer-voice-weekly"}},
      "plan":{"recurrence":{"everyDays":{"_0":7}},"firstStart":"2026-08-15T00:00:00Z",
      "expectedDuration":900,"flexibility":600,"timeZoneIdentifier":"UTC"},
      "authoredByActorID":"owner","createdAt":"2026-08-15T00:00:00Z","isPaused":false}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let policy = try decoder.decode(SchedulePolicy.self, from: Data(legacy.utf8))

    XCTAssertEqual(policy.catchUp, .leaveMissed)
  }
}
