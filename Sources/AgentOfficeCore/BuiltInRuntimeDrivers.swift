import Foundation

/// A session that runs one turn through an `EmployeeRunner`.
///
/// The built-in runtimes keep their existing behaviour; the driver contract is
/// what changes, not how demo or Codex work is produced.
public struct RunnerBackedSession: RuntimeSession {
  public let sessionID: String
  public let bindingID: String
  public let employeeID: String
  private let runner: any EmployeeRunner

  public init(
    sessionID: String, bindingID: String, employeeID: String, runner: any EmployeeRunner
  ) {
    self.sessionID = sessionID
    self.bindingID = bindingID
    self.employeeID = employeeID
    self.runner = runner
  }

  public func run(_ turn: RuntimeTurn) async throws -> RuntimeTurnResult {
    // A session belongs to one employee. Running another employee's turn
    // through it would attribute work to the wrong person.
    guard turn.employeeID == employeeID else {
      throw RuntimeSessionError.employeeMismatch(expected: employeeID, found: turn.employeeID)
    }
    var log = RuntimeEventLog(bindingID: bindingID, sessionID: sessionID)
    let origin = RuntimeEventOrigin(
      employeeID: turn.employeeID,
      bindingID: bindingID,
      sessionID: sessionID,
      commitmentID: turn.commitmentID,
      correlationID: turn.correlationID
    )
    func note(_ kind: RuntimeEvent.Kind, _ summary: String) throws {
      try log.record(RuntimeEvent(kind: kind, origin: origin, summary: summary))
    }

    try note(.turnStarted, "Started \(turn.work.operation.rawValue) for \(turn.commitmentID).")
    do {
      let output = try await runner.perform(turn.work)
      try note(.assistantOutput, "Returned \(turn.work.operation.rawValue) output.")
      try note(.turnFinished, "Finished \(turn.work.operation.rawValue).")
      return RuntimeTurnResult(output: output, events: log.events)
    } catch {
      try note(.error, error.localizedDescription)
      throw error
    }
  }

  public func interrupt() async {}

  public func stop() async {}
}

extension RuntimeDriver {
  /// Presents a runner as this driver's session for one employee.
  ///
  /// Shared so every driver attributes a session identically; a driver that
  /// built this itself could quietly bind a session to the wrong employee.
  func session(
    employeeID: String, bindingID: String, sessionID: String, runner: any EmployeeRunner
  ) -> any RuntimeSession {
    RunnerBackedSession(
      sessionID: sessionID, bindingID: bindingID, employeeID: employeeID, runner: runner)
  }
}

/// The built-in rehearsal runtime. Always available, never external.
public struct DemoRuntimeDriver: RuntimeDriver {
  public let kind = RuntimeDriverKind.demo
  public let version = 1
  public let declaredCapabilities: Set<RuntimeCapability> = [.planning, .execution, .review]

  public init() {}

  public func availability() async -> RuntimeAvailability { .available }

  public func openSession(employeeID: String, bindingID: String, sessionID: String) async throws
    -> any RuntimeSession
  {
    session(
      employeeID: employeeID, bindingID: bindingID, sessionID: sessionID,
      runner: DeterministicEmployeeRunner())
  }
}

/// A runtime backed by a locally installed agent CLI.
///
/// One type serves both Codex and Claude Code because the difference between
/// them is which CLI is invoked, not how a runtime behaves. Each reports itself
/// unavailable when its own CLI is missing rather than quietly producing work
/// through the other: an owner who believes Claude Code ran deserves to be told
/// when it did not.
public struct LocalAgentRuntimeDriver: RuntimeDriver {
  public let cli: LocalAgentCLI
  public let version = 1
  public let declaredCapabilities: Set<RuntimeCapability> = [
    .planning, .execution, .review, .toolInvocation,
  ]
  /// Which model this employee's binding asked for. `auto` sends no override.
  public let model: RuntimeModelChoice
  private let discovery: LocalAgentDiscovery

  public init(
    cli: LocalAgentCLI,
    model: RuntimeModelChoice = .auto,
    discovery: LocalAgentDiscovery = LocalAgentDiscovery()
  ) {
    self.cli = cli
    self.model = model
    self.discovery = discovery
  }

  public var kind: RuntimeDriverKind {
    switch cli {
    case .codex: .localCodex
    case .claudeCode: .localClaudeCode
    }
  }

  /// The same driver bound to a different model, so a per-employee model choice
  /// does not require a second registry entry.
  public func withModel(_ model: RuntimeModelChoice) -> LocalAgentRuntimeDriver {
    LocalAgentRuntimeDriver(cli: cli, model: model, discovery: discovery)
  }

  public func availability() async -> RuntimeAvailability {
    discovery.availability(of: cli)
  }

  public func openSession(employeeID: String, bindingID: String, sessionID: String) async throws
    -> any RuntimeSession
  {
    session(
      employeeID: employeeID, bindingID: bindingID, sessionID: sessionID,
      runner: try runner())
  }

  /// Refuses rather than returning a session that would run something else.
  private func runner() throws -> any EmployeeRunner {
    switch cli {
    case .codex:
      guard let runner = CodexEmployeeRunner.discover(discovery: discovery, model: model) else {
        throw CodexRunnerError.unavailable
      }
      return runner
    case .claudeCode:
      guard let runner = ClaudeCodeEmployeeRunner.discover(discovery: discovery, model: model)
      else {
        throw ClaudeCodeRunnerError.unavailable
      }
      return runner
    }
  }
}

extension RuntimeDriverRegistry {
  /// The runtimes Office OS ships with. No external provider is registered.
  public static func builtIn(discovery: LocalAgentDiscovery = LocalAgentDiscovery())
    -> RuntimeDriverRegistry
  {
    RuntimeDriverRegistry(drivers: [
      DemoRuntimeDriver(),
      LocalAgentRuntimeDriver(cli: .codex, discovery: discovery),
      LocalAgentRuntimeDriver(cli: .claudeCode, discovery: discovery),
    ])
  }
}

/// Presents a runtime session as the `EmployeeRunner` the work engines expect,
/// so moving to the driver contract does not change how work is produced.
public struct RuntimeSessionRunner: EmployeeRunner {
  private let session: any RuntimeSession
  private let employeeID: String
  private let commitmentID: String
  private let correlationID: String

  public init(
    session: any RuntimeSession, employeeID: String, commitmentID: String, correlationID: String
  ) {
    self.session = session
    self.employeeID = employeeID
    self.commitmentID = commitmentID
    self.correlationID = correlationID
  }

  public func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    try await session.run(
      RuntimeTurn(
        employeeID: employeeID,
        bindingID: session.bindingID,
        sessionID: session.sessionID,
        commitmentID: commitmentID,
        correlationID: correlationID,
        work: request
      )
    ).output
  }
}

/// Raised when an employee's runtime cannot be used. The employee is intact;
/// only its runtime is missing, incompatible, misconfigured, or unhealthy.
public struct RuntimeUnavailableError: LocalizedError, Equatable {
  public let shadow: RuntimeUnavailableShadow

  public init(_ shadow: RuntimeUnavailableShadow) {
    self.shadow = shadow
  }

  public var errorDescription: String? { shadow.reason }
}
