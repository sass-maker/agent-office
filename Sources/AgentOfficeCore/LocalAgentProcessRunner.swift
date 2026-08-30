import Foundation

/// Which model a runtime should use for an employee.
///
/// Deliberately three-valued in effect rather than a defaulted string: `auto`
/// means "send no override and let the runtime pick", which is not the same as
/// naming whatever model happens to be current today. Recording `auto` as a
/// concrete model name would be a claim Office OS cannot stand behind.
public enum RuntimeModelChoice: Codable, Sendable, Equatable {
  case auto
  case explicit(String)

  public init(modelName: String?) {
    guard let trimmed = modelName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmed.isEmpty
    else {
      self = .auto
      return
    }
    self = .explicit(trimmed)
  }

  /// The override to pass to a CLI, or nothing when the runtime default applies.
  public var overrideName: String? {
    if case .explicit(let name) = self { return name }
    return nil
  }

  /// What to record on a session or receipt. `nil` says "the runtime's own
  /// default", which is the honest record when no override was sent.
  public var recordedName: String? { overrideName }

  public var isAuto: Bool { self == .auto }
}

/// Which executable to run, and which model to ask it for.
struct LocalAgentInvocation: Sendable {
  var executableURL: URL
  var model: RuntimeModelChoice
}

/// A runner that works through one locally installed agent CLI.
///
/// Discovery is written once here rather than per runtime, so a new local CLI
/// cannot accidentally acquire a different idea of what "installed" means.
public protocol LocalAgentCLIRunner {
  /// Which CLI on disk this runner invokes.
  static var cli: LocalAgentCLI { get }
  var executableURL: URL { get }
  var model: RuntimeModelChoice { get }
  init(executableURL: URL, model: RuntimeModelChoice)
}

extension LocalAgentCLIRunner {
  /// Finds this runner's CLI, including via login-shell `PATH` recovery, or
  /// reports nothing when it is genuinely not installed.
  public static func discover(
    discovery: LocalAgentDiscovery = LocalAgentDiscovery(),
    model: RuntimeModelChoice = .auto
  ) -> Self? {
    guard let installation = discovery.locate(cli) else { return nil }
    return Self(executableURL: installation.executableURL, model: model)
  }
}

/// How a local agent CLI failed, before each runtime maps it to its own error.
///
/// Kept neutral so the shared execution path does not have to know which CLI it
/// is running, while each runtime keeps the error type its callers already
/// handle.
public enum LocalAgentFailure: Error, Equatable {
  case failed(status: Int32, detail: String)
  case emptyOutput
}

/// Runs one local agent CLI turn.
///
/// Shared by every locally installed runtime so that Codex and Claude Code
/// cannot drift in how a process is started, how cancellation is honoured, or
/// how a non-zero exit is treated. What differs between runtimes is the
/// executable and its arguments, which is exactly what this takes as input.
struct LocalAgentProcessRunner: Sendable {
  var executableURL: URL
  var arguments: [String]
  var workingDirectoryURL: URL

  /// Sends `prompt` on standard input and returns trimmed standard output.
  ///
  /// The prompt goes over standard input rather than the argument list so it
  /// never appears in the process table, where another local process could read
  /// organization context out of it.
  func run(prompt: String) async throws -> String {
    let executableURL = self.executableURL
    let arguments = self.arguments
    let workingDirectoryURL = self.workingDirectoryURL
    let process = Process()
    return try await withTaskCancellationHandler {
      try await Task.detached(priority: .userInitiated) {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        process.executableURL = executableURL
        process.currentDirectoryURL = workingDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe
        process.arguments = arguments

        try process.run()
        inputPipe.fileHandleForWriting.write(Data(prompt.utf8))
        try inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        try Task.checkCancellation()

        let output = Self.text(from: outputPipe)
        let error = Self.text(from: errorPipe)

        guard process.terminationStatus == 0 else {
          throw LocalAgentFailure.failed(status: process.terminationStatus, detail: error)
        }
        guard !output.isEmpty else { throw LocalAgentFailure.emptyOutput }
        return output
      }.value
    } onCancel: {
      process.terminate()
    }
  }

