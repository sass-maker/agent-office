import Foundation
import XCTest

@testable import AgentOfficeCore

/// Covers the routine projection, the receipt states an owner has to be able to
/// tell apart, and what survives reopening an organization.
final class EmployeeRoutineTests: XCTestCase {
  private let epoch = Date(timeIntervalSince1970: 1_000)

  // MARK: - Projection

  func testEveryHiredEmployeeGetsARoutineFileAndNobodyElseDoes() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var state = hiredOrganization()
    // Theo is paused, so there is no recurring work to describe.
    if let index = state.employees.firstIndex(where: { $0.id == "theo" }) {
      state.employees[index].employmentState = .paused
    }

    try await store.save(state)

    for employee in state.employees where employee.kind == .ai {
      let path = store.employeeHomeURL(employeeID: employee.id)
        .appendingPathComponent("ROUTINES.md")
      XCTAssertEqual(
        FileManager.default.fileExists(atPath: path.path),
        employee.effectiveEmploymentState == .hired,
        "\(employee.id) routine file presence should follow whether they are hired.")
    }
  }

  func testPausingAnEmployeeRemovesTheRoutineThatNoLongerApplies() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var state = hiredOrganization()
    try await store.save(state)
    let path = store.employeeHomeURL(employeeID: "theo").appendingPathComponent("ROUTINES.md")
    XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))

    if let index = state.employees.firstIndex(where: { $0.id == "theo" }) {
      state.employees[index].employmentState = .retired
    }
    try await store.save(state)

    XCTAssertFalse(
      FileManager.default.fileExists(atPath: path.path),
      "A retired employee must not leave behind a routine describing work that will not happen.")
  }

  func testRoutineIsDerivedFromTheWorkingContractNotTheEmployeeRecord() throws {
    var state = hiredOrganization()
    try state.updateWorkingContract(
      employeeID: "theo",
      role: "Launch Writer",
      responsibility: "Write the launch note and nothing else.",
      managerID: nil,
      assignedSkillIDs: ["communication"],
      declaredConnectionIDs: ["reddit"],
      capabilityGrants: ["web-research"],
      executionProvider: .localClaudeCode,
      modelName: "opus",
      boundaries: AutonomyBoundaries(mayDelegate: false, mayUseExternalTools: true),
      reviewPolicy: .whenAuthorityChanges,
      actorID: "owner",
      reason: "routine fixture"
    )

    // Make the two layers disagree. The contract is canonical, so the routine
    // must read it and not the employee record it was synced onto.
    if let index = state.employees.firstIndex(where: { $0.id == "theo" }) {
      state.employees[index].role = "Stale role from the employee record"
      state.employees[index].responsibility = "Stale responsibility"
    }

    let routine = try XCTUnwrap(state.employeeRoutine(for: "theo"))

    XCTAssertEqual(routine.role, "Launch Writer")
    XCTAssertEqual(routine.responsibility, "Write the launch note and nothing else.")
    XCTAssertEqual(routine.contractRevision, 2)
    XCTAssertEqual(routine.requiredCapabilityIDs, ["web-research"])
    XCTAssertEqual(routine.declaredConnectionIDs, ["reddit"])
    XCTAssertEqual(routine.executionProvider, .localClaudeCode)
    XCTAssertEqual(routine.modelName, "opus")
    XCTAssertEqual(routine.reviewPolicy, .whenAuthorityChanges)
    XCTAssertFalse(routine.boundaries.mayDelegate)
    XCTAssertTrue(routine.boundaries.mayUseExternalTools)

    let markdown = routine.markdown
    XCTAssertTrue(markdown.contains("Launch Writer"))
    XCTAssertTrue(markdown.contains("Ask a coworker for help: No"))
    XCTAssertTrue(markdown.contains("`web-research`"))
    XCTAssertTrue(markdown.contains("- Model: opus"))
  }

  func testARoutineWithNoRunSaysSoRatherThanImplyingSuccess() throws {
    let state = hiredOrganization()
    let routine = try XCTUnwrap(state.employeeRoutine(for: "theo"))

    XCTAssertNil(routine.lastRun)
    XCTAssertTrue(routine.markdown.contains("has not run yet"))
    XCTAssertFalse(routine.markdown.contains("Ran and changed something"))
  }

  func testARoutineNamesItsDutyAndWhenItIsNextDue() throws {
    var state = hiredOrganization()
    let duty = EmployeeDuty.customerVoiceWeekly(now: epoch)
    state.knowledge?.employeeDuties.append(duty)

    let routine = try XCTUnwrap(state.employeeRoutine(for: duty.assigneeID))

    XCTAssertEqual(
      routine.cadence, .duty(title: duty.title, recurrence: "weekly", nextDueAt: epoch))
    XCTAssertEqual(routine.reviewerName, state.employee(duty.reviewerID)?.name)
    XCTAssertTrue(routine.markdown.contains("Customer Voice Weekly"))
    XCTAssertTrue(routine.markdown.contains("Next expected:"))
  }

  func testAnEmployeeWithNoCadenceSaysThatPlainly() throws {
    let state = hiredOrganization()
    let routine = try XCTUnwrap(state.employeeRoutine(for: "theo"))

    XCTAssertEqual(routine.cadence, .onRequestOnly)
    XCTAssertTrue(routine.markdown.contains("No recurring cadence"))
  }

  func testTheProjectionCarriesNoSecrets() throws {
    var state = hiredOrganization()
    try state.updateWorkingContract(
      employeeID: "theo",
      role: "Writer",
      responsibility: "Write",
      managerID: nil,
      assignedSkillIDs: ["communication"],
      declaredConnectionIDs: ["reddit"],
      capabilityGrants: ["web-research"],
      executionProvider: .localCodex,
      modelName: nil,
      boundaries: AutonomyBoundaries(),
      reviewPolicy: .always,
      actorID: "owner",
      reason: "routine fixture"
    )
    let markdown = try XCTUnwrap(state.employeeRoutine(for: "theo")).markdown

    for forbidden in ["secret", "token", "password", "api_key", "apiKey", "Bearer"] {
      XCTAssertFalse(
        markdown.localizedCaseInsensitiveContains(forbidden),
        "The routine projection must never carry \(forbidden).")
    }
  }

  // MARK: - Reopening

  func testReopeningRebuildsTheSameRoutineWithoutInventingARun() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var state = hiredOrganization()
    state.knowledge?.employeeDuties.append(EmployeeDuty.customerVoiceWeekly(now: epoch))
    try await store.save(state)
    let before = try XCTUnwrap(state.employeeRoutine(for: "iris")).markdown

    let reopened = try await store.loadOrCreate()
    let after = try XCTUnwrap(reopened.employeeRoutine(for: "iris")).markdown

    XCTAssertEqual(before, after)
    XCTAssertNil(reopened.latestRunReceipt(forEmployee: "iris"))
    XCTAssertTrue(after.contains("has not run yet"))
  }

  func testLegacyStateWithoutANextActionStillDecodesAndAnswersHonestly() throws {
    // A receipt written before next actions existed.
    let json = """
      {"id":"receipt-o1","occurrenceID":"o1","scheduledReason":"Weekly",
       "scheduledWindow":{"start":0,"duration":900,"flexibility":900},
       "work":{"employeeID":"iris","subject":{"commitment":{"_0":"c1"}},"authorityUsed":[]},
       "result":{"kind":"blocked","summary":"Stuck.","evidenceIDs":[],
                 "usage":{"unknown":{}}},
       "createdAt":0}
      """
    let decoder = JSONDecoder()

    let receipt = try decoder.decode(RunReceipt.self, from: Data(json.utf8))

    XCTAssertNil(receipt.result.nextAction)
    XCTAssertEqual(receipt.nextAction.owner, .owner)
    XCTAssertTrue(receipt.nextAction.detail.contains("recorded no next action"))
    XCTAssertEqual(receipt.result.evidenceStatement, "No evidence was produced by this run.")
  }

  // MARK: - Receipt states

  func testEveryTerminalStateHasItsOwnHeadline() {
    let headlines = RunResultKind.allCases.map { kind in
      RunReceipt(
        occurrenceID: "o-\(kind.rawValue)",
        scheduledReason: "Fixture",
        scheduledWindow: OccurrenceWindow(start: epoch, duration: 60, flexibility: 60),
        actual: nil,
        work: ReceiptWork(employeeID: "iris", subject: .commitment("c1")),
        result: ReceiptResult(kind: kind, summary: "Fixture"),
        createdAt: epoch
      ).headline
    }

    XCTAssertEqual(Set(headlines).count, RunResultKind.allCases.count)
    XCTAssertEqual(RunResultKind.allCases.count, 8)
  }

  func testWaitingForOwnerIsNeitherSuccessNorFailure() {
    XCTAssertFalse(RunResultKind.waitingForOwner.isHonestSuccess)
    XCTAssertTrue(RunResultKind.waitingForOwner.awaitsOwner)
    XCTAssertFalse(RunResultKind.cancelled.awaitsOwner)
    XCTAssertFalse(RunResultKind.quiet.awaitsOwner)
  }

  func testNothingOutstandingIsSaidExplicitly() {
    XCTAssertEqual(ReceiptNextAction.nothingOutstanding.owner, .nobody)
    XCTAssertEqual(
      ReceiptNextAction.nothingOutstanding.statement, "Nobody: Nothing is waiting on anyone.")
  }

  // MARK: - Finding the window a commitment ran in

  func testAFinishedCommitmentClosesTheWindowItWasDispatchedFor() throws {
    var context = try scheduled()
    _ = context.state.beginScheduledWork(context.occurrenceID, now: epoch)
    _ = context.state.updateEmployeeOutcome(context.commitmentID, now: epoch) {
      $0.status = .delivered
      $0.deliverySummary = "Wrote the note."
      $0.artifactIDs = ["artifact-1"]
    }

    let receipt = try XCTUnwrap(
      context.state.completeScheduledWork(
        forCommitment: context.commitmentID, now: epoch.addingTimeInterval(300),
        reason: "Weekly note"))

    XCTAssertEqual(receipt.occurrenceID, context.occurrenceID)
    XCTAssertEqual(receipt.result.kind, .changed)
    XCTAssertEqual(receipt.nextAction.owner, .owner)
    XCTAssertEqual(receipt.result.evidenceIDs, ["artifact-1"])
    XCTAssertEqual(
      context.state.latestRunReceipt(forCommitment: context.commitmentID)?.id, receipt.id)
  }

  func testAnUnscheduledCommitmentHasNoWindowToClose() throws {
    var state = hiredOrganization()
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the note", context: "", now: epoch)

    XCTAssertNil(
      state.completeScheduledWork(
        forCommitment: commitmentID, now: epoch, reason: "Owner asked"),
      "An owner-initiated run has no scheduled window, and one must not be invented.")
    XCTAssertNil(state.latestRunReceipt(forCommitment: commitmentID))
  }

  // MARK: - Fixtures

  private func scheduled() throws -> (
    state: OrganizationState, occurrenceID: String, commitmentID: String
  ) {
    var state = hiredOrganization()
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the weekly note", context: "", now: epoch)
    state.addSchedulePolicy(
      SchedulePolicy(
        id: "policy-1",
        employeeID: "theo",
        subject: .commitment(commitmentID),
        plan: SchedulePlan(
          recurrence: .oneTime, firstStart: epoch, expectedDuration: 900, flexibility: 600,
          timeZoneIdentifier: "UTC"),
        createdAt: epoch
      ))
    let created = try state.generateOccurrences(
      forPolicy: "policy-1", from: epoch.addingTimeInterval(-1),
      through: epoch.addingTimeInterval(60))
    return (state, try XCTUnwrap(created.first).id, commitmentID)
  }

  private func hiredOrganization() -> OrganizationState {
    var state = LocalOrganizationStore.migrated(.seeded(now: epoch), now: epoch)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    return state
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-tests-\(UUID().uuidString)", isDirectory: true)
  }
}
