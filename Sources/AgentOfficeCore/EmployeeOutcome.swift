import Foundation

public enum EmployeeOutcomeStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case planning
    case proposed
    case approved
    case working
    case waiting
    case delivered
    case revision
    case accepted
    case closed
    case failed
    case cancelled

    public var isTerminal: Bool {
        self == .accepted || self == .closed || self == .failed || self == .cancelled
    }

    public var isActivelyRunning: Bool { self == .planning || self == .working || self == .revision }
}

public enum EmployeeOutcomePriority: String, Codable, Sendable, CaseIterable {
    case urgent
    case high
    case normal
    case low

    public var rank: Int {
        switch self { case .urgent: 0; case .high: 1; case .normal: 2; case .low: 3 }
    }
}

public enum EmployeeOutcomeSource: String, Codable, Sendable, CaseIterable {
    case owner
    case recurringResponsibility
    case legacyResearch
    case legacyWorkday
}

public enum OutcomePlanStatus: String, Codable, Sendable, CaseIterable {
    case notStarted
    case drafting
    case proposed
    case approved
    case returned
}

public struct OutcomeManagementMessage: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var actorID: String
    public var message: String
    public var taskID: String?
    public var createdAt: Date

    public init(id: String = UUID().uuidString, actorID: String, message: String, taskID: String? = nil, createdAt: Date) {
        self.id = id
        self.actorID = actorID
        self.message = message
        self.taskID = taskID
        self.createdAt = createdAt
    }
}

public struct OutcomeDelivery: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var summary: String
    public var artifactIDs: [String]
    public var evidenceBasis: String
    public var limitations: String
    public var recommendedNextAction: String
    public var deliveredByEmployeeID: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, summary: String, artifactIDs: [String], evidenceBasis: String, limitations: String, recommendedNextAction: String, deliveredByEmployeeID: String, createdAt: Date) {
        self.id = id
        self.summary = summary
        self.artifactIDs = artifactIDs
        self.evidenceBasis = evidenceBasis
        self.limitations = limitations
        self.recommendedNextAction = recommendedNextAction
        self.deliveredByEmployeeID = deliveredByEmployeeID
        self.createdAt = createdAt
    }
}

public struct OutcomeRevision: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var feedback: String
    public var requestedByActorID: String
    public var taskID: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, feedback: String, requestedByActorID: String, taskID: String, createdAt: Date) {
        self.id = id
        self.feedback = feedback
        self.requestedByActorID = requestedByActorID
        self.taskID = taskID
        self.createdAt = createdAt
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
    public var acceptanceCriteria: [String]?
    public var priority: EmployeeOutcomePriority?
    public var queuePosition: Int?
    public var source: EmployeeOutcomeSource?
    public var sourceID: String?
    public var planStatus: OutcomePlanStatus?
    public var accountableEmployeeID: String?
    public var managementMessages: [OutcomeManagementMessage]?
    public var deliveries: [OutcomeDelivery]?
    public var revisions: [OutcomeRevision]?
    public var acceptedByActorID: String?
    public var acceptedAt: Date?
    public var acceptanceNote: String?
    public var outcomeRevision: Int?

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
        updatedAt: Date,
        acceptanceCriteria: [String] = [],
        priority: EmployeeOutcomePriority = .normal,
        queuePosition: Int = 0,
        source: EmployeeOutcomeSource = .owner,
        sourceID: String? = nil,
        planStatus: OutcomePlanStatus = .notStarted,
        accountableEmployeeID: String? = nil,
        managementMessages: [OutcomeManagementMessage] = [],
        deliveries: [OutcomeDelivery] = [],
        revisions: [OutcomeRevision] = [],
        acceptedByActorID: String? = nil,
        acceptedAt: Date? = nil,
        acceptanceNote: String? = nil,
        outcomeRevision: Int = 0
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
        self.acceptanceCriteria = acceptanceCriteria
        self.priority = priority
        self.queuePosition = queuePosition
        self.source = source
        self.sourceID = sourceID
        self.planStatus = planStatus
        self.accountableEmployeeID = accountableEmployeeID ?? assigneeID
        self.managementMessages = managementMessages
        self.deliveries = deliveries
        self.revisions = revisions
        self.acceptedByActorID = acceptedByActorID
        self.acceptedAt = acceptedAt
        self.acceptanceNote = acceptanceNote
        self.outcomeRevision = outcomeRevision
    }

    public var effectiveAcceptanceCriteria: [String] { acceptanceCriteria ?? [] }
    public var effectivePriority: EmployeeOutcomePriority { priority ?? .normal }
    public var effectiveQueuePosition: Int { queuePosition ?? 0 }
    public var effectiveSource: EmployeeOutcomeSource { source ?? .owner }
    public var effectivePlanStatus: OutcomePlanStatus { planStatus ?? .notStarted }
    public var effectiveAccountableEmployeeID: String { accountableEmployeeID ?? assigneeID }
    public var effectiveManagementMessages: [OutcomeManagementMessage] { managementMessages ?? [] }
    public var effectiveDeliveries: [OutcomeDelivery] { deliveries ?? [] }
    public var effectiveRevisions: [OutcomeRevision] { revisions ?? [] }
    public var effectiveRevision: Int { outcomeRevision ?? 0 }
}

