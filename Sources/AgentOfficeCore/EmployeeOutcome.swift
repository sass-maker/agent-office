import Foundation

public enum EmployeeOutcomeStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case planning
    case working
    case waiting
    case delivered
    case failed
    case cancelled

    public var isTerminal: Bool {
        self == .delivered || self == .failed || self == .cancelled
    }
}

public struct EmployeeOutcome: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var outcome: String
    public var context: String
    public var requestedByActorID: String
    public var assigneeID: String
    public var status: EmployeeOutcomeStatus
    public var selectedSkillIDs: [String]
    public var taskIDs: [String]
    public var artifactIDs: [String]
    public var helpRequest: String?
    public var deliverySummary: String?
    public var attemptCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        outcome: String,
        context: String,
        requestedByActorID: String = "owner",
        assigneeID: String,
        status: EmployeeOutcomeStatus = .queued,
        selectedSkillIDs: [String] = [],
        taskIDs: [String] = [],
        artifactIDs: [String] = [],
        helpRequest: String? = nil,
        deliverySummary: String? = nil,
        attemptCount: Int = 0,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.outcome = outcome
        self.context = context
        self.requestedByActorID = requestedByActorID
        self.assigneeID = assigneeID
        self.status = status
        self.selectedSkillIDs = selectedSkillIDs
        self.taskIDs = taskIDs
        self.artifactIDs = artifactIDs
        self.helpRequest = helpRequest
        self.deliverySummary = deliverySummary
        self.attemptCount = attemptCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum EmployeeOutcomeError: LocalizedError, Equatable {
    case emptyOutcome
    case missingEmployee
    case humanAssignee
    case activeOutcomeExists
    case noAssignedSkills
    case invalidPlan

    public var errorDescription: String? {
        switch self {
        case .emptyOutcome:
            "Describe the result this employee should own before assigning it."
        case .missingEmployee:
            "That employee is no longer part of this organization."
        case .humanAssignee:
            "Choose an AI employee for this outcome. Human members assign or review work in this version."
        case .activeOutcomeExists:
            "An employee already owns an active outcome. Finish or stop it before assigning another."
        case .noAssignedSkills:
            "This employee needs at least one assigned skill before they can own an outcome."
        case .invalidPlan:
            "The employee did not return a usable plan of one to four tickets. Try again or teach a narrower skill."
        }
    }
}

public extension OrganizationState {
    var employeeOutcomes: [EmployeeOutcome] {
        knowledge?.employeeOutcomes ?? []
    }

    var activeEmployeeOutcome: EmployeeOutcome? {
        employeeOutcomes.last { !$0.status.isTerminal }
    }

    var latestEmployeeOutcome: EmployeeOutcome? {
        employeeOutcomes.max { $0.createdAt < $1.createdAt }
    }

    func latestEmployeeOutcome(for employeeID: String) -> EmployeeOutcome? {
        employeeOutcomes.filter { $0.assigneeID == employeeID }.max { $0.createdAt < $1.createdAt }
    }

    func employeeOutcome(_ id: String) -> EmployeeOutcome? {
        employeeOutcomes.first { $0.id == id }
    }

    @discardableResult
    mutating func updateEmployeeOutcome(
        _ id: String,
        now: Date = Date(),
        _ update: (inout EmployeeOutcome) -> Void
    ) -> Bool {
        guard let index = knowledge?.employeeOutcomes.firstIndex(where: { $0.id == id }) else {
            return false
        }
        update(&knowledge!.employeeOutcomes[index])
        knowledge!.employeeOutcomes[index].updatedAt = now
        return true
    }

