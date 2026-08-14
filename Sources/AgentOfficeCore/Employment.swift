import Foundation

public enum EmploymentState: String, Codable, Sendable, CaseIterable {
  case candidate
  case hired
  case paused
  case retired
}

public enum EmployeeExecutionProvider: String, Codable, Sendable, CaseIterable {
  case demo
  case localCodex

  public init(_ mode: ExecutionMode) {
    self = mode == .localCodex ? .localCodex : .demo
  }
}

public enum EmployeeExecutionEnvironment: String, Codable, Sendable, CaseIterable {
  case organizationSandbox
}

public enum PlanReviewPolicy: String, Codable, Sendable, CaseIterable {
  case always
  case whenAuthorityChanges
  case automaticForLocalWork
}

public struct AutonomyBoundaries: Codable, Sendable, Equatable {
  public var mayReadOrganizationFiles: Bool
  public var mayWriteEmployeeHome: Bool
  public var mayDelegate: Bool
  public var mayUseExternalTools: Bool
  public var mayPublish: Bool
  public var maximumRevisions: Int

  public init(
    mayReadOrganizationFiles: Bool = true,
    mayWriteEmployeeHome: Bool = true,
    mayDelegate: Bool = true,
    mayUseExternalTools: Bool = false,
    mayPublish: Bool = false,
    maximumRevisions: Int = 2
  ) {
    self.mayReadOrganizationFiles = mayReadOrganizationFiles
    self.mayWriteEmployeeHome = mayWriteEmployeeHome
    self.mayDelegate = mayDelegate
    self.mayUseExternalTools = mayUseExternalTools
    self.mayPublish = mayPublish
    self.maximumRevisions = min(max(maximumRevisions, 0), 4)
  }
}

public struct EmployeePackageSkill: Identifiable, Codable, Sendable, Equatable {
  public var id: String
  public var name: String
  public var category: String
  public var purpose: String
  public var instructions: String
  public var successCriteria: String
  public var version: Int
  public var requiredConnectionIDs: [String]

  public init(
    id: String,
    name: String,
    category: String,
    purpose: String,
    instructions: String,
    successCriteria: String,
    version: Int = 1,
    requiredConnectionIDs: [String] = []
  ) {
    self.id = id
    self.name = name
    self.category = category
    self.purpose = purpose
    self.instructions = instructions
    self.successCriteria = successCriteria
    self.requiredConnectionIDs = requiredConnectionIDs
    self.version = version
  }

  public init(_ definition: SkillDefinition) {
    self.init(
      id: definition.id,
      name: definition.name,
      category: definition.category,
      purpose: definition.purpose,
      instructions: definition.instructions,
      successCriteria: definition.successCriteria,
      version: definition.version,
      requiredConnectionIDs: definition.requiredConnectionIDs
    )
  }

  public func materialized(authorID: String, now: Date) -> SkillDefinition {
    SkillDefinition(
      id: id,
      name: name,
      category: category,
      purpose: purpose,
      instructions: instructions,
      successCriteria: successCriteria,
      version: version,
      source: .builtIn,
      requiredConnectionIDs: requiredConnectionIDs,
      authorID: authorID,
      createdAt: now,
      updatedAt: now
    )
  }
}

public struct EmployeePackage: Identifiable, Codable, Sendable, Equatable {
  public var id: String
  public var version: String
  public var creator: String
  public var name: String
  public var role: String
  public var responsibility: String
  public var managerRole: String?
  public var avatarColor: String
  public var skills: [EmployeePackageSkill]
  public var requiredConnectionIDs: [String]
  public var supportedProviders: [EmployeeExecutionProvider]
  public var preferredProvider: EmployeeExecutionProvider
  public var defaultModelName: String?
  public var boundaries: AutonomyBoundaries
  public var reducedModeDescription: String?
  public var builtIn: Bool

