import XCTest
@testable import AgentOfficeCore

final class EmployeeWorkCoordinatorTests: XCTestCase {
    func testCoordinatorRunsDifferentEmployeesWithinCapacityAndSerializesSameEmployee() async throws {
        let coordinator = EmployeeWorkCoordinator(concurrencyLimit: 2)
        let probe = ConcurrencyProbe()
        let requests = try makeRequests(employeeIDs: ["maya", "nia", "theo"])

        let first = await coordinator.submit(requests[0], operation: { request in
            await probe.begin(request.employeeID)
            try await Task.sleep(for: .milliseconds(120))
            await probe.end(request.employeeID)
            return try Self.syntheticResult(request)
        }, completion: { _ in })
        let duplicateEmployee = await coordinator.submit(requests[0], operation: { try Self.syntheticResult($0) }, completion: { _ in })
        let second = await coordinator.submit(requests[1], operation: { request in
            await probe.begin(request.employeeID)
            try await Task.sleep(for: .milliseconds(120))
            await probe.end(request.employeeID)
            return try Self.syntheticResult(request)
        }, completion: { _ in })
        let overCapacity = await coordinator.submit(requests[2], operation: { try Self.syntheticResult($0) }, completion: { _ in })

        XCTAssertTrue(first)
        XCTAssertFalse(duplicateEmployee)
        XCTAssertTrue(second)
        XCTAssertFalse(overCapacity)
        try await Task.sleep(for: .milliseconds(180))
        let activeCount = await coordinator.activeCount
        let peak = await probe.peak
        XCTAssertEqual(activeCount, 0)
        XCTAssertEqual(peak, 2)
    }

    func testCancellingOneEmployeeDoesNotCancelAnother() async throws {
        let coordinator = EmployeeWorkCoordinator(concurrencyLimit: 2)
        let requests = try makeRequests(employeeIDs: ["maya", "nia"])
        for request in requests {
            let submitted = await coordinator.submit(request, operation: { request in
                try await Task.sleep(for: .seconds(2))
                return try Self.syntheticResult(request)
            }, completion: { _ in })
            XCTAssertTrue(submitted)
        }

        await coordinator.cancel(employeeID: "maya")
        let active = await coordinator.activeEmployeeIDs
        XCTAssertFalse(active.contains("maya"))
        XCTAssertTrue(active.contains("nia"))
        await coordinator.cancelAll()
    }

    func testTypedResultAppliesToFreshStateAndRejectsStaleOutcome() throws {
        var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        let outcomeID = try state.createEmployeeOutcome(employeeID: "maya", outcome: "Prepare a note", context: "")
        state = EmployeeOutcomeEngine().start(state, outcomeID: outcomeID)
        let request = try EmployeeOutcomeRunRequest(organization: state, outcomeID: outcomeID)
        let result = try Self.syntheticResult(request)

        var fresh = state
        try fresh.apply(result)
        XCTAssertEqual(fresh.employeeOutcome(outcomeID)?.status, .delivered)

        var stale = state
        _ = stale.updateEmployeeOutcome(outcomeID) { $0.outcomeRevision = $0.effectiveRevision + 1 }
        XCTAssertThrowsError(try stale.apply(result)) {
            XCTAssertEqual($0 as? EmployeeRunApplyError, .outcomeChanged)
        }
    }

    private func makeRequests(employeeIDs: [String]) throws -> [EmployeeOutcomeRunRequest] {
        var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
        var ids: [String] = []
        for employeeID in employeeIDs {
            ids.append(try state.createEmployeeOutcome(employeeID: employeeID, outcome: "Outcome for \(employeeID)", context: ""))
        }
        return try ids.map { id in
            state = EmployeeOutcomeEngine().start(state, outcomeID: id)
            return try EmployeeOutcomeRunRequest(organization: state, outcomeID: id)
        }
    }

    private static func syntheticResult(_ request: EmployeeOutcomeRunRequest) throws -> EmployeeOutcomeRunResult {
        var result = request.organization
        _ = result.updateEmployeeOutcome(request.outcomeID) {
            $0.status = .delivered
            $0.deliverySummary = "Delivered independently."
            $0.outcomeRevision = $0.effectiveRevision + 1
        }
        return try EmployeeOutcomeRunResult(request: request, initial: request.organization, result: result)
    }
}

private actor ConcurrencyProbe {
    private var active = Set<String>()
    private(set) var peak = 0

    func begin(_ employeeID: String) {
        active.insert(employeeID)
        peak = max(peak, active.count)
    }

    func end(_ employeeID: String) {
        active.remove(employeeID)
    }
}
