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

public enum CapabilityEventKind: String, Codable, Sendable {
  case requested
  case granted
  case revoked
  case started
  case succeeded
  case failed
  case unavailable
}

public enum AssistantHandoffKind: String, Codable, Sendable {
  case endOfDay
  case interruptedDay
}

public enum ResearchAssignmentStatus: String, Codable, Sendable, CaseIterable {
  case queued
  case waiting
  case researching
  case delivered
  case failed
  case cancelled

  public var isTerminal: Bool {
    self == .delivered || self == .failed || self == .cancelled
  }
}

public enum SkillSource: String, Codable, Sendable, CaseIterable {
  case builtIn
  case organization
}

public enum ConnectionKind: String, Codable, Sendable, CaseIterable {
  case execution
  case tool
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
  case analysis
}

public enum ArtifactKind: String, Codable, Sendable {
  case research
  case draft
  case review
  case report
  case analysis
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
  case taught
}

public struct Employee: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var name: String
  public var kind: EmployeeKind
  public var role: String
  public var responsibility: String
  public var managerID: String?
  public var assistantForHumanID: String?
  public var status: EmployeeStatus
  public var currentTaskID: String?
  public var avatarColor: String
  public var capabilityGrants: [String]
  public var employmentState: EmploymentState?
  public var packageID: String?
  public var packageVersion: String?

  public init(
    id: String,
    name: String,
    kind: EmployeeKind = .ai,
    role: String,
    responsibility: String,
    managerID: String? = nil,
    assistantForHumanID: String? = nil,
    status: EmployeeStatus = .resting,
    currentTaskID: String? = nil,
    avatarColor: String,
    capabilityGrants: [String] = [],
    employmentState: EmploymentState? = .hired,
    packageID: String? = nil,
    packageVersion: String? = nil
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.role = role
    self.responsibility = responsibility
    self.managerID = managerID
    self.assistantForHumanID = assistantForHumanID
    self.status = status
    self.currentTaskID = currentTaskID
    self.avatarColor = avatarColor
    self.capabilityGrants = capabilityGrants
    self.employmentState = employmentState
    self.packageID = packageID
    self.packageVersion = packageVersion
  }

  public var effectiveEmploymentState: EmploymentState {
    employmentState ?? .hired
  }
}

public struct EmployeeMemoryEntry: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var employeeID: String
  public var authorID: String
  public var dayNumber: Int
  public var summary: String
  public var sourceArtifactID: String?
  public var createdAt: Date

  public init(
    id: String,
    employeeID: String,
    authorID: String,
    dayNumber: Int,
    summary: String,
    sourceArtifactID: String?,
    createdAt: Date
  ) {
    self.id = id
    self.employeeID = employeeID
    self.authorID = authorID
    self.dayNumber = dayNumber
    self.summary = summary
    self.sourceArtifactID = sourceArtifactID
    self.createdAt = createdAt
  }
}

public struct CapabilityEvent: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var capability: String
  public var employeeID: String
  public var taskID: String?
  public var actorID: String
  public var kind: CapabilityEventKind
  public var detail: String
  public var createdAt: Date

  public init(
    id: String,
    capability: String,
    employeeID: String,
    taskID: String?,
    actorID: String,
    kind: CapabilityEventKind,
    detail: String,
    createdAt: Date
  ) {
    self.id = id
    self.capability = capability
    self.employeeID = employeeID
    self.taskID = taskID
    self.actorID = actorID
    self.kind = kind
    self.detail = detail
    self.createdAt = createdAt
  }
}

public struct AssistantHandoff: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var assistantID: String
  public var humanID: String
  public var dayNumber: Int
  public var kind: AssistantHandoffKind
  public var summary: String
  public var artifactIDs: [String]
  public var createdAt: Date

  public init(
    id: String,
    assistantID: String,
    humanID: String,
    dayNumber: Int,
    kind: AssistantHandoffKind,
    summary: String,
    artifactIDs: [String],
    createdAt: Date
  ) {
    self.id = id
    self.assistantID = assistantID
    self.humanID = humanID
    self.dayNumber = dayNumber
    self.kind = kind
    self.summary = summary
    self.artifactIDs = artifactIDs
    self.createdAt = createdAt
  }
}

public struct ResearchAssignment: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var outcome: String
  public var context: String
  public var requestedByActorID: String
  public var delegatedByActorID: String
  public var assigneeID: String
  public var reviewerID: String
  public var status: ResearchAssignmentStatus
  public var blockingReason: String?
  public var evidenceBasis: String?
  public var briefArtifactID: String?
  public var deliveryArtifactID: String?
  public var attemptCount: Int
  public var createdAt: Date
  public var updatedAt: Date
  public var canonicalOutcomeID: String?

  public init(
    id: String,
    outcome: String,
    context: String,
    requestedByActorID: String = "owner",
    delegatedByActorID: String = "mira",
    assigneeID: String = "nia",
    reviewerID: String = "mira",
    status: ResearchAssignmentStatus = .queued,
    blockingReason: String? = nil,
    evidenceBasis: String? = nil,
    briefArtifactID: String? = nil,
    deliveryArtifactID: String? = nil,
    attemptCount: Int = 0,
    createdAt: Date,
    updatedAt: Date,
    canonicalOutcomeID: String? = nil
  ) {
    self.id = id
    self.outcome = outcome
    self.context = context
    self.requestedByActorID = requestedByActorID
    self.delegatedByActorID = delegatedByActorID
    self.assigneeID = assigneeID
    self.reviewerID = reviewerID
    self.status = status
    self.blockingReason = blockingReason
    self.evidenceBasis = evidenceBasis
    self.briefArtifactID = briefArtifactID
    self.deliveryArtifactID = deliveryArtifactID
    self.attemptCount = attemptCount
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.canonicalOutcomeID = canonicalOutcomeID
  }
}