  private static func text(from pipe: Pipe) -> String {
    String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}

/// The locally installed Claude Code CLI, employed the same way Codex is.
///
/// Reports itself unavailable when Claude Code is not installed rather than
/// letting a different runtime stand in for it. Tool access is restricted on the
/// command line to read-only tools, so the runtime is constrained by the CLI
/// itself and not only by what the prompt asks of it.
public struct ClaudeCodeEmployeeRunner: EmployeeRunner, LocalAgentCLIRunner {
  public static let cli = LocalAgentCLI.claudeCode

  /// The executable and model this runner works through, kept together because
  /// neither is meaningful without the other.
  private let invocation: LocalAgentInvocation

  public var executableURL: URL { invocation.executableURL }
  public var model: RuntimeModelChoice { invocation.model }

  public init(executableURL: URL, model: RuntimeModelChoice = .auto) {
    invocation = LocalAgentInvocation(executableURL: executableURL, model: model)
  }

  /// The read-only tools this runtime may use, and nothing else.
  ///
  /// Writing, editing, and command execution are withheld here as well as in
  /// the prompt: an employee's write target is decided by the organization's
  /// authority broker, never by the runtime deciding to edit a file.
  static func allowedTools(for request: EmployeeWorkRequest) -> [String] {
    var tools = ["Read", "Glob", "Grep"]
    if request.canUseWebResearch { tools += ["WebSearch", "WebFetch"] }
    return tools
  }

  public static func commandArguments(
    for request: EmployeeWorkRequest, model: RuntimeModelChoice = .auto
  ) -> [String] {
    var arguments = [
      "--print",
      "--output-format", "text",
      "--allowed-tools", allowedTools(for: request).joined(separator: ","),
      "--permission-mode", "default",
      "--add-dir", request.workspaceURL.path,
    ]
    // Auto sends no override at all, so the runtime's own default applies.
    if let name = model.overrideName { arguments += ["--model", name] }
    return arguments
  }

  public func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    let runner = LocalAgentProcessRunner(
      executableURL: executableURL,
      arguments: Self.commandArguments(for: request, model: model),
      workingDirectoryURL: request.workspaceURL
    )
    do {
      let output = try await runner.run(prompt: CodexEmployeeRunner.prompt(for: request))
      return try LocalAgentWorkOutput.make(
        from: output, request: request, runtimeLabel: "Claude Code",
        invalidPlan: ClaudeCodeRunnerError.invalidPlan)
    } catch let failure as LocalAgentFailure {
      throw ClaudeCodeRunnerError(failure)
    }
  }
}

public enum ClaudeCodeRunnerError: LocalizedError, Equatable {
  case unavailable
  case failed(Int32, String)
  case emptyOutput
  case invalidPlan

  init(_ failure: LocalAgentFailure) {
    switch failure {
    case .failed(let status, let detail): self = .failed(status, detail)
    case .emptyOutput: self = .emptyOutput
    }
  }

  public var errorDescription: String? {
    switch self {
    case .unavailable:
      "The locally installed Claude Code CLI is not available."
    case .failed(let status, let detail):
      "Claude Code stopped with status \(status). \(detail)"
    case .emptyOutput:
      "Claude Code completed without returning employee work."
    case .invalidPlan:
      "Claude Code returned a plan the employee runtime could not understand."
    }
  }
}

/// Turns a local agent CLI's standard output into employee work.
///
/// Shared by every local runtime so that two runtimes cannot disagree about
/// what a plan or an artifact is. Only the runtime's name in
/// the summary differs, because the summary is shown to the owner and should say
/// which runtime did the work.
enum LocalAgentWorkOutput {
  static func make(
    from output: String,
    request: EmployeeWorkRequest,
    runtimeLabel: String,
    invalidPlan: any Error
  ) throws -> EmployeeWorkOutput {
    if request.operation == .plan {
      guard let plan = CodexEmployeeRunner.decodedPlan(from: output) else { throw invalidPlan }
      return EmployeeWorkOutput(
        title: "\(request.employee.name)’s plan",
        summary:
          "\(request.employee.name) created \(plan.tasks.count) tickets using assigned skills.",
        content: plan.summary,
        proposedTasks: plan.tasks,
        selectedSkillIDs: plan.selectedSkillIDs
      )
    }
    return EmployeeWorkOutput(
      title: request.task.title,
      summary:
        "\(request.employee.name) completed \(request.operation.rawValue) work with \(runtimeLabel).",
      content: output,
      evidenceBasis: request.canUseWebResearch ? "permitted-web-research" : "owner-context-only"
    )
  }
}
