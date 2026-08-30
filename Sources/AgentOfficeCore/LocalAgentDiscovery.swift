import Foundation

/// A locally installed agent CLI Office OS knows how to employ.
///
/// Deliberately separate from `RuntimeDriverKind`: this names software on disk,
/// while a driver kind names a runtime an employee can be bound to.
public enum LocalAgentCLI: String, Codable, Sendable, CaseIterable {
  case codex
  case claudeCode

  /// The file name the installer puts on disk.
  public var executableName: String {
    switch self {
    case .codex: "codex"
    case .claudeCode: "claude"
    }
  }

  public var displayName: String {
    switch self {
    case .codex: "Codex"
    case .claudeCode: "Claude Code"
    }
  }

  /// Directories the Mac installers for this CLI are known to use.
  ///
  /// Checked only after both PATHs, so an owner's own installation always wins
  /// over a guess.
  public var installerDirectories: [String] {
    let home = NSHomeDirectory()
    switch self {
    case .codex:
      return [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "\(home)/.local/bin",
        "\(home)/.bun/bin",
        "\(home)/.volta/bin",
      ]
    case .claudeCode:
      return [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "\(home)/.local/bin",
        "\(home)/.claude/local",
        "\(home)/.bun/bin",
        "\(home)/.volta/bin",
      ]
    }
  }
}

/// How discovery observes this Mac.
///
/// Injected so every discovery behaviour can be tested on a machine where
/// neither CLI is installed, and so a test never depends on the developer's own
/// shell configuration.
public protocol LocalAgentEnvironmentProbe: Sendable {
  /// The `PATH` this process inherited.
  ///
  /// Empty or minimal for an app bundle launched from Finder, Dock, or
  /// Spotlight, which is exactly the case that made healthy CLIs read as
  /// missing.
  func processSearchPaths() -> [String]

  /// The `PATH` the owner's login shell reports.
  ///
  /// Recovered rather than assumed: a `.app` inherits `launchd`'s environment,
  /// not the environment the owner's shell builds from its start-up files.
  func loginShellSearchPaths() -> [String]

  func isExecutable(atPath path: String) -> Bool
}

/// Where a CLI was found, kept so the owner can be told how it was resolved
/// rather than being asked to trust a bare yes or no.
public enum LocalAgentDiscoverySource: String, Sendable, Equatable {
  /// Found on the `PATH` this process inherited.
  case processPath
  /// Found only after recovering the login shell's `PATH`.
  case loginShellPath
  /// Found in a location the installer is known to use.
  case installerDirectory
}

public struct LocalAgentInstallation: Sendable, Equatable {
  public var cli: LocalAgentCLI
  public var executableURL: URL
  public var source: LocalAgentDiscoverySource

  public init(cli: LocalAgentCLI, executableURL: URL, source: LocalAgentDiscoverySource) {
    self.cli = cli
    self.executableURL = executableURL
    self.source = source
  }
}

/// Finds locally installed agent CLIs from a native macOS app.
///
/// The inherited `PATH` alone is not enough. An app bundle launched from Finder,
/// the Dock, or Spotlight inherits `launchd`'s environment, so a perfectly
/// healthy CLI on the owner's `PATH` reads as missing and the employee looks
/// unemployable. Discovery therefore recovers the login shell's `PATH` before
/// concluding that anything is absent.
///
/// Only `PATH` is read. No credential, token, or configuration file is opened,
/// and the recovered environment is never logged or recorded.
public struct LocalAgentDiscovery: Sendable {
  private let probe: any LocalAgentEnvironmentProbe

  public init(probe: any LocalAgentEnvironmentProbe = SystemLocalAgentEnvironmentProbe.shared) {
    self.probe = probe
  }

  /// The places discovery draws directories from, in order.
  ///
  /// Order is the guarantee: what the app already inherited, then what the
  /// owner's shell would have provided, then known installer locations. Each is
  /// a closure so recovering the login shell's `PATH` — which starts a shell —
  /// only happens if the earlier source did not already answer.
  private func sources(for cli: LocalAgentCLI)
    -> [(source: LocalAgentDiscoverySource, directories: () -> [String])]
  {
    [
      (.processPath, probe.processSearchPaths),
      (.loginShellPath, probe.loginShellSearchPaths),
      (.installerDirectory, { cli.installerDirectories }),
    ]
  }

  /// The ordered, de-duplicated directories discovery would look in.
  ///
  /// For diagnostics and for showing an owner where the app searched. This
  /// consults every source, including the login shell.
  public func searchPaths(for cli: LocalAgentCLI)
    -> [(directory: String, source: LocalAgentDiscoverySource)]
  {
    var seen = Set<String>()
    var ordered: [(directory: String, source: LocalAgentDiscoverySource)] = []
    for entry in sources(for: cli) {
      for directory in Self.normalized(entry.directories(), seen: &seen) {
        ordered.append((directory, entry.source))
      }
    }
    return ordered
  }