public enum ResearchAssignmentError: LocalizedError, Equatable {
  case emptyOutcome
  case activeAssignmentExists
  case missingEmployee

  public var errorDescription: String? {
    switch self {
    case .emptyOutcome:
      "Tell Nia what you want researched before sending the assignment."
    case .activeAssignmentExists:
      "Nia already has an active research assignment. Finish or stop it before adding another."
    case .missingEmployee:
      "The owner, Mira, or Nia is missing from this organization."
    }
  }
}

public struct SkillDefinition: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var name: String
  public var category: String
  public var purpose: String
  public var instructions: String
  public var successCriteria: String
  public var version: Int
  public var source: SkillSource
  public var requiredConnectionIDs: [String]
  public var authorID: String
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String,
    name: String,
    category: String,
    purpose: String,
    instructions: String,
    successCriteria: String,
    version: Int = 1,
    source: SkillSource,
    requiredConnectionIDs: [String] = [],
    authorID: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.category = category
    self.purpose = purpose
    self.instructions = instructions
    self.successCriteria = successCriteria
    self.version = version
    self.source = source
    self.requiredConnectionIDs = requiredConnectionIDs
    self.authorID = authorID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct EmployeeSkillAssignment: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var skillID: String
  public var employeeID: String
  public var assignedByActorID: String
  public var assignedAt: Date

  public init(
    id: String, skillID: String, employeeID: String, assignedByActorID: String, assignedAt: Date
  ) {
    self.id = id
    self.skillID = skillID
    self.employeeID = employeeID
    self.assignedByActorID = assignedByActorID
    self.assignedAt = assignedAt
  }
}

public struct ConnectionDefinition: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public var name: String
  public var kind: ConnectionKind
  public var summary: String
  public var capabilityID: String?

  public init(
    id: String, name: String, kind: ConnectionKind, summary: String, capabilityID: String? = nil
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.summary = summary
    self.capabilityID = capabilityID
  }
}

public struct OrganizationProfile: Codable, Sendable, Equatable {
  public var purpose: String
  public var product: String
  public var audience: String
  public var stage: String
  public var operatingPrinciples: String
  public var constraints: String

  public init(
    purpose: String = "",
    product: String = "",
    audience: String = "",
    stage: String = "",
    operatingPrinciples: String = "",
    constraints: String = ""
  ) {
    self.purpose = purpose
    self.product = product
    self.audience = audience
    self.stage = stage
    self.operatingPrinciples = operatingPrinciples
    self.constraints = constraints
  }

  public static let empty = OrganizationProfile()
}

public struct OrganizationKnowledge: Codable, Sendable, Equatable {
  public var productBrief: String
  public var profile: OrganizationProfile
  public var memoryEntries: [EmployeeMemoryEntry]
  public var capabilityEvents: [CapabilityEvent]
  public var assistantHandoffs: [AssistantHandoff]
  public var skillDefinitions: [SkillDefinition]
  public var skillAssignments: [EmployeeSkillAssignment]
  public var connectionDefinitions: [ConnectionDefinition]
  public var researchAssignments: [ResearchAssignment]
  public var employeeOutcomes: [EmployeeOutcome]
  public var employeeDuties: [EmployeeDuty]
  public var dutyOccurrences: [DutyOccurrence]
  public var employeePackages: [EmployeePackage]
  public var workingContracts: [WorkingContract]
  public var contractChanges: [ContractChange]
  public var supervisionEvents: [SupervisionEvent]
  public var runtimeBindings: [RuntimeBinding]
  public var schedulePolicies: [SchedulePolicy]
  public var scheduledOccurrences: [ScheduledOccurrence]
  public var runReceipts: [RunReceipt]
  public var runtimeSessions: [RuntimeSessionPresence]
  public var resourceLeases: [ResourceLease]