  public init(
    id: String,
    version: String,
    creator: String,
    name: String,
    role: String,
    responsibility: String,
    managerRole: String? = nil,
    avatarColor: String,
    skills: [EmployeePackageSkill],
    requiredConnectionIDs: [String] = [],
    supportedProviders: [EmployeeExecutionProvider] = [.demo, .localCodex],
    preferredProvider: EmployeeExecutionProvider = .demo,
    defaultModelName: String? = nil,
    boundaries: AutonomyBoundaries = AutonomyBoundaries(),
    reducedModeDescription: String? = nil,
    builtIn: Bool = false
  ) {
    self.id = id
    self.version = version
    self.creator = creator
    self.name = name
    self.role = role
    self.responsibility = responsibility
    self.managerRole = managerRole
    self.avatarColor = avatarColor
    self.skills = skills
    self.requiredConnectionIDs = requiredConnectionIDs
    self.supportedProviders = supportedProviders
    self.preferredProvider = preferredProvider
    self.defaultModelName = defaultModelName
    self.boundaries = boundaries
    self.reducedModeDescription = reducedModeDescription
    self.builtIn = builtIn
  }

  public var versionedID: String { "\(id)@\(version)" }
}

public enum ContractValueSource: String, Codable, Sendable {
  case employeePackage
  case organization
  case migration
}

public struct ContractFieldProvenance: Codable, Sendable, Equatable {
  public var field: String
  public var source: ContractValueSource

  public init(field: String, source: ContractValueSource) {
    self.field = field
    self.source = source
  }
}

public struct WorkingContract: Identifiable, Codable, Sendable, Equatable {
  public var id: String { employeeID }
  public var employeeID: String
  public var packageID: String?
  public var packageVersion: String?
  public var revision: Int
  public var role: String
  public var responsibility: String
  public var managerID: String?
  public var assistantForHumanID: String?
  public var assignedSkillIDs: [String]
  public var declaredConnectionIDs: [String]
  public var capabilityGrants: [String]
  public var executionProvider: EmployeeExecutionProvider
  public var modelName: String?
  public var environment: EmployeeExecutionEnvironment
  public var workspacePath: String
  public var boundaries: AutonomyBoundaries
  public var reviewPolicy: PlanReviewPolicy
  public var provenance: [ContractFieldProvenance]
  public var updatedAt: Date

  public init(
    employeeID: String,
    packageID: String? = nil,
    packageVersion: String? = nil,
    revision: Int = 1,
    role: String,
    responsibility: String,
    managerID: String? = nil,
    assistantForHumanID: String? = nil,
    assignedSkillIDs: [String],
    declaredConnectionIDs: [String],
    capabilityGrants: [String],
    executionProvider: EmployeeExecutionProvider,
    modelName: String? = nil,
    environment: EmployeeExecutionEnvironment = .organizationSandbox,
    workspacePath: String,
    boundaries: AutonomyBoundaries = AutonomyBoundaries(),
    reviewPolicy: PlanReviewPolicy = .always,
    provenance: [ContractFieldProvenance] = [],
    updatedAt: Date
  ) {
    self.employeeID = employeeID
    self.packageID = packageID
    self.packageVersion = packageVersion
    self.revision = revision
    self.role = role
    self.responsibility = responsibility
    self.managerID = managerID
    self.assistantForHumanID = assistantForHumanID
    self.assignedSkillIDs = assignedSkillIDs
    self.declaredConnectionIDs = declaredConnectionIDs
    self.capabilityGrants = capabilityGrants
    self.executionProvider = executionProvider
    self.modelName = modelName
    self.environment = environment
    self.workspacePath = workspacePath
    self.boundaries = boundaries
    self.reviewPolicy = reviewPolicy
    self.provenance = provenance
    self.updatedAt = updatedAt
  }
}

public struct ContractChange: Identifiable, Codable, Sendable, Equatable {
  public var id: String
  public var employeeID: String
  public var field: String
  public var previousValue: String
  public var newValue: String
  public var actorID: String
  public var reason: String
  public var createdAt: Date

  public init(
    id: String = UUID().uuidString, employeeID: String, field: String, previousValue: String,
    newValue: String, actorID: String, reason: String, createdAt: Date
  ) {
    self.id = id
    self.employeeID = employeeID
    self.field = field
    self.previousValue = previousValue
    self.newValue = newValue
    self.actorID = actorID
    self.reason = reason
    self.createdAt = createdAt
  }
}

public enum SupervisionEventKind: String, Codable, Sendable, CaseIterable {
  case hire
  case pause
  case resume
  case retire
  case contractChanged
  case planProposed
  case planApproved
  case planReturned
  case helpRequested
  case ownerReplied
  case redirected
  case reassigned
  case stopped
  case delivered
  case revisionRequested
  case accepted
  case closed
}

