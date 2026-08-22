import XCTest

@testable import AgentOfficeCore

final class EmploymentTests: XCTestCase {
  func testFreshOrganizationStartsWithCandidatesAndHiringMaterializesContract() throws {
    let now = Date(timeIntervalSince1970: 100)
    var organization = LocalOrganizationStore.migrated(
      .seeded(now: now, hiredStarterTeam: false), now: now)

    XCTAssertEqual(organization.employee("nia")?.effectiveEmploymentState, .candidate)
    XCTAssertNil(organization.workingContract(for: "nia"))
    XCTAssertTrue(organization.managementInbox.contains { $0.id == "candidate:nia" })

    let employeeID = try organization.hireEmployee(
      packageID: "starter.nia", actorID: "owner", now: now)

    XCTAssertEqual(employeeID, "nia")
    XCTAssertEqual(organization.employee("nia")?.effectiveEmploymentState, .hired)
    XCTAssertEqual(organization.workingContract(for: "nia")?.packageID, "starter.nia")
    XCTAssertEqual(
      organization.workingContract(for: "nia")?.assignedSkillIDs.sorted(),
      ["audience-research", "communication"])
    XCTAssertTrue(organization.workingContract(for: "nia")?.capabilityGrants.isEmpty == true)
    XCTAssertTrue(
      organization.supervisionEvents.contains { $0.kind == .hire && $0.employeeID == "nia" })
  }

  func testLegacyMigrationIsIdempotentAndPreservesHiredIdentity() {
    let now = Date(timeIntervalSince1970: 100)
    var legacy = OrganizationState.seeded(now: now)
    legacy.schemaVersion = 8
    for index in legacy.employees.indices {
      legacy.employees[index].employmentState = nil
      legacy.employees[index].packageID = nil
      legacy.employees[index].packageVersion = nil
    }

    let migrated = LocalOrganizationStore.migrated(legacy, now: now)
    let migratedAgain = LocalOrganizationStore.migrated(
      migrated, now: Date(timeIntervalSince1970: 200))

    XCTAssertEqual(migrated.schemaVersion, 9)
    XCTAssertTrue(migrated.employees.allSatisfy { $0.effectiveEmploymentState == .hired })
    XCTAssertEqual(migrated.workingContracts.count, 5)
    XCTAssertEqual(migratedAgain.workingContracts.count, 5)
    // The seven stable versioned identities, asserted as identities rather than
    // as a count that every new built-in package would have to come back and
    // edit.
    XCTAssertEqual(
      migratedAgain.employeePackages.map(\.versionedID).sorted(),
      [
        "starter.asha@1.0.0", "starter.iris@1.0.0", "starter.maya@1.0.0", "starter.mira@1.0.0",
        "starter.nia@1.0.0", "starter.rowan@1.0.0", "starter.theo@1.0.0",
      ])
    XCTAssertEqual(migratedAgain.employee("mira")?.id, "mira")
  }

  func testPackageValidationRejectsSecretsExecutablesAndDuplicates() throws {
    let valid = EmployeePackageCatalogue.starterPackages().first!
    try EmployeePackageCatalogue.validate(valid)

    let secretData = Data(
      """
      {"id":"safe.agent","version":"1.0.0","creator":"Local","name":"Safe","role":"Analyst","responsibility":"Analyze","avatarColor":"FFFFFF","skills":[],"requiredConnectionIDs":[],"supportedProviders":["demo"],"preferredProvider":"demo","boundaries":{"mayReadOrganizationFiles":true,"mayWriteEmployeeHome":true,"mayDelegate":false,"mayUseExternalTools":false,"mayPublish":false,"maximumRevisions":1},"builtIn":false,"apiToken":"sk-example"}
      """.utf8)
    XCTAssertThrowsError(try EmployeePackageCatalogue.decodeAndValidate(secretData)) {
      guard case .unsafeSecret = $0 as? EmployeePackageError else {
        return XCTFail("Expected unsafe secret, got \($0)")
      }
    }

    var executable = valid
    executable.reducedModeDescription = "/tmp/run.command"
    let data = try JSONEncoder().encode(executable)
    XCTAssertThrowsError(try EmployeePackageCatalogue.decodeAndValidate(data)) {
      guard case .executableReference = $0 as? EmployeePackageError else {
        return XCTFail("Expected executable reference, got \($0)")
      }
    }

    var organization = OrganizationState.seeded()
    organization.knowledge?.employeePackages = []
    try organization.installEmployeePackage(valid)
    XCTAssertThrowsError(try organization.installEmployeePackage(valid)) {
      XCTAssertEqual($0 as? EmployeePackageError, .duplicateVersion)
    }
  }

  func testPauseResumeRetirePreserveHistoryAndBlockActiveRetirement() throws {
    let now = Date(timeIntervalSince1970: 100)
    var organization = LocalOrganizationStore.migrated(.seeded(now: now), now: now)
    let outcomeID = try organization.createEmployeeOutcome(
      employeeID: "theo", outcome: "Write a note", context: "", now: now)
    _ = organization.updateEmployeeOutcome(outcomeID, now: now) { $0.status = .working }

    XCTAssertThrowsError(try organization.retireEmployee("theo", now: now)) {
      XCTAssertEqual($0 as? EmploymentError, .activeWork)
    }
    try organization.pauseEmployee("theo", now: now)
    XCTAssertEqual(organization.employee("theo")?.effectiveEmploymentState, .paused)
    XCTAssertEqual(organization.employeeOutcome(outcomeID)?.status, .queued)
    try organization.resumeEmployee("theo", now: now)
    _ = organization.cancelEmployeeOutcome(outcomeID, now: now)
    try organization.retireEmployee("theo", now: now)

    XCTAssertEqual(organization.employee("theo")?.effectiveEmploymentState, .retired)
    XCTAssertNotNil(organization.employeeOutcome(outcomeID))
    XCTAssertNotNil(organization.workingContract(for: "theo"))
  }

