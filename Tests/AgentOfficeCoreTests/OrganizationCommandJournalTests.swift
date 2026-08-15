import Foundation
import XCTest

@testable import AgentOfficeCore

final class OrganizationCommandJournalTests: XCTestCase {
  private var directory = URL(fileURLWithPath: "/tmp")

  override func setUpWithError() throws {
    try super.setUpWithError()
    directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-journal-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
    try super.tearDownWithError()
  }

  private func makeJournal() -> OrganizationJournal {
    OrganizationJournal(fileURL: directory.appendingPathComponent("journal.jsonl"))
  }

  private func hiredOrganization() -> OrganizationState {
    var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    return state
  }

  private func assignCommand(
    employeeID: String = "theo",
    outcome: String = "Draft the launch note",
    id: String = "command-1",
    idempotencyKey: String = "assign-1",
    now: Date = Date(timeIntervalSince1970: 2_000)
  ) -> OrganizationCommand {
    OrganizationCommand(
      id: id,
      actor: .owner(id: "owner"),
      payload: .assignEmployeeOutcome(
        .init(employeeID: employeeID, outcome: outcome, context: "Keep it short.")),
      idempotencyKey: idempotencyKey,
      issuedAt: now
    )
  }

  // MARK: - Command boundary

  func testOwnerAssignmentAppendsOneAttributableEvent() throws {
    let processor = OrganizationCommandProcessor(journal: makeJournal())
    var state = hiredOrganization()

    let result = try processor.submit(assignCommand(), to: &state)

    XCTAssertFalse(result.wasAlreadyApplied)
    XCTAssertEqual(result.sequence, 1)
    let outcomeID = try XCTUnwrap(result.commitmentID)
    XCTAssertNotNil(state.employeeOutcome(outcomeID))
    XCTAssertEqual(state.journalSequence, 1)

    let events = try makeJournal().events()
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].type, "employee-outcome.assigned")
    XCTAssertEqual(events[0].actor, .owner(id: "owner"))
    XCTAssertEqual(events[0].schemaVersion, OrganizationJournal.schemaVersion)
    XCTAssertTrue(events[0].references(.commitment(outcomeID)))
    XCTAssertTrue(events[0].references(.employee("theo")))
  }

  func testRepeatedIdempotencyKeyAppliesOnce() throws {
    let processor = OrganizationCommandProcessor(journal: makeJournal())
    var state = hiredOrganization()

    let first = try processor.submit(assignCommand(), to: &state)
    let outcomeCount = state.employeeOutcomes.count
    let second = try processor.submit(
      assignCommand(id: "command-2", idempotencyKey: "assign-1"), to: &state)

    XCTAssertTrue(second.wasAlreadyApplied)
    XCTAssertEqual(second.producedIDs, first.producedIDs)
    XCTAssertEqual(state.employeeOutcomes.count, outcomeCount)
    XCTAssertEqual(try makeJournal().events().count, 1)
  }

  func testDistinctIdempotencyKeysBothApply() throws {
    let processor = OrganizationCommandProcessor(journal: makeJournal())
    var state = hiredOrganization()

    _ = try processor.submit(assignCommand(), to: &state)
    _ = try processor.submit(
      assignCommand(
        employeeID: "nia", outcome: "Find three sources", id: "command-2",
        idempotencyKey: "assign-2"),
      to: &state)

    XCTAssertEqual(try makeJournal().events().map(\.sequence), [1, 2])
    XCTAssertEqual(state.employeeOutcomes.count, 2)
  }

  func testRuntimeCannotSubmitAnOwnerCommand() throws {
    let processor = OrganizationCommandProcessor(journal: makeJournal())
    var state = hiredOrganization()
    let before = state

    let command = OrganizationCommand(
      actor: .employeeRuntime(employeeID: "theo", sessionID: "session-1"),
      payload: .assignEmployeeOutcome(
        .init(employeeID: "theo", outcome: "Give myself work", context: "")),
      idempotencyKey: "escalation-1"
    )

    XCTAssertThrowsError(try processor.submit(command, to: &state)) { error in
      XCTAssertEqual(
        error as? OrganizationCommandError,
        .unauthorizedActor(actor: "theo", commandType: "employee-outcome.assigned"))
    }
    XCTAssertEqual(state, before)
    XCTAssertEqual(try makeJournal().events().count, 0)
  }

  func testRuntimeCannotSubmitAnotherEmployeesWork() throws {
    let processor = OrganizationCommandProcessor(journal: makeJournal())
    var state = hiredOrganization()
    let outcomeID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft", context: "")
    let runResult = try runResult(for: outcomeID, in: state)

    let command = OrganizationCommand(
      actor: .employeeRuntime(employeeID: "nia", sessionID: nil),
      payload: .applyEmployeeRunResult(runResult),
      idempotencyKey: "impersonation-1"
    )

    XCTAssertThrowsError(try processor.submit(command, to: &state)) { error in
      XCTAssertEqual(
        error as? OrganizationCommandError, .actorMismatch(claimed: "nia", actual: "theo"))
    }
  }

  func testDomainRejectionLeavesNoHistoryAndAllowsRetry() throws {
    let processor = OrganizationCommandProcessor(journal: makeJournal())
    var state = hiredOrganization()
    let before = state

    XCTAssertThrowsError(
      try processor.submit(assignCommand(outcome: "   "), to: &state))
    XCTAssertEqual(state, before)
    XCTAssertEqual(try makeJournal().events().count, 0)

    // The same key is still eligible because nothing was recorded for it.
    let retry = try processor.submit(assignCommand(), to: &state)
    XCTAssertFalse(retry.wasAlreadyApplied)
  }

  // MARK: - Replay

  func testSnapshotPlusReplayEqualsDirectApplication() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    let snapshot = hiredOrganization()
    var applied = snapshot

    _ = try processor.submit(assignCommand(), to: &applied)
    _ = try processor.submit(
      assignCommand(
        employeeID: "nia", outcome: "Find three sources", id: "command-2",
        idempotencyKey: "assign-2"),
      to: &applied)

    let replayed = try processor.replay(from: snapshot, events: journal.events())
    XCTAssertEqual(replayed, applied)
  }

  func testReplayIsRepeatable() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    let snapshot = hiredOrganization()
    var applied = snapshot
    _ = try processor.submit(assignCommand(), to: &applied)

    let first = try processor.replay(from: snapshot, events: journal.events())
    let second = try processor.replay(from: snapshot, events: journal.events())
    XCTAssertEqual(first, second)
  }

  func testRuntimeResultReplaysIdentically() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    let snapshot = hiredOrganization()
    var applied = snapshot

    let assignment = try processor.submit(assignCommand(), to: &applied)
    let outcomeID = try XCTUnwrap(assignment.commitmentID)
    let result = try runResult(for: outcomeID, in: applied)
    _ = try processor.submit(
      OrganizationCommand(
        id: "command-run",
        actor: .employeeRuntime(employeeID: "theo", sessionID: "session-1"),
        payload: .applyEmployeeRunResult(result),
        idempotencyKey: "run-result:\(outcomeID):0",
        issuedAt: Date(timeIntervalSince1970: 3_000)
      ),
      to: &applied)

    let replayed = try processor.replay(from: snapshot, events: journal.events())
    XCTAssertEqual(replayed, applied)
    XCTAssertEqual(replayed.employeeOutcome(outcomeID)?.status, .delivered)
  }

  // MARK: - Journal integrity

  func testBackwardsClockDoesNotReorderHistory() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = hiredOrganization()

    _ = try processor.submit(
      assignCommand(now: Date(timeIntervalSince1970: 5_000)), to: &state)
    _ = try processor.submit(
      assignCommand(
        employeeID: "nia", outcome: "Find sources", id: "command-2", idempotencyKey: "assign-2",
        now: Date(timeIntervalSince1970: 1)),
      to: &state)

    let events = try journal.events()
    XCTAssertEqual(events.map(\.sequence), [1, 2])
    XCTAssertLessThan(events[1].occurredAt, events[0].occurredAt)
  }

  func testTruncatedFinalEntryFailsVisibly() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = hiredOrganization()
    _ = try processor.submit(assignCommand(), to: &state)

    var contents = try String(contentsOf: journal.fileURL, encoding: .utf8)
    contents = String(contents.dropLast(60))
    try contents.write(to: journal.fileURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try journal.events()) { error in
      XCTAssertEqual(error as? OrganizationJournalError, .truncatedEntry(line: 2))
    }
  }

  func testUnsupportedSchemaVersionFailsVisibly() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = hiredOrganization()
    _ = try processor.submit(assignCommand(), to: &state)

    let contents = try String(contentsOf: journal.fileURL, encoding: .utf8)
    let patched = contents.replacingOccurrences(
      of: "\"schemaVersion\":1", with: "\"schemaVersion\":99")
    try patched.write(to: journal.fileURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try journal.events()) { error in
      XCTAssertEqual(
        error as? OrganizationJournalError,
        .unsupportedSchemaVersion(found: 99, supported: OrganizationJournal.schemaVersion))
    }
  }

  func testDuplicateSequenceFailsVisibly() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = hiredOrganization()
    _ = try processor.submit(assignCommand(), to: &state)

    var lines = try String(contentsOf: journal.fileURL, encoding: .utf8)
      .components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    lines.append(lines[1])
    try (lines.joined(separator: "\n") + "\n")
      .write(to: journal.fileURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try journal.events()) { error in
      XCTAssertEqual(error as? OrganizationJournalError, .duplicateSequence(1, line: 3))
    }
  }

  func testMissingHeaderFailsVisibly() throws {
    let journal = makeJournal()
    try "{\"not\":\"a header\"}\n".write(to: journal.fileURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try journal.events()) { error in
      XCTAssertEqual(error as? OrganizationJournalError, .missingHeader)
    }
  }

  func testIntegrityFailureLeavesTheJournalUnchanged() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = hiredOrganization()
    _ = try processor.submit(assignCommand(), to: &state)

    let contents = try String(contentsOf: journal.fileURL, encoding: .utf8)
    let corrupted = contents.replacingOccurrences(
      of: "\"sequence\":1", with: "\"sequence\":7")
    try corrupted.write(to: journal.fileURL, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try journal.events())
    XCTAssertEqual(try String(contentsOf: journal.fileURL, encoding: .utf8), corrupted)
  }

  func testEventsCanBeReadByEntity() throws {
    let journal = makeJournal()
    let processor = OrganizationCommandProcessor(journal: journal)
    var state = hiredOrganization()

    let assignment = try processor.submit(assignCommand(), to: &state)
    _ = try processor.submit(
      assignCommand(
        employeeID: "nia", outcome: "Find sources", id: "command-2", idempotencyKey: "assign-2"),
      to: &state)

    let outcomeID = try XCTUnwrap(assignment.commitmentID)
    let commitmentEvents = try journal.events(referencing: .commitment(outcomeID))
    XCTAssertEqual(commitmentEvents.map(\.sequence), [1])
    XCTAssertEqual(try journal.events(referencing: .employee("nia")).map(\.sequence), [2])
  }

  // MARK: - Helpers

  private func runResult(for outcomeID: String, in state: OrganizationState) throws
    -> EmployeeOutcomeRunResult
  {
    let outcome = try XCTUnwrap(state.employeeOutcome(outcomeID))
    var delivered = outcome
    delivered.status = .delivered
    delivered.deliverySummary = "Delivered one local artifact."
    delivered.outcomeRevision = outcome.effectiveRevision
    let employee = try XCTUnwrap(state.employee(outcome.assigneeID))

    var result = try EmployeeOutcomeRunResult(
      request: EmployeeOutcomeRunRequest(organization: state, outcomeID: outcomeID),
      initial: state,
      result: state
    )
    result.outcome = delivered
    result.employee = employee
    return result
  }
}