  public init(
    productBrief: String,
    profile: OrganizationProfile = .empty,
    memoryEntries: [EmployeeMemoryEntry] = [],
    capabilityEvents: [CapabilityEvent] = [],
    assistantHandoffs: [AssistantHandoff] = [],
    skillDefinitions: [SkillDefinition] = [],
    skillAssignments: [EmployeeSkillAssignment] = [],
    connectionDefinitions: [ConnectionDefinition] = [],
    researchAssignments: [ResearchAssignment] = [],
    employeeOutcomes: [EmployeeOutcome] = [],
    employeeDuties: [EmployeeDuty] = [],
    dutyOccurrences: [DutyOccurrence] = [],
    employeePackages: [EmployeePackage] = [],
    workingContracts: [WorkingContract] = [],
    contractChanges: [ContractChange] = [],
    supervisionEvents: [SupervisionEvent] = [],
    runtimeBindings: [RuntimeBinding] = [],
    schedulePolicies: [SchedulePolicy] = [],
    scheduledOccurrences: [ScheduledOccurrence] = [],
    runReceipts: [RunReceipt] = [],
    runtimeSessions: [RuntimeSessionPresence] = [],
    resourceLeases: [ResourceLease] = []
  ) {
    self.productBrief = productBrief
    self.profile = profile
    self.memoryEntries = memoryEntries
    self.capabilityEvents = capabilityEvents
    self.assistantHandoffs = assistantHandoffs
    self.skillDefinitions = skillDefinitions
    self.skillAssignments = skillAssignments
    self.connectionDefinitions = connectionDefinitions
    self.researchAssignments = researchAssignments
    self.employeeOutcomes = employeeOutcomes
    self.employeeDuties = employeeDuties
    self.dutyOccurrences = dutyOccurrences
    self.employeePackages = employeePackages
    self.workingContracts = workingContracts
    self.contractChanges = contractChanges
    self.supervisionEvents = supervisionEvents
    self.runtimeBindings = runtimeBindings
    self.schedulePolicies = schedulePolicies
    self.scheduledOccurrences = scheduledOccurrences
    self.runReceipts = runReceipts
    self.runtimeSessions = runtimeSessions
    self.resourceLeases = resourceLeases
  }

  private enum CodingKeys: String, CodingKey {
    case productBrief
    case profile
    case memoryEntries
    case capabilityEvents
    case assistantHandoffs
    case skillDefinitions
    case skillAssignments
    case connectionDefinitions
    case researchAssignments
    case employeeOutcomes
    case employeeDuties
    case dutyOccurrences
    case employeePackages
    case workingContracts
    case contractChanges
    case supervisionEvents
    case runtimeBindings
    case schedulePolicies
    case scheduledOccurrences
    case runReceipts
    case runtimeSessions
    case resourceLeases
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    productBrief = try container.decode(String.self, forKey: .productBrief)
    profile = try container.decodeIfPresent(OrganizationProfile.self, forKey: .profile) ?? .empty
    memoryEntries =
      try container.decodeIfPresent([EmployeeMemoryEntry].self, forKey: .memoryEntries) ?? []
    capabilityEvents =
      try container.decodeIfPresent([CapabilityEvent].self, forKey: .capabilityEvents) ?? []
    assistantHandoffs =
      try container.decodeIfPresent([AssistantHandoff].self, forKey: .assistantHandoffs) ?? []
    skillDefinitions =
      try container.decodeIfPresent([SkillDefinition].self, forKey: .skillDefinitions) ?? []
    skillAssignments =
      try container.decodeIfPresent([EmployeeSkillAssignment].self, forKey: .skillAssignments) ?? []
    connectionDefinitions =
      try container.decodeIfPresent([ConnectionDefinition].self, forKey: .connectionDefinitions)
      ?? []
    researchAssignments =
      try container.decodeIfPresent([ResearchAssignment].self, forKey: .researchAssignments) ?? []
    employeeOutcomes =
      try container.decodeIfPresent([EmployeeOutcome].self, forKey: .employeeOutcomes) ?? []
    employeeDuties =
      try container.decodeIfPresent([EmployeeDuty].self, forKey: .employeeDuties) ?? []
    dutyOccurrences =
      try container.decodeIfPresent([DutyOccurrence].self, forKey: .dutyOccurrences) ?? []
    employeePackages =
      try container.decodeIfPresent([EmployeePackage].self, forKey: .employeePackages) ?? []
    workingContracts =
      try container.decodeIfPresent([WorkingContract].self, forKey: .workingContracts) ?? []
    contractChanges =
      try container.decodeIfPresent([ContractChange].self, forKey: .contractChanges) ?? []
    supervisionEvents =
      try container.decodeIfPresent([SupervisionEvent].self, forKey: .supervisionEvents) ?? []
    runtimeBindings =
      try container.decodeIfPresent([RuntimeBinding].self, forKey: .runtimeBindings) ?? []
    schedulePolicies =
      try container.decodeIfPresent([SchedulePolicy].self, forKey: .schedulePolicies) ?? []
    scheduledOccurrences =
      try container.decodeIfPresent([ScheduledOccurrence].self, forKey: .scheduledOccurrences) ?? []
    runReceipts = try container.decodeIfPresent([RunReceipt].self, forKey: .runReceipts) ?? []
    runtimeSessions =
      try container.decodeIfPresent([RuntimeSessionPresence].self, forKey: .runtimeSessions) ?? []
    resourceLeases =
      try container.decodeIfPresent([ResourceLease].self, forKey: .resourceLeases) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(productBrief, forKey: .productBrief)
    try container.encode(profile, forKey: .profile)
    try container.encode(memoryEntries, forKey: .memoryEntries)
    try container.encode(capabilityEvents, forKey: .capabilityEvents)
    try container.encode(assistantHandoffs, forKey: .assistantHandoffs)
    try container.encode(skillDefinitions, forKey: .skillDefinitions)
    try container.encode(skillAssignments, forKey: .skillAssignments)
    try container.encode(connectionDefinitions, forKey: .connectionDefinitions)
    try container.encode(researchAssignments, forKey: .researchAssignments)
    try container.encode(employeeOutcomes, forKey: .employeeOutcomes)
    try container.encode(employeeDuties, forKey: .employeeDuties)
    try container.encode(dutyOccurrences, forKey: .dutyOccurrences)
    try container.encode(employeePackages, forKey: .employeePackages)
    try container.encode(workingContracts, forKey: .workingContracts)
    try container.encode(contractChanges, forKey: .contractChanges)
    try container.encode(supervisionEvents, forKey: .supervisionEvents)
    try container.encode(runtimeBindings, forKey: .runtimeBindings)
    try container.encode(schedulePolicies, forKey: .schedulePolicies)
    try container.encode(scheduledOccurrences, forKey: .scheduledOccurrences)
    try container.encode(runReceipts, forKey: .runReceipts)
    try container.encode(runtimeSessions, forKey: .runtimeSessions)
    try container.encode(resourceLeases, forKey: .resourceLeases)
  }
}

