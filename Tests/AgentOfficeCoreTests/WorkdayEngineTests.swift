import XCTest

@testable import AgentOfficeCore

final class WorkdayEngineTests: XCTestCase {
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
    XCTAssertEqual(organization.knowledge?.skillDefinitions.count, 11)
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

  func testCompletedFirstUsePathSurvivesQuitAndReopen() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let engine = WorkdayEngine()
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.name = "Juniper House"
    organization.setupCompleted = true
    organization.dayNumber = 1
    organization.workdayStatus = .active
    organization.knowledge?.productBrief = """
      Juniper House is a local Mac workplace for solo founders who need recurring non-technical work completed. Named AI employees receive explicit outcomes, coordinate through bounded tasks and review, and leave inspectable local artifacts. The product may safely claim local persistence, visible permissions, and resumable workdays.
      """
    organization.employees[organization.employees.firstIndex { $0.id == "nia" }!]
      .capabilityGrants = ["web-research"]

    for step in 0..<10 where organization.workdayStatus == .active {
      organization = await engine.advance(
        organization,
        runner: DeterministicEmployeeRunner(),
        store: store,
        now: Date(timeIntervalSince1970: TimeInterval(200 + step))
      )
    }
    try await store.save(organization)

    let reopened = try await LocalOrganizationStore(rootURL: root).loadOrCreate()
    XCTAssertEqual(reopened.name, "Juniper House")
    XCTAssertEqual(reopened.setupCompleted, true)
    XCTAssertEqual(reopened.workdayStatus, .complete)
    XCTAssertTrue(reopened.tasks.allSatisfy { $0.status == .done })
    XCTAssertTrue(reopened.hasMeaningfulProductBrief)
    XCTAssertTrue(reopened.hasCapability("web-research", employeeID: "nia"))
    XCTAssertEqual(reopened.knowledge?.assistantHandoffs.last?.kind, .endOfDay)
    XCTAssertFalse(reopened.knowledge?.memoryEntries.isEmpty == true)
    XCTAssertFalse(reopened.artifacts.isEmpty)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/mira/IDENTITY.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/nia/MEMORY.md").path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("employees/maya/ARTIFACTS.md").path))
  }

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
    XCTAssertEqual(migrated.knowledge?.skillDefinitions.count, 11)
    XCTAssertEqual(migrated.knowledge?.skillAssignments.count, 12)
    XCTAssertEqual(migrated.knowledge?.connectionDefinitions.count, 3)
    XCTAssertNotNil(migrated.employee("iris"))
    XCTAssertNotNil(migrated.employeeDuty("customer-voice-weekly"))
    XCTAssertFalse(migrated.knowledge?.profile.purpose.isEmpty == true)
    XCTAssertFalse(migrated.knowledge?.profile.product.isEmpty == true)

    let migratedAgain = LocalOrganizationStore.migrated(
      migrated, now: Date(timeIntervalSince1970: 300))
    XCTAssertEqual(migratedAgain.employees.filter { $0.assistantForHumanID == "owner" }.count, 1)
    XCTAssertEqual(migratedAgain.knowledge?.skillDefinitions.count, 11)
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
    XCTAssertEqual(migrated.knowledge?.skillDefinitions.count, 11)
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

  func testAssistantBriefIsGroundedAndInterruptedHandoffIsDeduplicated() {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let brief = ExecutiveAssistant.morningBrief(for: organization)

    XCTAssertEqual(brief?.assistantID, "mira")
    XCTAssertTrue(brief?.summary.contains("No work is being claimed as complete") == true)
    XCTAssertTrue(brief?.decisions.contains(where: { $0.contains("product") }) == true)

    organization.dayNumber = 1
    organization.workdayStatus = .active
    ExecutiveAssistant.appendInterruptedHandoff(
      to: &organization, now: Date(timeIntervalSince1970: 200))
    ExecutiveAssistant.appendInterruptedHandoff(
      to: &organization, now: Date(timeIntervalSince1970: 300))

    XCTAssertEqual(organization.knowledge?.assistantHandoffs.count, 1)
    XCTAssertEqual(organization.knowledge?.assistantHandoffs.first?.assistantID, "mira")
  }

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

  func testGrantedResearchRecordsCapabilitySuccessAndEvidence() async {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.executionMode = .localCodex
    organization.workdayStatus = .active
    organization.employees[organization.employees.firstIndex { $0.id == "nia" }!].capabilityGrants =
      ["web-research"]

    let result = await WorkdayEngine().advance(
      organization,
      runner: ResearchedOutputRunner(),
      store: store,
      now: Date(timeIntervalSince1970: 200)
    )

    XCTAssertEqual(result.knowledge?.capabilityEvents.map(\.kind), [.started, .succeeded])
    XCTAssertEqual(result.artifacts.first?.evidenceBasis, "permitted-web-research")
    XCTAssertEqual(
      result.knowledge?.memoryEntries.first?.sourceArtifactID, result.artifacts.first?.id)
  }

  func testUnavailableAndFailedResearchBecomeAttributedBlockers() async {
    for (runner, expectedKind) in [
      (
        AnyEmployeeRunner { _ in throw CodexRunnerError.unavailable },
        CapabilityEventKind.unavailable
      ),
      (AnyEmployeeRunner { _ in throw TestFailure() }, CapabilityEventKind.failed),
    ] {
      let root = temporaryDirectory()
      defer { try? FileManager.default.removeItem(at: root) }
      let store = LocalOrganizationStore(rootURL: root)
      var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
      organization.executionMode = .localCodex
      organization.workdayStatus = .active
      organization.employees[organization.employees.firstIndex { $0.id == "nia" }!]
        .capabilityGrants = ["web-research"]

      let result = await WorkdayEngine().advance(
        organization,
        runner: runner,
        store: store,
        now: Date(timeIntervalSince1970: 200)
      )

      XCTAssertEqual(result.knowledge?.capabilityEvents.map(\.kind), [.started, expectedKind])
      XCTAssertEqual(result.task("research-audience")?.status, .blocked)
      XCTAssertEqual(result.blockers.count, 1)
      XCTAssertTrue(result.artifacts.isEmpty)
    }
  }

  func testDeterministicTeamCompletesResearchDraftReviewRevisionAndReport() async {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let engine = WorkdayEngine()
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.workdayStatus = .active

    for step in 0..<10 where organization.workdayStatus == .active {
      organization = await engine.advance(
        organization,
        runner: DeterministicEmployeeRunner(),
        store: store,
        now: Date(timeIntervalSince1970: TimeInterval(200 + step))
      )
    }

    XCTAssertEqual(organization.workdayStatus, .complete)
    XCTAssertTrue(organization.tasks.allSatisfy { $0.status == .done })
    XCTAssertEqual(organization.goals.first?.progress, 1)
    XCTAssertEqual(organization.task("draft-first-article")?.revisionCount, 1)
    XCTAssertEqual(organization.artifacts.filter { $0.kind == .draft }.count, 2)
    XCTAssertEqual(organization.artifacts.filter { $0.kind == .review }.count, 2)
    XCTAssertEqual(organization.artifacts.filter { $0.kind == .report }.count, 1)
    XCTAssertTrue(organization.blockers.isEmpty)
    XCTAssertTrue(organization.employees.allSatisfy { $0.status == .resting })

    let knownActors = Set(organization.employees.map(\.id) + ["owner"])
    XCTAssertTrue(organization.activity.allSatisfy { knownActors.contains($0.actorID) })
  }

  func testThirdRevisionRequestStopsAsOwnerBlocker() async {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let engine = WorkdayEngine()
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.workdayStatus = .active

    for step in 0..<12 where organization.blockers.isEmpty {
      organization = await engine.advance(
        organization,
        runner: AlwaysReviseRunner(),
        store: store,
        now: Date(timeIntervalSince1970: TimeInterval(300 + step))
      )
    }

    let draft = organization.task("draft-first-article")
    XCTAssertEqual(draft?.revisionCount, 2)
    XCTAssertEqual(draft?.status, .blocked)
    XCTAssertEqual(organization.blockers.count, 1)
    XCTAssertTrue(organization.blockers[0].detail.contains("2-revision limit"))
    XCTAssertEqual(organization.blockers[0].employeeID, "maya")
  }

  func testRestingOrganizationDoesNotAdvanceWork() async {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let original = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

    let unchanged = await WorkdayEngine().advance(
      original,
      runner: DeterministicEmployeeRunner(),
      store: store,
      now: Date(timeIntervalSince1970: 200)
    )

    XCTAssertEqual(unchanged, original)
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("organization.json").path))
  }

  func testCancelledEmployeeWorkDoesNotCreateAFalseBlocker() async {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.workdayStatus = .active

    let result = await WorkdayEngine().advance(
      organization,
      runner: CancelledRunner(),
      store: store,
      now: Date(timeIntervalSince1970: 200)
    )

    XCTAssertEqual(result, organization)
    XCTAssertTrue(result.blockers.isEmpty)
    XCTAssertEqual(result.task("research-audience")?.status, .ready)
    let persisted = try? await store.loadOrCreate()
    XCTAssertEqual(persisted?.workdayStatus, .active)
    XCTAssertEqual(persisted?.tasks, organization.tasks)
    XCTAssertEqual(persisted?.blockers, organization.blockers)
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-tests-\(UUID().uuidString)", isDirectory: true)
  }
}

private struct AlwaysReviseRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    if request.operation == .review {
      return EmployeeWorkOutput(
        title: "Review",
        summary: "More revision requested.",
        content: "# Revise\n\nPlease try again.",
        verdict: .revise
      )
    }
    return try await DeterministicEmployeeRunner().perform(request)
  }
}

private struct CancelledRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    throw CancellationError()
  }
}

private struct ResearchedOutputRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    EmployeeWorkOutput(
      title: "Researched audience question",
      summary: "Nia found and cited current evidence.",
      content: "# Evidence\n\n- [Current source](https://example.com/source)",
      evidenceBasis: "permitted-web-research"
    )
  }
}

private struct TestFailure: LocalizedError {
  var errorDescription: String? { "The research provider failed." }
}

private struct AnyEmployeeRunner: EmployeeRunner {
  let operation: @Sendable (EmployeeWorkRequest) async throws -> EmployeeWorkOutput

  init(_ operation: @escaping @Sendable (EmployeeWorkRequest) async throws -> EmployeeWorkOutput) {
    self.operation = operation
  }

  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    try await operation(request)
  }
}
