import Foundation
import XCTest

@testable import AgentOfficeCore

/// Exercises the process and parsing machinery with ordinary POSIX tools, so the
/// suite proves the plumbing works without either agent CLI being installed.
final class LocalAgentProcessRunnerTests: XCTestCase {
  private func request(operation: WorkOperation = .draft) -> EmployeeWorkRequest {
    let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    return EmployeeWorkRequest(
      operation: operation,
      employee: organization.employee("nia")!,
      task: organization.task("research-audience")!,
      organizationName: organization.name,
      outcome: organization.outcome,
      context: "",
      workspaceURL: URL(fileURLWithPath: NSTemporaryDirectory())
    )
  }

  private func runner(_ executable: String, _ arguments: [String] = [])
    -> LocalAgentProcessRunner
  {
    LocalAgentProcessRunner(
      executableURL: URL(fileURLWithPath: executable),
      arguments: arguments,
      workingDirectoryURL: URL(fileURLWithPath: NSTemporaryDirectory())
    )
  }

  /// The prompt travels over standard input, never the argument list, so
  /// organization context cannot be read out of the process table.
  func testThePromptIsDeliveredOnStandardInput() async throws {
    let output = try await runner("/bin/cat").run(prompt: "the prompt")

    XCTAssertEqual(output, "the prompt")
  }