public enum SkillTeachingError: LocalizedError, Equatable {
  case missingEmployee
  case incomplete

  public var errorDescription: String? {
    switch self {
    case .missingEmployee:
      "Choose an employee who should learn this skill."
    case .incomplete:
      "Add a name, purpose, actionable instructions, and success criteria before teaching this skill."
    }
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
  public var accountableEmployeeID: String?
  public var delegationReason: String?
  public var requiredSkillIDs: [String]?
  public var requiredConnectionIDs: [String]?
  public var workRevision: Int?

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
    updatedAt: Date,
    accountableEmployeeID: String? = nil,
    delegationReason: String? = nil,
    requiredSkillIDs: [String]? = nil,
    requiredConnectionIDs: [String]? = nil,
    workRevision: Int? = 0
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
    self.accountableEmployeeID = accountableEmployeeID
    self.delegationReason = delegationReason
    self.requiredSkillIDs = requiredSkillIDs
    self.requiredConnectionIDs = requiredConnectionIDs
    self.workRevision = workRevision
  }

  public var effectiveAccountableEmployeeID: String { accountableEmployeeID ?? assigneeID }
  public var effectiveWorkRevision: Int { workRevision ?? 0 }
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
  public var sourceArtifactIDs: [String]?
  public var evidenceBasis: String?

  public init(
    id: String,
    title: String,
    kind: ArtifactKind,
    relativePath: String,
    authorID: String,
    taskID: String,
    createdAt: Date,
    sourceArtifactIDs: [String]? = nil,
    evidenceBasis: String? = nil
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.relativePath = relativePath
    self.authorID = authorID
    self.taskID = taskID
    self.createdAt = createdAt
    self.sourceArtifactIDs = sourceArtifactIDs
    self.evidenceBasis = evidenceBasis
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
  public var setupCompleted: Bool?
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
  public var knowledge: OrganizationKnowledge?
  public var lastSavedAt: Date
  public var organizationConcurrencyLimit: Int?
  /// The journal sequence this snapshot reflects, so replay knows where to
  /// resume. Absent for organizations written before the journal existed.
  public var journalSequence: Int?

  public static func seeded(now: Date = Date(), hiredStarterTeam: Bool = true) -> OrganizationState
  {
    let starterEmployment: EmploymentState = hiredStarterTeam ? .hired : .candidate
    let owner = Employee(
      id: "owner",
      name: "Founder",
      kind: .human,
      role: "Owner",
      responsibility: "Set the company's outcomes, make judgment calls, and approve new access.",
      avatarColor: "D9B18E"
    )
    let assistant = Employee(
      id: "mira",
      name: "Mira",
      role: "Executive Assistant",
      responsibility:
        "Keep the owner oriented, surface decisions, and prepare clear daily handoffs.",
      managerID: owner.id,
      assistantForHumanID: owner.id,
      avatarColor: "B7A5D8",
      employmentState: starterEmployment,
      packageID: "starter.mira",
      packageVersion: "1.0.0"
    )
    let manager = Employee(
      id: "maya",
      name: "Maya",
      role: "Editorial Manager",
      responsibility: "Own the content outcome, review work, and keep the team moving.",
      avatarColor: "E78B5B",
      employmentState: starterEmployment,
      packageID: "starter.maya",
      packageVersion: "1.0.0"
    )
    let researcher = Employee(
      id: "nia",
      name: "Nia",
      role: "Audience Researcher",
      responsibility: "Understand the product and find useful questions worth answering.",
      managerID: manager.id,
      avatarColor: "F2C96D",
      employmentState: starterEmployment,
      packageID: "starter.nia",
      packageVersion: "1.0.0"
    )
    let writer = Employee(
      id: "theo",
      name: "Theo",
      role: "Content Writer",
      responsibility: "Turn evidence and direction into clear, useful articles.",
      managerID: manager.id,
      avatarColor: "7395A8",
      employmentState: starterEmployment,
      packageID: "starter.theo",
      packageVersion: "1.0.0"
    )
    let customerVoiceAnalyst = Employee(
      id: "iris",
      name: "Iris",
      role: "Customer Voice Analyst",
      responsibility:
        "Turn deliberately supplied customer feedback into one cited owner decision each week.",
      managerID: assistant.id,
      avatarColor: "6E8B62",
      employmentState: starterEmployment,
      packageID: "starter.iris",
      packageVersion: "1.0.0"
    )

    let researchID = "research-audience"
    let draftID = "draft-first-article"
    let reportID = "prepare-daily-report"

    return OrganizationState(
      schemaVersion: 9,
      setupCompleted: false,
      id: "willow-studio",
      name: "Willow Studio",
      outcome:
        "Create one genuinely useful article that helps the right people discover and understand the product.",
      workdayStatus: .resting,
      executionMode: .demo,
      dayNumber: 0,
      employees: [owner, assistant, manager, researcher, writer, customerVoiceAnalyst],
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
        ),
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
      knowledge: OrganizationKnowledge(
        productBrief: """
          # Product brief

          ## Product
          Describe what you are building.

          ## Audience
          Describe who it is for.

          ## Problem
          Describe the painful problem it solves.

          ## Claims we can support
          List only claims the team may safely make.
          """,
        profile: OrganizationProfile(
          purpose:
            "Build a useful body of work that helps the right people understand the product.",
          product: "A prepared local studio for rehearsing a small content team's first mission.",
          audience:
            "Early product teams learning how named AI employees can coordinate useful work.",
          stage: "Proof of concept",
          operatingPrinciples:
            "Stay grounded in supplied facts. Prefer useful evidence to content volume. Keep owner decisions explicit.",
          constraints: "Local-only practice mode. No publishing or unsupported product claims."
        ),
        skillDefinitions: OrganizationKnowledge.builtInSkills(now: now),
        skillAssignments: OrganizationKnowledge.builtInAssignments(now: now),
        connectionDefinitions: OrganizationKnowledge.builtInConnections(),
        employeeDuties: [.customerVoiceWeekly(now: now)]
      ),
      lastSavedAt: now,
      organizationConcurrencyLimit: 2
    )
  }