public struct SupervisionEvent: Identifiable, Codable, Sendable, Equatable {
  public var id: String
  public var kind: SupervisionEventKind
  public var actorID: String
  public var employeeID: String
  public var outcomeID: String?
  public var taskID: String?
  public var message: String
  public var priorValue: String?
  public var createdAt: Date

  public init(
    id: String = UUID().uuidString, kind: SupervisionEventKind, actorID: String, employeeID: String,
    outcomeID: String? = nil, taskID: String? = nil, message: String, priorValue: String? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.kind = kind
    self.actorID = actorID
    self.employeeID = employeeID
    self.outcomeID = outcomeID
    self.taskID = taskID
    self.message = message
    self.priorValue = priorValue
    self.createdAt = createdAt
  }
}

public enum EmployeePackageError: LocalizedError, Equatable {
  case malformed
  case invalidIdentifier
  case invalidVersion
  case incompleteIdentity
  case missingSkills
  case invalidSkill(String)
  case unsupportedProvider
  case unsafeSecret(String)
  case executableReference(String)
  case duplicateVersion
  case packageInUse
  case missingPackage

  public var errorDescription: String? {
    switch self {
    case .malformed: "The selected file is not a valid employee package."
    case .invalidIdentifier:
      "Use a stable lowercase package identifier containing letters, numbers, dots, or hyphens."
    case .invalidVersion: "The employee package needs a numeric dotted version such as 1.0.0."
    case .incompleteIdentity: "The package must declare a name, role, responsibility, and creator."
    case .missingSkills: "The package must include at least one complete skill."
    case .invalidSkill(let id): "The package contains an invalid or duplicate skill: \(id)."
    case .unsupportedProvider:
      "The preferred execution provider is not included in the package's supported providers."
    case .unsafeSecret(let key):
      "Employee packages cannot contain credentials or secret-shaped data (\(key))."
    case .executableReference(let value):
      "Employee packages are declarative and cannot reference executable code (\(value))."
    case .duplicateVersion: "That employee package version is already available."
    case .packageInUse: "A current or historical employee still references that package version."
    case .missingPackage: "That employee package is no longer available."
    }
  }
}

public enum EmploymentError: LocalizedError, Equatable {
  case missingPackage
  case missingEmployee
  case humanMember
  case notHired
  case alreadyEmployed
  case activeWork
  case incompatiblePackage

  public var errorDescription: String? {
    switch self {
    case .missingPackage: "That employee package is no longer available."
    case .missingEmployee: "That employee is no longer part of the organization."
    case .humanMember: "Human organization members do not use the AI employment lifecycle."
    case .notHired: "This employee is not currently hired."
    case .alreadyEmployed: "This candidate is already employed by the organization."
    case .activeWork:
      "Stop or transfer the employee's active work before changing their employment state."
    case .incompatiblePackage: "The package update does not match this employee's package identity."
    }
  }
}

