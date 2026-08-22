import Foundation
import XCTest

@testable import AgentOfficeCore

/// A machine whose PATHs and installed executables the test decides.
///
/// Every behaviour below runs against this fake, so the suite passes identically
/// on a Mac with both CLIs installed, one, or neither, and never depends on the
/// developer's own shell configuration.
private struct FakeEnvironmentProbe: LocalAgentEnvironmentProbe {
  var processPaths: [String] = []
  var loginPaths: [String] = []
  var executables: Set<String> = []
  /// Proves the login shell is only asked when it is actually needed.
  var loginShellReads: Counter = Counter()

  func processSearchPaths() -> [String] { processPaths }

  func loginShellSearchPaths() -> [String] {
    loginShellReads.increment()
    return loginPaths
  }

  func isExecutable(atPath path: String) -> Bool { executables.contains(path) }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
}

final class LocalAgentDiscoveryTests: XCTestCase {
  /// The live bug: an app bundle launched from Finder inherits no shell PATH, so
  /// a Codex that is plainly installed reads as missing.
  func testFindsACLIThatOnlyTheLoginShellPATHKnowsAbout() {
    let probe = FakeEnvironmentProbe(
      processPaths: [],
      loginPaths: ["/Users/owner/.nvm/versions/node/v22/bin"],
      executables: ["/Users/owner/.nvm/versions/node/v22/bin/codex"]
    )
    let discovery = LocalAgentDiscovery(probe: probe)

    let found = discovery.locate(.codex)

    XCTAssertEqual(found?.executableURL.path, "/Users/owner/.nvm/versions/node/v22/bin/codex")
    XCTAssertEqual(found?.source, .loginShellPath)
    XCTAssertTrue(discovery.availability(of: .codex).isAvailable)
  }

  func testTheInheritedPATHIsPreferredOverTheLoginShellPATH() {
    let probe = FakeEnvironmentProbe(
      processPaths: ["/inherited/bin"],
      loginPaths: ["/login/bin"],
      executables: ["/inherited/bin/claude", "/login/bin/claude"]
    )

    let found = LocalAgentDiscovery(probe: probe).locate(.claudeCode)

    XCTAssertEqual(found?.executableURL.path, "/inherited/bin/claude")
    XCTAssertEqual(found?.source, .processPath)
  }

  func testKnownInstallerLocationsAreCheckedLast() {
    let probe = FakeEnvironmentProbe(
      processPaths: ["/inherited/bin"],
      loginPaths: ["/login/bin"],
      executables: ["/opt/homebrew/bin/claude"]
    )

    let found = LocalAgentDiscovery(probe: probe).locate(.claudeCode)

    XCTAssertEqual(found?.source, .installerDirectory)
  }

  func testAnAbsentCLIIsReportedWithAReasonThatNamesWhatWasSearched() {
    let discovery = LocalAgentDiscovery(probe: FakeEnvironmentProbe())

    XCTAssertNil(discovery.locate(.claudeCode))
    let availability = discovery.availability(of: .claudeCode)
    XCTAssertFalse(availability.isAvailable)
    let reason = availability.reason ?? ""
    XCTAssertTrue(reason.contains("Claude Code"))
    // The owner is told the app looked past its own environment, because
    // "not installed" and "installed where this app cannot see" are different
    // problems with different fixes.
    XCTAssertTrue(reason.contains("login shell"))
  }

  func testEachCLIIsDetectedIndependently() {
    let probe = FakeEnvironmentProbe(
      processPaths: ["/bin"], executables: ["/bin/codex"])
    let discovery = LocalAgentDiscovery(probe: probe)

    XCTAssertNotNil(discovery.locate(.codex))
    XCTAssertNil(discovery.locate(.claudeCode))
  }

  func testTheLoginShellIsNotConsultedWhenTheInheritedPATHAlreadyAnswers() {
    let probe = FakeEnvironmentProbe(
      processPaths: ["/inherited/bin"], executables: ["/inherited/bin/codex"])

    _ = LocalAgentDiscovery(probe: probe).locate(.codex)

    XCTAssertEqual(probe.loginShellReads.value, 0)
  }

  func testSearchOrderContainsNoDuplicateDirectories() {
    let probe = FakeEnvironmentProbe(
      processPaths: ["/opt/homebrew/bin", "/bin"],
      loginPaths: ["/bin", "/opt/homebrew/bin"]
    )

    let directories = LocalAgentDiscovery(probe: probe).searchPaths(for: .codex)
      .map(\.directory)

    XCTAssertEqual(Set(directories).count, directories.count)
  }
}

