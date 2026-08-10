import XCTest
@testable import AgentOfficeCore

final class ResearchAssignmentEngineTests: XCTestCase {
    func testAssignmentRequiresOutcomeDelegatesAndAllowsOnlyOneActiveAssignment() throws {
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

        XCTAssertThrowsError(try organization.createResearchAssignment(outcome: "  ", context: "")) { error in
            XCTAssertEqual(error as? ResearchAssignmentError, .emptyOutcome)
        }

        let assignmentID = try organization.createResearchAssignment(
            outcome: "  Compare three onboarding approaches  ",
            context: "  Focus on first-run clarity.  ",
            now: Date(timeIntervalSince1970: 200)
        )
        let assignment = try XCTUnwrap(organization.researchAssignment(assignmentID))

        XCTAssertEqual(assignment.outcome, "Compare three onboarding approaches")
        XCTAssertEqual(assignment.context, "Focus on first-run clarity.")
        XCTAssertEqual(assignment.requestedByActorID, "owner")
        XCTAssertEqual(assignment.delegatedByActorID, "mira")
        XCTAssertEqual(assignment.assigneeID, "nia")
        XCTAssertEqual(assignment.reviewerID, "mira")
        XCTAssertEqual(Array(organization.activity.suffix(2).map(\.actorID)), ["owner", "mira"])

        XCTAssertThrowsError(try organization.createResearchAssignment(outcome: "Another question", context: "")) { error in
            XCTAssertEqual(error as? ResearchAssignmentError, .activeAssignmentExists)
        }
    }