public enum EmployeePackageCatalogue {
  public static func starterPackages(now: Date = Date()) -> [EmployeePackage] {
    let skills = Dictionary(
      uniqueKeysWithValues: OrganizationKnowledge.builtInSkills(now: now).map {
        ($0.id, EmployeePackageSkill($0))
      })
    func selected(_ ids: [String]) -> [EmployeePackageSkill] { ids.compactMap { skills[$0] } }
    return [
      EmployeePackage(
        id: "starter.mira", version: "1.0.0", creator: "Agent Office", name: "Mira",
        role: "Executive Assistant",
        responsibility:
          "Keep the owner oriented, surface decisions, and prepare clear daily handoffs.",
        managerRole: "Owner", avatarColor: "B7A5D8",
        skills: selected(["executive-briefing", "communication"]),
        reducedModeDescription: "Can organize local company context without external connections.",
        builtIn: true),
      EmployeePackage(
        id: "starter.maya", version: "1.0.0", creator: "Agent Office", name: "Maya",
        role: "Editorial Manager",
        responsibility: "Own the content outcome, review work, and keep the team moving.",
        avatarColor: "E78B5B",
        skills: selected([
          "outcome-ownership", "editorial-review", "owner-reporting", "communication",
        ]), builtIn: true),
      EmployeePackage(
        id: "starter.nia", version: "1.0.0", creator: "Agent Office", name: "Nia",
        role: "Audience Researcher",
        responsibility: "Understand the product and find useful questions worth answering.",
        managerRole: "Editorial Manager", avatarColor: "F2C96D",
        skills: selected(["audience-research", "communication"]),
        requiredConnectionIDs: ["web-research"],
        reducedModeDescription:
          "Can research supplied local material; live web research waits for an explicit grant.",
        builtIn: true),
      EmployeePackage(
        id: "starter.theo", version: "1.0.0", creator: "Agent Office", name: "Theo",
        role: "Content Writer",
        responsibility: "Turn evidence and direction into clear, useful articles.",
        managerRole: "Editorial Manager", avatarColor: "7395A8",
        skills: selected(["evidence-writing", "communication"]), builtIn: true),
      EmployeePackage(
        id: "starter.iris", version: "1.0.0", creator: "Agent Office", name: "Iris",
        role: "Customer Voice Analyst",
        responsibility:
          "Turn deliberately supplied customer feedback into one cited owner decision each week.",
        managerRole: "Executive Assistant", avatarColor: "6E8B62",
        skills: selected(["customer-voice-analysis", "communication"]),
        reducedModeDescription: "Works only from feedback deliberately placed in the local inbox.",
        builtIn: true),
    ]
  }

  public static func validate(_ package: EmployeePackage) throws {
    let identifierPattern = /^[a-z0-9]+(?:[.-][a-z0-9]+)*$/
    let versionPattern = /^\d+(?:\.\d+){1,2}$/
    guard package.id.wholeMatch(of: identifierPattern) != nil else {
      throw EmployeePackageError.invalidIdentifier
    }
    guard package.version.wholeMatch(of: versionPattern) != nil else {
      throw EmployeePackageError.invalidVersion
    }
    guard !package.creator.trimmed.isEmpty, !package.name.trimmed.isEmpty,
      !package.role.trimmed.isEmpty, !package.responsibility.trimmed.isEmpty
    else {
      throw EmployeePackageError.incompleteIdentity
    }
    guard !package.skills.isEmpty else { throw EmployeePackageError.missingSkills }
    var skillIDs = Set<String>()
    for skill in package.skills {
      guard skillIDs.insert(skill.id).inserted,
        skill.id.wholeMatch(of: identifierPattern) != nil,
        !skill.name.trimmed.isEmpty,
        !skill.purpose.trimmed.isEmpty,
        !skill.instructions.trimmed.isEmpty,
        !skill.successCriteria.trimmed.isEmpty,
        skill.version > 0
      else { throw EmployeePackageError.invalidSkill(skill.id) }
    }
    guard package.supportedProviders.contains(package.preferredProvider) else {
      throw EmployeePackageError.unsupportedProvider
    }
  }

  public static func decodeAndValidate(_ data: Data) throws -> EmployeePackage {
    let object: Any
    do { object = try JSONSerialization.jsonObject(with: data) } catch {
      throw EmployeePackageError.malformed
    }
    try inspect(object, keyPath: "package")
    var package: EmployeePackage
    do { package = try JSONDecoder().decode(EmployeePackage.self, from: data) } catch {
      throw EmployeePackageError.malformed
    }
    package.builtIn = false
    try validate(package)
    return package
  }

  private static func inspect(_ value: Any, keyPath: String) throws {
    if let dictionary = value as? [String: Any] {
      for (key, nested) in dictionary {
        let normalized = key.lowercased().filter(\.isLetter)
        if ["secret", "token", "password", "credential", "apikey", "privatekey", "sessionkey"]
          .contains(where: normalized.contains)
        {
          throw EmployeePackageError.unsafeSecret("\(keyPath).\(key)")
        }
        try inspect(nested, keyPath: "\(keyPath).\(key)")
      }
    } else if let array = value as? [Any] {
      for (index, nested) in array.enumerated() {
        try inspect(nested, keyPath: "\(keyPath)[\(index)]")
      }
    } else if let string = value as? String {
      let lowered = string.lowercased()
      if lowered.hasPrefix("sk-") || lowered.contains("-----begin private key-----") {
        throw EmployeePackageError.unsafeSecret(keyPath)
      }
      if lowered.hasPrefix("/")
        || [".sh", ".command", ".app", ".dylib", ".so", ".exe"].contains(where: lowered.hasSuffix)
      {
        throw EmployeePackageError.executableReference(string)
      }
    }
  }
}