final class LocalAgentRuntimeDriverTests: XCTestCase {
  private func discovery(installed: [LocalAgentCLI]) -> LocalAgentDiscovery {
    let executables = Set(installed.map { "/fake/bin/\($0.executableName)" })
    return LocalAgentDiscovery(
      probe: FakeEnvironmentProbe(processPaths: ["/fake/bin"], executables: executables))
  }

  func testClaudeCodeReportsItselfAvailableOnlyWhenInstalled() async {
    let installed = LocalAgentRuntimeDriver(
      cli: .claudeCode, discovery: discovery(installed: [.claudeCode]))
    let absent = LocalAgentRuntimeDriver(cli: .claudeCode, discovery: discovery(installed: []))

    let installedHealth = await installed.availability()
    let absentHealth = await absent.availability()

    XCTAssertTrue(installedHealth.isAvailable)
    XCTAssertFalse(absentHealth.isAvailable)
  }

  func testCodexAvailabilityIsIndependentOfClaudeCode() async {
    let onlyCodex = discovery(installed: [.codex])

    let codexHealth = await LocalAgentRuntimeDriver(cli: .codex, discovery: onlyCodex)
      .availability()
    let claudeHealth = await LocalAgentRuntimeDriver(cli: .claudeCode, discovery: onlyCodex)
      .availability()

    XCTAssertTrue(codexHealth.isAvailable)
    XCTAssertFalse(claudeHealth.isAvailable)
  }

  /// A missing runtime refuses rather than handing back a session that would
  /// quietly produce something else.
  func testAnAbsentRuntimeRefusesToOpenASession() async {
    let driver = LocalAgentRuntimeDriver(cli: .claudeCode, discovery: discovery(installed: []))

    do {
      _ = try await driver.openSession(employeeID: "nia", bindingID: "b", sessionID: "s")
      XCTFail("An uninstalled runtime must not open a session.")
    } catch {
      XCTAssertEqual(error as? ClaudeCodeRunnerError, .unavailable)
    }
  }

  func testAllThreeRuntimesAreRegisteredAndNoOtherProviderIs() async {
    let registry = RuntimeDriverRegistry.builtIn(discovery: discovery(installed: []))

    let kinds = await registry.registeredKinds

    XCTAssertEqual(kinds, [.demo, .localCodex, .localClaudeCode])
  }

  // MARK: - Model selection

  private func request(webResearch: Bool = false) -> EmployeeWorkRequest {
    let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    return EmployeeWorkRequest(
      operation: webResearch ? .research : .draft,
      employee: organization.employee("nia")!,
      task: organization.task("research-audience")!,
      organizationName: organization.name,
      outcome: organization.outcome,
      context: "",
      capabilityGrants: webResearch ? ["web-research"] : [],
      workspaceURL: URL(fileURLWithPath: "/tmp/workspace")
    )
  }

  /// Auto omits the override entirely rather than naming today's default, so the
  /// runtime's own choice applies and nothing is claimed about which model ran.
  func testAutoModelSendsNoOverrideToEitherRuntime() {
    let work = request()

    XCTAssertFalse(CodexEmployeeRunner.commandArguments(for: work).contains("--model"))
    XCTAssertFalse(ClaudeCodeEmployeeRunner.commandArguments(for: work).contains("--model"))
    XCTAssertNil(RuntimeModelChoice.auto.overrideName)
    XCTAssertNil(RuntimeModelChoice.auto.recordedName)
  }

  func testAnExplicitModelIsPassedToEitherRuntime() {
    let work = request()

    let codex = CodexEmployeeRunner.commandArguments(for: work, model: .explicit("gpt-5.1-codex"))
    let claude = ClaudeCodeEmployeeRunner.commandArguments(for: work, model: .explicit("opus"))

    XCTAssertEqual(codex.firstIndex(of: "--model").map { codex[$0 + 1] }, "gpt-5.1-codex")
    XCTAssertEqual(claude.firstIndex(of: "--model").map { claude[$0 + 1] }, "opus")
    // Codex reads the prompt from the trailing "-", which must stay last.
    XCTAssertEqual(codex.last, "-")
  }

