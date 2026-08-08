import XCTest
@testable import AgentOfficeCore

final class WorkdayEngineTests: XCTestCase {
    func testSeededOrganizationHasDurableEmployeeShape() {
        let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(organization.employees.map(\.id), ["maya", "nia", "theo"])
        XCTAssertEqual(organization.employees.map(\.kind), [.ai, .ai, .ai])
        XCTAssertEqual(organization.employee("theo")?.managerID, "maya")
        XCTAssertTrue(organization.employees.allSatisfy { $0.capabilityGrants.isEmpty })
        XCTAssertEqual(organization.tasks.filter { $0.status == .ready }.map(\.kind), [.research])
    }

    func testPersistenceRoundTripKeepsOrganizationAndArtifactsInspectable() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.outcome = "A persisted outcome"

        try await store.save(organization)
        try await store.writeArtifact(
            relativePath: "employees/nia/research.md",
            content: "# Evidence\n\nLocal and inspectable."
        )

        let loaded = try await store.loadOrCreate()
        let artifact = try await store.readArtifact(relativePath: "employees/nia/research.md")

        XCTAssertEqual(loaded.outcome, "A persisted outcome")
        XCTAssertEqual(loaded.employees, organization.employees)
        XCTAssertTrue(artifact.contains("Local and inspectable"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("organization.json").path))
    }

    func testDeterministicTeamCompletesResearchDraftReviewRevisionAndReport() async {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        let engine = WorkdayEngine()
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.workdayStatus = .active

        for step in 0..<10 where organization.workdayStatus == .active {
            organization = await engine.advance(
                organization,
                runner: DeterministicEmployeeRunner(),
                store: store,
                now: Date(timeIntervalSince1970: TimeInterval(200 + step))
            )
        }

        XCTAssertEqual(organization.workdayStatus, .complete)
        XCTAssertTrue(organization.tasks.allSatisfy { $0.status == .done })
        XCTAssertEqual(organization.goals.first?.progress, 1)
        XCTAssertEqual(organization.task("draft-first-article")?.revisionCount, 1)
        XCTAssertEqual(organization.artifacts.filter { $0.kind == .draft }.count, 2)
        XCTAssertEqual(organization.artifacts.filter { $0.kind == .review }.count, 2)
        XCTAssertEqual(organization.artifacts.filter { $0.kind == .report }.count, 1)
        XCTAssertTrue(organization.blockers.isEmpty)
        XCTAssertTrue(organization.employees.allSatisfy { $0.status == .resting })

        let knownActors = Set(organization.employees.map(\.id) + ["owner"])
        XCTAssertTrue(organization.activity.allSatisfy { knownActors.contains($0.actorID) })
    }

    func testThirdRevisionRequestStopsAsOwnerBlocker() async {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        let engine = WorkdayEngine()
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.workdayStatus = .active

        for step in 0..<12 where organization.blockers.isEmpty {
            organization = await engine.advance(
                organization,
                runner: AlwaysReviseRunner(),
                store: store,
                now: Date(timeIntervalSince1970: TimeInterval(300 + step))
            )
        }

        let draft = organization.task("draft-first-article")
        XCTAssertEqual(draft?.revisionCount, 2)
        XCTAssertEqual(draft?.status, .blocked)
        XCTAssertEqual(organization.blockers.count, 1)
        XCTAssertTrue(organization.blockers[0].detail.contains("2-revision limit"))
        XCTAssertEqual(organization.blockers[0].employeeID, "maya")
    }

    func testRestingOrganizationDoesNotAdvanceWork() async {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        let original = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

        let unchanged = await WorkdayEngine().advance(
            original,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(unchanged, original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("organization.json").path))
    }

    func testCancelledEmployeeWorkDoesNotCreateAFalseBlocker() async {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.workdayStatus = .active

        let result = await WorkdayEngine().advance(
            organization,
            runner: CancelledRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(result, organization)
        XCTAssertTrue(result.blockers.isEmpty)
        XCTAssertEqual(result.task("research-audience")?.status, .ready)
        let persisted = try? await store.loadOrCreate()
        XCTAssertEqual(persisted?.workdayStatus, .active)
        XCTAssertEqual(persisted?.tasks, organization.tasks)
        XCTAssertEqual(persisted?.blockers, organization.blockers)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-office-tests-\(UUID().uuidString)", isDirectory: true)
    }
}

private struct AlwaysReviseRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        if request.operation == .review {
            return EmployeeWorkOutput(
                title: "Review",
                summary: "More revision requested.",
                content: "# Revise\n\nPlease try again.",
                verdict: .revise
            )
        }
        return try await DeterministicEmployeeRunner().perform(request)
    }
}

private struct CancelledRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        throw CancellationError()
    }
}
