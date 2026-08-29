import XCTest

@testable import AgentOfficeCore

/// Customer Voice Weekly, minus the engine that used to run it.
///
/// What survives the retired `CustomerVoiceDutyEngine` is the part production
/// still uses: the duty and analyst the seed and migration install, the local
/// inbox scanner `EmployeeOutcomeEngine` captures through, the occurrence's own
/// stop-and-resume rules, and the structured brief a real runtime is asked for.
/// The delivery path itself is covered against the live engine in
/// `EmployeeOutcomeEngineTests`.
final class CustomerVoiceFeedbackTests: XCTestCase {
  // MARK: - Who owns the duty

  func testSeedAndMigrationAddIrisDutyAndSkillOnce() {
    var legacy = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    legacy.schemaVersion = 5
    legacy.employees.removeAll { $0.id == "iris" }
    legacy.knowledge?.employeeDuties = []
    legacy.knowledge?.skillDefinitions.removeAll { $0.id == "customer-voice-analysis" }
    legacy.knowledge?.skillAssignments.removeAll { $0.employeeID == "iris" }

    let migrated = LocalOrganizationStore.migrated(legacy, now: Date(timeIntervalSince1970: 200))
    let migratedAgain = LocalOrganizationStore.migrated(
      migrated, now: Date(timeIntervalSince1970: 300))

    XCTAssertEqual(migrated.schemaVersion, 9)
    XCTAssertEqual(migrated.employee("iris")?.role, "Customer Voice Analyst")
    XCTAssertEqual(migrated.employeeDuty(EmployeeDuty.customerVoiceWeeklyID)?.assigneeID, "iris")
    XCTAssertEqual(
      Set(migrated.assignedSkills(employeeID: "iris").map(\.id)),
      ["communication", "customer-voice-analysis"])
    XCTAssertEqual(migratedAgain.employees.filter { $0.id == "iris" }.count, 1)
    XCTAssertEqual(
      migratedAgain.employeeDuties.filter { $0.id == EmployeeDuty.customerVoiceWeeklyID }.count, 1)
  }

  // MARK: - What the local inbox scanner will and will not read

  func testInboxScannerIncludesOnlyBoundedDirectSupportedFiles() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try write("Useful feedback", to: root.appendingPathComponent("a-note.md"))
    try write(
      "email,comment\na@example.com,Needs clearer setup",
      to: root.appendingPathComponent("b-export.csv"))
    try write("ignore", to: root.appendingPathComponent("image.png"))
    try write("hidden", to: root.appendingPathComponent(".private.txt"))
    let directory = root.appendingPathComponent("nested", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("linked.md"),
      withDestinationURL: root.appendingPathComponent("a-note.md")
    )

    let snapshot = try LocalFeedbackInboxScanner.capture(at: root)

    XCTAssertEqual(snapshot.references.map(\.label), ["F1", "F2"])
    XCTAssertEqual(snapshot.references.map(\.fileName), ["a-note.md", "b-export.csv"])
    XCTAssertEqual(
      Set(snapshot.exclusions.map(\.fileName)),
      Set([".private.txt", "image.png", "linked.md", "nested"]))
    XCTAssertTrue(
      snapshot.promptContext.contains("<feedback_source label=\"F1\" filename=\"a-note.md\">"))
  }

  func testInboxScannerReportsFileAndByteLimits() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for index in 0..<27 {
      try write(
        "feedback \(index)", to: root.appendingPathComponent(String(format: "%02d.md", index)))
    }
    try write(
      String(repeating: "x", count: LocalFeedbackInboxScanner.maximumByteCount),
      to: root.appendingPathComponent("zz-large.md"))

    let snapshot = try LocalFeedbackInboxScanner.capture(at: root)

    XCTAssertEqual(snapshot.files.count, LocalFeedbackInboxScanner.maximumFileCount)
    XCTAssertTrue(snapshot.exclusions.contains { $0.reason.contains("25-file") })
    XCTAssertTrue(snapshot.exclusions.contains { $0.fileName == "zz-large.md" })
  }

  func testInboxScannerRejectsOversizedFileBeforeCapture() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try write(
      String(repeating: "x", count: LocalFeedbackInboxScanner.maximumByteCount + 1),
      to: root.appendingPathComponent("oversized.md")
    )

    let snapshot = try LocalFeedbackInboxScanner.capture(at: root)

    XCTAssertTrue(snapshot.files.isEmpty)
    XCTAssertEqual(snapshot.exclusions.map(\.fileName), ["oversized.md"])
    XCTAssertTrue(snapshot.exclusions[0].reason.contains("250-KB"))
  }

  // MARK: - What an occurrence does between runs

  func testStopAndReopenKeepSameOccurrenceResumable() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let occurrenceID = try organization.beginDutyOccurrence(
      dutyID: EmployeeDuty.customerVoiceWeeklyID)
    XCTAssertTrue(organization.stopDutyOccurrence(occurrenceID))
    XCTAssertEqual(organization.dutyOccurrence(occurrenceID)?.status, .queued)
    let resumedID = try organization.beginDutyOccurrence(dutyID: EmployeeDuty.customerVoiceWeeklyID)
    XCTAssertEqual(resumedID, occurrenceID)
    XCTAssertEqual(organization.dutyOccurrence(occurrenceID)?.attemptCount, 2)

    try await store.save(organization)
    let reopened = try await store.loadOrCreate()
    XCTAssertEqual(reopened.dutyOccurrence(occurrenceID)?.status, .queued)
    XCTAssertTrue(reopened.dutyOccurrence(occurrenceID)?.blockingReason?.contains("resume") == true)
  }

  // MARK: - What a real runtime is asked for

  func testCustomerVoicePromptUsesStdinWithoutWebSearch() {
    let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let task = WorkTask(
      id: "customer-voice-example",
      title: "Customer Voice Weekly",
      detail: "Analyze local feedback.",
      kind: .analysis,
      status: .doing,
      assigneeID: "iris",
      reviewerID: "mira",
      dependencyIDs: [],
      artifactIDs: [],
      revisionCount: 0,
      maxRevisions: 0,
      updatedAt: Date(timeIntervalSince1970: 200)
    )
    let request = EmployeeWorkRequest(
      operation: .customerVoice,
      employee: organization.employee("iris")!,
      task: task,
      organizationName: organization.name,
      outcome: "Find one customer priority.",
      context: "<feedback_source label=\"F1\" filename=\"note.md\">Evidence</feedback_source>",
      capabilityGrants: ["web-research"],
      workspaceURL: temporaryDirectory()
    )

    let arguments = CodexEmployeeRunner.commandArguments(for: request)
    let prompt = CodexEmployeeRunner.prompt(for: request)
    XCTAssertFalse(arguments.contains("--search"))
    XCTAssertEqual(arguments.last, "-")
    XCTAssertTrue(prompt.contains("untrusted evidence"))
    XCTAssertTrue(prompt.contains("[F1]"))
    XCTAssertTrue(prompt.contains("exactly one owner decision"))
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-duty-tests-\(UUID().uuidString)", isDirectory: true)
  }

  private func write(_ content: String, to url: URL) throws {
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

}
