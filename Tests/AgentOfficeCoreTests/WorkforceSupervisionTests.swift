import XCTest
@testable import AgentOfficeCore

final class WorkforceSupervisionTests: XCTestCase {
    func testContractPlanRequiresApprovalAndDeliveryRequiresAcceptance() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalOrganizationStore(rootURL: root)
        let engine = EmployeeOutcomeEngine()
        var state = LocalOrganizationStore.migrated(.seeded(now: Date(timeIntervalSince1970: 100)))
        let outcomeID = try state.createEmployeeOutcome(employeeID: "maya", outcome: "Prepare an editorial decision", context: "", acceptanceCriteria: ["Name one decision"], now: Date(timeIntervalSince1970: 200))
        state = engine.start(state, outcomeID: outcomeID, now: Date(timeIntervalSince1970: 210))

        state = await engine.run(state, outcomeID: outcomeID, runner: DeterministicEmployeeRunner(), store: store, now: Date(timeIntervalSince1970: 300), persistsTransitions: false)
        XCTAssertEqual(state.employeeOutcome(outcomeID)?.status, .proposed)
        XCTAssertEqual(state.managementInbox.first { $0.outcomeID == outcomeID }?.kind, .plan)

        try state.approveOutcomePlan(outcomeID, note: "Proceed with the bounded plan.", now: Date(timeIntervalSince1970: 310))
        state = engine.start(state, outcomeID: outcomeID, now: Date(timeIntervalSince1970: 320))
        state = await engine.run(state, outcomeID: outcomeID, runner: DeterministicEmployeeRunner(), store: store, now: Date(timeIntervalSince1970: 400), persistsTransitions: false)

        XCTAssertEqual(state.employeeOutcome(outcomeID)?.status, .delivered)
        XCTAssertEqual(state.employeeOutcome(outcomeID)?.effectiveDeliveries.count, 1)
        XCTAssertNil(state.employeeOutcome(outcomeID)?.acceptedAt)
        XCTAssertEqual(state.managementInbox.first { $0.outcomeID == outcomeID }?.kind, .delivery)

        try state.acceptOutcome(outcomeID, note: "This resolves the decision.", now: Date(timeIntervalSince1970: 500))
        XCTAssertEqual(state.employeeOutcome(outcomeID)?.status, .accepted)
        XCTAssertEqual(state.employeeOutcome(outcomeID)?.acceptedByActorID, "owner")
        XCTAssertFalse(state.managementInbox.contains { $0.outcomeID == outcomeID })
    }

    func testContextualReplyResumesOnlyAffectedOutcome() throws {
        var state = LocalOrganizationStore.migrated(.seeded())
        let waitingID = try state.createEmployeeOutcome(employeeID: "nia", outcome: "Find evidence", context: "")
        let otherID = try state.createEmployeeOutcome(employeeID: "theo", outcome: "Draft note", context: "")
        _ = state.updateEmployeeOutcome(waitingID) { $0.status = .waiting; $0.helpRequest = "Which customer segment?" }

        try state.replyToOutcome(waitingID, message: "Focus on solo founders.")

        XCTAssertEqual(state.employeeOutcome(waitingID)?.status, .queued)
        XCTAssertNil(state.employeeOutcome(waitingID)?.helpRequest)
        XCTAssertEqual(state.employeeOutcome(otherID)?.status, .queued)
        XCTAssertEqual(state.employeeOutcome(waitingID)?.effectiveManagementMessages.last?.actorID, "owner")
        XCTAssertEqual(state.supervisionEvents.last?.kind, .ownerReplied)
    }

    func testDelegationValidatesEmploymentAndSkillCoverage() throws {
        var state = LocalOrganizationStore.migrated(.seeded())
        let outcomeID = try state.createEmployeeOutcome(employeeID: "maya", outcome: "Coordinate a brief", context: "")
        let taskID = "\(outcomeID)-task-1"
        state.tasks.append(WorkTask(id: taskID, title: "Communicate the result", detail: "Prepare the handoff.", kind: .report, status: .ready, assigneeID: "maya", reviewerID: nil, dependencyIDs: [], artifactIDs: [], revisionCount: 0, maxRevisions: 0, updatedAt: Date(), accountableEmployeeID: "maya", requiredSkillIDs: ["communication"]))
        _ = state.updateEmployeeOutcome(outcomeID) { $0.taskIDs = [taskID]; $0.status = .proposed }

        try state.reassignTicket(taskID, to: "mira", reason: "Mira owns owner handoffs.")
        XCTAssertEqual(state.task(taskID)?.assigneeID, "mira")
        XCTAssertEqual(state.task(taskID)?.effectiveAccountableEmployeeID, "maya")

        try state.pauseEmployee("theo")
        XCTAssertThrowsError(try state.reassignTicket(taskID, to: "theo", reason: "Try another writer.")) {
            XCTAssertEqual($0 as? EmployeeOutcomeError, .ineligibleDelegate)
        }
    }

    func testQueuePriorityReorderAndBoundedRevisionPreserveDelivery() throws {
        var state = LocalOrganizationStore.migrated(.seeded())
        let first = try state.createEmployeeOutcome(employeeID: "theo", outcome: "First", context: "")
        let second = try state.createEmployeeOutcome(employeeID: "theo", outcome: "Second", context: "")
        try state.changeOutcomePriority(second, priority: .urgent)
        XCTAssertEqual(state.queuedEmployeeOutcomes(for: "theo").first?.id, second)
        try state.reorderOutcome(first, to: 0)
        XCTAssertEqual(state.employeeOutcome(first)?.effectiveQueuePosition, 0)

        _ = state.updateEmployeeOutcome(first) { value in
            value.status = .delivered
            value.deliverySummary = "Original delivery"
            value.deliveries = [OutcomeDelivery(summary: "Original delivery", artifactIDs: [], evidenceBasis: "local", limitations: "None", recommendedNextAction: "Review", deliveredByEmployeeID: "theo", createdAt: Date())]
        }
        try state.requestOutcomeRevision(first, feedback: "Add one concrete example.")

        XCTAssertEqual(state.employeeOutcome(first)?.status, .revision)
        XCTAssertEqual(state.employeeOutcome(first)?.effectiveDeliveries.first?.summary, "Original delivery")
        XCTAssertEqual(state.employeeOutcome(first)?.effectiveRevisions.count, 1)
        XCTAssertEqual(state.task(state.employeeOutcome(first)!.taskIDs.last!)?.status, .ready)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AgentOfficeSupervisionTests-\(UUID().uuidString)", isDirectory: true)
    }
}