extension OrganizationState {
  public var employeePackages: [EmployeePackage] { knowledge?.employeePackages ?? [] }
  public var workingContracts: [WorkingContract] { knowledge?.workingContracts ?? [] }
  public var contractChanges: [ContractChange] { knowledge?.contractChanges ?? [] }
  public var supervisionEvents: [SupervisionEvent] { knowledge?.supervisionEvents ?? [] }

  public var activeAIEmployees: [Employee] {
    employees.filter { $0.kind == .ai && [.hired, .paused].contains($0.effectiveEmploymentState) }
  }

  public func workingContract(for employeeID: String) -> WorkingContract? {
    workingContracts.first { $0.employeeID == employeeID }
  }

  public func employeePackage(id: String, version: String? = nil) -> EmployeePackage? {
    employeePackages.first { $0.id == id && (version == nil || $0.version == version) }
  }

  @discardableResult
  public mutating func installEmployeePackage(_ package: EmployeePackage) throws -> Bool {
    try EmployeePackageCatalogue.validate(package)
    if employeePackages.contains(where: { $0.versionedID == package.versionedID }) {
      throw EmployeePackageError.duplicateVersion
    }
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    knowledge?.employeePackages.append(package)
    return true
  }

  @discardableResult
  public mutating func removeEmployeePackage(id: String, version: String) throws -> Bool {
    guard
      let index = knowledge?.employeePackages.firstIndex(where: {
        $0.id == id && $0.version == version
      })
    else { throw EmployeePackageError.missingPackage }
    guard !employees.contains(where: { $0.packageID == id && $0.packageVersion == version }) else {
      throw EmployeePackageError.packageInUse
    }
    knowledge?.employeePackages.remove(at: index)
    return true
  }

  @discardableResult
  public mutating func hireEmployee(
    packageID: String,
    version: String? = nil,
    managerID: String? = nil,
    actorID: String = "owner",
    now: Date = Date()
  ) throws -> String {
    guard let package = employeePackage(id: packageID, version: version) else {
      throw EmploymentError.missingPackage
    }
    if let employed = employees.first(where: {
      $0.kind == .ai && $0.packageID == package.id && $0.packageVersion == package.version
        && [.hired, .paused].contains($0.effectiveEmploymentState)
    }) {
      return employed.id
    }
    if let candidateIndex = employees.firstIndex(where: {
      $0.kind == .ai && $0.packageID == package.id && $0.packageVersion == package.version
        && $0.effectiveEmploymentState == .candidate
    }) {
      let id = employees[candidateIndex].id
      employees[candidateIndex].employmentState = .hired
      employees[candidateIndex].managerID = managerID ?? employees[candidateIndex].managerID
      try materializeContract(for: id, package: package, actorID: actorID, now: now)
      recordEmployment(
        kind: .hire, employeeID: id, actorID: actorID,
        message: "Hired \(employees[candidateIndex].name) as \(employees[candidateIndex].role).",
        now: now)
      return id
    }
    let baseID = Self.employeeSlug(package.name)
    var employeeID = baseID
    var suffix = 2
    while employee(employeeID) != nil {
      employeeID = "\(baseID)-\(suffix)"
      suffix += 1
    }
    employees.append(
      Employee(
        id: employeeID,
        name: package.name,
        role: package.role,
        responsibility: package.responsibility,
        managerID: managerID,
        avatarColor: package.avatarColor,
        employmentState: .hired,
        packageID: package.id,
        packageVersion: package.version
      ))
    try materializeContract(for: employeeID, package: package, actorID: actorID, now: now)
    recordEmployment(
      kind: .hire, employeeID: employeeID, actorID: actorID,
      message: "Hired \(package.name) as \(package.role).", now: now)
    return employeeID
  }

