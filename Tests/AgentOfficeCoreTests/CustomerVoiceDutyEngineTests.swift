import XCTest
@testable import AgentOfficeCore

final class CustomerVoiceDutyEngineTests: XCTestCase {
    func testSeedAndMigrationAddIrisDutyAndSkillOnce() {
        var legacy = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        legacy.schemaVersion = 5
        legacy.employees.removeAll { $0.id == "iris" }
        legacy.knowledge?.employeeDuties = []
        legacy.knowledge?.skillDefinitions.removeAll { $0.id == "customer-voice-analysis" }
        legacy.knowledge?.skillAssignments.removeAll { $0.employeeID == "iris" }

        let migrated = LocalOrganizationStore.migrated(legacy, now: Date(timeIntervalSince1970: 200))
        let migratedAgain = LocalOrganizationStore.migrated(migrated, now: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(migrated.schemaVersion, 8)
        XCTAssertEqual(migrated.employee("iris")?.role, "Customer Voice Analyst")
        XCTAssertEqual(migrated.employeeDuty(CustomerVoiceDutyEngine.dutyID)?.assigneeID, "iris")
        XCTAssertEqual(Set(migrated.assignedSkills(employeeID: "iris").map(\.id)), ["communication", "customer-voice-analysis"])
        XCTAssertEqual(migratedAgain.employees.filter { $0.id == "iris" }.count, 1)
        XCTAssertEqual(migratedAgain.employeeDuties.filter { $0.id == CustomerVoiceDutyEngine.dutyID }.count, 1)
    }

    func testInboxScannerIncludesOnlyBoundedDirectSupportedFiles() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try write("Useful feedback", to: root.appendingPathComponent("a-note.md"))
        try write("email,comment\na@example.com,Needs clearer setup", to: root.appendingPathComponent("b-export.csv"))
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
        XCTAssertEqual(Set(snapshot.exclusions.map(\.fileName)), Set([".private.txt", "image.png", "linked.md", "nested"]))
        XCTAssertTrue(snapshot.promptContext.contains("<feedback_source label=\"F1\" filename=\"a-note.md\">"))
    }

    func testInboxScannerReportsFileAndByteLimits() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for index in 0..<27 {
            try write("feedback \(index)", to: root.appendingPathComponent(String(format: "%02d.md", index)))
        }
        try write(String(repeating: "x", count: LocalFeedbackInboxScanner.maximumByteCount), to: root.appendingPathComponent("zz-large.md"))

        let snapshot = try LocalFeedbackInboxScanner.capture(at: root)