public enum EmployeeOutcomeError: LocalizedError, Equatable {
    case emptyOutcome
    case missingEmployee
    case humanAssignee
    case activeOutcomeExists
    case noAssignedSkills
    case invalidPlan
    case employeeNotHired
    case employeePaused
    case invalidTransition
    case emptyReply
    case revisionLimitReached
    case ineligibleDelegate

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
        case .employeeNotHired:
            "Only a currently hired employee can own new work."
        case .employeePaused:
            "Resume this employee before assigning or starting new work."
        case .invalidTransition:
            "That management action is not valid for the outcome's current state."
        case .emptyReply:
            "Add a concise instruction before continuing."
        case .revisionLimitReached:
            "This outcome has reached its contract's revision limit."
        case .ineligibleDelegate:
            "The selected employee is unavailable or their working contract does not cover this ticket."
        }
    }
}

public extension OrganizationState {
    var employeeOutcomes: [EmployeeOutcome] {
        knowledge?.employeeOutcomes ?? []
    }

    var activeEmployeeOutcome: EmployeeOutcome? {
        employeeOutcomes.last { !$0.status.isTerminal && $0.status != .delivered }
    }

    var latestEmployeeOutcome: EmployeeOutcome? {
        employeeOutcomes.max { $0.createdAt < $1.createdAt }
    }

    func latestEmployeeOutcome(for employeeID: String) -> EmployeeOutcome? {
        employeeOutcomes.filter { $0.assigneeID == employeeID }.max { $0.createdAt < $1.createdAt }
    }

    func activeEmployeeOutcome(for employeeID: String) -> EmployeeOutcome? {
        employeeOutcomes
            .filter { $0.assigneeID == employeeID && !$0.status.isTerminal && $0.status != .delivered }
            .sorted(by: Self.outcomeQueueOrder)
            .first
    }

    func queuedEmployeeOutcomes(for employeeID: String) -> [EmployeeOutcome] {
        employeeOutcomes.filter { $0.assigneeID == employeeID && [.queued, .approved, .revision].contains($0.status) }
            .sorted(by: Self.outcomeQueueOrder)
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
        acceptanceCriteria: [String] = [],
        priority: EmployeeOutcomePriority = .normal,
        source: EmployeeOutcomeSource = .owner,
        sourceID: String? = nil,
        now: Date = Date()
    ) throws -> String {
        let trimmedOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutcome.isEmpty else { throw EmployeeOutcomeError.emptyOutcome }
        guard let employee = employee(employeeID) else { throw EmployeeOutcomeError.missingEmployee }
        guard employee.kind == .ai else { throw EmployeeOutcomeError.humanAssignee }
        guard employee.effectiveEmploymentState != .paused else { throw EmployeeOutcomeError.employeePaused }
        guard employee.effectiveEmploymentState == .hired else { throw EmployeeOutcomeError.employeeNotHired }
        guard !assignedSkills(employeeID: employeeID).isEmpty else { throw EmployeeOutcomeError.noAssignedSkills }

        if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
        let id = "employee-outcome-\(UUID().uuidString.lowercased().prefix(8))"
        let nextQueuePosition = (employeeOutcomes.filter { $0.assigneeID == employeeID && !$0.status.isTerminal }.map(\.effectiveQueuePosition).max() ?? -1) + 1
        knowledge?.employeeOutcomes.append(EmployeeOutcome(
            id: id,
            outcome: trimmedOutcome,
            context: context.trimmingCharacters(in: .whitespacesAndNewlines),
            assigneeID: employeeID,
            createdAt: now,
            updatedAt: now,
            acceptanceCriteria: acceptanceCriteria.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            priority: priority,
            queuePosition: nextQueuePosition,
            source: source,
            sourceID: sourceID
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
        let interrupted = employeeOutcomes.filter { $0.status.isActivelyRunning }
        guard !interrupted.isEmpty else { return false }
        for outcome in interrupted {
            _ = updateEmployeeOutcome(outcome.id, now: now) { value in
                value.status = value.effectivePlanStatus == .approved ? .approved : .queued
                value.helpRequest = "The previous run stopped before delivery. Resume when you are ready."
                value.outcomeRevision = value.effectiveRevision + 1
            }
            for taskID in outcome.taskIDs {
                guard let index = tasks.firstIndex(where: { $0.id == taskID }), tasks[index].status == .doing else { continue }
                tasks[index].status = .ready
                tasks[index].workRevision = tasks[index].effectiveWorkRevision + 1
                tasks[index].updatedAt = now
            }
            if let employeeIndex = employees.firstIndex(where: { $0.id == outcome.assigneeID }) {
                employees[employeeIndex].status = .resting
                employees[employeeIndex].currentTaskID = nil
            }
            activity.append(Activity(id: UUID().uuidString, actorID: outcome.assigneeID, kind: .stopped, message: "My previous run stopped before delivery. I kept the plan and completed tickets ready to resume.", createdAt: now))
        }
        return true
    }

    private static func outcomeQueueOrder(_ lhs: EmployeeOutcome, _ rhs: EmployeeOutcome) -> Bool {
        if lhs.effectivePriority.rank != rhs.effectivePriority.rank { return lhs.effectivePriority.rank < rhs.effectivePriority.rank }
        if lhs.effectiveQueuePosition != rhs.effectiveQueuePosition { return lhs.effectiveQueuePosition < rhs.effectiveQueuePosition }
        return lhs.createdAt < rhs.createdAt
    }
}