  public mutating func pauseEmployee(
    _ employeeID: String, actorID: String = "owner", reason: String = "Paused by the owner.",
    now: Date = Date()
  ) throws {
    guard let index = employees.firstIndex(where: { $0.id == employeeID }) else {
      throw EmploymentError.missingEmployee
    }
    guard employees[index].kind == .ai else { throw EmploymentError.humanMember }
    guard employees[index].effectiveEmploymentState == .hired else {
      throw EmploymentError.notHired
    }
    employees[index].employmentState = .paused
    if let outcome = employeeOutcomes.first(where: {
      $0.assigneeID == employeeID && $0.status.isActivelyRunning
    }) {
      _ = updateEmployeeOutcome(outcome.id, now: now) {
        $0.status = .queued
        $0.helpRequest = "Work was paused by the owner and is ready to resume."
      }
    }
    employees[index].status = .resting
    employees[index].currentTaskID = nil
    recordEmployment(
      kind: .pause, employeeID: employeeID, actorID: actorID, message: reason, now: now)
  }

  public mutating func resumeEmployee(
    _ employeeID: String, actorID: String = "owner", reason: String = "Resumed by the owner.",
    now: Date = Date()
  ) throws {
    guard let index = employees.firstIndex(where: { $0.id == employeeID }) else {
      throw EmploymentError.missingEmployee
    }
    guard employees[index].kind == .ai else { throw EmploymentError.humanMember }
    guard employees[index].effectiveEmploymentState == .paused else {
      throw EmploymentError.notHired
    }
    employees[index].employmentState = .hired
    recordEmployment(
      kind: .resume, employeeID: employeeID, actorID: actorID, message: reason, now: now)
  }

  public mutating func retireEmployee(
    _ employeeID: String, actorID: String = "owner", reason: String = "Retired by the owner.",
    now: Date = Date()
  ) throws {
    guard let index = employees.firstIndex(where: { $0.id == employeeID }) else {
      throw EmploymentError.missingEmployee
    }
    guard employees[index].kind == .ai else { throw EmploymentError.humanMember }
    guard
      employees[index].effectiveEmploymentState == .hired
        || employees[index].effectiveEmploymentState == .paused
    else { throw EmploymentError.notHired }
    guard
      !employeeOutcomes.contains(where: {
        $0.assigneeID == employeeID && $0.status.isActivelyRunning
      })
    else { throw EmploymentError.activeWork }
    employees[index].employmentState = .retired
    employees[index].status = .resting
    employees[index].currentTaskID = nil
    recordEmployment(
      kind: .retire, employeeID: employeeID, actorID: actorID, message: reason, now: now)
  }

  public mutating func updateWorkingContract(
    employeeID: String,
    role: String,
    responsibility: String,
    managerID: String?,
    assignedSkillIDs: [String],
    declaredConnectionIDs: [String],
    capabilityGrants: [String],
    executionProvider: EmployeeExecutionProvider,
    modelName: String?,
    boundaries: AutonomyBoundaries,
    reviewPolicy: PlanReviewPolicy,
    actorID: String = "owner",
    reason: String,
    now: Date = Date()
  ) throws {
    guard let employeeIndex = employees.firstIndex(where: { $0.id == employeeID }),
      employees[employeeIndex].kind == .ai
    else { throw EmploymentError.missingEmployee }
    guard
      let contractIndex = knowledge?.workingContracts.firstIndex(where: {
        $0.employeeID == employeeID
      })
    else { throw EmploymentError.notHired }
    let old = knowledge!.workingContracts[contractIndex]
    var revised = old
    revised.revision += 1
    revised.role = role.trimmed
    revised.responsibility = responsibility.trimmed
    revised.managerID = managerID
    revised.assignedSkillIDs = assignedSkillIDs.uniqued.sorted()
    revised.declaredConnectionIDs = declaredConnectionIDs.uniqued.sorted()
    revised.capabilityGrants = capabilityGrants.uniqued.sorted()
    revised.executionProvider = executionProvider
    revised.modelName = modelName?.trimmed.nilIfEmpty
    revised.boundaries = boundaries
    revised.reviewPolicy = reviewPolicy
    revised.updatedAt = now
    revised.provenance = Self.contractFields.map {
      ContractFieldProvenance(field: $0, source: .organization)
    }
    knowledge!.workingContracts[contractIndex] = revised
    employees[employeeIndex].role = revised.role
    employees[employeeIndex].responsibility = revised.responsibility
    employees[employeeIndex].managerID = revised.managerID
    employees[employeeIndex].capabilityGrants = revised.capabilityGrants
    knowledge?.skillAssignments.removeAll {
      $0.employeeID == employeeID && !revised.assignedSkillIDs.contains($0.skillID)
    }
    for skillID in revised.assignedSkillIDs where skill(skillID) != nil {
      if knowledge?.skillAssignments.contains(where: {
        $0.employeeID == employeeID && $0.skillID == skillID
      }) != true {
        knowledge?.skillAssignments.append(
          EmployeeSkillAssignment(
            id: "\(employeeID):\(skillID)", skillID: skillID, employeeID: employeeID,
            assignedByActorID: actorID, assignedAt: now))
      }
    }
    appendContractChanges(from: old, to: revised, actorID: actorID, reason: reason, now: now)
    recordEmployment(
      kind: .contractChanged, employeeID: employeeID, actorID: actorID,
      message: "Updated working contract revision \(revised.revision): \(reason)", now: now)
  }

