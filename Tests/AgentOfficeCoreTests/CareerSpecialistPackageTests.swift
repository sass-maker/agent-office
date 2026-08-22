import Foundation
import XCTest

@testable import AgentOfficeCore

/// Asha is a declarative package, not a hard-coded job-application engine, so
/// these tests check the package and what hiring it through the generic
/// employment path actually produces.
///
/// The boundary tests matter most: this is a local POC, and nothing here may
/// leave an owner believing an application was sent.
final class CareerSpecialistPackageTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000)
  private let packageID = "starter.asha"
  private let skillIDs = [
    "job-fit-research", "truthful-application-writing", "application-outcome-review",
  ]

  private func fresh() -> OrganizationState {
    LocalOrganizationStore.migrated(.seeded(now: now), now: now)
  }

  /// An organization saved before Asha existed: her package and her skills are
  /// simply absent from an otherwise complete company.
  private func organizationWithoutAsha() -> OrganizationState {
    var state = fresh()
    state.knowledge?.employeePackages.removeAll { $0.id == packageID }
    state.knowledge?.skillDefinitions.removeAll { skillIDs.contains($0.id) }
    return state
  }

  private func asha(in state: OrganizationState) throws -> EmployeePackage {
    try XCTUnwrap(state.employeePackage(id: packageID))
  }

  private func hire(into state: inout OrganizationState) throws -> String {
    let journal = OrganizationJournal(
      fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("agent-office-asha-\(UUID().uuidString).jsonl"))
    defer { try? FileManager.default.removeItem(at: journal.fileURL) }
    let result = try OrganizationCommandProcessor(journal: journal).submit(
      OrganizationCommand(
        actor: .owner(id: "owner"),
        payload: .decideEmployment(.hire(packageID: packageID, version: "1.0.0")),
        idempotencyKey: "hire-asha",
        issuedAt: now
      ),
      to: &state
    )
    return try XCTUnwrap(result.producedIDs.first)
  }

  // MARK: - Package

  func testAshaIsOneAvailableCandidateInFreshAndMigratedOrganizations() throws {
    for state in [fresh(), LocalOrganizationStore.migrated(organizationWithoutAsha(), now: now)] {
      XCTAssertEqual(state.employeePackages.filter { $0.id == packageID }.count, 1)
      let package = try asha(in: state)
      XCTAssertEqual(package.version, "1.0.0")
      XCTAssertTrue(package.builtIn)
      XCTAssertEqual(package.role, "Career Application Specialist")
      XCTAssertNil(state.employee("asha"))
    }
  }

  func testMigrationRunsTwiceWithoutDuplicatingTheCandidate() throws {
    let once = LocalOrganizationStore.migrated(organizationWithoutAsha(), now: now)
    let twice = LocalOrganizationStore.migrated(once, now: now)

    XCTAssertEqual(twice.employeePackages.filter { $0.id == packageID }.count, 1)
    XCTAssertEqual(twice.employeePackages.count, once.employeePackages.count)
    for skillID in skillIDs {
      XCTAssertEqual(twice.knowledge?.skillDefinitions.filter { $0.id == skillID }.count, 1)
    }
  }

  func testMigrationDoesNotHireAshaOrDisturbTheExistingRoster() throws {
    let before = organizationWithoutAsha()
    let after = LocalOrganizationStore.migrated(before, now: now)

    XCTAssertNil(after.employee("asha"))
    XCTAssertEqual(after.employees.map(\.id), before.employees.map(\.id))
    XCTAssertEqual(
      after.employees.map(\.effectiveEmploymentState),
      before.employees.map(\.effectiveEmploymentState)
    )
    XCTAssertEqual(
      after.workingContracts.map(\.employeeID), before.workingContracts.map(\.employeeID))
    XCTAssertEqual(after.employeeOutcomes.count, before.employeeOutcomes.count)
    XCTAssertEqual(after.tasks.count, before.tasks.count)
    XCTAssertEqual(after.artifacts.count, before.artifacts.count)
    XCTAssertEqual(after.supervisionEvents.count, before.supervisionEvents.count)
    // Her skills become available company knowledge; nobody is assigned them.
    for skillID in skillIDs { XCTAssertNotNil(after.skill(skillID)) }
    XCTAssertTrue(after.knowledge?.skillAssignments.allSatisfy { $0.employeeID != "asha" } == true)
  }

  func testTheFolioStatesNormalAndReducedModeBeforeHiring() throws {
    let package = try asha(in: fresh())

    // Read-only research is declared, which is what the folio's normal mode is
    // built from. Declaring is not granting.
    XCTAssertEqual(package.requiredConnectionIDs, ["web-research"])
    XCTAssertEqual(package.skills.map(\.id), skillIDs + ["communication"])

    let reduced = try XCTUnwrap(package.reducedModeDescription)
    XCTAssertTrue(reduced.contains("owner-context-only"))
    XCTAssertTrue(reduced.contains("synthetic practice"))
    // The reduced mode must refuse the three current-fact claims it cannot back.
    XCTAssertTrue(reduced.contains("still open"))
    XCTAssertTrue(reduced.contains("market pays"))
    XCTAssertTrue(reduced.contains("applied to"))
  }

  func testTheFolioNamesEveryExternalActionThatStaysWithTheOwner() throws {
    let boundary = try XCTUnwrap(try asha(in: fresh()).externalActionBoundary)

    for forbidden in [
      "submits an application", "uploads a resume", "signs in", "fills a portal",
      "screening question", "legal attestation", "CAPTCHA", "messages a recruiter", "delegates",
      "controls any account",
    ] {
      XCTAssertTrue(
        boundary.contains(forbidden),
        "The folio must name \(forbidden) as unavailable before hiring.")
    }
  }

  func testAshaMayNotPublishOrDelegate() throws {
    let package = try asha(in: fresh())

    XCTAssertFalse(package.boundaries.mayPublish)
    XCTAssertFalse(package.boundaries.mayDelegate)
    // External tools stay possible only so a granted read-only research
    // connection can be permitted later; the grant itself is the owner's.
    XCTAssertTrue(package.boundaries.mayUseExternalTools)
    XCTAssertEqual(package.boundaries.maximumRevisions, 2)
    XCTAssertTrue(package.supportedProviders.contains(package.preferredProvider))
    XCTAssertNoThrow(try EmployeePackageCatalogue.validate(package))
  }

  func testThePackageDeclaresNoConnectionBeyondReadOnlyResearch() throws {
    let package = try asha(in: fresh())
    let declared = Set(
      package.requiredConnectionIDs + package.skills.flatMap(\.requiredConnectionIDs))

    XCTAssertEqual(declared, ["web-research"])
  }

  // MARK: - Skills

  func testTheSkillsCarryTheirEvidenceAndStoppingRules() throws {
    let state = fresh()

    let research = try XCTUnwrap(state.skill("job-fit-research"))
    XCTAssertEqual(research.requiredConnectionIDs, ["web-research"])
    XCTAssertTrue(research.instructions.contains("unclear"))
    XCTAssertTrue(research.instructions.contains("owner-context-only"))
    XCTAssertTrue(research.instructions.contains("work authorization"))
    XCTAssertTrue(research.successCriteria.contains("apply, review, ask, skip, or exclude"))

    let writing = try XCTUnwrap(state.skill("truthful-application-writing"))
    XCTAssertTrue(writing.instructions.contains("may not add, upgrade, or soften a fact"))
    XCTAssertTrue(writing.instructions.contains("nothing was submitted"))
    XCTAssertTrue(writing.instructions.contains("no file was uploaded"))

    let review = try XCTUnwrap(state.skill("application-outcome-review"))
    XCTAssertTrue(review.instructions.contains("silence is not a rejection"))
    XCTAssertTrue(review.instructions.contains("owner approval"))
  }

  /// The writing skill decides how the artifact talks about itself, so it must
  /// forbid the words that would make a prepared packet read as a sent one.
  func testTheWritingSkillForbidsClaimingTheApplicationHappened() throws {
    let writing = try XCTUnwrap(fresh().skill("truthful-application-writing"))

    for verb in ["submitted", "applied", "uploaded", "sent"] {
      XCTAssertTrue(
        writing.instructions.contains(verb),
        "The instructions must name \(verb) as a word the employee may not use about itself.")
    }
    XCTAssertTrue(writing.instructions.contains("never use"))
  }

  // MARK: - Hiring

  func testHiringCreatesIdentitySkillsAndAContractThroughTheGenericPath() throws {
    var state = fresh()
    let employeeID = try hire(into: &state)

    XCTAssertEqual(employeeID, "asha")
    let employee = try XCTUnwrap(state.employee(employeeID))
    XCTAssertEqual(employee.kind, .ai)
    XCTAssertEqual(employee.effectiveEmploymentState, .hired)
    XCTAssertEqual(employee.packageID, packageID)
    XCTAssertEqual(employee.packageVersion, "1.0.0")
    XCTAssertEqual(employee.role, "Career Application Specialist")

    let contract = try XCTUnwrap(state.workingContract(for: employeeID))
    XCTAssertEqual(contract.revision, 1)
    XCTAssertEqual(contract.workspacePath, "employees/asha")
    XCTAssertEqual(contract.declaredConnectionIDs, ["web-research"])
    XCTAssertEqual(
      state.assignedSkills(employeeID: employeeID).map(\.id).sorted(),
      (skillIDs + ["communication"]).sorted())
  }

  func testHiringGrantsNoConnection() throws {
    var state = fresh()
    let employeeID = try hire(into: &state)

    XCTAssertEqual(state.employee(employeeID)?.capabilityGrants, [])
    XCTAssertEqual(state.workingContract(for: employeeID)?.capabilityGrants, [])
    XCTAssertFalse(state.hasCapability("web-research", employeeID: employeeID))
    XCTAssertFalse(state.workingContract(for: employeeID)?.boundaries.mayPublish ?? true)
    XCTAssertFalse(state.workingContract(for: employeeID)?.boundaries.mayDelegate ?? true)
  }

  func testHiringWritesALocalHomeThatRecordsTheBoundary() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-asha-home-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var state = fresh()
    _ = try hire(into: &state)

    try await store.save(state)
    let contract = try String(
      contentsOf: root.appendingPathComponent("employees/asha/WORKING_CONTRACT.md"),
      encoding: .utf8)
    let catalogue = try String(
      contentsOf: root.appendingPathComponent("EMPLOYEE_PACKAGES.md"), encoding: .utf8)

    XCTAssertTrue(contract.contains("starter.asha"))
    XCTAssertTrue(contract.contains("web-research"))
    XCTAssertTrue(contract.contains("Publishing allowed: No"))
    XCTAssertTrue(catalogue.contains("Asha"))
    XCTAssertTrue(catalogue.contains("Never submits an application"))
  }

  /// Hiring must not widen what the runtime broker will allow. Asha's declared
  /// research connection is only a declaration until the owner grants it.
  func testTheBrokerRefusesResearchUntilTheOwnerGrantsIt() async throws {
    var state = fresh()
    let employeeID = try hire(into: &state)
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: employeeID, outcome: "Assess the platform engineer posting", context: "",
      now: now)
    let broker = RuntimeCapabilityBroker()

    let authorized = await broker.authorizedCapabilities(
      employeeID: employeeID, commitmentID: commitmentID, organization: state)

    XCTAssertTrue(
      authorized.isEmpty,
      "Hiring declared web research; it did not grant it, so nothing is authorized yet.")
  }
}