  func testWorkingContractProjectionContainsIdentifiersButNoCredentials() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "AgentOfficeEmploymentTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let organization = LocalOrganizationStore.migrated(
      .seeded(now: Date(timeIntervalSince1970: 100)))

    try await store.save(organization)
    let contract = try String(
      contentsOf: root.appendingPathComponent("employees/nia/WORKING_CONTRACT.md"), encoding: .utf8)

    XCTAssertTrue(contract.contains("starter.nia"))
    XCTAssertTrue(contract.contains("web-research"))
    XCTAssertTrue(contract.contains("never contains credential values"))
    XCTAssertFalse(contract.localizedCaseInsensitiveContains("api token"))
  }

  func testUpdateWorkingContractRecordsChangesAndSyncsEmployee() throws {
    let now = Date(timeIntervalSince1970: 100)
    var organization = LocalOrganizationStore.migrated(.seeded(now: now), now: now)
    _ = try organization.hireEmployee(packageID: "starter.mira", actorID: "owner", now: now)

    try organization.updateWorkingContract(
      employeeID: "mira",
      role: "Chief Briefing Officer",
      responsibility: "Surface every decision clearly.",
      managerID: "maya",
      assignedSkillIDs: ["executive-briefing", "communication"],
      declaredConnectionIDs: [],
      capabilityGrants: ["web-research"],
      executionProvider: .localCodex,
      modelName: "test-model",
      boundaries: AutonomyBoundaries(
        mayReadOrganizationFiles: true, mayWriteEmployeeHome: true, mayDelegate: true,
        mayUseExternalTools: false, mayPublish: false, maximumRevisions: 3),
      reviewPolicy: .whenAuthorityChanges,
      actorID: "owner",
      reason: "Expanded authority for research season.",
      now: now
    )

    let contract = organization.workingContract(for: "mira")
    XCTAssertEqual(contract?.revision, 2)
    XCTAssertEqual(contract?.role, "Chief Briefing Officer")
    XCTAssertEqual(contract?.managerID, "maya")
    XCTAssertEqual(contract?.capabilityGrants, ["web-research"])
    XCTAssertEqual(contract?.modelName, "test-model")
    XCTAssertEqual(contract?.reviewPolicy, .whenAuthorityChanges)
    XCTAssertEqual(organization.employee("mira")?.role, "Chief Briefing Officer")
    XCTAssertTrue(
      organization.contractChanges.contains { $0.field == "role" && $0.employeeID == "mira" })
  }

  func testApplyPackageUpdateUpdatesVersionAndConnections() throws {
    let now = Date(timeIntervalSince1970: 100)
    var organization = LocalOrganizationStore.migrated(.seeded(now: now), now: now)
    _ = try organization.hireEmployee(packageID: "starter.theo", actorID: "owner", now: now)

    var updatedPackage = organization.employeePackage(id: "starter.theo")!
    updatedPackage.version = "1.1.0"
    updatedPackage.requiredConnectionIDs = ["web-research"]
    try organization.installEmployeePackage(updatedPackage)

    try organization.applyPackageUpdate(
      employeeID: "theo", packageID: "starter.theo", version: "1.1.0", actorID: "owner", now: now)

    XCTAssertEqual(organization.employee("theo")?.packageVersion, "1.1.0")
    XCTAssertEqual(organization.workingContract(for: "theo")?.packageVersion, "1.1.0")
    XCTAssertEqual(organization.workingContract(for: "theo")?.revision, 2)
    XCTAssertEqual(
      organization.workingContract(for: "theo")?.declaredConnectionIDs, ["web-research"])
  }

  func testRemoveEmployeePackageFailsWhenInUse() throws {
    let now = Date(timeIntervalSince1970: 100)
    var organization = LocalOrganizationStore.migrated(.seeded(now: now), now: now)
    _ = try organization.hireEmployee(packageID: "starter.iris", actorID: "owner", now: now)

    XCTAssertThrowsError(
      try organization.removeEmployeePackage(id: "starter.iris", version: "1.0.0")
    ) {
      XCTAssertEqual($0 as? EmployeePackageError, .packageInUse)
    }
  }

  func testEmploymentAndPackageErrorDescriptionsAreNonEmpty() {
    for error in EmployeePackageError.allCases {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
    for error in EmploymentError.allCases {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
  }
}

extension EmployeePackageError: CaseIterable {
  public static var allCases: [EmployeePackageError] {
    [
      .malformed, .invalidIdentifier, .invalidVersion, .incompleteIdentity, .missingSkills,
      .invalidSkill("bad"), .unsupportedProvider, .unsafeSecret("key"),
      .executableReference("run.sh"), .duplicateVersion, .packageInUse, .missingPackage,
    ]
  }
}

extension EmploymentError: CaseIterable {
  public static var allCases: [EmploymentError] {
    [
      .missingPackage, .missingEmployee, .humanMember, .notHired, .alreadyEmployed, .activeWork,
      .incompatiblePackage,
    ]
  }
}
