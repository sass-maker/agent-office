import XCTest
@testable import AgentOfficeCore

final class EmployeeOutcomeEngineTests: XCTestCase {
    func testOutcomeValidationAndIndependentEmployeeQueues() throws {
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

        XCTAssertThrowsError(try organization.createEmployeeOutcome(
            employeeID: "maya",
            outcome: "   ",
            context: ""
        )) { XCTAssertEqual($0 as? EmployeeOutcomeError, .emptyOutcome) }
        XCTAssertThrowsError(try organization.createEmployeeOutcome(
            employeeID: "owner",
            outcome: "Prepare a decision brief",
            context: ""
        )) { XCTAssertEqual($0 as? EmployeeOutcomeError, .humanAssignee) }

        _ = try organization.createEmployeeOutcome(
            employeeID: "maya",
            outcome: "Prepare a decision brief",
            context: "Use the company profile.",
            now: Date(timeIntervalSince1970: 200)
        )
        let secondID = try organization.createEmployeeOutcome(
            employeeID: "theo",
            outcome: "Write the follow-up",
            context: ""
        )
        XCTAssertEqual(organization.employeeOutcome(secondID)?.assigneeID, "theo")
        XCTAssertEqual(organization.employeeOutcomes.filter { !$0.status.isTerminal }.count, 2)
        XCTAssertEqual(organization.activity.suffix(2).map(\.actorID), ["owner", "theo"])
    }

    func testCommunicationMigratesOnceToEveryAIEmployee() {
        var legacy = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        legacy.schemaVersion = 7
        legacy.knowledge?.skillDefinitions.removeAll { $0.id == "communication" }
        legacy.knowledge?.skillAssignments.removeAll { $0.skillID == "communication" }

        let migrated = LocalOrganizationStore.migrated(legacy, now: Date(timeIntervalSince1970: 200))
        let migratedAgain = LocalOrganizationStore.migrated(migrated, now: Date(timeIntervalSince1970: 300))
        let aiIDs = Set(migrated.employees.filter { $0.kind == .ai }.map(\.id))
        let communicationAssignees = Set(migrated.knowledge?.skillAssignments
            .filter { $0.skillID == "communication" }.map(\.employeeID) ?? [])

        XCTAssertEqual(migrated.schemaVersion, 9)
        XCTAssertEqual(communicationAssignees, aiIDs)
        XCTAssertTrue(migrated.assignedSkills(employeeID: "owner").isEmpty)
        XCTAssertEqual(migratedAgain.knowledge?.skillDefinitions.filter { $0.id == "communication" }.count, 1)
        XCTAssertEqual(migratedAgain.knowledge?.skillAssignments.filter { $0.skillID == "communication" }.count, aiIDs.count)
    }

    func testEmployeePlansTicketsDeliversArtifactsAndDoesNotDuplicate() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        let engine = EmployeeOutcomeEngine()
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let outcomeID = try organization.createEmployeeOutcome(
            employeeID: "theo",
            outcome: "Draft a concise launch note",
            context: "The audience is solo founders.",
            now: Date(timeIntervalSince1970: 200)
        )
        organization = engine.start(organization, outcomeID: outcomeID, now: Date(timeIntervalSince1970: 210))

        let result = await engine.run(
            organization,
            outcomeID: outcomeID,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )
        let outcome = try XCTUnwrap(result.employeeOutcome(outcomeID))

        XCTAssertEqual(outcome.status, .delivered)
        XCTAssertEqual(outcome.taskIDs.count, 2)
        XCTAssertEqual(outcome.artifactIDs.count, 2)
        XCTAssertTrue(outcome.selectedSkillIDs.contains("communication"))
        XCTAssertTrue(outcome.taskIDs.allSatisfy { result.task($0)?.status == .done })
        XCTAssertEqual(result.employee("theo")?.status, .resting)
        XCTAssertTrue(result.activity.contains { $0.actorID == "theo" && $0.message.contains("tickets") })
        XCTAssertTrue(result.activity.contains { $0.actorID == "theo" && $0.kind == .completed })

