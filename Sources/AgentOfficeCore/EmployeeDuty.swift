import Foundation

public enum DutyRecurrence: String, Codable, Sendable {
    case weekly
}

public enum DutyOccurrenceStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case blocked
    case delivered
    case cancelled

    public var isTerminal: Bool {
        self == .delivered || self == .cancelled
    }
}

public struct DutyInputReference: Identifiable, Codable, Sendable, Equatable {
    public var id: String { label }
    public var label: String
    public var fileName: String
    public var byteCount: Int

    public init(label: String, fileName: String, byteCount: Int) {
        self.label = label
        self.fileName = fileName
        self.byteCount = byteCount
    }
}

public struct DutyInputExclusion: Identifiable, Codable, Sendable, Equatable {
    public var id: String { fileName }
    public var fileName: String
    public var reason: String

    public init(fileName: String, reason: String) {
        self.fileName = fileName
        self.reason = reason
    }
}

public struct EmployeeDuty: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var responsibility: String
    public var assigneeID: String
    public var reviewerID: String
    public var recurrence: DutyRecurrence
    public var nextDueAt: Date
    public var lastCompletedAt: Date?
    public var createdAt: Date

    public init(
        id: String,
        title: String,
        responsibility: String,
        assigneeID: String,
        reviewerID: String,
        recurrence: DutyRecurrence,
        nextDueAt: Date,
        lastCompletedAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.responsibility = responsibility
        self.assigneeID = assigneeID
        self.reviewerID = reviewerID
        self.recurrence = recurrence
        self.nextDueAt = nextDueAt
        self.lastCompletedAt = lastCompletedAt
        self.createdAt = createdAt
    }

    public static func customerVoiceWeekly(now: Date = Date()) -> EmployeeDuty {
        EmployeeDuty(
            id: "customer-voice-weekly",
            title: "Customer Voice Weekly",
            responsibility: "Turn deliberately supplied customer feedback into one cited owner decision.",
            assigneeID: "iris",
            reviewerID: "mira",
            recurrence: .weekly,
            nextDueAt: now,
            createdAt: now
        )
    }
}