  public var effectiveConcurrencyLimit: Int {
    min(max(organizationConcurrencyLimit ?? 2, 1), 4)
  }

  public func employee(_ id: String) -> Employee? {
    employees.first { $0.id == id }
  }

  public func task(_ id: String) -> WorkTask? {
    tasks.first { $0.id == id }
  }

  public func assistant(for humanID: String) -> Employee? {
    employees.first { $0.assistantForHumanID == humanID }
  }

  public func hasCapability(_ capability: String, employeeID: String) -> Bool {
    employee(employeeID)?.capabilityGrants.contains(capability) == true
  }

  public var researchAssignments: [ResearchAssignment] {
    knowledge?.researchAssignments ?? []
  }

  public var activeResearchAssignment: ResearchAssignment? {
    researchAssignments.last { !$0.status.isTerminal }
  }

  public var latestResearchAssignment: ResearchAssignment? {
    researchAssignments.max { $0.createdAt < $1.createdAt }
  }

  public func researchAssignment(_ id: String) -> ResearchAssignment? {
    researchAssignments.first { $0.id == id }
  }

  @discardableResult
  public mutating func updateResearchAssignment(
    _ id: String,
    now: Date = Date(),
    _ update: (inout ResearchAssignment) -> Void
  ) -> Bool {
    guard let index = knowledge?.researchAssignments.firstIndex(where: { $0.id == id }) else {
      return false
    }
    update(&knowledge!.researchAssignments[index])
    knowledge!.researchAssignments[index].updatedAt = now
    return true
  }