  func testANonZeroExitIsReportedWithItsStatus() async {
    do {
      _ = try await runner("/bin/sh", ["-c", "echo trouble >&2; exit 3"]).run(prompt: "x")
      XCTFail("A failing CLI must not look like success.")
    } catch let failure as LocalAgentFailure {
      XCTAssertEqual(failure, .failed(status: 3, detail: "trouble"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  /// Silence is not success. A runtime that returns nothing produced no work.
  func testEmptyOutputIsAFailureRatherThanAnEmptyDelivery() async {
    do {
      _ = try await runner("/bin/sh", ["-c", "exit 0"]).run(prompt: "x")
      XCTFail("Empty output must not be treated as a delivery.")
    } catch let failure as LocalAgentFailure {
      XCTAssertEqual(failure, .emptyOutput)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  // MARK: - Claude Code runner, driven by a stand-in CLI

  /// A stand-in for the real CLI: it accepts whatever arguments the runner
  /// passes and behaves as the test asks, so the runner can be exercised end to
  /// end on a machine where Claude Code is not installed.
  private func fakeCLI(body: String) throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("agent-office-fake-cli-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let script = directory.appendingPathComponent("claude")
    try "#!/bin/sh\n\(body)\n".write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: script.path)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return script
  }

  func testClaudeCodeTurnsCLIOutputIntoAttributedEmployeeWork() async throws {
    let runner = ClaudeCodeEmployeeRunner(executableURL: try fakeCLI(body: "cat"))

    let output = try await runner.perform(request())

    XCTAssertTrue(output.summary.contains("Claude Code"))
    XCTAssertFalse(output.content.isEmpty)
    XCTAssertEqual(output.evidenceBasis, "owner-context-only")
  }

  func testClaudeCodeFailuresSurfaceAsClaudeCodeErrors() async throws {
    let runner = ClaudeCodeEmployeeRunner(
      executableURL: try fakeCLI(body: "echo 'no session' >&2; exit 4"))

    do {
      _ = try await runner.perform(request())
      XCTFail("A failing CLI must not look like success.")
    } catch let error as ClaudeCodeRunnerError {
      XCTAssertEqual(error, .failed(4, "no session"))
    } catch {
      XCTFail("Expected a Claude Code error, got \(error)")
    }
  }

  func testClaudeCodeSilenceIsReportedAsNoWork() async throws {
    let runner = ClaudeCodeEmployeeRunner(executableURL: try fakeCLI(body: "exit 0"))

    do {
      _ = try await runner.perform(request())
      XCTFail("Silence must not be treated as a delivery.")
    } catch {
      XCTAssertEqual(error as? ClaudeCodeRunnerError, .emptyOutput)
    }
  }

  /// A plan that cannot be read is refused rather than turned into empty work.
  func testAnUnreadablePlanIsRefused() async throws {
    let runner = ClaudeCodeEmployeeRunner(executableURL: try fakeCLI(body: "echo 'just prose'"))

    do {
      _ = try await runner.perform(request(operation: .plan))
      XCTFail("Prose is not a plan.")
    } catch {
      XCTAssertEqual(error as? ClaudeCodeRunnerError, .invalidPlan)
    }
  }

  /// The explicit model reaches the CLI, which is what makes the receipt's
  /// record of it true rather than decorative.
  func testAnExplicitModelActuallyReachesTheCLI() async throws {
    let runner = ClaudeCodeEmployeeRunner(
      executableURL: try fakeCLI(body: #"echo "$@""#), model: .explicit("opus"))

    let output = try await runner.perform(request())

    XCTAssertTrue(output.content.contains("--model opus"))
  }

  func testAReadablePlanBecomesProposedTickets() throws {
    let json = """
      {"summary":"one sentence","selectedSkillIDs":["communication"],
       "tasks":[{"title":"Frame it","detail":"done when clear","kind":"analysis",
       "skillIDs":["communication"]}]}
      """

    let output = try LocalAgentWorkOutput.make(
      from: json, request: request(operation: .plan), runtimeLabel: "Claude Code",
      invalidPlan: ClaudeCodeRunnerError.invalidPlan)

    XCTAssertEqual(output.proposedTasks.count, 1)
    XCTAssertEqual(output.selectedSkillIDs, ["communication"])
    XCTAssertEqual(output.content, "one sentence")
  }

  func testAReviewVerdictIsReadFromTheRuntimeOutput() throws {
    func verdict(_ text: String) throws -> ReviewVerdict? {
      try LocalAgentWorkOutput.make(
        from: text, request: request(operation: .review), runtimeLabel: "Claude Code",
        invalidPlan: ClaudeCodeRunnerError.invalidPlan
      ).verdict
    }

    XCTAssertEqual(try verdict("APPROVE — this is ready."), .approve)
    XCTAssertEqual(try verdict("Needs another pass."), .revise)
    XCTAssertNil(
      try LocalAgentWorkOutput.make(
        from: "prose", request: request(operation: .draft), runtimeLabel: "Claude Code",
        invalidPlan: ClaudeCodeRunnerError.invalidPlan
      ).verdict)
  }

  func testErrorDescriptionsNameTheRuntimeThatFailed() {
    for error: ClaudeCodeRunnerError in [
      .unavailable, .failed(2, "detail"), .emptyOutput, .invalidPlan,
    ] {
      XCTAssertTrue(
        error.errorDescription?.contains("Claude Code") == true,
        "\(error) should say which runtime failed.")
    }
  }
}

/// Covers the real environment probe, including login-shell recovery, using a
/// known shell rather than the developer's own configuration.
final class SystemLocalAgentEnvironmentProbeTests: XCTestCase {
  func testTheInheritedPATHIsReadFromTheProcessEnvironment() {
    let probe = SystemLocalAgentEnvironmentProbe()

    // The test process always has a PATH; the point is that it is parsed.
    XCTAssertFalse(probe.processSearchPaths().isEmpty)
    XCTAssertFalse(probe.processSearchPaths().contains(""))
  }

  func testAPATHStringIsSplitAndEmptyEntriesDropped() {
    XCTAssertEqual(SystemLocalAgentEnvironmentProbe.split("/a::/b:"), ["/a", "/b"])
    XCTAssertEqual(SystemLocalAgentEnvironmentProbe.split(nil), [])
    XCTAssertEqual(SystemLocalAgentEnvironmentProbe.split(""), [])
  }

  /// Start-up banners must not be mistaken for directories to search.
  func testOnlyTheMarkedValueIsTakenFromNoisyShellOutput() {
    let text = "Welcome to your shell!\nM/usr/bin:/binM"

    XCTAssertEqual(
      SystemLocalAgentEnvironmentProbe.extract(between: "M", in: text), "/usr/bin:/bin")
    XCTAssertNil(SystemLocalAgentEnvironmentProbe.extract(between: "M", in: "no markers here"))
  }

  func testRecoveryReadsAPATHFromAKnownLoginShell() {
    let recovered = SystemLocalAgentEnvironmentProbe.recoverLoginShellPaths(shellPath: "/bin/sh")

    XCTAssertFalse(recovered.isEmpty)
    XCTAssertFalse(recovered.contains(""))
  }

  func testAShellThatDoesNotExistRecoversNothingRatherThanFailing() {
    XCTAssertEqual(
      SystemLocalAgentEnvironmentProbe.recoverLoginShellPaths(shellPath: "/nonexistent/shell"), [])
  }

  func testRecoveryIsCachedAndCanBeForgotten() {
    let probe = SystemLocalAgentEnvironmentProbe()

    let first = probe.loginShellSearchPaths()
    let cached = probe.loginShellSearchPaths()
    probe.forgetRecoveredPath()
    let afterForgetting = probe.loginShellSearchPaths()

    XCTAssertEqual(first, cached)
    XCTAssertEqual(first, afterForgetting)
  }

  func testDriverKindsNameThemselvesAndMapToTheirCLI() {
    XCTAssertEqual(RuntimeDriverKind.localCodex.localAgentCLI, .codex)
    XCTAssertEqual(RuntimeDriverKind.localClaudeCode.localAgentCLI, .claudeCode)
    XCTAssertNil(RuntimeDriverKind.demo.localAgentCLI)
    XCTAssertEqual(RuntimeDriverKind.localClaudeCode.displayName, "Claude Code")
    XCTAssertEqual(RuntimeDriverKind.demo.displayName, "Practice mode")
    XCTAssertEqual(RuntimeDriverKind("x.y").displayName, "x.y")
  }
}
