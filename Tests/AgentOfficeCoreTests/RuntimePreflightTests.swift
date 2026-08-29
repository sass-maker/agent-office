import Foundation
import XCTest

@testable import AgentOfficeCore

/// Proves the owner-facing preflight gates ask the per-employee runtime policy
/// rather than the legacy organization-wide execution mode.
///
/// The production gates in `AppModel` — `startDay`, `runCustomerVoiceDuty`, and
/// `submitEmployeeOutcome` — used to read `organization.executionMode` directly.
/// Two things went wrong with that, and both are asserted here: an employee
/// whose contract named a healthy runtime was refused because a different
/// organization-wide default was unavailable, and an employee whose contract
/// named a real runtime skipped the checks that exist only to protect real work
/// because the organization-wide default said Demo.
final class RuntimePreflightTests: XCTestCase {
  private let epoch = Date(timeIntervalSince1970: 1_000)

  // MARK: - The contract, not the organization mode, decides what is real

  func testAContractNamingARealRuntimeIsRealWorkThoughTheOrganizationSaysDemo() throws {
    let state = try organization(contracts: ["theo": .localCodex])
    XCTAssertEqual(state.executionMode, .demo, "The fixture must disagree with the contract.")

    let preflight = state.runtimePreflight(for: "theo", health: .localAgents(codex: .available))

    XCTAssertNil(preflight.refusal)
    XCTAssertFalse(preflight.isBlocked)
    XCTAssertTrue(
      preflight.performsRealWork,
      "Theo's contract names Codex, so this run is real work and the checks that protect real work apply to it."
    )
  }

  func testARealRuntimeOnTheContractIsNotBlockedByAnUnavailableOrganizationDefault() throws {
    var state = try organization(contracts: ["theo": .localClaudeCode])
    // The organization-wide default names Codex, and Codex is missing from this
    // Mac. That combination is exactly what the old gate refused on.
    state.executionMode = .localCodex

    let preflight = state.runtimePreflight(
      for: "theo", health: .localAgents(claudeCode: .available))

    XCTAssertNil(
      preflight.refusal,
      "Theo is set to Claude Code and Claude Code works, so nothing about Codex may block him."
    )
    XCTAssertTrue(preflight.performsRealWork)
  }

  // MARK: - Rehearsal stays rehearsal

  func testAnExplicitRehearsalIsNotReportedAsRealWork() throws {
    let state = try organization(contracts: ["theo": .demo])

    let preflight = state.runtimePreflight(for: "theo", health: .localAgents(codex: .available))

    XCTAssertNil(preflight.refusal, "An owner may always rehearse.")
    XCTAssertFalse(
      preflight.performsRealWork,
      "A rehearsal reaches nothing outside the company folder, so real-work preconditions do not apply."
    )
  }

  func testAnOrganizationWideDemoDefaultStillRehearsesWhenNoContractDisagrees() throws {
    let state = try organization(contracts: [:])

    let preflight = state.runtimePreflight(for: "theo", health: .localAgents(codex: .available))

    XCTAssertNil(preflight.refusal)
    XCTAssertFalse(
      preflight.performsRealWork,
      "Without a contract the organization-wide choice still stands in, and it says Demo."
    )
  }

  // MARK: - Refusals carry the policy's own reason

  func testPreflightRefusesWithTheReasonWhenTheContractsRuntimeIsMissing() throws {
    let state = try organization(contracts: ["theo": .localCodex])

    let preflight = state.runtimePreflight(for: "theo", health: .practiceOnly)

    XCTAssertTrue(preflight.isBlocked)
    XCTAssertEqual(preflight.refusal?.contains("Codex"), true)
    XCTAssertEqual(preflight.refusal?.contains("will not swap in a different runtime"), true)
    XCTAssertFalse(preflight.performsRealWork)
  }

  func testAPinnedCommitmentRefusalReachesPreflight() throws {
    var state = try organization(contracts: ["theo": .auto])
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "", now: epoch)
    _ = state.updateEmployeeOutcome(commitmentID, now: epoch) {
      $0.runtime = CommitmentRuntime(
        kind: RuntimeDriverKind.localCodex.rawValue, selectionRule: "fixture")
    }

    let preflight = state.runtimePreflight(
      for: "theo", health: .localAgents(claudeCode: .available), commitmentID: commitmentID)

    XCTAssertEqual(preflight.refusal?.contains("cannot be moved to another runtime"), true)
  }

  // MARK: - A shared mission is resolved employee by employee

  func testTheMissionIsRealWorkWhenAnySingleMemberRunsOnARealRuntime() throws {
    let state = try organization(contracts: ["nia": .demo, "theo": .localCodex, "maya": .demo])

    let preflight = state.runtimePreflight(
      for: OrganizationState.firstContentMissionEmployeeIDs,
      health: .localAgents(codex: .available))

    XCTAssertNil(preflight.refusal)
    XCTAssertTrue(
      preflight.performsRealWork,
      "One real runtime in the mission makes the mission's output real work.")
  }

  func testOneBlockedMemberBlocksTheWholeMissionRegardlessOfRosterOrder() throws {
    // Maya is last in the roster and is the only one who cannot run.
    let state = try organization(
      contracts: ["nia": .localCodex, "theo": .localCodex, "maya": .localClaudeCode])

    let preflight = state.runtimePreflight(
      for: OrganizationState.firstContentMissionEmployeeIDs,
      health: .localAgents(codex: .available))

    XCTAssertEqual(preflight.refusal?.contains("Claude Code"), true)
    XCTAssertTrue(
      preflight.performsRealWork,
      "The members who did resolve are still real, which is what the refusal is protecting.")
  }

  func testTheMissionRosterMatchesTheCommitmentsTheMissionCreates() throws {
    var state = try organization(contracts: [:])

    let outcomeIDs = try state.prepareFirstContentMission(now: epoch)

    XCTAssertEqual(
      outcomeIDs.compactMap { state.employeeOutcome($0)?.assigneeID },
      OrganizationState.firstContentMissionEmployeeIDs,
      "Preflight must never check a roster the mission has stopped using.")
  }

  // MARK: - Fixtures

  /// A seeded organization whose execution mode is Demo, with a working
  /// contract naming a provider for each employee in `contracts`.
  private func organization(
    contracts: [String: EmployeeExecutionProvider]
  ) throws -> OrganizationState {
    var state = LocalOrganizationStore.migrated(.seeded(now: epoch), now: epoch)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    for (employeeID, provider) in contracts.sorted(by: { $0.key < $1.key }) {
      try state.updateWorkingContract(
        employeeID: employeeID,
        role: state.employee(employeeID)?.role ?? "Employee",
        responsibility: state.employee(employeeID)?.responsibility ?? "Work",
        managerID: nil,
        assignedSkillIDs: state.assignedSkills(employeeID: employeeID).map(\.id),
        declaredConnectionIDs: [],
        capabilityGrants: [],
        executionProvider: provider,
        modelName: nil,
        boundaries: AutonomyBoundaries(),
        reviewPolicy: .automaticForLocalWork,
        actorID: "owner",
        reason: "preflight fixture"
      )
    }
    return state
  }
}