    @discardableResult
    mutating func createEmployeeOutcome(
        employeeID: String,
        outcome: String,
        context: String,
        now: Date = Date()
    ) throws -> String {
        let trimmedOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutcome.isEmpty else { throw EmployeeOutcomeError.emptyOutcome }
        guard activeEmployeeOutcome == nil else { throw EmployeeOutcomeError.activeOutcomeExists }
        guard let employee = employee(employeeID) else { throw EmployeeOutcomeError.missingEmployee }
        guard employee.kind == .ai else { throw EmployeeOutcomeError.humanAssignee }
        guard !assignedSkills(employeeID: employeeID).isEmpty else { throw EmployeeOutcomeError.noAssignedSkills }

        if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
        let id = "employee-outcome-\(UUID().uuidString.lowercased().prefix(8))"
        knowledge?.employeeOutcomes.append(EmployeeOutcome(
            id: id,
            outcome: trimmedOutcome,
            context: context.trimmingCharacters(in: .whitespacesAndNewlines),
            assigneeID: employeeID,
            createdAt: now,
            updatedAt: now
        ))
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: "owner",
            kind: .started,
            message: "You asked \(employee.name) to own: \(trimmedOutcome)",
            createdAt: now
        ))
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: employeeID,
            kind: .handoff,
            message: "I’ll own this outcome. I’m choosing the right skills and turning it into a short plan.",
            createdAt: now
        ))
        return id
    }

    @discardableResult
    mutating func cancelEmployeeOutcome(_ id: String, now: Date = Date()) -> Bool {
        guard let outcome = employeeOutcome(id), !outcome.status.isTerminal else { return false }
        _ = updateEmployeeOutcome(id, now: now) { value in
            value.status = .cancelled
            value.helpRequest = nil
        }
        for taskID in outcome.taskIDs {
            guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].status != .done else { continue }
            tasks[index].status = .blocked
            tasks[index].updatedAt = now
        }
        blockers.indices
            .filter { outcome.taskIDs.contains(blockers[$0].taskID) }
            .forEach { blockers[$0].resolved = true }
        if let employeeIndex = employees.firstIndex(where: { $0.id == outcome.assigneeID }) {
            employees[employeeIndex].status = .resting
            employees[employeeIndex].currentTaskID = nil
        }
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: "owner",
            kind: .stopped,
            message: "You stopped \(employee(outcome.assigneeID)?.name ?? "the employee")’s outcome.",
            createdAt: now
        ))
        return true
    }

    @discardableResult
    mutating func retryEmployeeOutcome(_ id: String, now: Date = Date()) -> Bool {
        guard let outcome = employeeOutcome(id),
              outcome.status == .failed || outcome.status == .waiting || outcome.status == .queued
        else { return false }
        _ = updateEmployeeOutcome(id, now: now) { value in
            value.status = .queued
            value.helpRequest = nil
        }
        for index in blockers.indices where outcome.taskIDs.contains(blockers[index].taskID) {
            blockers[index].resolved = true
        }
        for taskID in outcome.taskIDs {
            guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].status == .blocked else { continue }
            tasks[index].status = tasks[index].dependencyIDs.allSatisfy { dependencyID in
                tasks.first(where: { $0.id == dependencyID })?.status == .done
            } ? .ready : .waiting
            tasks[index].updatedAt = now
        }
        return true
    }

    @discardableResult
    mutating func resetInterruptedEmployeeOutcome(now: Date = Date()) -> Bool {
        guard let outcome = employeeOutcomes.last(where: { $0.status == .planning || $0.status == .working }) else {
            return false
        }
        _ = updateEmployeeOutcome(outcome.id, now: now) { value in
            value.status = .queued
            value.helpRequest = "The previous run stopped before delivery. Resume when you are ready."
        }
        for taskID in outcome.taskIDs {
            guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].status == .doing else { continue }
            tasks[index].status = .ready
            tasks[index].updatedAt = now
        }
        if let employeeIndex = employees.firstIndex(where: { $0.id == outcome.assigneeID }) {
            employees[employeeIndex].status = .resting
            employees[employeeIndex].currentTaskID = nil
        }
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: outcome.assigneeID,
            kind: .stopped,
            message: "My previous run stopped before delivery. I kept the plan and completed tickets ready to resume.",
            createdAt: now
        ))
        return true
    }
}