  public mutating func applyPackageUpdate(
    employeeID: String, packageID: String, version: String, actorID: String = "owner",
    now: Date = Date()
  ) throws {
    guard let employeeIndex = employees.firstIndex(where: { $0.id == employeeID }) else {
      throw EmploymentError.missingEmployee
    }
    guard employees[employeeIndex].packageID == packageID else {
      throw EmploymentError.incompatiblePackage
    }
    guard let package = employeePackage(id: packageID, version: version) else {
      throw EmploymentError.missingPackage
    }
    guard
      let contractIndex = knowledge?.workingContracts.firstIndex(where: {
        $0.employeeID == employeeID
      })
    else { throw EmploymentError.notHired }
    employees[employeeIndex].packageVersion = version
    knowledge!.workingContracts[contractIndex].packageVersion = version
    knowledge!.workingContracts[contractIndex].revision += 1
    knowledge!.workingContracts[contractIndex].declaredConnectionIDs = package.requiredConnectionIDs
    knowledge!.workingContracts[contractIndex].updatedAt = now
    for packageSkill in package.skills where skill(packageSkill.id) == nil {
      knowledge?.skillDefinitions.append(
        packageSkill.materialized(authorID: package.creator, now: now))
    }
    recordEmployment(
      kind: .contractChanged, employeeID: employeeID, actorID: actorID,
      message:
        "Applied \(package.name) package \(version) without changing employee identity or grants.",
      now: now)
  }

  public mutating func migrateEmployment(now: Date) {
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    for package in EmployeePackageCatalogue.starterPackages(now: now)
    where !employeePackages.contains(where: { $0.versionedID == package.versionedID }) {
      knowledge?.employeePackages.append(package)
    }
    let packageByEmployee = [
      "mira": "starter.mira", "maya": "starter.maya", "nia": "starter.nia", "theo": "starter.theo",
      "iris": "starter.iris",
    ]
    for index in employees.indices {
      if employees[index].employmentState == nil { employees[index].employmentState = .hired }
      guard employees[index].kind == .ai else { continue }
      if employees[index].packageID == nil, let packageID = packageByEmployee[employees[index].id],
        let package = employeePackage(id: packageID)
      {
        employees[index].packageID = package.id
        employees[index].packageVersion = package.version
      }
      guard employees[index].effectiveEmploymentState == .hired,
        workingContract(for: employees[index].id) == nil
      else { continue }
      let package = employees[index].packageID.flatMap {
        employeePackage(id: $0, version: employees[index].packageVersion)
      }
      try? materializeContract(
        for: employees[index].id, package: package, actorID: "agent-office-migration", now: now,
        source: .migration)
    }
    organizationConcurrencyLimit = effectiveConcurrencyLimit
  }

