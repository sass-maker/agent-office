import Foundation
import XCTest

@testable import AgentOfficeCore

/// Proves the owner-facing screens describe the runtime the work will actually
/// run on, rather than the legacy organization-wide execution mode.
///
/// The gates migrated in the preceding slice resolve a runtime per employee.
/// The screens did not, which left a dead end: with the organization on Demo and
/// Nia's contract on Codex, `startDay` asks for read-only web research and
/// refuses without it, while the home screen showed no row for granting it. The
/// same mismatch ran the other way — a rehearsal that never reaches the network
/// was asked to hand over a web key.
final class RuntimeDispositionTests: XCTestCase {
  private let epoch = Date(timeIntervalSince1970: 1_000)

  // MARK: - The dead end: asking for the web key exactly when the gate needs it

  func testTheWebKeyIsAskedForWhenTheContractMakesResearchRealThoughTheOrganizationSaysDemo()
    throws
  {
    let state = try organization(contracts: ["nia": .localCodex])
    XCTAssertEqual(state.executionMode, .demo, "The fixture must disagree with the contract.")

    let disposition = state.runtimeDisposition(
      for: "nia", health: .localAgents(codex: .available))

    XCTAssertTrue(
      disposition.needsWebResearchGrant(granted: false),
      "Nia's contract names Codex, so startDay refuses without the grant and the owner must be shown a way to give it."
    )
  }

  func testTheWebKeyIsNotAskedForWhenTheContractIsARehearsal() throws {
    var state = try organization(contracts: ["nia": .demo])
    // The organization-wide default is the one the old row read.
    state.executionMode = .localCodex

    let disposition = state.runtimeDisposition(
      for: "nia", health: .localAgents(codex: .available))

    XCTAssertFalse(
      disposition.needsWebResearchGrant(granted: false),
      "A rehearsal never reaches the network, so asking the owner for a web key is asking for nothing."
    )
  }

  func testTheWebKeyIsNotAskedForWhenNoRuntimeCanRun() throws {
    let state = try organization(contracts: ["nia": .localCodex])

    let disposition = state.runtimeDisposition(for: "nia", health: .practiceOnly)

    XCTAssertTrue(disposition.isBlocked)
    XCTAssertFalse(
      disposition.needsWebResearchGrant(granted: false),
      "Granting a key cannot supply a missing runtime, so the row would be a request that resolves nothing."
    )
  }

  func testTheWebKeyIsNoLongerAskedForOnceItIsGranted() throws {
    let state = try organization(contracts: ["nia": .localCodex])

    let disposition = state.runtimeDisposition(
      for: "nia", health: .localAgents(codex: .available))

    XCTAssertFalse(disposition.needsWebResearchGrant(granted: true))
  }

  /// The row and the gate must never disagree, whatever the contract says.
  func testTheScreenAsksForTheWebKeyInExactlyTheCasesTheGateRefusesWithout() throws {
    let providers: [EmployeeExecutionProvider] = [.demo, .localCodex, .localClaudeCode, .auto]
    let healths: [RuntimeHealthSnapshot] = [
      .practiceOnly, .localAgents(codex: .available),
      .localAgents(codex: .available, claudeCode: .available),
    ]
    for provider in providers {
      for health in healths {
        for granted in [true, false] {
          let state = try organization(contracts: ["nia": provider])
          let gate = state.runtimePreflight(for: "nia", health: health)
          let screen = state.runtimeDisposition(for: "nia", health: health)

          XCTAssertEqual(
            screen.needsWebResearchGrant(granted: granted),
            gate.performsRealWork && !granted,
            "\(provider.rawValue) with granted=\(granted): the screen must ask for the key exactly when the gate refuses without it."
          )
          XCTAssertEqual(screen.refusalReason, gate.refusal)
          XCTAssertEqual(screen.performsRealWork, gate.performsRealWork)
        }
      }
    }
  }

  // MARK: - Naming the runtime an employee actually works on

