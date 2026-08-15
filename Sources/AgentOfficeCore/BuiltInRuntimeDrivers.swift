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
    RunnerBackedSession(
      sessionID: sessionID,
      bindingID: bindingID,
      employeeID: employeeID,
      runner: DeterministicEmployeeRunner()
    )
  }
}

/// The locally installed Codex runtime.
///
/// Reports itself unavailable when Codex is not installed rather than quietly
/// producing synthetic work in its place: an owner who believes real research
/// ran deserves to be told when it did not.
public struct LocalCodexRuntimeDriver: RuntimeDriver {
  public let kind = RuntimeDriverKind.localCodex
  public let version = 1
  public let declaredCapabilities: Set<RuntimeCapability> = [
    .planning, .execution, .review, .toolInvocation,
  ]

  public init() {}

  public func availability() async -> RuntimeAvailability {
    guard CodexEmployeeRunner.discover() != nil else {
      return .unavailable(
        reason:
          "Codex was not found on this Mac. Reconnect it, or move this employee to the demo runtime for a rehearsal."
      )
    }
    return .available
  }

  public func openSession(employeeID: String, bindingID: String, sessionID: String) async throws
    -> any RuntimeSession
  {
    guard let runner = CodexEmployeeRunner.discover() else {
      throw CodexRunnerError.unavailable
    }
    return RunnerBackedSession(
      sessionID: sessionID, bindingID: bindingID, employeeID: employeeID, runner: runner)
  }
}

extension RuntimeDriverRegistry {
  /// The runtimes Office OS ships with. No external provider is registered.
  public static func builtIn() -> RuntimeDriverRegistry {
    RuntimeDriverRegistry(drivers: [DemoRuntimeDriver(), LocalCodexRuntimeDriver()])
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