  private mutating func materializeContract(
    for employeeID: String, package: EmployeePackage?, actorID: String, now: Date,
    source: ContractValueSource = .employeePackage
  ) throws {
    guard let employeeIndex = employees.firstIndex(where: { $0.id == employeeID }) else {
      throw EmploymentError.missingEmployee
    }
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    let employee = employees[employeeIndex]
    if let package {
      for packageSkill in package.skills where skill(packageSkill.id) == nil {
        knowledge?.skillDefinitions.append(
          packageSkill.materialized(authorID: package.creator, now: now))
      }
      for packageSkill in package.skills
      where knowledge?.skillAssignments.contains(where: {
        $0.employeeID == employeeID && $0.skillID == packageSkill.id
      }) != true {
        knowledge?.skillAssignments.append(
          EmployeeSkillAssignment(
            id: "\(employeeID):\(packageSkill.id)", skillID: packageSkill.id,
            employeeID: employeeID, assignedByActorID: actorID, assignedAt: now))
      }
    }
    let skillIDs = assignedSkills(employeeID: employeeID).map(\.id)
    let connectionIDs =
      package?.requiredConnectionIDs
      ?? skillIDs.flatMap { skill($0)?.requiredConnectionIDs ?? [] }.uniqued
    let contract = WorkingContract(
      employeeID: employeeID,
      packageID: employee.packageID ?? package?.id,
      packageVersion: employee.packageVersion ?? package?.version,
      role: employee.role,
      responsibility: employee.responsibility,
      managerID: employee.managerID,
      assistantForHumanID: employee.assistantForHumanID,
      assignedSkillIDs: skillIDs,
      declaredConnectionIDs: connectionIDs,
      capabilityGrants: employee.capabilityGrants,
      executionProvider: source == .migration
        ? EmployeeExecutionProvider(executionMode)
        : (package?.preferredProvider ?? EmployeeExecutionProvider(executionMode)),
      modelName: package?.defaultModelName,
      workspacePath: "employees/\(employeeID)",
      boundaries: package?.boundaries ?? AutonomyBoundaries(),
      reviewPolicy: .always,
      provenance: Self.contractFields.map { ContractFieldProvenance(field: $0, source: source) },
      updatedAt: now
    )
    if let existing = knowledge?.workingContracts.firstIndex(where: { $0.employeeID == employeeID })
    {
      knowledge?.workingContracts[existing] = contract
    } else {
      knowledge?.workingContracts.append(contract)
    }
  }

  private mutating func recordEmployment(
    kind: SupervisionEventKind, employeeID: String, actorID: String, message: String, now: Date
  ) {
    knowledge?.supervisionEvents.append(
      SupervisionEvent(
        kind: kind, actorID: actorID, employeeID: employeeID, message: message, createdAt: now))
    activity.append(
      Activity(
        id: UUID().uuidString, actorID: actorID, kind: kind == .hire ? .joined : .progress,
        message: message, createdAt: now))
  }

  private mutating func appendContractChanges(
    from old: WorkingContract, to new: WorkingContract, actorID: String, reason: String, now: Date
  ) {
    let values: [(String, String, String)] = [
      ("role", old.role, new.role), ("responsibility", old.responsibility, new.responsibility),
      ("manager", old.managerID ?? "None", new.managerID ?? "None"),
      (
        "skills", old.assignedSkillIDs.joined(separator: ","),
        new.assignedSkillIDs.joined(separator: ",")
      ),
      (
        "connections", old.declaredConnectionIDs.joined(separator: ","),
        new.declaredConnectionIDs.joined(separator: ",")
      ),
      (
        "grants", old.capabilityGrants.joined(separator: ","),
        new.capabilityGrants.joined(separator: ",")
      ),
      ("executionProvider", old.executionProvider.rawValue, new.executionProvider.rawValue),
      ("model", old.modelName ?? "Default", new.modelName ?? "Default"),
      ("boundaries", String(describing: old.boundaries), String(describing: new.boundaries)),
      ("reviewPolicy", old.reviewPolicy.rawValue, new.reviewPolicy.rawValue),
    ]
    for (field, previous, next) in values where previous != next {
      knowledge?.contractChanges.append(
        ContractChange(
          employeeID: new.employeeID, field: field, previousValue: previous, newValue: next,
          actorID: actorID, reason: reason, createdAt: now))
    }
  }

  private static let contractFields = [
    "identity", "role", "responsibility", "relationships", "skills", "connections", "grants",
    "executionProvider", "model", "environment", "workspace", "boundaries", "reviewPolicy",
  ]

  private static func employeeSlug(_ value: String) -> String {
    let slug = value.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
      .split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-")
    return slug.isEmpty ? "employee" : slug
  }
}

extension String {
  fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Array where Element: Hashable {
  fileprivate var uniqued: [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