  func testTheAssignmentChipNamesClaudeCodeWhichTheOrganizationModeCouldNotExpress() throws {
    let state = try organization(contracts: ["theo": .localClaudeCode])

    let notice = state.runtimeDisposition(
      for: "theo", health: .localAgents(claudeCode: .available)
    ).assignmentNotice(employeeName: "Theo")

    XCTAssertEqual(notice.standing, .real)
    XCTAssertEqual(
      notice.title, "Work with Claude Code",
      "The two-valued organization mode had no value that could say this.")
  }

  func testTheAssignmentChipStillCallsAnOwnersRehearsalARehearsal() throws {
    var state = try organization(contracts: ["theo": .demo])
    state.executionMode = .localCodex

    let notice = state.runtimeDisposition(
      for: "theo", health: .localAgents(codex: .available)
    ).assignmentNotice(employeeName: "Theo")

    XCTAssertEqual(notice.standing, .rehearsal)
    XCTAssertEqual(notice.title, "Practice with the Demo team")
  }

  func testTheAssignmentChipReportsTheRefusalRatherThanNamingARuntime() throws {
    let state = try organization(contracts: ["theo": .localCodex])

    let disposition = state.runtimeDisposition(for: "theo", health: .practiceOnly)
    let notice = disposition.assignmentNotice(employeeName: "Theo")

    XCTAssertEqual(notice.standing, .blocked)
    XCTAssertEqual(notice.detail, disposition.refusalReason)
    XCTAssertTrue(notice.title.contains("Theo"))
  }

  func testTheResearchNoticeCallsAContractDrivenRunRealThoughTheOrganizationSaysDemo() throws {
    let state = try organization(contracts: ["nia": .localCodex])

    let notice = state.runtimeDisposition(
      for: "nia", health: .localAgents(codex: .available)
    ).researchNotice(employeeName: "Nia", webResearchGranted: false)

    XCTAssertEqual(
      notice.standing, .real,
      "The organization mode said Demo, so this line used to promise a rehearsal for a real run.")
    XCTAssertTrue(notice.detail.contains("Codex"), notice.detail)
  }

  func testTheResearchNoticeMarksAnOwnersRehearsalAsARehearsal() throws {
    var state = try organization(contracts: ["nia": .demo])
    state.executionMode = .localCodex

    let notice = state.runtimeDisposition(
      for: "nia", health: .localAgents(codex: .available)
    ).researchNotice(employeeName: "Nia", webResearchGranted: true)

    XCTAssertEqual(notice.standing, .rehearsal)
    XCTAssertEqual(notice.title, "Practice run — no web")
  }

  func testTheResearchNoticeSaysWhyNothingCanRunWhenTheRuntimeIsMissing() throws {
    let state = try organization(contracts: ["nia": .localClaudeCode])

    let disposition = state.runtimeDisposition(for: "nia", health: .practiceOnly)
    let notice = disposition.researchNotice(employeeName: "Nia", webResearchGranted: true)

    XCTAssertEqual(notice.standing, .blocked)
    XCTAssertEqual(notice.detail, disposition.refusalReason)
  }

  // MARK: - Remedies that can actually change the resolver's answer

  func testABlockedAssignmentIsOfferedRemediesThatCanActuallyUnblockIt() throws {
    var state = try organization(contracts: ["nia": .localClaudeCode])

    let remedies = state.runtimeDisposition(for: "nia", health: .practiceOnly)
      .waitingRemedies(webResearchGranted: true)

    XCTAssertEqual(remedies.count, 2)
    guard case .recheckRuntimeInstallations(let reason) = remedies.first else {
      return XCTFail("The refusal names a runtime to install, so re-probing comes first.")
    }
    XCTAssertTrue(reason.contains("Claude Code"), reason)
    XCTAssertEqual(remedies.last, .rehearseWholeOrganization)

    // The escape hatch is offerable because it works, and it works by rewriting
    // contracts — not by writing the organization-wide field, which the
    // resolver never reads for an employee who has a contract.
    state.executionMode = .demo
    XCTAssertTrue(
      state.runtimeDisposition(for: "nia", health: .practiceOnly).isBlocked,
      "The organization-wide field alone changes nothing for a contracted employee.")
    state.applyExecutionProvider(.demo, reason: "Moved everyone to a practice run.")
    XCTAssertFalse(state.runtimeDisposition(for: "nia", health: .practiceOnly).isBlocked)
  }

