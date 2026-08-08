import Foundation

public enum EmployeeKind: String, Codable, Sendable, CaseIterable {
    case ai
    case human
}

public enum EmployeeStatus: String, Codable, Sendable, CaseIterable {
    case resting
    case planning
    case working
    case reviewing
    case waiting
    case blocked
    case celebrating
}

public enum WorkdayStatus: String, Codable, Sendable {
    case resting
    case active
    case ending
    case complete
}

public enum ExecutionMode: String, Codable, Sendable, CaseIterable {
    case demo
    case localCodex
}

public enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case waiting
    case ready
    case doing
    case review
    case revision
    case done
    case blocked
}

public enum TaskKind: String, Codable, Sendable {
    case research
    case draft
    case report
}

public enum ArtifactKind: String, Codable, Sendable {
    case research
    case draft
    case review
    case report
}

public enum ActivityKind: String, Codable, Sendable {
    case joined
    case started
    case progress
    case handoff
    case review
    case approved
    case blocked
    case completed
    case stopped
}

public struct Employee: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var kind: EmployeeKind
    public var role: String
    public var responsibility: String
    public var managerID: String?
    public var status: EmployeeStatus
    public var currentTaskID: String?
    public var avatarColor: String
    public var capabilityGrants: [String]

    public init(
        id: String,
        name: String,
        kind: EmployeeKind = .ai,
        role: String,
        responsibility: String,
        managerID: String? = nil,
        status: EmployeeStatus = .resting,
        currentTaskID: String? = nil,
        avatarColor: String,
        capabilityGrants: [String] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.role = role
        self.responsibility = responsibility
        self.managerID = managerID
        self.status = status
        self.currentTaskID = currentTaskID
        self.avatarColor = avatarColor
        self.capabilityGrants = capabilityGrants
    }
}

public struct Goal: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var detail: String
    public var progress: Double
    public var ownerID: String

    public init(id: String, title: String, detail: String, progress: Double, ownerID: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.progress = progress
        self.ownerID = ownerID
    }
}

public struct WorkTask: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var detail: String
    public var kind: TaskKind
    public var status: TaskStatus
    public var assigneeID: String
    public var reviewerID: String?
    public var dependencyIDs: [String]
    public var artifactIDs: [String]
    public var revisionCount: Int
    public var maxRevisions: Int
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        detail: String,
        kind: TaskKind,
        status: TaskStatus,
        assigneeID: String,
        reviewerID: String?,
        dependencyIDs: [String],
        artifactIDs: [String],
        revisionCount: Int,
        maxRevisions: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.status = status
        self.assigneeID = assigneeID
        self.reviewerID = reviewerID
        self.dependencyIDs = dependencyIDs
        self.artifactIDs = artifactIDs
        self.revisionCount = revisionCount
        self.maxRevisions = maxRevisions
        self.updatedAt = updatedAt
    }
}

public struct Blocker: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var detail: String
    public var employeeID: String
    public var taskID: String
    public var createdAt: Date
    public var resolved: Bool

    public init(
        id: String,
        title: String,
        detail: String,
        employeeID: String,
        taskID: String,
        createdAt: Date,
        resolved: Bool
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.employeeID = employeeID
        self.taskID = taskID
        self.createdAt = createdAt
        self.resolved = resolved
    }
}

public struct Artifact: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var kind: ArtifactKind
    public var relativePath: String
    public var authorID: String
    public var taskID: String
    public var createdAt: Date

    public init(
        id: String,
        title: String,
        kind: ArtifactKind,
        relativePath: String,
        authorID: String,
        taskID: String,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.relativePath = relativePath
        self.authorID = authorID
        self.taskID = taskID
        self.createdAt = createdAt
    }
}

public struct Activity: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var actorID: String
    public var kind: ActivityKind
    public var message: String
    public var createdAt: Date

    public init(id: String, actorID: String, kind: ActivityKind, message: String, createdAt: Date) {
        self.id = id
        self.actorID = actorID
        self.kind = kind
        self.message = message
        self.createdAt = createdAt
    }
}

public struct OrganizationState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var outcome: String
    public var workdayStatus: WorkdayStatus
    public var executionMode: ExecutionMode
    public var dayNumber: Int
    public var employees: [Employee]
    public var goals: [Goal]
    public var tasks: [WorkTask]
    public var blockers: [Blocker]
    public var artifacts: [Artifact]
    public var activity: [Activity]
    public var lastSavedAt: Date

    public static func seeded(now: Date = Date()) -> OrganizationState {
        let manager = Employee(
            id: "maya",
            name: "Maya",
            role: "Editorial Manager",
            responsibility: "Own the content outcome, review work, and keep the team moving.",
            avatarColor: "E78B5B"
        )
        let researcher = Employee(
            id: "nia",
            name: "Nia",
            role: "Audience Researcher",
            responsibility: "Understand the product and find useful questions worth answering.",
            managerID: manager.id,
            avatarColor: "F2C96D"
        )
        let writer = Employee(
            id: "theo",
            name: "Theo",
            role: "Content Writer",
            responsibility: "Turn evidence and direction into clear, useful articles.",
            managerID: manager.id,
            avatarColor: "7395A8"
        )

        let researchID = "research-audience"
        let draftID = "draft-first-article"
        let reportID = "prepare-daily-report"

        return OrganizationState(
            schemaVersion: 1,
            id: "willow-studio",
            name: "Willow Studio",
            outcome: "Create one genuinely useful article that helps the right people discover and understand the product.",
            workdayStatus: .resting,
            executionMode: .demo,
            dayNumber: 0,
            employees: [manager, researcher, writer],
            goals: [
                Goal(
                    id: "content-outcome",
                    title: "Earn useful organic discovery",
                    detail: "Research, write, review, and deliver one strong article.",
                    progress: 0,
                    ownerID: manager.id
                )
            ],
            tasks: [
                WorkTask(
                    id: researchID,
                    title: "Find the audience question",
                    detail: "Read the product brief and identify the most useful question to answer.",
                    kind: .research,
                    status: .ready,
                    assigneeID: researcher.id,
                    reviewerID: manager.id,
                    dependencyIDs: [],
                    artifactIDs: [],
                    revisionCount: 0,
                    maxRevisions: 0,
                    updatedAt: now
                ),
                WorkTask(
                    id: draftID,
                    title: "Write the first article",
                    detail: "Create a practical article from Nia's research and send it to Maya.",
                    kind: .draft,
                    status: .waiting,
                    assigneeID: writer.id,
                    reviewerID: manager.id,
                    dependencyIDs: [researchID],
                    artifactIDs: [],
                    revisionCount: 0,
                    maxRevisions: 2,
                    updatedAt: now
                ),
                WorkTask(
                    id: reportID,
                    title: "Prepare the owner's report",
                    detail: "Summarize what shipped, what changed, and what needs attention next.",
                    kind: .report,
                    status: .waiting,
                    assigneeID: manager.id,
                    reviewerID: nil,
                    dependencyIDs: [draftID],
                    artifactIDs: [],
                    revisionCount: 0,
                    maxRevisions: 0,
                    updatedAt: now
                )
            ],
            blockers: [],
            artifacts: [],
            activity: [
                Activity(
                    id: UUID().uuidString,
                    actorID: "owner",
                    kind: .joined,
                    message: "The content team is ready for its first day.",
                    createdAt: now
                )
            ],
            lastSavedAt: now
        )
    }

    public func employee(_ id: String) -> Employee? {
        employees.first { $0.id == id }
    }

    public func task(_ id: String) -> WorkTask? {
        tasks.first { $0.id == id }
    }
}