public struct DutyOccurrence: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var dutyID: String
    public var requestedByActorID: String
    public var delegatedByActorID: String
    public var assigneeID: String
    public var reviewerID: String
    public var scheduledFor: Date
    public var status: DutyOccurrenceStatus
    public var includedInputs: [DutyInputReference]
    public var excludedInputs: [DutyInputExclusion]
    public var blockingReason: String?
    public var evidenceBasis: String?
    public var briefArtifactID: String?
    public var deliveryArtifactID: String?
    public var attemptCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        dutyID: String,
        requestedByActorID: String = "owner",
        delegatedByActorID: String = "mira",
        assigneeID: String = "iris",
        reviewerID: String = "mira",
        scheduledFor: Date,
        status: DutyOccurrenceStatus = .queued,
        includedInputs: [DutyInputReference] = [],
        excludedInputs: [DutyInputExclusion] = [],
        blockingReason: String? = nil,
        evidenceBasis: String? = nil,
        briefArtifactID: String? = nil,
        deliveryArtifactID: String? = nil,
        attemptCount: Int = 0,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.dutyID = dutyID
        self.requestedByActorID = requestedByActorID
        self.delegatedByActorID = delegatedByActorID
        self.assigneeID = assigneeID
        self.reviewerID = reviewerID
        self.scheduledFor = scheduledFor
        self.status = status
        self.includedInputs = includedInputs
        self.excludedInputs = excludedInputs
        self.blockingReason = blockingReason
        self.evidenceBasis = evidenceBasis
        self.briefArtifactID = briefArtifactID
        self.deliveryArtifactID = deliveryArtifactID
        self.attemptCount = attemptCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension OrganizationState {
    public var employeeDuties: [EmployeeDuty] {
        knowledge?.employeeDuties ?? []
    }

    public var dutyOccurrences: [DutyOccurrence] {
        knowledge?.dutyOccurrences ?? []
    }

    public func employeeDuty(_ id: String) -> EmployeeDuty? {
        employeeDuties.first { $0.id == id }
    }

    public func dutyOccurrence(_ id: String) -> DutyOccurrence? {
        dutyOccurrences.first { $0.id == id }
    }

    public func occurrences(for dutyID: String) -> [DutyOccurrence] {
        dutyOccurrences.filter { $0.dutyID == dutyID }
    }

    public func activeOccurrence(for dutyID: String) -> DutyOccurrence? {
        occurrences(for: dutyID).last { !$0.status.isTerminal }
    }

    public func latestOccurrence(for dutyID: String) -> DutyOccurrence? {
        occurrences(for: dutyID).max { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    public mutating func updateDuty(
        _ id: String,
        _ update: (inout EmployeeDuty) -> Void
    ) -> Bool {
        guard let index = knowledge?.employeeDuties.firstIndex(where: { $0.id == id }) else {
            return false
        }
        update(&knowledge!.employeeDuties[index])
        return true
    }

    @discardableResult
    public mutating func updateDutyOccurrence(
        _ id: String,
        now: Date = Date(),
        _ update: (inout DutyOccurrence) -> Void
    ) -> Bool {
        guard let index = knowledge?.dutyOccurrences.firstIndex(where: { $0.id == id }) else {
            return false
        }
        update(&knowledge!.dutyOccurrences[index])
        knowledge!.dutyOccurrences[index].updatedAt = now
        return true
    }

    public mutating func beginDutyOccurrence(
        dutyID: String,
        now: Date = Date()
    ) throws -> String {
        guard let duty = employeeDuty(dutyID),
              employee("owner") != nil,
              employee(duty.assigneeID) != nil,
              employee(duty.reviewerID) != nil
        else { throw CustomerVoiceDutyError.missingEmployee }

        if let current = activeOccurrence(for: dutyID) {
            guard current.status != .running else { return current.id }
            _ = updateDutyOccurrence(current.id, now: now) { occurrence in
                occurrence.status = .running
                occurrence.blockingReason = nil
                occurrence.attemptCount += 1
            }
            markDutyEmployeesWorking(duty: duty, occurrenceID: current.id)
            activity.append(Activity(
                id: UUID().uuidString,
                actorID: duty.assigneeID,
                kind: .started,
                message: "Iris resumed Customer Voice Weekly.",
                createdAt: now
            ))
            return current.id
        }

        let occurrenceID = "customer-voice-\(UUID().uuidString.lowercased().prefix(8))"
        knowledge?.dutyOccurrences.append(DutyOccurrence(
            id: occurrenceID,
            dutyID: duty.id,
            scheduledFor: duty.nextDueAt,
            status: .running,
            attemptCount: 1,
            createdAt: now,
            updatedAt: now
        ))
        markDutyEmployeesWorking(duty: duty, occurrenceID: occurrenceID)
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: "owner",
            kind: .started,
            message: "You asked Mira to run Customer Voice Weekly.",
            createdAt: now
        ))
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: duty.reviewerID,
            kind: .handoff,
            message: "Mira delegated the weekly customer evidence to Iris.",
            createdAt: now
        ))
        return occurrenceID
    }

    @discardableResult
    public mutating func stopDutyOccurrence(
        _ id: String,
        now: Date = Date()
    ) -> Bool {
        guard let occurrence = dutyOccurrence(id), !occurrence.status.isTerminal else { return false }
        _ = updateDutyOccurrence(id, now: now) { value in
            value.status = .queued
            value.blockingReason = "The owner stopped this run before delivery. It is ready to resume."
        }
        restDutyEmployees(occurrence)
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: "owner",
            kind: .stopped,
            message: "You stopped Customer Voice Weekly before delivery.",
            createdAt: now
        ))
        return true
    }

    @discardableResult
    public mutating func resetInterruptedDuty(now: Date = Date()) -> Bool {
        guard let index = knowledge?.dutyOccurrences.lastIndex(where: { $0.status == .running }) else {
            return false
        }
        let occurrence = knowledge!.dutyOccurrences[index]
        knowledge!.dutyOccurrences[index].status = .queued
        knowledge!.dutyOccurrences[index].blockingReason = "The previous run stopped before delivery. It is ready to resume."
        knowledge!.dutyOccurrences[index].updatedAt = now
        restDutyEmployees(occurrence)
        activity.append(Activity(
            id: UUID().uuidString,
            actorID: occurrence.reviewerID,
            kind: .stopped,
            message: "Mira kept Iris's interrupted weekly duty ready to resume.",
            createdAt: now
        ))
        return true
    }

    private mutating func markDutyEmployeesWorking(duty: EmployeeDuty, occurrenceID: String) {
        if let assigneeIndex = employees.firstIndex(where: { $0.id == duty.assigneeID }) {
            employees[assigneeIndex].status = .working
            employees[assigneeIndex].currentTaskID = occurrenceID
        }
        if let reviewerIndex = employees.firstIndex(where: { $0.id == duty.reviewerID }) {
            employees[reviewerIndex].status = .reviewing
            employees[reviewerIndex].currentTaskID = occurrenceID
        }
    }

    private mutating func restDutyEmployees(_ occurrence: DutyOccurrence) {
        for employeeID in [occurrence.assigneeID, occurrence.reviewerID] {
            guard let index = employees.firstIndex(where: { $0.id == employeeID }) else { continue }
            employees[index].status = .resting
            employees[index].currentTaskID = nil
        }
    }
}
