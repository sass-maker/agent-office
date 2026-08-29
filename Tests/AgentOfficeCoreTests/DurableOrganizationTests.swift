import XCTest

@testable import AgentOfficeCore

/// What the local organization is before and after it is put away.
///
/// Everything here is about durability rather than about running work: the
/// shape the organization seeds with, what onboarding writes, what survives
/// being saved and reopened, what migration adds to an older file, and what the
/// owner can teach a named employee. These tests lived in `WorkdayEngineTests`
/// only because that file happened to be where the first suite was written;
/// none of them needs a work engine.
final class DurableOrganizationTests: XCTestCase {

  // MARK: - What a new organization is

  func testSeededOrganizationHasDurableEmployeeShape() {
    let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

    XCTAssertEqual(organization.setupCompleted, false)
    XCTAssertEqual(
      organization.employees.map(\.id), ["owner", "mira", "maya", "nia", "theo", "iris"])
    XCTAssertEqual(organization.employee("owner")?.kind, .human)
    XCTAssertEqual(organization.assistant(for: "owner")?.id, "mira")
    XCTAssertEqual(organization.employee("theo")?.managerID, "maya")
    XCTAssertTrue(organization.employees.allSatisfy { $0.capabilityGrants.isEmpty })
    XCTAssertEqual(organization.employee("iris")?.managerID, "mira")
    XCTAssertEqual(
      organization.knowledge?.skillDefinitions.count, OrganizationKnowledge.builtInSkills().count)
    XCTAssertEqual(organization.knowledge?.skillAssignments.count, 12)
    XCTAssertEqual(organization.knowledge?.connectionDefinitions.count, 3)
    XCTAssertEqual(organization.employeeDuty("customer-voice-weekly")?.assigneeID, "iris")
    XCTAssertEqual(
      organization.assignedSkills(employeeID: "maya").map(\.id),
      ["communication", "editorial-review", "outcome-ownership", "owner-reporting"])
    XCTAssertTrue(organization.assignedSkills(employeeID: "owner").isEmpty)
    XCTAssertEqual(organization.tasks.filter { $0.status == .ready }.map(\.kind), [.research])
    XCTAssertFalse(organization.hasMeaningfulProductBrief)

    var grounded = organization
    grounded.knowledge?.productBrief = """
      Agent Office is a cosy local workplace for founders who need repeatable non-technical work completed. It gives named AI employees outcomes, visible responsibilities, bounded review cycles, and ordinary local artifacts. The current product can safely claim local persistence and an inspectable content workday.
      """
    XCTAssertTrue(grounded.hasMeaningfulProductBrief)

    grounded.knowledge?.productBrief = String(
      repeating: "Describe what this product does. ", count: 8)
    XCTAssertFalse(grounded.hasMeaningfulProductBrief)
  }

  func testOnboardingAppliesCompanyModeAndPermissionToOnePersistableSnapshot() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let profile = OrganizationProfile(
      purpose: "Give a small studio a dependable team.",
      product: "A cosy local workplace for AI employees.",
      audience: "Solo founders",
      stage: "Private proof of concept",
      operatingPrinciples: "Stay grounded and ask before external action.",
      constraints: "Never publish or spend without approval."
    )

    organization.applyOnboarding(
      name: "Juniper House",
      ownerName: "Sarthak",
      outcome: "Deliver one decision-ready customer brief.",
      productBrief:
        "A complete grounded product brief for Juniper House and its first bounded mission.",
      profile: profile,
      executionMode: .localCodex,
      webResearchGranted: true,
      now: Date(timeIntervalSince1970: 200)
    )
    try await store.save(organization)