        XCTAssertEqual(snapshot.files.count, LocalFeedbackInboxScanner.maximumFileCount)
        XCTAssertTrue(snapshot.exclusions.contains { $0.reason.contains("25-file") })
        XCTAssertTrue(snapshot.exclusions.contains { $0.fileName == "zz-large.md" })
    }

    func testEmptyInboxBlocksBeforeRunner() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let occurrenceID = try organization.beginDutyOccurrence(
            dutyID: CustomerVoiceDutyEngine.dutyID,
            now: Date(timeIntervalSince1970: 200)
        )

        let result = await CustomerVoiceDutyEngine().run(
            organization,
            occurrenceID: occurrenceID,
            runner: UnexpectedDutyRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(result.dutyOccurrence(occurrenceID)?.status, .blocked)
        XCTAssertTrue(result.dutyOccurrence(occurrenceID)?.blockingReason?.contains("Add a .txt") == true)
        XCTAssertTrue(result.artifacts.isEmpty)
        XCTAssertEqual(result.employee("iris")?.status, .resting)
    }

    func testDemoDutyDeliversProjectsAndAdvancesOnce() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        try await store.ensureFeedbackInbox()
        try write("Onboarding was confusing, but the local files felt trustworthy.", to: store.feedbackInboxURL.appendingPathComponent("founder-note.md"))
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.executionMode = .demo
        let originalDue = try XCTUnwrap(organization.employeeDuty(CustomerVoiceDutyEngine.dutyID)?.nextDueAt)
        let occurrenceID = try organization.beginDutyOccurrence(
            dutyID: CustomerVoiceDutyEngine.dutyID,
            now: Date(timeIntervalSince1970: 200)
        )

        let result = await CustomerVoiceDutyEngine().run(
            organization,
            occurrenceID: occurrenceID,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )
        try await store.save(result)

        let occurrence = try XCTUnwrap(result.dutyOccurrence(occurrenceID))
        XCTAssertEqual(occurrence.status, .delivered)
        XCTAssertEqual(occurrence.evidenceBasis, "synthetic-demo")
        XCTAssertEqual(occurrence.includedInputs.map(\.fileName), ["founder-note.md"])
        XCTAssertEqual(result.artifacts.filter { $0.taskID == occurrenceID }.count, 2)
        XCTAssertEqual(result.employee("iris")?.status, .resting)
        XCTAssertEqual(
            result.employeeDuty(CustomerVoiceDutyEngine.dutyID)?.nextDueAt,
            Calendar.current.date(byAdding: .day, value: 7, to: originalDue)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("DUTIES.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("feedback-inbox").path))
        XCTAssertTrue(try String(contentsOf: root.appendingPathComponent("DUTIES.md"), encoding: .utf8).contains("Open Iris's brief"))

        let rerun = await CustomerVoiceDutyEngine().run(
            result,
            occurrenceID: occurrenceID,
            runner: UnexpectedDutyRunner(),
            store: store
        )
        XCTAssertEqual(rerun, result)
    }

    func testNextWeekCreatesAndDeliversADistinctOccurrence() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        try await store.ensureFeedbackInbox()
        try write("The weekly setup still needs a clearer next action.", to: store.feedbackInboxURL.appendingPathComponent("weekly-note.md"))
        var firstWeek = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        firstWeek.executionMode = .demo
        let firstID = try firstWeek.beginDutyOccurrence(
            dutyID: CustomerVoiceDutyEngine.dutyID,
            now: Date(timeIntervalSince1970: 200)
        )
        let firstResult = await CustomerVoiceDutyEngine().run(
            firstWeek,
            occurrenceID: firstID,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )

        var secondWeek = firstResult
        let secondID = try secondWeek.beginDutyOccurrence(
            dutyID: CustomerVoiceDutyEngine.dutyID,
            now: Date(timeIntervalSince1970: 700_000)
        )
        let secondResult = await CustomerVoiceDutyEngine().run(
            secondWeek,
            occurrenceID: secondID,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 700_100)
        )

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(secondResult.dutyOccurrence(firstID)?.status, .delivered)
        XCTAssertEqual(secondResult.dutyOccurrence(secondID)?.status, .delivered)
        XCTAssertEqual(secondResult.artifacts.filter { $0.taskID == secondID }.count, 2)
    }

    func testRealDutyRequiresValidCapturedSourceLabel() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        try await store.ensureFeedbackInbox()
        try write("I could not tell what to do next.", to: store.feedbackInboxURL.appendingPathComponent("feedback.txt"))
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.executionMode = .localCodex
        let occurrenceID = try organization.beginDutyOccurrence(dutyID: CustomerVoiceDutyEngine.dutyID)

        let result = await CustomerVoiceDutyEngine().run(
            organization,
            occurrenceID: occurrenceID,
            runner: InvalidLabelDutyRunner(),
            store: store
        )

        XCTAssertEqual(result.dutyOccurrence(occurrenceID)?.status, .blocked)
        XCTAssertTrue(result.dutyOccurrence(occurrenceID)?.blockingReason?.contains("captured feedback source") == true)
        XCTAssertTrue(result.artifacts.isEmpty)
    }

    func testStopAndReopenKeepSameOccurrenceResumable() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let occurrenceID = try organization.beginDutyOccurrence(dutyID: CustomerVoiceDutyEngine.dutyID)
        XCTAssertTrue(organization.stopDutyOccurrence(occurrenceID))
        XCTAssertEqual(organization.dutyOccurrence(occurrenceID)?.status, .queued)
        let resumedID = try organization.beginDutyOccurrence(dutyID: CustomerVoiceDutyEngine.dutyID)
        XCTAssertEqual(resumedID, occurrenceID)
        XCTAssertEqual(organization.dutyOccurrence(occurrenceID)?.attemptCount, 2)

        try await store.save(organization)
        let reopened = try await store.loadOrCreate()
        XCTAssertEqual(reopened.dutyOccurrence(occurrenceID)?.status, .queued)
        XCTAssertTrue(reopened.dutyOccurrence(occurrenceID)?.blockingReason?.contains("resume") == true)
    }

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

private struct InvalidLabelDutyRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        EmployeeWorkOutput(
            title: "Invalid customer voice brief",
            summary: "The brief cited an input that was not captured.",
            content: "# Input coverage\nOne file.\n# Themes\nConfusion.\n# Evidence\n[F9]\n# Uncertainty\nNarrow.\n# Owner decision\nClarify setup.\n# Next occurrence\nNext week."
        )
    }
}

private struct UnexpectedDutyRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        XCTFail("The duty runner should not have been called.")
        throw CustomerVoiceDutyError.notRunnable
    }
}
