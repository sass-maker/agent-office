import XCTest
@testable import AgentOfficeCore

final class LegacyWorkAdaptersTests: XCTestCase {
    func testResearchAssignmentCreatesOneCanonicalOutcomeAndMirrorsDelivery() throws {
        var state = LocalOrganizationStore.migrated(.seeded())
        let assignmentID = try state.createResearchAssignment(outcome: "Understand onboarding friction", context: "Use supplied interviews.")
        let outcomeID = try XCTUnwrap(state.researchAssignment(assignmentID)?.canonicalOutcomeID)

        XCTAssertEqual(state.employeeOutcome(outcomeID)?.effectiveSource, .legacyResearch)
        XCTAssertEqual(state.employeeOutcome(outcomeID)?.sourceID, assignmentID)

        _ = state.updateEmployeeOutcome(outcomeID) { $0.status = .delivered; $0.deliverySummary = "Delivered" }
        state.synchronizeLegacyAdapters(outcomeID: outcomeID)
        XCTAssertEqual(state.researchAssignment(assignmentID)?.status, .delivered)
        XCTAssertEqual(state.researchAssignment(assignmentID)?.canonicalOutcomeID, outcomeID)
    }

    func testRecurringDutyReusesOccurrenceAndAdvancesOnlyOnceAfterDelivery() throws {
        let now = Date(timeIntervalSince1970: 100)
        var state = LocalOrganizationStore.migrated(.seeded(now: now), now: now)
        let initialDue = try XCTUnwrap(state.employeeDuty("customer-voice-weekly")?.nextDueAt)
        let occurrenceID = try state.beginDutyOccurrence(dutyID: "customer-voice-weekly", now: now)
        let repeatedID = try state.beginDutyOccurrence(dutyID: "customer-voice-weekly", now: now)
        let outcomeID = try XCTUnwrap(state.dutyOccurrence(occurrenceID)?.canonicalOutcomeID)

        XCTAssertEqual(repeatedID, occurrenceID)
        XCTAssertEqual(state.employeeOutcomes.filter { $0.sourceID == occurrenceID }.count, 1)
        XCTAssertEqual(state.employeeDuty("customer-voice-weekly")?.nextDueAt, initialDue)

        _ = state.updateEmployeeOutcome(outcomeID, now: now) { $0.status = .delivered }
        state.synchronizeLegacyAdapters(outcomeID: outcomeID, now: now)
        let advancedDue = try XCTUnwrap(state.employeeDuty("customer-voice-weekly")?.nextDueAt)
        state.synchronizeLegacyAdapters(outcomeID: outcomeID, now: now.addingTimeInterval(10))

        XCTAssertEqual(advancedDue.timeIntervalSince(initialDue), 604_800, accuracy: 1)
        XCTAssertEqual(state.employeeDuty("customer-voice-weekly")?.nextDueAt, advancedDue)
    }

    func testPreparedFirstMissionIsIdempotentAndEmployeeOwned() throws {
        var state = OrganizationState.seeded()
        let first = try state.prepareFirstContentMission()
        let second = try state.prepareFirstContentMission()

        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first.compactMap { state.employeeOutcome($0)?.assigneeID }), Set(["nia", "theo", "maya"]))
        XCTAssertTrue(first.allSatisfy { state.employeeOutcome($0)?.effectiveSource == .legacyWorkday })
    }

    func testMigrationLinksLegacyAssignmentWithoutDeletingHistory() throws {
        let now = Date(timeIntervalSince1970: 100)
        var legacy = OrganizationState.seeded(now: now)
        legacy.schemaVersion = 8
        legacy.knowledge?.researchAssignments.append(ResearchAssignment(id: "legacy-research", outcome: "Legacy outcome", context: "Legacy context", status: .delivered, createdAt: now, updatedAt: now))

        let migrated = LocalOrganizationStore.migrated(legacy, now: now)

        XCTAssertEqual(migrated.researchAssignments.count, 1)
        let outcomeID = try XCTUnwrap(migrated.researchAssignment("legacy-research")?.canonicalOutcomeID)
        XCTAssertEqual(migrated.employeeOutcome(outcomeID)?.sourceID, "legacy-research")
    }
}