final class OrganizationJournalMigrationTests: XCTestCase {
  func testOrganizationWrittenBeforeTheJournalGainsOneWithoutDataLoss() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-migration-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)

    // A snapshot written before this change has no journal and no sequence.
    var legacy = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    for index in legacy.employees.indices where legacy.employees[index].kind == .ai {
      legacy.employees[index].employmentState = .hired
    }
    legacy.name = "Willow Studio"
    legacy.journalSequence = nil
    try await store.save(legacy)
    let journal = store.journal
    XCTAssertFalse(journal.exists)

    let loaded = try await store.loadOrCreate()
    XCTAssertEqual(loaded.name, "Willow Studio")
    XCTAssertNil(loaded.journalSequence)
    XCTAssertEqual(loaded.employees.count, legacy.employees.count)

    let applied = try await store.submit(
      OrganizationCommand(
        actor: .owner(id: "owner"),
        payload: .assignEmployeeOutcome(
          .init(employeeID: "theo", outcome: "Draft the launch note", context: "")),
        idempotencyKey: "migration-assign-1"
      ),
      to: loaded
    )

    XCTAssertTrue(journal.exists)
    XCTAssertEqual(applied.state.journalSequence, 1)
    XCTAssertEqual(applied.state.name, "Willow Studio")
    XCTAssertEqual(try journal.events().count, 1)

    let reloaded = try await store.loadOrCreate()
    XCTAssertEqual(reloaded.journalSequence, 1)
    XCTAssertNotNil(reloaded.employeeOutcome(applied.result.commitmentID ?? ""))
  }
}