  func testBlankAndWhitespaceModelNamesMeanAuto() {
    XCTAssertEqual(RuntimeModelChoice(modelName: nil), .auto)
    XCTAssertEqual(RuntimeModelChoice(modelName: ""), .auto)
    XCTAssertEqual(RuntimeModelChoice(modelName: "   "), .auto)
    XCTAssertEqual(RuntimeModelChoice(modelName: " opus "), .explicit("opus"))
  }

  func testEachRuntimeOffersItsOwnModels() {
    XCTAssertFalse(RuntimeModelCatalog.offeredModels(for: .localCodex).isEmpty)
    XCTAssertFalse(RuntimeModelCatalog.offeredModels(for: .localClaudeCode).isEmpty)
    // Demo runs no model of its own, so it offers none to override.
    XCTAssertTrue(RuntimeModelCatalog.offeredModels(for: .demo).isEmpty)
    XCTAssertTrue(
      Set(RuntimeModelCatalog.offeredModels(for: .codex))
        .isDisjoint(with: Set(RuntimeModelCatalog.offeredModels(for: .claudeCode))))
  }

  // MARK: - Sandboxing

  /// Tool access is withheld on the command line as well as in the prompt: the
  /// runtime is constrained by the CLI, not only asked to behave.
  func testClaudeCodeIsRestrictedToReadOnlyTools() {
    let tools = ClaudeCodeEmployeeRunner.allowedTools(for: request())

    XCTAssertEqual(Set(tools), ["Read", "Glob", "Grep"])
    for forbidden in ["Write", "Edit", "Bash", "NotebookEdit"] {
      XCTAssertFalse(tools.contains(forbidden))
    }
    XCTAssertFalse(
      ClaudeCodeEmployeeRunner.commandArguments(for: request())
        .contains("--dangerously-skip-permissions"))
  }

  func testWebToolsAppearOnlyWithAGrantedResearchCapability() {
    XCTAssertFalse(ClaudeCodeEmployeeRunner.allowedTools(for: request()).contains("WebSearch"))
    XCTAssertTrue(
      ClaudeCodeEmployeeRunner.allowedTools(for: request(webResearch: true)).contains("WebSearch"))
  }

  func testTheGovernedOrganizationDirectoryIsTheOnlyDirectoryOffered() {
    let work = request()
    let arguments = ClaudeCodeEmployeeRunner.commandArguments(for: work)

    XCTAssertEqual(
      arguments.firstIndex(of: "--add-dir").map { arguments[$0 + 1] }, work.workspaceURL.path)
  }
}

final class RuntimeAutoResolutionTests: XCTestCase {
  private let resolver = RuntimeAutoResolver()

  private func health(
    codex: Bool = false, claudeCode: Bool = false, demo: Bool = true
  ) -> [RuntimeDriverKind: RuntimeAvailability] {
    func state(_ healthy: Bool, _ name: String) -> RuntimeAvailability {
      healthy ? .available : .unavailable(reason: "\(name) is not installed.")
    }
    return [
      .localCodex: state(codex, "Codex"),
      .localClaudeCode: state(claudeCode, "Claude Code"),
      .demo: state(demo, "Practice mode"),
    ]
  }

  // MARK: - Rule 1