  @discardableResult
  public mutating func createResearchAssignment(
    outcome: String,
    context: String,
    now: Date = Date()
  ) throws -> String {
    let trimmedOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedOutcome.isEmpty else { throw ResearchAssignmentError.emptyOutcome }
    guard activeResearchAssignment == nil else {
      throw ResearchAssignmentError.activeAssignmentExists
    }
    guard employee("owner") != nil, employee("mira") != nil, employee("nia") != nil else {
      throw ResearchAssignmentError.missingEmployee
    }
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    let id = "research-assignment-\(UUID().uuidString.lowercased().prefix(8))"
    let canonicalOutcomeID = try createEmployeeOutcome(
      employeeID: "nia",
      outcome: trimmedOutcome,
      context: context.trimmingCharacters(in: .whitespacesAndNewlines),
      acceptanceCriteria: [
        "Return an evidence basis, uncertainty, and one recommended next action."
      ],
      priority: .normal,
      source: .legacyResearch,
      sourceID: id,
      now: now
    )
    knowledge?.researchAssignments.append(
      ResearchAssignment(
        id: id,
        outcome: trimmedOutcome,
        context: context.trimmingCharacters(in: .whitespacesAndNewlines),
        createdAt: now,
        updatedAt: now,
        canonicalOutcomeID: canonicalOutcomeID
      ))
    activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "owner",
        kind: .started,
        message: "You gave Mira a research outcome: \(trimmedOutcome)",
        createdAt: now
      ))
    activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "mira",
        kind: .handoff,
        message: "Mira delegated the research assignment to Nia.",
        createdAt: now
      ))
    return id
  }

  @discardableResult
  public mutating func resetInterruptedResearch(now: Date = Date()) -> Bool {
    guard let index = knowledge?.researchAssignments.lastIndex(where: { $0.status == .researching })
    else {
      return false
    }
    knowledge?.researchAssignments[index].status = .queued
    knowledge?.researchAssignments[index].blockingReason =
      "The previous run stopped before delivery. It is ready to resume."
    knowledge?.researchAssignments[index].updatedAt = now
    activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "mira",
        kind: .stopped,
        message: "Mira kept Nia's interrupted research assignment ready to resume.",
        createdAt: now
      ))
    return true
  }

  @discardableResult
  public mutating func cancelResearchAssignment(
    _ id: String,
    actorID: String = "owner",
    reason: String = "The owner stopped this research assignment.",
    now: Date = Date()
  ) -> Bool {
    guard let assignment = researchAssignment(id), !assignment.status.isTerminal else {
      return false
    }
    _ = updateResearchAssignment(id, now: now) { value in
      value.status = .cancelled
      value.blockingReason = nil
    }
    activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: actorID,
        kind: .stopped,
        message: reason,
        createdAt: now
      ))
    return true
  }

  public func skill(_ id: String) -> SkillDefinition? {
    knowledge?.skillDefinitions.first { $0.id == id }
  }

  public func assignedSkills(employeeID: String) -> [SkillDefinition] {
    let skillIDs = Set(
      knowledge?.skillAssignments.filter { $0.employeeID == employeeID }.map(\.skillID) ?? [])
    return (knowledge?.skillDefinitions ?? [])
      .filter { skillIDs.contains($0.id) }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  public func employeesWithSkill(_ skillID: String) -> [Employee] {
    let employeeIDs = Set(
      knowledge?.skillAssignments.filter { $0.skillID == skillID }.map(\.employeeID) ?? [])
    return employees.filter { employeeIDs.contains($0.id) }
  }

  @discardableResult
  public mutating func assignSkill(
    skillID: String,
    employeeID: String,
    actorID: String = "owner",
    now: Date = Date()
  ) -> Bool {
    guard skill(skillID) != nil, employee(employeeID) != nil else { return false }
    if knowledge?.skillAssignments.contains(where: {
      $0.skillID == skillID && $0.employeeID == employeeID
    }) == true {
      return false
    }
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    knowledge?.skillAssignments.append(
      EmployeeSkillAssignment(
        id: "\(employeeID):\(skillID)",
        skillID: skillID,
        employeeID: employeeID,
        assignedByActorID: actorID,
        assignedAt: now
      ))
    let skillName = skill(skillID)?.name ?? skillID
    let employeeName = employee(employeeID)?.name ?? employeeID
    activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: actorID,
        kind: .taught,
        message: "\(employeeName) received the \(skillName) skill guidance.",
        createdAt: now
      ))
    return true
  }

  @discardableResult
  public mutating func teachSkill(
    name: String,
    category: String,
    purpose: String,
    instructions: String,
    successCriteria: String,
    requiredConnectionIDs: [String] = [],
    employeeID: String,
    actorID: String = "owner",
    now: Date = Date()
  ) throws -> String {
    guard employee(employeeID) != nil else { throw SkillTeachingError.missingEmployee }
    let values = [name, purpose, instructions, successCriteria]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard values.allSatisfy({ !$0.isEmpty }) else { throw SkillTeachingError.incomplete }
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    let id = "organization-\(UUID().uuidString.lowercased().prefix(8))"
    knowledge?.skillDefinitions.append(
      SkillDefinition(
        id: id,
        name: values[0],
        category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? "Organization" : category.trimmingCharacters(in: .whitespacesAndNewlines),
        purpose: values[1],
        instructions: values[2],
        successCriteria: values[3],
        source: .organization,
        requiredConnectionIDs: Array(Set(requiredConnectionIDs)).sorted(),
        authorID: actorID,
        createdAt: now,
        updatedAt: now
      ))
    _ = assignSkill(skillID: id, employeeID: employeeID, actorID: actorID, now: now)
    return id
  }

  public var productBrief: String {
    knowledge?.productBrief ?? ""
  }

  /// Applies first-run identity, company memory, execution mode, and the
  /// initial web-research grant to one in-memory snapshot. Callers can then
  /// persist that snapshot once, avoiding competing pre-setup saves.
  public mutating func applyOnboarding(
    name: String,
    ownerName: String,
    outcome: String,
    productBrief: String,
    profile: OrganizationProfile,
    executionMode: ExecutionMode,
    webResearchGranted: Bool,
    now: Date = Date()
  ) {
    let isFirstSetup = setupCompleted != true
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedOwnerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBrief = productBrief.trimmingCharacters(in: .whitespacesAndNewlines)

    if !trimmedName.isEmpty { self.name = trimmedName }
    if !trimmedOwnerName.isEmpty,
      let ownerIndex = employees.firstIndex(where: { $0.id == "owner" })
    {
      employees[ownerIndex].name = trimmedOwnerName
      if let assistantIndex = employees.firstIndex(where: { $0.assistantForHumanID == "owner" }) {
        employees[assistantIndex].responsibility =
          "Keep \(trimmedOwnerName) oriented, surface decisions, and prepare clear daily handoffs."
      }
    }
    if !trimmedOutcome.isEmpty {
      self.outcome = trimmedOutcome
      if !goals.isEmpty { goals[0].detail = trimmedOutcome }
    }
    if knowledge == nil {
      knowledge = OrganizationKnowledge(productBrief: trimmedBrief, profile: profile)
    } else {
      if !trimmedBrief.isEmpty { knowledge?.productBrief = trimmedBrief }
      if profile != .empty { knowledge?.profile = profile }
    }

    self.executionMode = executionMode
    if let niaIndex = employees.firstIndex(where: { $0.id == "nia" }) {
      let hadGrant = employees[niaIndex].capabilityGrants.contains("web-research")
      if webResearchGranted && !hadGrant {
        employees[niaIndex].capabilityGrants.append("web-research")
      } else if !webResearchGranted && hadGrant {
        employees[niaIndex].capabilityGrants.removeAll { $0 == "web-research" }
      }
      if hadGrant != webResearchGranted {
        knowledge?.capabilityEvents.append(
          CapabilityEvent(
            id: UUID().uuidString,
            capability: "web-research",
            employeeID: "nia",
            taskID: "research-audience",
            actorID: "owner",
            kind: webResearchGranted ? .granted : .revoked,
            detail: webResearchGranted
              ? "The owner granted Nia read-only web research."
              : "The owner revoked Nia's web research access.",
            createdAt: now
          ))
      }
    }

    setupCompleted = true
    if isFirstSetup {
      activity.append(
        Activity(
          id: UUID().uuidString,
          actorID: "owner",
          kind: .joined,
          message: "The doors opened for \(self.name).",
          createdAt: now
        ))
    }
  }

  public var hasMeaningfulProductBrief: Bool {
    Self.isMeaningfulProductBrief(productBrief)
  }

  public static func isMeaningfulProductBrief(_ brief: String) -> Bool {
    let normalized = brief.lowercased()
    return brief.trimmingCharacters(in: .whitespacesAndNewlines).count >= 120
      && !normalized.contains("describe what")
      && !normalized.contains("describe who")
      && !normalized.contains("describe the painful")
      && !normalized.contains("list only claims")
  }
}