    func testStartingResearchPublishesLiveEmployeeAndAssignmentState() throws {
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let assignmentID = try organization.createResearchAssignment(
            outcome: "Map current onboarding patterns",
            context: "",
            now: Date(timeIntervalSince1970: 200)
        )

        let started = ResearchAssignmentEngine().start(
            organization,
            assignmentID: assignmentID,
            now: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(started.researchAssignment(assignmentID)?.status, .researching)
        XCTAssertEqual(started.researchAssignment(assignmentID)?.attemptCount, 1)
        XCTAssertEqual(started.employee("nia")?.status, .working)
        XCTAssertEqual(started.employee("mira")?.status, .planning)
        XCTAssertEqual(started.workdayStatus, .active)
    }

    func testOwnerCanStopBlockedAssignmentAndCreateAnother() throws {
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let firstID = try organization.createResearchAssignment(
            outcome: "A question that needs permission",
            context: "",
            now: Date(timeIntervalSince1970: 200)
        )
        _ = organization.updateResearchAssignment(firstID) { value in
            value.status = .waiting
            value.blockingReason = "Permission required"
        }

        XCTAssertTrue(organization.cancelResearchAssignment(firstID, now: Date(timeIntervalSince1970: 300)))
        XCTAssertEqual(organization.researchAssignment(firstID)?.status, .cancelled)
        XCTAssertNil(organization.activeResearchAssignment)
        XCTAssertEqual(organization.activity.last?.actorID, "owner")
        XCTAssertNoThrow(try organization.createResearchAssignment(outcome: "A new question", context: ""))
    }

    func testSourceVerifierRequiresValidURLInsideSourcesSection() {
        XCTAssertFalse(ResearchEvidenceVerifier.containsSourceURL("A link https://example.com outside any source section."))
        XCTAssertFalse(ResearchEvidenceVerifier.containsSourceURL("## Sources\n- https://"))
        XCTAssertTrue(ResearchEvidenceVerifier.containsSourceURL("## Sources\n- https://example.com/official"))
        XCTAssertFalse(ResearchEvidenceVerifier.hasRequiredSections("## Findings\nUseful\n\n## Sources\n- https://example.com"))
        XCTAssertTrue(ResearchEvidenceVerifier.hasRequiredSections("## Findings\nUseful\n\n## Sources\n- https://example.com\n\n## Uncertainty\nLimited sample.\n\n## Recommended next actions\nValidate."))
    }

    func testDemoAssignmentDeliversSyntheticArtifactsAndPersistsProjection() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.executionMode = .demo
        let assignmentID = try organization.createResearchAssignment(
            outcome: "Map the decisions a founder makes during first use",
            context: "Use only the supplied product context.",
            now: Date(timeIntervalSince1970: 200)
        )

        let result = await ResearchAssignmentEngine().run(
            organization,
            assignmentID: assignmentID,
            runner: DeterministicEmployeeRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )
        let assignment = try XCTUnwrap(result.researchAssignment(assignmentID))

        XCTAssertEqual(assignment.status, .delivered)
        XCTAssertEqual(assignment.evidenceBasis, "synthetic-demo")
        XCTAssertEqual(assignment.attemptCount, 1)
        XCTAssertNotNil(assignment.briefArtifactID)
        XCTAssertNotNil(assignment.deliveryArtifactID)
        XCTAssertEqual(result.artifacts.filter { $0.taskID == assignmentID }.count, 2)
        XCTAssertTrue(result.knowledge?.capabilityEvents.isEmpty == true)
        XCTAssertEqual(result.workdayStatus, .resting)
        XCTAssertTrue(result.employees.filter { $0.kind == .ai }.allSatisfy { $0.status == .resting })

        let brief = try XCTUnwrap(result.artifacts.first { $0.id == assignment.briefArtifactID })
        let briefContent = try await store.readArtifact(relativePath: brief.relativePath)
        XCTAssertTrue(briefContent.contains("synthetic-demo"))
        XCTAssertTrue(briefContent.localizedCaseInsensitiveContains("no web research"))

        try await store.save(result)
        let reopened = try await store.loadOrCreate()
        XCTAssertEqual(reopened.researchAssignment(assignmentID)?.status, .delivered)
        XCTAssertEqual(reopened.artifacts.filter { $0.taskID == assignmentID }.count, 2)
        let projection = try String(contentsOf: root.appendingPathComponent("RESEARCH_ASSIGNMENTS.md"), encoding: .utf8)
        XCTAssertTrue(projection.contains("Map the decisions a founder makes during first use"))
        XCTAssertTrue(projection.contains("synthetic-demo"))
        XCTAssertTrue(projection.contains("Open Nia's brief"))

        let rerun = await ResearchAssignmentEngine().run(
            reopened,
            assignmentID: assignmentID,
            runner: UnexpectedResearchRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 400)
        )
        XCTAssertEqual(rerun, reopened)
        XCTAssertEqual(rerun.artifacts.filter { $0.taskID == assignmentID }.count, 2)
    }

    func testLocalResearchWaitsForPermissionWithoutStartingRunner() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.executionMode = .localCodex
        let assignmentID = try organization.createResearchAssignment(
            outcome: "Find current primary evidence",
            context: "",
            now: Date(timeIntervalSince1970: 200)
        )

        let result = await ResearchAssignmentEngine().run(
            organization,
            assignmentID: assignmentID,
            runner: UnexpectedResearchRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(result.researchAssignment(assignmentID)?.status, .waiting)
        XCTAssertEqual(result.researchAssignment(assignmentID)?.attemptCount, 0)
        XCTAssertTrue(result.researchAssignment(assignmentID)?.blockingReason?.contains("grant") == true)
        XCTAssertTrue(result.artifacts.isEmpty)
    }

    func testLocalResearchRequiresURLBeforeDelivery() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = permittedOrganization()
        let assignmentID = try organization.createResearchAssignment(
            outcome: "Find current primary evidence",
            context: "",
            now: Date(timeIntervalSince1970: 200)
        )

        let result = await ResearchAssignmentEngine().run(
            organization,
            assignmentID: assignmentID,
            runner: UncitedResearchRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(result.researchAssignment(assignmentID)?.status, .failed)
        XCTAssertTrue(result.researchAssignment(assignmentID)?.blockingReason?.localizedCaseInsensitiveContains("source URL") == true)
        XCTAssertTrue(result.artifacts.isEmpty)
        XCTAssertEqual(result.knowledge?.capabilityEvents.suffix(2).map(\.kind), [.started, .failed])
    }

    func testPermittedLocalResearchDeliversCitedBriefAndCapabilityEvidence() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = permittedOrganization()
        let assignmentID = try organization.createResearchAssignment(
            outcome: "Find current primary evidence",
            context: "Prefer official documentation.",
            now: Date(timeIntervalSince1970: 200)
        )

        let result = await ResearchAssignmentEngine().run(
            organization,
            assignmentID: assignmentID,
            runner: CitedResearchRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(result.researchAssignment(assignmentID)?.status, .delivered)
        XCTAssertEqual(result.researchAssignment(assignmentID)?.evidenceBasis, "permitted-web-research")
        XCTAssertEqual(result.knowledge?.capabilityEvents.suffix(2).map(\.kind), [.started, .succeeded])
        XCTAssertEqual(result.artifacts.filter { $0.taskID == assignmentID }.count, 2)
        XCTAssertEqual(result.knowledge?.memoryEntries.last?.employeeID, "nia")
        XCTAssertEqual(result.activity.suffix(2).map(\.actorID), ["nia", "mira"])
    }

    func testUnavailableRuntimeWaitsAndOrdinaryFailureCanRetry() async throws {
        for (runner, expectedStatus) in [
            (AnyResearchRunner { _ in throw CodexRunnerError.unavailable }, ResearchAssignmentStatus.waiting),
            (AnyResearchRunner { _ in throw ResearchTestFailure() }, ResearchAssignmentStatus.failed),
        ] {
            let root = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let store = LocalOrganizationStore(rootURL: root)
            var organization = permittedOrganization()
            let assignmentID = try organization.createResearchAssignment(
                outcome: "Investigate a current market question",
                context: "",
                now: Date(timeIntervalSince1970: 200)
            )

            let result = await ResearchAssignmentEngine().run(
                organization,
                assignmentID: assignmentID,
                runner: runner,
                store: store,
                now: Date(timeIntervalSince1970: 300)
            )

            XCTAssertEqual(result.researchAssignment(assignmentID)?.status, expectedStatus)
            XCTAssertEqual(result.workdayStatus, .resting)
            XCTAssertTrue(result.artifacts.isEmpty)
        }
    }

    func testCancellationAndReopenLeaveResearchReadyToResume() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let assignmentID = try organization.createResearchAssignment(
            outcome: "Summarize a long-running question",
            context: "",
            now: Date(timeIntervalSince1970: 200)
        )

        let cancelled = await ResearchAssignmentEngine().run(
            organization,
            assignmentID: assignmentID,
            runner: CancelledResearchRunner(),
            store: store,
            now: Date(timeIntervalSince1970: 300)
        )
        XCTAssertEqual(cancelled.researchAssignment(assignmentID)?.status, .queued)
        XCTAssertTrue(cancelled.researchAssignment(assignmentID)?.blockingReason?.contains("resume") == true)

        var interrupted = cancelled
        _ = interrupted.updateResearchAssignment(assignmentID) { $0.status = .researching }
        try await store.save(interrupted)
        let reopened = try await store.loadOrCreate()

        XCTAssertEqual(reopened.researchAssignment(assignmentID)?.status, .queued)
        XCTAssertTrue(reopened.researchAssignment(assignmentID)?.blockingReason?.contains("resume") == true)
        XCTAssertTrue(reopened.artifacts.isEmpty)
    }

    func testAssignmentCodexArgumentsRequireGrantAndSearchPrompt() {
        let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let employee = organization.employee("nia")!
        let assignmentTask = WorkTask(
            id: "research-assignment-example",
            title: "Research current onboarding patterns",
            detail: "Return primary sources.",
            kind: .research,
            status: .doing,
            assigneeID: "nia",
            reviewerID: "mira",
            dependencyIDs: [],
            artifactIDs: [],
            revisionCount: 0,
            maxRevisions: 0,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        var request = EmployeeWorkRequest(
            operation: .research,
            employee: employee,
            task: assignmentTask,
            organizationName: organization.name,
            outcome: "Find current evidence",
            productBrief: organization.productBrief,
            context: "",
            capabilityGrants: [],
            workspaceURL: temporaryDirectory()
        )

        XCTAssertFalse(CodexEmployeeRunner.commandArguments(for: request).contains("--search"))
        request.capabilityGrants = ["web-research"]
        XCTAssertEqual(CodexEmployeeRunner.commandArguments(for: request).first, "--search")
        let prompt = CodexEmployeeRunner.prompt(for: request)
        XCTAssertTrue(prompt.contains("Sources"))
        XCTAssertTrue(prompt.contains("full HTTP(S) source URL"))
        XCTAssertTrue(prompt.contains("Recommended next actions"))
    }

    private func permittedOrganization() -> OrganizationState {
        var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        organization.executionMode = .localCodex
        organization.employees[organization.employees.firstIndex { $0.id == "nia" }!]
            .capabilityGrants = ["web-research"]
        return organization
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-office-research-tests-\(UUID().uuidString)", isDirectory: true)
    }
}

