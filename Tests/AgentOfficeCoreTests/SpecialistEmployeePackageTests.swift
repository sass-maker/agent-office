import Foundation
import XCTest

@testable import AgentOfficeCore

/// Rowan is a declarative package, not a hard-coded Reddit engine, so these
/// tests check the package and what hiring it through the generic employment
/// path actually produces.
final class SpecialistEmployeePackageTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000)
  private let packageID = "starter.rowan"

  private func fresh() -> OrganizationState {
    LocalOrganizationStore.migrated(.seeded(now: now), now: now)
  }

  /// An organization saved before Rowan existed: her package and her skills are
  /// simply absent from an otherwise complete company.
  private func organizationWithoutRowan() -> OrganizationState {
    var state = fresh()
    state.knowledge?.employeePackages.removeAll { $0.id == packageID }
    state.knowledge?.skillDefinitions.removeAll { $0.id.contains("reddit") }
    return state
  }

  private func rowan(in state: OrganizationState) throws -> EmployeePackage {
    try XCTUnwrap(state.employeePackage(id: packageID))
  }

  private func hire(into state: inout OrganizationState) throws -> String {
    let journal = OrganizationJournal(
      fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("agent-office-rowan-\(UUID().uuidString).jsonl"))
    defer { try? FileManager.default.removeItem(at: journal.fileURL) }
    let result = try OrganizationCommandProcessor(journal: journal).submit(
      OrganizationCommand(
        actor: .owner(id: "owner"),
        payload: .decideEmployment(.hire(packageID: packageID, version: "1.0.0")),
        idempotencyKey: "hire-rowan",
        issuedAt: now
      ),
      to: &state
    )
    return try XCTUnwrap(result.producedIDs.first)
  }

  // MARK: - Package

  func testRowanIsOneAvailableCandidateInFreshAndMigratedOrganizations() throws {
    for state in [fresh(), LocalOrganizationStore.migrated(organizationWithoutRowan(), now: now)] {
      XCTAssertEqual(state.employeePackages.filter { $0.id == packageID }.count, 1)
      let package = try rowan(in: state)
      XCTAssertEqual(package.version, "1.0.0")
      XCTAssertTrue(package.builtIn)
      XCTAssertEqual(package.role, "Reddit Growth Strategist")
      XCTAssertNil(state.employee("rowan"))
    }
  }

  func testMigrationRunsTwiceWithoutDuplicatingTheCandidate() throws {
    let once = LocalOrganizationStore.migrated(organizationWithoutRowan(), now: now)
    let twice = LocalOrganizationStore.migrated(once, now: now)

    XCTAssertEqual(twice.employeePackages.filter { $0.id == packageID }.count, 1)
    XCTAssertEqual(twice.employeePackages.count, once.employeePackages.count)
  }

  func testMigrationDoesNotHireRowanOrDisturbTheExistingRoster() throws {
    let before = organizationWithoutRowan()
    let after = LocalOrganizationStore.migrated(before, now: now)

    XCTAssertNil(after.employee("rowan"))
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
    // Rowan's skills become available company knowledge; nobody is assigned them.
    XCTAssertNotNil(after.skill("reddit-community-research"))
    XCTAssertTrue(after.knowledge?.skillAssignments.allSatisfy { $0.employeeID != "rowan" } == true)
  }

  func testTheFolioFactsAreDeclaredBeforeHiring() throws {
    let package = try rowan(in: fresh())

    // Read-only research is declared, not granted.
    XCTAssertEqual(package.requiredConnectionIDs, ["web-research"])
    XCTAssertEqual(
      package.skills.map(\.id),
      [
        "reddit-community-research", "rule-aware-reddit-writing", "reddit-growth-review",
        "communication",
      ])
    let reduced = try XCTUnwrap(package.reducedModeDescription)
    XCTAssertTrue(reduced.contains("owner-context-only"))
    XCTAssertTrue(reduced.contains("synthetic practice"))
    let boundary = try XCTUnwrap(package.externalActionBoundary)
    for forbidden in ["posts", "comments", "messages", "signs in", "delegates"] {
      XCTAssertTrue(
        boundary.contains(forbidden), "The folio must name \(forbidden) as unavailable.")
    }
  }

  func testRowanMayNotPublishOrDelegate() throws {
    let package = try rowan(in: fresh())

    XCTAssertFalse(package.boundaries.mayPublish)
    XCTAssertFalse(package.boundaries.mayDelegate)
    // External tools stay possible only so a granted read-only research
    // connection can be permitted later; the grant itself is the owner's.
    XCTAssertTrue(package.boundaries.mayUseExternalTools)
    XCTAssertTrue(package.supportedProviders.contains(package.preferredProvider))
    XCTAssertNoThrow(try EmployeePackageCatalogue.validate(package))
  }

  func testTheSkillsCarryTheirEvidenceAndStoppingRules() throws {
    let state = fresh()

    let research = try XCTUnwrap(state.skill("reddit-community-research"))
    XCTAssertEqual(research.requiredConnectionIDs, ["web-research"])
    XCTAssertTrue(research.instructions.contains("unclear"))
    XCTAssertTrue(research.instructions.contains("owner-context-only"))

    let writing = try XCTUnwrap(state.skill("rule-aware-reddit-writing"))
    XCTAssertTrue(writing.instructions.contains("social proof"))
    XCTAssertTrue(writing.instructions.contains("nothing has been posted"))
    XCTAssertTrue(writing.instructions.contains("re-check"))

    let review = try XCTUnwrap(state.skill("reddit-growth-review"))
    XCTAssertTrue(review.instructions.contains("causality"))
    XCTAssertTrue(review.instructions.contains("owner approval"))
  }

  // MARK: - Hiring

  func testHiringCreatesIdentitySkillsAndAContractThroughTheGenericPath() throws {
    var state = fresh()
    let employeeID = try hire(into: &state)

    XCTAssertEqual(employeeID, "rowan")
    let employee = try XCTUnwrap(state.employee(employeeID))
    XCTAssertEqual(employee.kind, .ai)
    XCTAssertEqual(employee.effectiveEmploymentState, .hired)
    XCTAssertEqual(employee.packageID, packageID)
    XCTAssertEqual(employee.packageVersion, "1.0.0")
    XCTAssertEqual(employee.role, "Reddit Growth Strategist")

    let contract = try XCTUnwrap(state.workingContract(for: employeeID))
    XCTAssertEqual(contract.revision, 1)
    XCTAssertEqual(contract.workspacePath, "employees/rowan")
    XCTAssertEqual(contract.declaredConnectionIDs, ["web-research"])
    XCTAssertEqual(
      state.assignedSkills(employeeID: employeeID).map(\.id).sorted(),
      [
        "communication", "reddit-community-research", "reddit-growth-review",
        "rule-aware-reddit-writing",
      ])
  }

  func testHiringGrantsNoConnection() throws {
    var state = fresh()
    let employeeID = try hire(into: &state)

    XCTAssertEqual(state.employee(employeeID)?.capabilityGrants, [])
    XCTAssertEqual(state.workingContract(for: employeeID)?.capabilityGrants, [])
    XCTAssertFalse(state.hasCapability("web-research", employeeID: employeeID))
    XCTAssertFalse(state.workingContract(for: employeeID)?.boundaries.mayPublish ?? true)
  }

  func testHiringWritesALocalHomeWithNoGrantedAuthority() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-rowan-home-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    var state = fresh()
    _ = try hire(into: &state)

    try await store.save(state)
    let contract = try String(
      contentsOf: root.appendingPathComponent("employees/rowan/WORKING_CONTRACT.md"),
      encoding: .utf8)
    let catalogue = try String(
      contentsOf: root.appendingPathComponent("EMPLOYEE_PACKAGES.md"), encoding: .utf8)

    XCTAssertTrue(contract.contains("starter.rowan"))
    XCTAssertTrue(contract.contains("web-research"))
    XCTAssertTrue(catalogue.contains("Rowan"))
    XCTAssertTrue(catalogue.contains("Never posts, comments, messages"))
  }
}