extension OrganizationKnowledge {
  public static func builtInSkills(now: Date = Date()) -> [SkillDefinition] {
    [
      SkillDefinition(
        id: "executive-briefing", name: "Executive briefing", category: "Coordination",
        purpose: "Keep the owner oriented around current work and decisions.",
        instructions:
          "Summarize only persisted goals, tasks, blockers, permissions, and artifacts. Separate completed work from pending work and end with the next owner decision.",
        successCriteria:
          "The brief is attributable, contains no invented progress, and names one clear next action.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "outcome-ownership", name: "Outcome ownership", category: "Management",
        purpose: "Own a bounded organizational outcome and coordinate specialists toward it.",
        instructions:
          "Break the outcome into the existing bounded tasks, keep ownership explicit, review handoffs, and stop at the configured revision limit.",
        successCriteria:
          "The outcome ends with approved work or a precise owner blocker, never an infinite review loop.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "audience-research", name: "Audience research", category: "Research",
        purpose: "Find the useful audience question that the content should answer.",
        instructions:
          "Ground the question in the product brief. Use external sources only when web research is granted, cite URLs when used, and distinguish evidence from owner claims.",
        successCriteria:
          "Research identifies a concrete reader question, evidence basis, and article direction without fabricated sources.",
        source: .builtIn, requiredConnectionIDs: ["web-research"], authorID: "agent-office",
        createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "evidence-writing", name: "Evidence-based writing", category: "Content",
        purpose: "Turn approved evidence and direction into a useful article.",
        instructions:
          "Write from the product brief and research artifact, preserve claim boundaries, and make the result independently readable rather than summarizing the transcript.",
        successCriteria:
          "The draft answers the audience question, traces its evidence, and is ready for editorial review.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "editorial-review", name: "Editorial review", category: "Quality",
        purpose: "Evaluate content against its outcome, evidence, and safe claims.",
        instructions:
          "Return a clear approve or revise verdict with focused evidence. Do not request more than the bounded revision limit permits.",
        successCriteria:
          "The verdict is actionable, grounded in the artifact, and either approves the work or identifies one bounded correction.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "owner-reporting", name: "Owner reporting", category: "Coordination",
        purpose: "Leave the owner a concise account of completed work and next decisions.",
        instructions:
          "Summarize completed tasks, created artifacts, unresolved blockers, capability use, and the recommended next action.",
        successCriteria:
          "The report matches persisted state and lets the owner resume without reading the full activity timeline.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "customer-voice-analysis", name: "Customer voice analysis", category: "Research",
        purpose:
          "Turn a bounded set of supplied customer evidence into one traceable weekly decision.",
        instructions:
          "Account for every included source, group repeated themes without overstating prevalence, cite source labels for each claim, state uncertainty, and recommend exactly one owner decision.",
        successCriteria:
          "The brief reports coverage, traces themes to supplied files, distinguishes single observations from repeated evidence, and recommends one bounded decision.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "reddit-community-research", name: "Reddit community research", category: "Research",
        purpose:
          "Find the communities worth entering and establish what each one currently permits.",
        instructions:
          "Start from the product brief and the requested outcome. Name each candidate community, why it fits the product and audience, and the evidence for that fit. When web research is granted, verify current rules, promotion limits and posting requirements from the community's own current text and cite the URL you read. Mark a community unclear when its current rules cannot be verified, and never carry a rule over from another community or from memory. Without granted research, label the work owner-context-only and use only the communities and rules the owner supplied.",
        successCriteria:
          "Every listed community carries a fit reason, either a cited rule finding or an explicit unclear label, and a source the owner can re-check.",
        source: .builtIn, requiredConnectionIDs: ["web-research"], authorID: "agent-office",
        createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "rule-aware-reddit-writing", name: "Rule-aware Reddit writing", category: "Content",
        purpose: "Prepare community-specific posts and replies the owner can read, edit and post.",
        instructions:
          "Write each draft for one named community and against that community's verified rules, and say which rule shaped each choice. Keep every product claim inside what the brief supports. Never invent participation, karma, comment history, testimonials or other social proof, and never write as though you already belong to the community. Include the promotion disclosure the community requires. State plainly that nothing has been posted, and end each draft with the instruction to re-check that community's current rules immediately before posting.",
        successCriteria:
          "Each draft names its community, traces its choices to verified rules, invents no participation or social proof, and ends with the owner's re-check-then-post step.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "reddit-growth-review", name: "Reddit growth review", category: "Quality",
        purpose:
          "Turn today's priorities and the owner's recorded results into an honest next step.",
        instructions:
          "Produce a bounded daily plan: a short ordered list of actions, the community each belongs to, timing considerations, the risk of each, and the next owner action. Review only the traffic, engagement, removals and mentions the owner supplied, name the period they cover, and keep what the numbers show separate from what caused it. Do not claim causality from one post, one week, or an uncontrolled comparison. Recommend revisions for owner approval and state what evidence would change the recommendation.",
        successCriteria:
          "The plan is bounded, ordered and risk-labelled, the review names its supplied period, causal claims are absent or explicitly hedged, and one recommendation waits for owner approval.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
      SkillDefinition(
        id: "communication", name: "Communication", category: "Coordination",
        purpose:
          "Keep work supervisable through concise, attributable updates and precise requests for help.",
        instructions:
          "Acknowledge the outcome, announce the ticket plan, report meaningful progress, ask one precise question when blocked, and finish with what changed, the artifacts created, and the recommended next action.",
        successCriteria:
          "The owner can understand acceptance, plan, progress, blockers, and delivery from persisted activity without reading a raw model transcript.",
        source: .builtIn, authorID: "agent-office", createdAt: now, updatedAt: now),
    ]
  }

  public static func builtInAssignments(now: Date = Date()) -> [EmployeeSkillAssignment] {
    [
      EmployeeSkillAssignment(
        id: "mira:executive-briefing", skillID: "executive-briefing", employeeID: "mira",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "maya:outcome-ownership", skillID: "outcome-ownership", employeeID: "maya",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "nia:audience-research", skillID: "audience-research", employeeID: "nia",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "theo:evidence-writing", skillID: "evidence-writing", employeeID: "theo",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "maya:editorial-review", skillID: "editorial-review", employeeID: "maya",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "maya:owner-reporting", skillID: "owner-reporting", employeeID: "maya",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "iris:customer-voice-analysis", skillID: "customer-voice-analysis", employeeID: "iris",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "mira:communication", skillID: "communication", employeeID: "mira",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "maya:communication", skillID: "communication", employeeID: "maya",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "nia:communication", skillID: "communication", employeeID: "nia",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "theo:communication", skillID: "communication", employeeID: "theo",
        assignedByActorID: "agent-office", assignedAt: now),
      EmployeeSkillAssignment(
        id: "iris:communication", skillID: "communication", employeeID: "iris",
        assignedByActorID: "agent-office", assignedAt: now),
    ]
  }

  public static func builtInConnections() -> [ConnectionDefinition] {
    [
      ConnectionDefinition(
        id: "demo-runner", name: "Demo team", kind: .execution,
        summary: "Local deterministic rehearsal with no account or network."),
      ConnectionDefinition(
        id: "local-codex", name: "Local Codex", kind: .execution,
        summary: "Uses the locally installed and authenticated Codex CLI in a read-only sandbox."),
      ConnectionDefinition(
        id: "web-research", name: "Web research", kind: .tool,
        summary: "Read-only live research for explicitly permitted research work.",
        capabilityID: "web-research"),
    ]
  }
}