private struct CitedResearchRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        EmployeeWorkOutput(
            title: "Current evidence",
            summary: "Nia found a current primary source.",
            content: "# Findings\n\nThe official documentation supports the finding.\n\n## Sources\n- https://example.com/official\n\n## Uncertainty\nThe sample is narrow.\n\n## Recommended next actions\nValidate the finding with another primary source.",
            evidenceBasis: "permitted-web-research"
        )
    }
}

private struct UncitedResearchRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        EmployeeWorkOutput(
            title: "Uncited findings",
            summary: "This output has no checkable source.",
            content: "# Findings\n\nA conclusion without any source reference.\n\n## Sources\nNo source supplied.\n\n## Uncertainty\nEvidence is missing.\n\n## Recommended next actions\nRetry with a primary source."
        )
    }
}

private struct UnexpectedResearchRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        XCTFail("The runner should not have been called.")
        throw ResearchTestFailure()
    }
}

private struct CancelledResearchRunner: EmployeeRunner {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        throw CancellationError()
    }
}

private struct ResearchTestFailure: LocalizedError {
    var errorDescription: String? { "The research service failed." }
}

private struct AnyResearchRunner: EmployeeRunner {
    let operation: @Sendable (EmployeeWorkRequest) async throws -> EmployeeWorkOutput

    init(_ operation: @escaping @Sendable (EmployeeWorkRequest) async throws -> EmployeeWorkOutput) {
        self.operation = operation
    }

    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        try await operation(request)
    }
}
