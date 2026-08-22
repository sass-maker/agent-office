import Foundation
import XCTest

@testable import AgentOfficeCore

/// Proves the seven-rule runtime policy is in effect *in the work engines*, not
/// only inside `RuntimeAutoResolver`.
///
/// Every test here drives `EmployeeOutcomeEngine` or `WorkdayEngine` and asserts
/// on what the engine did — what it pinned, what it refused, and whether it
/// invoked a runtime at all — so the resolver being correct in isolation cannot
/// make any of them pass.
final class RuntimePolicyInEnginesTests: XCTestCase {
  private let epoch = Date(timeIntervalSince1970: 1_000)

  // MARK: - Rule 7: never silently substitute Practice mode

  func testEngineBlocksInsteadOfSubstitutingPracticeMode() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .auto)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: NeverRunsRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .practiceOnly
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.status, .waiting)
    XCTAssertNil(outcome.runtime, "Nothing ran, so nothing may claim a runtime.")
    XCTAssertNotEqual(outcome.resolvedRuntimeKind, .demo)
    XCTAssertFalse(outcome.isRehearsal)
    XCTAssertTrue(state.artifacts.isEmpty)
    XCTAssertEqual(
      outcome.helpRequest?.contains("blocked rather than rehearsing"), true,
      "The refusal must say it refused, not quietly rehearse.")
    XCTAssertEqual(state.employee("theo")?.status, .blocked)
  }

  func testWorkdayEngineBlocksTheTicketInsteadOfRehearsing() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var state = try workdayOrganization(provider: .auto)

    state = await WorkdayEngine().advance(
      state,
      runner: NeverRunsRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .practiceOnly
    )

    XCTAssertEqual(state.task("research-audience")?.status, .blocked)
    XCTAssertTrue(state.artifacts.isEmpty)
    XCTAssertEqual(state.blockers.count, 1)
    XCTAssertEqual(
      state.blockers.first?.detail.contains("blocked rather than rehearsing"), true)
  }

  // MARK: - Rule 1: an explicit choice is preserved, and allowed to fail

  func testEngineHonoursAnExplicitRuntimeAndRefusesToSwapItOut() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .localClaudeCode)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: NeverRunsRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      // Codex is right there and healthy. Using it would be the substitution
      // rule 1 forbids.
      runtimeHealth: .localAgents(codex: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.status, .waiting)
    XCTAssertNil(outcome.runtime)
    XCTAssertEqual(outcome.helpRequest?.contains("Claude Code"), true)
    XCTAssertEqual(
      outcome.helpRequest?.contains("will not swap in a different runtime"), true)
  }

  func testEngineRunsOnTheExplicitlyChosenRuntimeWhenItIsHealthy() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .localClaudeCode)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available, claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.resolvedRuntimeKind, .localClaudeCode)
    XCTAssertEqual(
      outcome.runtime?.selectionRule, RuntimeSelectionRule.explicitEmployeeChoice.rawValue)
  }

  // MARK: - Rule 2: reuse the last runtime that actually delivered

  func testEngineReusesTheLastSuccessfulRuntime() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .auto)
    appendReceipt(to: &state, employeeID: "theo", runtimeKind: .localClaudeCode, kind: .changed)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      // Both are healthy, so rule 4 alone would have chosen Codex.
      runtimeHealth: .localAgents(codex: .available, claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.resolvedRuntimeKind, .localClaudeCode)
    XCTAssertEqual(
      outcome.runtime?.selectionRule, RuntimeSelectionRule.lastSuccessfulRuntime.rawValue)
  }

  func testAFailedRunDoesNotCountAsTheLastSuccessfulRuntime() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .auto)
    appendReceipt(to: &state, employeeID: "theo", runtimeKind: .localClaudeCode, kind: .failed)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available, claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.resolvedRuntimeKind, .localCodex)
    XCTAssertEqual(
      outcome.runtime?.selectionRule, RuntimeSelectionRule.firstHealthyRuntime.rawValue)
  }

  // MARK: - Rule 3: the employee package's preference

  func testEngineUsesThePackagePreferenceWhenThereIsNoHistory() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(
      provider: .auto, packagePreference: .localClaudeCode)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available, claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.resolvedRuntimeKind, .localClaudeCode)
    XCTAssertEqual(outcome.runtime?.selectionRule, RuntimeSelectionRule.packagePreference.rawValue)
  }

  func testAPackageThatPrefersPracticeModeDoesNotGetIt() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .auto, packagePreference: .demo)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(
      outcome.resolvedRuntimeKind, .localClaudeCode,
      "A package preference is not a licence to rehearse.")
    XCTAssertFalse(outcome.isRehearsal)
  }

  // MARK: - Rule 4: first healthy real runtime, never Practice mode

  func testEngineFallsBackToTheOnlyHealthyRealRuntime() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .auto)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.resolvedRuntimeKind, .localClaudeCode)
    XCTAssertEqual(
      outcome.runtime?.selectionRule, RuntimeSelectionRule.firstHealthyRuntime.rawValue)
  }

  // MARK: - Rule 5: the resolved runtime and model are recorded

  func testEngineRecordsTheResolvedRuntimeAndModelOnTheCommitment() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(
      provider: .localCodex, modelName: "gpt-5.1-codex")

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.runtime?.kind, RuntimeDriverKind.localCodex.rawValue)
    XCTAssertEqual(outcome.runtime?.modelName, "gpt-5.1-codex")
    XCTAssertEqual(
      outcome.runtime?.selectionRule, RuntimeSelectionRule.explicitEmployeeChoice.rawValue)
  }

  func testAutoModelIsRecordedAsNoOverrideRatherThanAName() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .localCodex, modelName: nil)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.runtime?.kind, RuntimeDriverKind.localCodex.rawValue)
    XCTAssertNil(outcome.runtime?.modelName)
  }

  // MARK: - Rule 6: never switch runtimes during an active commitment

  func testAnOpenCommitmentIsNotMovedToAnotherRuntime() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    // The commitment started on Codex; the owner has since named Claude Code.
    var (state, commitmentID) = try organization(provider: .localClaudeCode)
    pin(.localCodex, to: commitmentID, in: &state)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available, claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(
      outcome.resolvedRuntimeKind, .localCodex,
      "A newer contract must not move work that is already open.")
  }

  func testAnOpenCommitmentBlocksWhenItsRuntimeIsLost() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .auto)
    pin(.localCodex, to: commitmentID, in: &state)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: NeverRunsRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      // Claude Code is healthy. Continuing on it would be a mid-commitment
      // runtime switch.
      runtimeHealth: .localAgents(claudeCode: .available)
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.status, .waiting)
    XCTAssertEqual(outcome.resolvedRuntimeKind, .localCodex)
    XCTAssertEqual(outcome.helpRequest?.contains("cannot be moved to another runtime"), true)
    XCTAssertTrue(state.artifacts.isEmpty)
  }

  // MARK: - Real work versus rehearsal

  func testWebResearchIsRealOnlyWhenTheResolvedRuntimeIsReal() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var rehearsal = try workdayOrganization(provider: .demo, grantResearch: true)

    rehearsal = await WorkdayEngine().advance(
      rehearsal,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available)
    )

    XCTAssertEqual(rehearsal.task("research-audience")?.status, .done)
    XCTAssertEqual(
      rehearsal.knowledge?.capabilityEvents.isEmpty, true,
      "A rehearsal reaches no network, so it may not record web research.")
    XCTAssertNotEqual(rehearsal.artifacts.first?.evidenceBasis, "permitted-web-research")
  }

  /// The organization-wide execution mode says Practice here, and the employee's
  /// contract says Codex. The contract is what decides, so the research is real.
  ///
  /// This is the case the old organization-wide check got wrong.
  func testTheContractNotTheOrganizationModeDecidesWhetherResearchIsReal() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var state = try workdayOrganization(provider: .localCodex, grantResearch: true)
    XCTAssertEqual(state.executionMode, .demo, "The fixture must disagree with the contract.")

    state = await WorkdayEngine().advance(
      state,
      runner: ResearchingRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available)
    )

    XCTAssertEqual(
      state.knowledge?.capabilityEvents.map(\.kind), [.started, .succeeded],
      "A real runtime doing granted research must be recorded as having used it.")
    XCTAssertEqual(state.artifacts.first?.evidenceBasis, "permitted-web-research")
  }

  func testAnExplicitRehearsalIsStillAllowed() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var (state, commitmentID) = try organization(provider: .demo)

    state = await EmployeeOutcomeEngine().run(
      state,
      outcomeID: commitmentID,
      runner: DeterministicEmployeeRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .practiceOnly
    )

    let outcome = try XCTUnwrap(state.employeeOutcome(commitmentID))
    XCTAssertEqual(outcome.resolvedRuntimeKind, .demo)
    XCTAssertTrue(outcome.isRehearsal)
    XCTAssertEqual(
      outcome.runtime?.selectionRule, RuntimeSelectionRule.explicitEmployeeChoice.rawValue)
  }

  // MARK: - Fixtures

  /// An organization with Theo hired, a working contract naming `provider`, and
  /// one open commitment whose plan does not need owner review.
  private func organization(
    provider: EmployeeExecutionProvider,
    modelName: String? = nil,
    packagePreference: EmployeeExecutionProvider? = nil
  ) throws -> (state: OrganizationState, commitmentID: String) {
    var state = LocalOrganizationStore.migrated(.seeded(now: epoch), now: epoch)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    if let packagePreference {
      let theoPackageVersion = state.employee("theo")?.packageVersion ?? "1.0.0"
      state.knowledge?.employeePackages.removeAll { $0.id == "starter.theo" }
      state.knowledge?.employeePackages.append(
        EmployeePackage(
          id: "starter.theo",
          version: theoPackageVersion,
          creator: "Office OS",
          name: "Theo",
          role: "Content Writer",
          responsibility: "Write",
          avatarColor: "7395A8",
          skills: [],
          supportedProviders: [.demo, .localCodex, .localClaudeCode],
          preferredProvider: packagePreference
        ))
    }
    try state.updateWorkingContract(
      employeeID: "theo",
      role: "Content Writer",
      responsibility: "Write",
      managerID: nil,
      assignedSkillIDs: ["communication"],
      declaredConnectionIDs: [],
      capabilityGrants: [],
      executionProvider: provider,
      modelName: modelName,
      boundaries: AutonomyBoundaries(),
      reviewPolicy: .automaticForLocalWork,
      actorID: "owner",
      reason: "runtime policy fixture"
    )
    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "", now: epoch)
    state = EmployeeOutcomeEngine().start(state, outcomeID: commitmentID, now: epoch)
    return (state, commitmentID)
  }

  /// An active workday whose first ready ticket is Nia's research.
  private func workdayOrganization(
    provider: EmployeeExecutionProvider, grantResearch: Bool = false
  ) throws -> OrganizationState {
    var state = LocalOrganizationStore.migrated(.seeded(now: epoch), now: epoch)
    state.workdayStatus = .active
    if grantResearch, let index = state.employees.firstIndex(where: { $0.id == "nia" }) {
      state.employees[index].capabilityGrants = ["web-research"]
    }
    try state.updateWorkingContract(
      employeeID: "nia",
      role: state.employee("nia")?.role ?? "Researcher",
      responsibility: state.employee("nia")?.responsibility ?? "Research",
      managerID: nil,
      assignedSkillIDs: state.assignedSkills(employeeID: "nia").map(\.id),
      declaredConnectionIDs: [],
      capabilityGrants: grantResearch ? ["web-research"] : [],
      executionProvider: provider,
      modelName: nil,
      boundaries: AutonomyBoundaries(),
      reviewPolicy: .automaticForLocalWork,
      actorID: "owner",
      reason: "runtime policy fixture"
    )
    return state
  }

  private func pin(
    _ kind: RuntimeDriverKind, to commitmentID: String, in state: inout OrganizationState
  ) {
    _ = state.updateEmployeeOutcome(commitmentID, now: epoch) {
      $0.runtime = CommitmentRuntime(kind: kind.rawValue, selectionRule: "fixture")
    }
  }

  private func appendReceipt(
    to state: inout OrganizationState,
    employeeID: String,
    runtimeKind: RuntimeDriverKind,
    kind: RunResultKind
  ) {
    state.knowledge?.runReceipts.append(
      RunReceipt(
        occurrenceID: "occurrence-\(UUID().uuidString)",
        scheduledReason: "Fixture",
        scheduledWindow: OccurrenceWindow(start: epoch, duration: 60, flexibility: 60),
        actual: OccurrenceActual(
          startedAt: epoch, endedAt: epoch, runtimeKind: runtimeKind.rawValue),
        work: ReceiptWork(
          employeeID: employeeID,
          subject: .commitment("fixture"),
          runtimeKind: runtimeKind.rawValue
        ),
        result: ReceiptResult(kind: kind, summary: "Fixture"),
        createdAt: epoch
      ))
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-tests-\(UUID().uuidString)", isDirectory: true)
  }
}

/// A runtime that must never be reached.
///
/// Failing inside `perform` is the point: it turns "the engine ran something
/// after resolution refused" into a test failure rather than a silent pass.
/// Returns research that claims permitted web evidence, so the engine's own
/// decision about whether the run was real is what the assertions read.
private struct ResearchingRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    EmployeeWorkOutput(
      title: "Audience research",
      summary: "Found three primary sources.",
      content: "# Audience\n\nThree sources.",
      evidenceBasis: request.canUseWebResearch ? "permitted-web-research" : "local-reasoning"
    )
  }
}

private struct NeverRunsRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    XCTFail("A runtime was invoked even though runtime resolution refused to select one.")
    throw RuntimeSessionError.interrupted
  }
}