  func testAnExplicitRuntimeChoiceIsPreservedEvenWhenAnotherIsHealthy() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        explicitChoice: .localClaudeCode,
        lastSuccessful: .localCodex,
        packagePreference: .localCodex,
        health: health(codex: true, claudeCode: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .localClaudeCode)
    XCTAssertEqual(outcome.selection?.rule, .explicitEmployeeChoice)
    XCTAssertTrue(outcome.selection?.runtime.wasChosenByOwner == true)
  }

  /// An explicit choice that cannot run blocks. Falling through to the other
  /// runtime would be the substitution the policy exists to prevent.
  func testAnUnavailableExplicitChoiceBlocksInsteadOfSwitching() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        explicitChoice: .localClaudeCode, health: health(codex: true, claudeCode: false)))

    XCTAssertNil(outcome.selection)
    XCTAssertEqual(
      outcome.refusal?.cause,
      .explicitRuntimeUnavailable(.localClaudeCode, detail: "Claude Code is not installed."))
    XCTAssertTrue(outcome.refusal?.reason.contains("Claude Code") == true)
  }

  // MARK: - Rule 2

  func testTheLastSuccessfulRuntimeIsReusedWhenHealthy() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        lastSuccessful: .localClaudeCode,
        packagePreference: .localCodex,
        health: health(codex: true, claudeCode: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .localClaudeCode)
    XCTAssertEqual(outcome.selection?.rule, .lastSuccessfulRuntime)
    XCTAssertFalse(outcome.selection?.runtime.wasChosenByOwner == true)
  }

  func testAnUnhealthyLastSuccessfulRuntimeFallsThroughToThePackagePreference() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        lastSuccessful: .localClaudeCode,
        packagePreference: .localCodex,
        health: health(codex: true, claudeCode: false)))

    XCTAssertEqual(outcome.selection?.driverKind, .localCodex)
    XCTAssertEqual(outcome.selection?.rule, .packagePreference)
  }

  // MARK: - Rule 3

  func testThePackagePreferenceIsUsedWhenNothingHasSucceededYet() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        packagePreference: .localClaudeCode, health: health(codex: true, claudeCode: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .localClaudeCode)
    XCTAssertEqual(outcome.selection?.rule, .packagePreference)
  }

  // MARK: - Rule 4

  func testHealthyCodexIsChosenBeforeHealthyClaudeCode() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(health: health(codex: true, claudeCode: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .localCodex)
    XCTAssertEqual(outcome.selection?.rule, .firstHealthyRuntime)
  }

  func testClaudeCodeIsChosenWhenCodexIsNotHealthy() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(health: health(codex: false, claudeCode: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .localClaudeCode)
    XCTAssertEqual(outcome.selection?.rule, .firstHealthyRuntime)
  }

  func testARuntimeWhoseHealthWasNeverProbedIsTreatedAsUnavailable() {
    let outcome = resolver.resolve(RuntimeSelectionInputs(health: [:]))

    XCTAssertNil(outcome.selection)
  }

  // MARK: - Rule 5

  func testTheResolvedRuntimeAndModelAreRecordedOnTheReceipt() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        explicitChoice: .localClaudeCode,
        health: health(claudeCode: true),
        contractModel: .explicit("opus")))
    let selection = outcome.selection

    let work = selection?.receiptWork(employeeID: "nia", subject: .commitment("c-1"))

    XCTAssertEqual(work?.runtimeKind, "office.local-claude-code")
    XCTAssertEqual(work?.modelName, "opus")
    XCTAssertTrue(selection?.evidenceSummary.contains("Claude Code") == true)
  }

  /// Auto records no model name. Writing down whichever model happened to run
  /// would be a claim the app cannot substantiate.
  func testAutoModelIsRecordedAsTheRuntimeDefaultRatherThanAName() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(health: health(codex: true), contractModel: .auto))

    let work = outcome.selection?.receiptWork(employeeID: "nia", subject: .commitment("c-1"))

    XCTAssertNil(work?.modelName)
    XCTAssertEqual(work?.runtimeKind, "office.local-codex")
    XCTAssertTrue(outcome.selection?.evidenceSummary.contains("default model") == true)
  }

  func testTheContractModelWinsOverThePackageModel() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        health: health(codex: true),
        contractModel: .explicit("gpt-5.1"),
        packageModel: .explicit("gpt-5.1-codex-mini")))

    XCTAssertEqual(outcome.selection?.model, .explicit("gpt-5.1"))
  }

  func testThePackageModelAppliesWhenTheContractLeavesModelOnAuto() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        health: health(codex: true), contractModel: .auto,
        packageModel: .explicit("gpt-5.1-codex-mini")))

    XCTAssertEqual(outcome.selection?.model, .explicit("gpt-5.1-codex-mini"))
  }

  // MARK: - Rule 6

  func testAnOpenCommitmentKeepsItsRuntimeEvenWhenTheOwnerChangesTheChoice() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        explicitChoice: .localClaudeCode,
        activeCommitmentRuntime: .localCodex,
        health: health(codex: true, claudeCode: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .localCodex)
    XCTAssertEqual(outcome.selection?.rule, .pinnedToActiveCommitment)
  }

  func testLosingTheRuntimeMidCommitmentBlocksRatherThanMovingProvider() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(
        activeCommitmentRuntime: .localCodex, health: health(codex: false, claudeCode: true)))

    XCTAssertNil(outcome.selection)
    XCTAssertEqual(
      outcome.refusal?.cause,
      .activeCommitmentRuntimeLost(.localCodex, detail: "Codex is not installed."))
  }

  // MARK: - Rule 7

  func testNoHealthyRuntimeBlocksInsteadOfRehearsingInDemo() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(health: health(codex: false, claudeCode: false, demo: true)))

    XCTAssertNil(outcome.selection)
    XCTAssertEqual(
      outcome.refusal?.cause, .noHealthyRuntime(checked: AutoSelectableRuntime.preferenceOrder))
    XCTAssertTrue(outcome.refusal?.reason.contains("blocked") == true)
  }

  /// Demo is reachable, but only because the owner asked for a rehearsal.
  func testDemoIsStillAvailableAsAnExplicitRehearsal() {
    let outcome = resolver.resolve(
      RuntimeSelectionInputs(explicitChoice: .demo, health: health(demo: true)))

    XCTAssertEqual(outcome.selection?.driverKind, .demo)
    XCTAssertTrue(outcome.selection?.isRehearsal == true)
    XCTAssertTrue(outcome.selection?.runtime.wasChosenByOwner == true)
    XCTAssertEqual(outcome.selection?.rule, .explicitEmployeeChoice)
  }

  /// The structural guarantee: Demo has no representation as an automatically
  /// selectable runtime, so no automatic branch can name it.
  func testDemoCannotBeRepresentedAsAnAutomaticallySelectableRuntime() {
    XCTAssertNil(AutoSelectableRuntime(driverKind: .demo))
    XCTAssertNil(AutoSelectableRuntime(driverKind: RuntimeDriverKind("test.fake")))
    XCTAssertEqual(AutoSelectableRuntime.allCases.count, 2)
    for runtime in AutoSelectableRuntime.allCases {
      XCTAssertNotEqual(runtime.driverKind, .demo)
    }
    XCTAssertEqual(
      Set(AutoSelectableRuntime.preferenceOrder), Set(AutoSelectableRuntime.allCases))
  }

  /// A rehearsal that the owner did not ask for cannot be produced, whatever the
  /// inputs say. Demo is offered as every hint and marked healthy while both
  /// real runtimes are down, which is the exact shape of a silent substitution.
  func testDemoNeverArrivesFromAnySweepOfAutomaticInputs() {
    let candidates: [RuntimeDriverKind?] = [
      nil, .demo, .localCodex, .localClaudeCode, RuntimeDriverKind("test.fake"),
    ]
    var checked = 0

    for last in candidates {
      for preference in candidates {
        for pinned in candidates {
          for codexHealthy in [true, false] {
            for claudeHealthy in [true, false] {
              let outcome = resolver.resolve(
                RuntimeSelectionInputs(
                  explicitChoice: nil,
                  lastSuccessful: last,
                  packagePreference: preference,
                  activeCommitmentRuntime: pinned,
                  health: health(
                    codex: codexHealthy, claudeCode: claudeHealthy, demo: true)))
              checked += 1
              guard let selection = outcome.selection else { continue }
              // Nothing here was owner-chosen, so nothing here may be a rehearsal.
              XCTAssertFalse(
                selection.isRehearsal,
                "Auto resolution produced Demo for last=\(String(describing: last)) "
                  + "preference=\(String(describing: preference)) "
                  + "pinned=\(String(describing: pinned))")
            }
          }
        }
      }
    }

    XCTAssertEqual(checked, 500)
  }

  func testAnAutoProviderNeverBindsAnEmployeeToARehearsalRuntime() {
    for provider in EmployeeExecutionProvider.allCases where provider != .demo {
      XCTAssertNotEqual(
        provider.explicitDriverKind ?? AutoSelectableRuntime.preferenceOrder[0].driverKind,
        .demo,
        "\(provider.rawValue) must not resolve to a rehearsal runtime.")
    }
    XCTAssertNil(EmployeeExecutionProvider.auto.explicitDriverKind)
    XCTAssertEqual(EmployeeExecutionProvider.localClaudeCode.explicitDriverKind, .localClaudeCode)
  }

  func testTheAgentChoicesOfferedLeadWithAutoAndCoverBothRealRuntimes() {
    let choices = EmployeeExecutionProvider.agentChoices

    XCTAssertEqual(choices.first, .auto)
    XCTAssertTrue(choices.contains(.localCodex))
    XCTAssertTrue(choices.contains(.localClaudeCode))
    XCTAssertEqual(Set(choices), Set(EmployeeExecutionProvider.allCases))
  }
}