  func testACommitmentPinnedToALostRuntimeIsNotOfferedARehearsalItCannotUse() throws {
    var state = try organization(contracts: ["theo": .auto])
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "", now: epoch)
    _ = state.updateEmployeeOutcome(commitmentID, now: epoch) {
      $0.runtime = CommitmentRuntime(
        kind: RuntimeDriverKind.localCodex.rawValue, selectionRule: "fixture")
    }

    let remedies = state.runtimeDisposition(
      for: "theo", health: .localAgents(claudeCode: .available), commitmentID: commitmentID
    ).waitingRemedies(webResearchGranted: true)

    XCTAssertFalse(
      remedies.contains(.rehearseWholeOrganization),
      "An open commitment stays pinned to the runtime it started on however the contracts are rewritten, so offering a rehearsal here would be a button that cannot work."
    )
    // And the pin really does survive the rewrite the button would perform.
    state.applyExecutionProvider(.demo, reason: "Moved everyone to a practice run.")
    XCTAssertTrue(
      state.runtimeDisposition(
        for: "theo", health: .localAgents(claudeCode: .available), commitmentID: commitmentID
      ).isBlocked)
  }

  func testEveryEmployedPersonHasAContractSoTheOrganizationWideModeIsNeverTheirChoice() throws {
    var state = LocalOrganizationStore.migrated(.seeded(now: epoch), now: epoch)
    let hiredID = try state.hireEmployee(packageID: "starter.mira", now: epoch)

    for employee in state.employees
    where employee.kind == .ai && employee.effectiveEmploymentState == .hired {
      XCTAssertNotNil(
        state.workingContract(for: employee.id),
        "\(employee.id) is employed without a contract, which would make the organization-wide mode their operative runtime choice."
      )
    }
    XCTAssertNotNil(state.workingContract(for: hiredID))
  }

  func testAWaitingRealRunIsOfferedTheWebKey() throws {
    let state = try organization(contracts: ["nia": .localCodex])

    let remedies = state.runtimeDisposition(for: "nia", health: .localAgents(codex: .available))
      .waitingRemedies(webResearchGranted: false)

    XCTAssertEqual(remedies, [.grantWebResearch])
  }

  func testARehearsalIsOfferedARetryRatherThanAKeyItDoesNotNeed() throws {
    var state = try organization(contracts: ["nia": .demo])
    state.executionMode = .localCodex

    let remedies = state.runtimeDisposition(for: "nia", health: .localAgents(codex: .available))
      .waitingRemedies(webResearchGranted: false)

    XCTAssertEqual(
      remedies, [.retry],
      "The old card offered the web key here purely because the organization-wide mode said Codex.")
  }

  // MARK: - The commitment pin reaches the screen too

  func testAPinnedCommitmentRefusalReachesTheScreen() throws {
    var state = try organization(contracts: ["theo": .auto])
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "", now: epoch)
    _ = state.updateEmployeeOutcome(commitmentID, now: epoch) {
      $0.runtime = CommitmentRuntime(
        kind: RuntimeDriverKind.localCodex.rawValue, selectionRule: "fixture")
    }

    let disposition = state.runtimeDisposition(
      for: "theo", health: .localAgents(claudeCode: .available), commitmentID: commitmentID)

    XCTAssertEqual(
      disposition.refusalReason?.contains("cannot be moved to another runtime"), true)
    XCTAssertEqual(disposition.assignmentNotice(employeeName: "Theo").standing, .blocked)
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
        reason: "disposition fixture"
      )
    }
    return state
  }
}