    let reopened = try await store.loadOrCreate()
    XCTAssertEqual(reopened.setupCompleted, true)
    XCTAssertEqual(reopened.name, "Juniper House")
    XCTAssertEqual(reopened.employee("owner")?.name, "Sarthak")
    XCTAssertEqual(reopened.outcome, "Deliver one decision-ready customer brief.")
    XCTAssertEqual(reopened.knowledge?.profile, profile)
    XCTAssertEqual(reopened.executionMode, .localCodex)
    XCTAssertTrue(reopened.hasCapability("web-research", employeeID: "nia"))
    XCTAssertEqual(reopened.knowledge?.capabilityEvents.last?.kind, .granted)
    XCTAssertEqual(reopened.activity.filter { $0.message.contains("doors opened") }.count, 1)
  }

  // MARK: - What survives being saved and reopened

  func testSetupCompletionSurvivesPersistence() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.setupCompleted = true
    organization.name = "Juniper House"

    try await store.save(organization)
    let loaded = try await store.loadOrCreate()

    XCTAssertEqual(loaded.setupCompleted, true)
    XCTAssertEqual(loaded.name, "Juniper House")
  }

  func testPersistenceRoundTripKeepsOrganizationAndArtifactsInspectable() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.outcome = "A persisted outcome"

    try await store.save(organization)
    try await store.writeArtifact(
      relativePath: "employees/nia/research.md",
      content: "# Evidence\n\nLocal and inspectable."
    )

    let loaded = try await store.loadOrCreate()
    let artifact = try await store.readArtifact(relativePath: "employees/nia/research.md")

    XCTAssertEqual(loaded.outcome, "A persisted outcome")
    XCTAssertEqual(loaded.employees, organization.employees)
    XCTAssertTrue(artifact.contains("Local and inspectable"))
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("organization.json").path))
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("COMPANY.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("PRODUCT_BRIEF.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("SKILLS.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("CONNECTIONS.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("RESEARCH_ASSIGNMENTS.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/maya/IDENTITY.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/maya/MEMORY.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/maya/CAPABILITIES.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/maya/SKILLS.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/maya/ARTIFACTS.md").path))
  }

  func testDeliveredWorkIsProjectedIntoTheOwnerReadableHistories() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

    let assignmentID = try organization.createResearchAssignment(
      outcome: "Map the decisions a founder makes during first use",
      context: "",
      now: Date(timeIntervalSince1970: 200)
    )
    let brief = Artifact(
      id: "brief-artifact",
      title: "Nia's brief",
      kind: .research,
      relativePath: "employees/nia/brief.md",
      authorID: "nia",
      taskID: assignmentID,
      createdAt: Date(timeIntervalSince1970: 300),
      evidenceBasis: "synthetic-demo"
    )
    organization.artifacts.append(brief)
    XCTAssertTrue(
      organization.updateResearchAssignment(assignmentID, now: Date(timeIntervalSince1970: 300)) {
        value in
        value.status = .delivered
        value.evidenceBasis = "synthetic-demo"
        value.briefArtifactID = brief.id
      })

    let occurrenceID = try organization.beginDutyOccurrence(
      dutyID: EmployeeDuty.customerVoiceWeeklyID,
      now: Date(timeIntervalSince1970: 400)
    )
    let dutyBrief = Artifact(
      id: "duty-brief-artifact",
      title: "Iris's brief",
      kind: .analysis,
      relativePath: "employees/iris/brief.md",
      authorID: "iris",
      taskID: occurrenceID,
      createdAt: Date(timeIntervalSince1970: 500),
      evidenceBasis: "local-feedback-analysis"
    )
    organization.artifacts.append(dutyBrief)
    XCTAssertTrue(
      organization.updateDutyOccurrence(occurrenceID, now: Date(timeIntervalSince1970: 500)) {
        value in
        value.status = .delivered
        value.evidenceBasis = "local-feedback-analysis"
        value.briefArtifactID = dutyBrief.id
        value.includedInputs = [
          DutyInputReference(label: "F1", fileName: "founder-note.md", byteCount: 12)
        ]
      })

    try await store.save(organization)

    let assignments = try String(
      contentsOf: root.appendingPathComponent("RESEARCH_ASSIGNMENTS.md"), encoding: .utf8)
    XCTAssertTrue(assignments.contains("Map the decisions a founder makes during first use"))
    XCTAssertTrue(assignments.contains("synthetic-demo"))
    XCTAssertTrue(assignments.contains("[Open Nia's brief](employees/nia/brief.md)"))

    let duties = try String(contentsOf: root.appendingPathComponent("DUTIES.md"), encoding: .utf8)
    XCTAssertTrue(duties.contains("Customer Voice Weekly"))
    XCTAssertTrue(duties.contains("[Open Iris's brief](employees/iris/brief.md)"))
    XCTAssertTrue(duties.contains("1 included · 0 excluded"))
  }

  func testEmployeeHomesStayInsideSelectedOrganization() async throws {
    let firstRoot = temporaryDirectory()
    let secondRoot = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: firstRoot)
      try? FileManager.default.removeItem(at: secondRoot)
    }
    let firstStore = LocalOrganizationStore(rootURL: firstRoot)
    let secondStore = LocalOrganizationStore(rootURL: secondRoot)
    var first = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    first.name = "First Company"
    var second = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    second.name = "Second Company"

    try await firstStore.save(first)
    try await secondStore.save(second)

    let firstIdentity = try String(
      contentsOf: firstRoot.appendingPathComponent("employees/maya/IDENTITY.md"), encoding: .utf8)
    let secondIdentity = try String(
      contentsOf: secondRoot.appendingPathComponent("employees/maya/IDENTITY.md"), encoding: .utf8)
    XCTAssertEqual(firstIdentity, secondIdentity)
    XCTAssertNotEqual(firstStore.rootURL, secondStore.rootURL)
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: firstRoot.appendingPathComponent("employees/unknown").path))
  }

  // MARK: - What migration adds to an older organization file

  func testMigrationAddsOwnerAssistantAndKnowledgeWithoutLosingWork() {
    var legacy = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    legacy.schemaVersion = 2
    legacy.employees.removeAll { ["owner", "mira"].contains($0.id) }
    legacy.knowledge = nil
    let originalTasks = legacy.tasks
    let originalActivity = legacy.activity

    let migrated = LocalOrganizationStore.migrated(legacy, now: Date(timeIntervalSince1970: 200))

    XCTAssertEqual(migrated.schemaVersion, 9)
    XCTAssertEqual(migrated.employee("owner")?.kind, .human)
    XCTAssertEqual(migrated.assistant(for: "owner")?.id, "mira")
    XCTAssertEqual(migrated.tasks, originalTasks)
    XCTAssertTrue(migrated.activity.starts(with: originalActivity))
    XCTAssertFalse(migrated.productBrief.isEmpty)
    XCTAssertEqual(
      migrated.knowledge?.skillDefinitions.count, OrganizationKnowledge.builtInSkills().count)
    XCTAssertEqual(migrated.knowledge?.skillAssignments.count, 12)
    XCTAssertEqual(migrated.knowledge?.connectionDefinitions.count, 3)
    XCTAssertNotNil(migrated.employee("iris"))
    XCTAssertNotNil(migrated.employeeDuty("customer-voice-weekly"))
    XCTAssertFalse(migrated.knowledge?.profile.purpose.isEmpty == true)
    XCTAssertFalse(migrated.knowledge?.profile.product.isEmpty == true)

    let migratedAgain = LocalOrganizationStore.migrated(
      migrated, now: Date(timeIntervalSince1970: 300))
    XCTAssertEqual(migratedAgain.employees.filter { $0.assistantForHumanID == "owner" }.count, 1)
    XCTAssertEqual(
      migratedAgain.knowledge?.skillDefinitions.count, OrganizationKnowledge.builtInSkills().count)
    XCTAssertEqual(migratedAgain.knowledge?.skillAssignments.count, 12)
    XCTAssertEqual(migratedAgain.knowledge?.connectionDefinitions.count, 3)
    XCTAssertEqual(migratedAgain.employees.filter { $0.id == "iris" }.count, 1)
    XCTAssertEqual(
      migratedAgain.employeeDuties.filter { $0.id == "customer-voice-weekly" }.count, 1)
    XCTAssertEqual(migratedAgain.knowledge?.profile, migrated.knowledge?.profile)
  }

  func testVersionThreeKnowledgeDecodesWithoutCatalogueKeys() throws {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.schemaVersion = 3
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let encoded = try encoder.encode(organization)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var knowledge = try XCTUnwrap(json["knowledge"] as? [String: Any])
    knowledge.removeValue(forKey: "skillDefinitions")
    knowledge.removeValue(forKey: "skillAssignments")
    knowledge.removeValue(forKey: "connectionDefinitions")
    knowledge.removeValue(forKey: "employeeDuties")
    knowledge.removeValue(forKey: "dutyOccurrences")
    json["knowledge"] = knowledge
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(OrganizationState.self, from: legacyData)
    XCTAssertTrue(decoded.knowledge?.skillDefinitions.isEmpty == true)
    let migrated = LocalOrganizationStore.migrated(decoded, now: Date(timeIntervalSince1970: 200))
    XCTAssertEqual(migrated.schemaVersion, 9)
    XCTAssertEqual(
      migrated.knowledge?.skillDefinitions.count, OrganizationKnowledge.builtInSkills().count)
  }

  func testKnowledgeWithoutProfileMigratesAndProjectsCompanyMemory() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.name = "Juniper House"
    organization.outcome = "Help solo founders understand the product."

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let encoded = try encoder.encode(organization)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var knowledge = try XCTUnwrap(json["knowledge"] as? [String: Any])
    knowledge.removeValue(forKey: "profile")
    json["knowledge"] = knowledge
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(OrganizationState.self, from: legacyData)
    XCTAssertEqual(decoded.knowledge?.profile, .empty)

    let migrated = LocalOrganizationStore.migrated(decoded, now: Date(timeIntervalSince1970: 200))
    XCTAssertEqual(migrated.schemaVersion, 9)
    XCTAssertEqual(migrated.knowledge?.profile.purpose, organization.goals.first?.title)
    XCTAssertTrue(migrated.knowledge?.profile.product.contains("Product brief") == true)

    let store = LocalOrganizationStore(rootURL: root)
    try await store.save(migrated)
    let company = try String(contentsOf: root.appendingPathComponent("COMPANY.md"), encoding: .utf8)
    XCTAssertTrue(company.contains("# Juniper House"))
    XCTAssertTrue(company.contains("## Current mission"))
    XCTAssertTrue(company.contains("**Mira** · AI"))
  }

  // MARK: - What the owner can teach a named employee

  func testOwnerCanTeachPersistAndAssignSkillWithoutDuplicates() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

    let skillID = try organization.teachSkill(
      name: "Founder interview synthesis",
      category: "Research",
      purpose: "Turn a founder interview into durable product insight.",
      instructions:
        "Separate observed statements from interpretation, group repeated needs, and retain contradictory evidence.",
      successCriteria:
        "The result names themes, supporting observations, contradictions, and unanswered questions.",
      employeeID: "nia",
      now: Date(timeIntervalSince1970: 200)
    )

    XCTAssertEqual(organization.skill(skillID)?.source, .organization)
    XCTAssertEqual(organization.skill(skillID)?.version, 1)
    XCTAssertTrue(organization.assignedSkills(employeeID: "nia").contains { $0.id == skillID })
    XCTAssertEqual(organization.activity.last?.kind, .taught)
    XCTAssertFalse(
      organization.assignSkill(
        skillID: skillID, employeeID: "nia", now: Date(timeIntervalSince1970: 201)))
    XCTAssertTrue(
      organization.assignSkill(
        skillID: skillID, employeeID: "theo", now: Date(timeIntervalSince1970: 202)))

    try await store.save(organization)
    let reopened = try await store.loadOrCreate()
    XCTAssertNotNil(reopened.skill(skillID))
    XCTAssertEqual(reopened.employeesWithSkill(skillID).map(\.id), ["nia", "theo"])

    let catalogue = try String(
      contentsOf: root.appendingPathComponent("SKILLS.md"), encoding: .utf8)
    let niaSkills = try String(
      contentsOf: root.appendingPathComponent("employees/nia/SKILLS.md"), encoding: .utf8)
    XCTAssertTrue(catalogue.contains("Founder interview synthesis"))
    XCTAssertTrue(catalogue.contains("Owner-taught guidance"))
    XCTAssertTrue(niaSkills.contains("Founder interview synthesis"))
  }

  func testTeachingRejectsIncompleteGuidance() {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    XCTAssertThrowsError(
      try organization.teachSkill(
        name: "",
        category: "Research",
        purpose: "Useful purpose",
        instructions: "",
        successCriteria: "Useful result",
        employeeID: "nia"
      )
    ) { error in
      XCTAssertEqual(error as? SkillTeachingError, .incomplete)
    }
  }

  func testAssignedSkillPromptIsIsolatedToTheEmployee() throws {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let skillID = try organization.teachSkill(
      name: "Quote discipline",
      category: "Writing",
      purpose: "Keep quotations short and attributable.",
      instructions: "Never invent a quotation and attach every quotation to its provided source.",
      successCriteria: "Every quotation is attributable and supported by supplied context.",
      employeeID: "theo",
      now: Date(timeIntervalSince1970: 200)
    )
    let root = temporaryDirectory()
    let task = organization.task("draft-first-article")!
    let theoRequest = EmployeeWorkRequest(
      operation: .draft,
      employee: organization.employee("theo")!,
      task: task,
      organizationName: organization.name,
      outcome: organization.outcome,
      context: "",
      skills: organization.assignedSkills(employeeID: "theo"),
      workspaceURL: root
    )
    let niaRequest = EmployeeWorkRequest(
      operation: .research,
      employee: organization.employee("nia")!,
      task: organization.task("research-audience")!,
      organizationName: organization.name,
      outcome: organization.outcome,
      context: "",
      skills: organization.assignedSkills(employeeID: "nia"),
      workspaceURL: root
    )

    let theoPrompt = CodexEmployeeRunner.prompt(for: theoRequest)
    let niaPrompt = CodexEmployeeRunner.prompt(for: niaRequest)
    XCTAssertTrue(theoRequest.skills.contains { $0.id == skillID })
    XCTAssertTrue(theoPrompt.contains("Quote discipline"))
    XCTAssertTrue(theoPrompt.contains("<organizational_skills>"))
    XCTAssertFalse(niaPrompt.contains("Quote discipline"))
  }

  // MARK: - What the assistant leaves on the owner's desk

  func testInterruptedHandoffIsRecordedOnceForTheDay() {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.dayNumber = 1
    organization.workdayStatus = .active

    ExecutiveAssistant.appendInterruptedHandoff(
      to: &organization, now: Date(timeIntervalSince1970: 200))
    ExecutiveAssistant.appendInterruptedHandoff(
      to: &organization, now: Date(timeIntervalSince1970: 300))

    XCTAssertEqual(organization.knowledge?.assistantHandoffs.count, 1)
    XCTAssertEqual(organization.knowledge?.assistantHandoffs.first?.assistantID, "mira")
    XCTAssertEqual(organization.knowledge?.assistantHandoffs.first?.kind, .interruptedDay)
    XCTAssertEqual(organization.activity.last?.actorID, "mira")
  }

  // MARK: - What the runner is allowed to reach

  func testCodexWebSearchFlagRequiresResearchGrant() {
    let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let employee = organization.employee("nia")!
    let task = organization.task("research-audience")!
    let root = temporaryDirectory()
    var request = EmployeeWorkRequest(
      operation: .research,
      employee: employee,
      task: task,
      organizationName: organization.name,
      outcome: organization.outcome,
      productBrief: organization.productBrief,
      context: "",
      capabilityGrants: [],
      workspaceURL: root
    )

    XCTAssertFalse(CodexEmployeeRunner.commandArguments(for: request).contains("--search"))
    request.capabilityGrants = ["web-research"]
    let permitted = CodexEmployeeRunner.commandArguments(for: request)
    XCTAssertEqual(permitted.first, "--search")

    request.operation = .draft
    XCTAssertFalse(CodexEmployeeRunner.commandArguments(for: request).contains("--search"))
  }

  // MARK: - Where employees stand in the office

  func testOfficeRoutesUseAuthoredLanesAndReserveSharedDestinations() {
    let planner = OfficeRoutePlanner()
    let origin = OfficePoint(x: 0.56, y: 0.72)
    let route = planner.route(from: origin, to: .writerDesk)
    let firstSeat = planner.destination(for: .reviewTable, occupancySlot: 0)
    let secondSeat = planner.destination(for: .reviewTable, occupancySlot: 1)

    XCTAssertGreaterThan(route.count, 3)
    XCTAssertEqual(route.first, origin)
    XCTAssertEqual(route.last, planner.destination(for: .writerDesk))
    XCTAssertNotEqual(firstSeat, secondSeat)
    XCTAssertGreaterThan(firstSeat.distance(to: secondSeat), 0.03)
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-tests-\(UUID().uuidString)", isDirectory: true)
  }

}