        try await store.save(result)
        let projection = try String(contentsOf: root.appendingPathComponent("EMPLOYEE_OUTCOMES.md"), encoding: .utf8)
        XCTAssertTrue(projection.contains("Draft a concise launch note"))
        XCTAssertTrue(projection.contains("Communication"))

        let rerun = await engine.run(
            result,
            outcomeID: outcomeID,
            runner: UnexpectedOutcomeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 400)
        )
        XCTAssertEqual(rerun, result)
        XCTAssertEqual(rerun.artifacts.filter { outcome.artifactIDs.contains($0.id) }.count, 2)
    }

    func testMissingResearchPermissionCreatesPreciseHelpRequest() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        let engine = EmployeeOutcomeEngine()
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.executionMode = .localCodex
        let outcomeID = try organization.createEmployeeOutcome(
            employeeID: "nia",
            outcome: "Research current onboarding patterns",
            context: "Use primary sources.",
            now: Date(timeIntervalSince1970: 200)
        )
        organization = engine.start(organization, outcomeID: outcomeID, now: Date(timeIntervalSince1970: 210))

        let result = await engine.run(
            organization,
            outcomeID: outcomeID,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )
        let outcome = try XCTUnwrap(result.employeeOutcome(outcomeID))
        let blockedTask = try XCTUnwrap(outcome.taskIDs.compactMap(result.task).first { $0.status == .blocked })

        XCTAssertEqual(outcome.status, .waiting)
        XCTAssertTrue(outcome.helpRequest?.localizedCaseInsensitiveContains("web research permission") == true)
        XCTAssertEqual(blockedTask.kind, .research)
        XCTAssertEqual(result.employee("nia")?.status, .blocked)
        XCTAssertEqual(result.blockers.last?.taskID, blockedTask.id)
        XCTAssertEqual(result.activity.last?.actorID, "nia")
        XCTAssertEqual(result.activity.last?.kind, .blocked)
    }

    func testInterruptedOutcomeKeepsPlanAndReturnsToQueued() throws {
        let now = Date(timeIntervalSince1970: 100)
        var organization = OrganizationState.seeded(now: now)
        let outcomeID = try organization.createEmployeeOutcome(
            employeeID: "maya",
            outcome: "Prepare an operating note",
            context: "",
            now: now
        )
        _ = organization.updateEmployeeOutcome(outcomeID, now: now) { outcome in
            outcome.status = .working
            outcome.taskIDs = ["\(outcomeID)-task-1"]
        }
        organization.tasks.append(WorkTask(
            id: "\(outcomeID)-task-1",
            title: "Frame the note",
            detail: "Create a useful frame.",
            kind: .analysis,
            status: .doing,
            assigneeID: "maya",
            reviewerID: nil,
            dependencyIDs: [],
            artifactIDs: [],
            revisionCount: 0,
            maxRevisions: 0,
            updatedAt: now
        ))
        let employeeIndex = organization.employees.firstIndex { $0.id == "maya" }!
        organization.employees[employeeIndex].status = .working
        organization.employees[employeeIndex].currentTaskID = "\(outcomeID)-task-1"

        XCTAssertTrue(organization.resetInterruptedEmployeeOutcome(now: Date(timeIntervalSince1970: 200)))
        XCTAssertEqual(organization.employeeOutcome(outcomeID)?.status, .queued)
        XCTAssertEqual(organization.task("\(outcomeID)-task-1")?.status, .ready)
        XCTAssertEqual(organization.employee("maya")?.status, .resting)
        XCTAssertEqual(organization.employeeOutcome(outcomeID)?.taskIDs, ["\(outcomeID)-task-1"])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentOfficeOutcomeTests-\(UUID().uuidString)", isDirectory: true)
    }
}

private struct UnexpectedOutcomeRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        XCTFail("A delivered outcome must not invoke the runner again")
        return EmployeeWorkOutput(title: "Unexpected", summary: "Unexpected", content: "Unexpected")
    }
}