  /// Locates one CLI, or reports nothing when it is genuinely not installed.
  ///
  /// Stops at the first hit, so an installation already on the inherited `PATH`
  /// never pays the cost of login-shell recovery.
  public func locate(_ cli: LocalAgentCLI) -> LocalAgentInstallation? {
    var seen = Set<String>()
    for entry in sources(for: cli) {
      for directory in Self.normalized(entry.directories(), seen: &seen) {
        let path = URL(fileURLWithPath: directory)
          .appendingPathComponent(cli.executableName).path
        guard probe.isExecutable(atPath: path) else { continue }
        return LocalAgentInstallation(
          cli: cli, executableURL: URL(fileURLWithPath: path), source: entry.source)
      }
    }
    return nil
  }

  private static func normalized(_ directories: [String], seen: inout Set<String>) -> [String] {
    directories.compactMap { directory in
      let trimmed = directory.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
      return trimmed
    }
  }

  /// Whether a CLI can be used right now, with an owner-readable reason when it
  /// cannot.
  ///
  /// The reason names login-shell recovery explicitly, because "not installed"
  /// is a different problem from "installed somewhere this app cannot see".
  public func availability(of cli: LocalAgentCLI) -> RuntimeAvailability {
    guard locate(cli) == nil else { return .available }
    return .unavailable(
      reason:
        "\(cli.displayName) was not found on this Mac. Office OS checked this app's PATH, the PATH your login shell reports, and the usual install locations. Install or reconnect \(cli.displayName), or move this employee to the demo runtime for a rehearsal."
    )
  }
}

/// Observes the real machine.
///
/// The login shell's `PATH` is recovered once and cached: recovery starts a
/// shell, and doing that on every availability check would make the app feel
/// slow for an answer that does not change while it is running.
public final class SystemLocalAgentEnvironmentProbe: LocalAgentEnvironmentProbe, @unchecked Sendable
{
  public static let shared = SystemLocalAgentEnvironmentProbe()

  /// How long the login shell is given before recovery gives up.
  ///
  /// A start-up file that waits for input must not be able to hang the app, so
  /// a slow shell degrades to "nothing recovered" rather than to a freeze.
  private static let recoveryTimeout: TimeInterval = 5

  private let lock = NSLock()
  private var cachedLoginShellPaths: [String]?

  public init() {}

  public func processSearchPaths() -> [String] {
    Self.split(ProcessInfo.processInfo.environment["PATH"])
  }

  public func loginShellSearchPaths() -> [String] {
    lock.lock()
    if let cached = cachedLoginShellPaths {
      lock.unlock()
      return cached
    }
    lock.unlock()

    let recovered = Self.recoverLoginShellPaths()

    lock.lock()
    cachedLoginShellPaths = recovered
    lock.unlock()
    return recovered
  }

  public func isExecutable(atPath path: String) -> Bool {
    FileManager.default.isExecutableFile(atPath: path)
  }

  /// Forgets the recovered `PATH` so a newly installed CLI can be found without
  /// relaunching the app.
  public func forgetRecoveredPath() {
    lock.lock()
    cachedLoginShellPaths = nil
    lock.unlock()
  }

  // MARK: - Internals

  static func split(_ path: String?) -> [String] {
    guard let path, !path.isEmpty else { return [] }
    return path.split(separator: ":").map(String.init).filter { !$0.isEmpty }
  }

  private static func recoverLoginShellPaths() -> [String] {
    recoverLoginShellPaths(
      shellPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
  }

  /// Asks a login shell what its `PATH` is.
  ///
  /// Run as a login *and* interactive shell because owners commonly set `PATH`
  /// in `.zshrc`, which a non-interactive shell never reads. Standard input is
  /// closed so an interactive shell cannot wait for a person, and standard
  /// error is discarded so a chatty start-up file is not mistaken for output.
  ///
  /// The shell is a parameter so tests can drive recovery with a known shell
  /// instead of depending on the developer's own login configuration.
  static func recoverLoginShellPaths(shellPath shell: String) -> [String] {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return [] }

    // A marker brackets the value so a start-up banner cannot be read as a
    // directory that the app would then search.
    let marker = "__AGENT_OFFICE_PATH__"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = [
      "-l", "-i", "-c", "printf '%s%s%s' '\(marker)' \"$PATH\" '\(marker)'",
    ]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    process.standardInput = FileHandle.nullDevice

    let collected = DataBox()
    let finished = DispatchSemaphore(value: 0)
    do {
      try process.run()
    } catch {
      return []
    }
    DispatchQueue.global(qos: .userInitiated).async {
      collected.set(output.fileHandleForReading.readDataToEndOfFile())
      finished.signal()
    }
    if finished.wait(timeout: .now() + recoveryTimeout) == .timedOut {
      process.terminate()
      _ = finished.wait(timeout: .now() + 1)
    }
    process.waitUntilExit()

    guard let text = String(data: collected.value, encoding: .utf8) else { return [] }
    return split(extract(between: marker, in: text))
  }

  /// Takes the value the shell was asked to print, ignoring anything around it.
  static func extract(between marker: String, in text: String) -> String? {
    let parts = text.components(separatedBy: marker)
    guard parts.count >= 3 else { return nil }
    return parts[1]
  }
}

/// Carries bytes off the reading thread without sharing mutable state.
final class DataBox: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = Data()

  var value: Data {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func set(_ data: Data) {
    lock.lock()
    storage = data
    lock.unlock()
  }
}