/// Owner decisions are consequential, so they travel the same boundary and
/// reconstruct the same way.
final class SupervisionCommandTests: XCTestCase {
  private var directory = URL(fileURLWithPath: "/tmp")
  private let now = Date(timeIntervalSince1970: 5_000)

  override func setUpWithError() throws {
    try super.setUpWithError()
    directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-supervision-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
    try super.tearDownWithError()
  }

  private func journal() -> OrganizationJournal {
    OrganizationJournal(fileURL: directory.appendingPathComponent("journal.jsonl"))
  }

  private func waitingCommitment() throws -> (state: OrganizationState, commitmentID: String) {
    var state = LocalOrganizationStore.migrated(
      .seeded(now: Date(timeIntervalSince1970: 1_000)), now: Date(timeIntervalSince1970: 1_000))
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "",
      now: Date(timeIntervalSince1970: 1_000))
    _ = state.updateEmployeeOutcome(commitmentID, now: Date(timeIntervalSince1970: 1_000)) {
      $0.status = .waiting
      $0.helpRequest = "I need a source."
    }
    return (state, commitmentID)
  }

  private func replyCommand(_ commitmentID: String, id: String = "command-reply")
    -> OrganizationCommand
  {
    OrganizationCommand(
      id: id,
      actor: .owner(id: "owner"),
      payload: .superviseCommitment(
        .replyToHelp(commitmentID: commitmentID, message: "Use the internal archive.")),
      idempotencyKey: "supervision-\(id)",
      issuedAt: now
    )
  }

  func testAnOwnerDecisionIsJournalledWithItsEntities() throws {
    var fixture = try waitingCommitment()
    let processor = OrganizationCommandProcessor(journal: journal())

    _ = try processor.submit(replyCommand(fixture.commitmentID), to: &fixture.state)

    let events = try journal().events()
    XCTAssertEqual(events.map(\.type), ["commitment.help-answered"])
    XCTAssertEqual(events[0].actor, .owner(id: "owner"))
    XCTAssertTrue(events[0].references(.commitment(fixture.commitmentID)))
    XCTAssertTrue(events[0].references(.employee("theo")))
  }

  func testARuntimeCannotSuperviseItsOwnCommitment() throws {
    var fixture = try waitingCommitment()
    let processor = OrganizationCommandProcessor(journal: journal())
    let command = OrganizationCommand(
      actor: .employeeRuntime(employeeID: "theo", sessionID: "session-1"),
      payload: .superviseCommitment(
        .acceptDelivery(commitmentID: fixture.commitmentID, note: "Looks great to me.")),
      idempotencyKey: "self-accept"
    )

    XCTAssertThrowsError(try processor.submit(command, to: &fixture.state)) { error in
      XCTAssertEqual(
        error as? OrganizationCommandError,
        .unauthorizedActor(actor: "theo", commandType: "commitment.delivery-accepted"))
    }
    XCTAssertEqual(try journal().events().count, 0)
  }

  func testADecisionReplaysToTheSameState() throws {
    var fixture = try waitingCommitment()
    let snapshot = fixture.state
    let processor = OrganizationCommandProcessor(journal: journal())

    _ = try processor.submit(replyCommand(fixture.commitmentID), to: &fixture.state)
    let replayed = try processor.replay(from: snapshot, events: journal().events())

    XCTAssertEqual(replayed, fixture.state)
  }

  func testARepeatedDecisionAppliesOnce() throws {
    var fixture = try waitingCommitment()
    let processor = OrganizationCommandProcessor(journal: journal())

    _ = try processor.submit(replyCommand(fixture.commitmentID), to: &fixture.state)
    let messagesAfterFirst =
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveManagementMessages.count
    let second = try processor.submit(
      replyCommand(fixture.commitmentID, id: "command-reply"), to: &fixture.state)

    XCTAssertTrue(second.wasAlreadyApplied)
    XCTAssertEqual(
      fixture.state.employeeOutcome(fixture.commitmentID)?.effectiveManagementMessages.count,
      messagesAfterFirst)
    XCTAssertEqual(try journal().events().count, 1)
  }

  func testARejectedDecisionLeavesNoHistory() throws {
    var fixture = try waitingCommitment()
    _ = fixture.state.updateEmployeeOutcome(fixture.commitmentID, now: now) { $0.status = .working }
    let before = fixture.state
    let processor = OrganizationCommandProcessor(journal: journal())

    XCTAssertThrowsError(
      try processor.submit(replyCommand(fixture.commitmentID), to: &fixture.state))
    XCTAssertEqual(fixture.state, before)
    XCTAssertEqual(try journal().events().count, 0)
  }
}
