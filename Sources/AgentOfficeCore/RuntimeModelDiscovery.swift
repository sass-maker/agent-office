import Foundation

/// Why a listing attempt produced no models.
///
/// Named rather than collapsed to an empty list, because "Office OS could not
/// ask" and "the CLI offers nothing" are different facts and only one of them
/// is about the CLI.
public enum RuntimeModelListingFailure: Error, Sendable, Equatable {
  /// The CLI is not installed, so there was nothing to ask.
  case notInstalled
  /// The listing command ran and refused.
  case commandFailed(status: Int32, detail: String)
  /// The listing command was still running when its budget ran out.
  case timedOut(seconds: Int)
  /// The listing command answered in a shape this version does not understand.
  case unreadableOutput
  /// The listing command succeeded and named nothing.
  ///
  /// Kept separate from `unreadableOutput` because a CLI that genuinely offers
  /// no model is a different report from one whose answer we failed to read.
  case reportedNoModels

  /// What to tell the owner, in their terms rather than the process's.
  public var explanation: String {
    switch self {
    case .notInstalled:
      "Office OS could not ask which models are offered, because this runtime is not installed on this Mac."
    case .commandFailed(let status, let detail):
      detail.isEmpty
        ? "Asking this runtime for its models stopped with status \(status)."
        : "Asking this runtime for its models stopped with status \(status). \(detail)"
    case .timedOut(let seconds):
      "Asking this runtime for its models took longer than \(seconds) seconds, so Office OS stopped waiting."
    case .unreadableOutput:
      "This runtime answered in a form Office OS does not understand, so its models cannot be listed here."
    case .reportedNoModels:
      "This runtime listed no models Office OS can offer."
    }
  }
}

/// Where an offered set of model names came from.
///
/// Carried with the names so a screen can never present an assumption as a
/// report. The organization's premise is that an unverified number is worse
/// than an absent one; the same holds for an unverified list.
public enum RuntimeModelProvenance: Sendable, Equatable {
  /// The installed CLI enumerated these itself.
  case reportedByCLI
  /// The CLI exposes no way to ask, so these are Office OS's own assumption.
  case assumed(reason: String)
  /// The CLI could have been asked and the answer did not arrive.
  case unavailable(RuntimeModelListingFailure)

  public var isReported: Bool { self == .reportedByCLI }
}

/// The model names Office OS will offer for one runtime, and where they came
/// from.
///
/// `names` is deliberately allowed to be empty. Offering nothing but Auto is a
/// truthful answer when the runtime could not be asked; substituting a guess
/// there is how a stale list survives a CLI upgrade unnoticed.
public struct RuntimeModelOffer: Sendable, Equatable {
  public var cli: LocalAgentCLI
  public var names: [String]
  public var provenance: RuntimeModelProvenance
  /// The executable the answer describes, so an offer cannot outlive a
  /// reinstall that moved the CLI somewhere else.
  public var executablePath: String?
  public var observedAt: Date

  public init(
    cli: LocalAgentCLI,
    names: [String],
    provenance: RuntimeModelProvenance,
    executablePath: String?,
    observedAt: Date
  ) {
    self.cli = cli
    self.names = names
    self.provenance = provenance
    self.executablePath = executablePath
    self.observedAt = observedAt
  }

  /// What to say beneath the picker, so the owner can tell a report from an
  /// assumption without opening a log.
  public var explanation: String {
    switch provenance {
    case .reportedByCLI:
      return
        "\(cli.displayName) reported these models on this Mac. Update \(cli.displayName) to change the list."
    case .assumed(let reason):
      return
        "Office OS is showing what it assumes \(cli.displayName) offers, not what \(cli.displayName) reported. \(reason)"
    case .unavailable(let failure):
      return "\(failure.explanation) Leave the model on Auto and the runtime will pick its own."
    }
  }
}

/// The strictly local command that makes a CLI enumerate its models, and how to
/// read the answer.
///
/// Pure on both sides: choosing the command takes no process, and reading the
/// answer takes no machine. The process itself sits behind
/// `RuntimeModelListingRunner`, which is the only part a test cannot own.
public enum RuntimeModelListing {
  /// How long a listing command is given before it is abandoned.
  ///
  /// Generous next to the ~30ms the real command takes, and short enough that a
  /// wedged CLI cannot make the contract editor feel broken.
  public static let timeoutSeconds = 10

  /// The arguments that make `cli` print its model catalogue, or `nil` when the
  /// CLI offers no way to ask.
  ///
  /// Every command here must be free and offline. A probe that would start a
  /// billed session is not a listing command, however much it looks like one.
  public static func arguments(for cli: LocalAgentCLI) -> [String]? {
    switch cli {
    case .codex:
      // `--bundled` dumps the catalogue the installed binary already carries
      // and explicitly skips the refresh, so asking costs nothing and reaches
      // no network. The answer therefore tracks the installed Codex version,
      // which is exactly the question being asked.
      return ["debug", "models", "--bundled"]
    case .claudeCode:
      // Claude Code has no model-listing subcommand. A bare argument is
      // forwarded to the model as a prompt, so `claude models` does not list
      // models — it starts a billed session that answers in prose. There is no
      // free, offline way to ask, so the assumed list stands and says so.
      return nil
    }
  }

  /// Why a CLI's list is an assumption, for the CLIs that cannot be asked.
  public static func assumptionReason(for cli: LocalAgentCLI) -> String {
    switch cli {
    case .codex:
      "Codex can be asked for its models, so nothing here is assumed."
    case .claudeCode:
      "The Claude Code CLI has no model-listing command, and a bare argument is sent to the model as a prompt rather than answered locally."
    }
  }

  /// The names Office OS falls back to when a CLI cannot be asked at all.
  ///
  /// Empty for a CLI that *can* be asked: if the ask was possible and failed,
  /// a guess would dress a failure up as an answer. A CLI with nothing to ask
  /// is the only case where assuming is the honest option.
  public static func assumedNames(for cli: LocalAgentCLI) -> [String] {
    guard arguments(for: cli) == nil else { return [] }
    switch cli {
    case .codex: return []
    case .claudeCode: return ["opus", "sonnet", "haiku"]
    }
  }

  /// Reads a CLI's answer into model names, or says why it could not.
  public static func parse(_ output: String, for cli: LocalAgentCLI)
    -> Result<[String], RuntimeModelListingFailure>
  {
    switch cli {
    case .codex: return parseCodexCatalog(output)
    case .claudeCode: return .failure(.unreadableOutput)
    }
  }

  /// Codex prints a JSON catalogue whose entries carry a slug and two exclusion
  /// signals.
  ///
  /// Absent fields are treated as "not excluded" on purpose: an added field or
  /// a renamed one should narrow the list, never empty it, and only an explicit
  /// `hide` or `supported_in_api: false` withholds a model.
  private static func parseCodexCatalog(_ output: String)
    -> Result<[String], RuntimeModelListingFailure>
  {
    guard let data = output.data(using: .utf8),
      let catalog = try? JSONDecoder().decode(CodexModelCatalog.self, from: data)
    else { return .failure(.unreadableOutput) }

    var seen = Set<String>()
    let names =
      catalog.models
      .filter(\.isOfferable)
      .sorted { ($0.priority ?? .max, $0.slug) < ($1.priority ?? .max, $1.slug) }
      .compactMap { entry -> String? in
        let slug = entry.slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty, seen.insert(slug).inserted else { return nil }
        return slug
      }
    return names.isEmpty ? .failure(.reportedNoModels) : .success(names)
  }

  /// Only the fields Office OS acts on. The catalogue also carries prompt
  /// templates and other runtime internals, which are deliberately not decoded
  /// and never retained.
  private struct CodexModelCatalog: Decodable {
    var models: [Entry]

    struct Entry: Decodable {
      var slug: String
      var visibility: String?
      var priority: Int?
      var supportedInAPI: Bool?

      enum CodingKeys: String, CodingKey {
        case slug
        case visibility
        case priority
        case supportedInAPI = "supported_in_api"
      }

      var isOfferable: Bool { visibility != "hide" && supportedInAPI != false }
    }
  }
}

/// Runs one listing command.
///
/// The seam between the pure decision and the machine. Everything above it is
/// testable without either CLI installed; everything below it is one process.
public protocol RuntimeModelListingRunner: Sendable {
  func listModels(executableURL: URL, arguments: [String]) async
    -> Result<String, RuntimeModelListingFailure>
}

/// Asks each installed CLI what models it offers.
///
/// Discovery of the executable is reused rather than repeated, so a CLI that
/// discovery cannot find is reported as not installed here too instead of
/// acquiring a second idea of what "installed" means.
public struct RuntimeModelInquiry: Sendable {
  private let discovery: LocalAgentDiscovery
  private let runner: any RuntimeModelListingRunner

  public init(
    discovery: LocalAgentDiscovery = LocalAgentDiscovery(),
    runner: any RuntimeModelListingRunner = SystemRuntimeModelListingRunner()
  ) {
    self.discovery = discovery
    self.runner = runner
  }

  /// Produces the offer for one CLI, asking it when it can be asked.
  public func offer(for cli: LocalAgentCLI, now: Date = Date()) async -> RuntimeModelOffer {
    guard let installation = discovery.locate(cli) else {
      return RuntimeModelOffer(
        cli: cli, names: [], provenance: .unavailable(.notInstalled),
        executablePath: nil, observedAt: now)
    }
    let path = installation.executableURL.path
    guard let arguments = RuntimeModelListing.arguments(for: cli) else {
      return RuntimeModelOffer(
        cli: cli,
        names: RuntimeModelListing.assumedNames(for: cli),
        provenance: .assumed(reason: RuntimeModelListing.assumptionReason(for: cli)),
        executablePath: path,
        observedAt: now)
    }
    let answer = await runner.listModels(
      executableURL: installation.executableURL, arguments: arguments)
    switch answer.flatMap({ RuntimeModelListing.parse($0, for: cli) }) {
    case .success(let names):
      return RuntimeModelOffer(
        cli: cli, names: names, provenance: .reportedByCLI,
        executablePath: path, observedAt: now)
    case .failure(let failure):
      return RuntimeModelOffer(
        cli: cli, names: [], provenance: .unavailable(failure),
        executablePath: path, observedAt: now)
    }
  }
}

/// Remembers what each CLI answered, so the screens do not start a process to
/// draw a picker.
///
/// Two lifetimes rather than one: a report is worth keeping until the owner
/// changes their installation, while a failure is worth retrying soon. A single
/// long lifetime would pin a transient failure for hours; a single short one
/// would shell out constantly for an answer that does not move.
public struct RuntimeModelOfferCache: Sendable, Equatable {
  /// How long a successful answer stands. Long, because it only changes when
  /// the owner updates the CLI — and the owner already has an explicit
  /// "Check again" that clears this outright.
  public static let reportedLifetime: TimeInterval = 6 * 60 * 60
  /// How long a failure stands. Short, because the next attempt may succeed and
  /// nothing is gained by making the owner wait for it.
  public static let failedLifetime: TimeInterval = 60

  private var offers: [LocalAgentCLI: RuntimeModelOffer] = [:]

  public init() {}

  /// How long `offer` remains usable before it must be asked again.
  public static func lifetime(of offer: RuntimeModelOffer) -> TimeInterval {
    switch offer.provenance {
    // An assumption is not going to improve by being re-asked, but it must
    // still expire so a newly installed CLI is not hidden behind it.
    case .reportedByCLI, .assumed: reportedLifetime
    case .unavailable: failedLifetime
    }
  }

  /// The remembered answer, or `nil` when there is none worth reusing.
  ///
  /// `executablePath` is part of the question: an answer from a different
  /// binary is about a different installation and is not reused for this one.
  public func offer(for cli: LocalAgentCLI, executablePath: String?, now: Date)
    -> RuntimeModelOffer?
  {
    guard let stored = offers[cli], stored.executablePath == executablePath else { return nil }
    guard !Self.isStale(stored, now: now) else { return nil }
    return stored
  }

  public static func isStale(_ offer: RuntimeModelOffer, now: Date) -> Bool {
    let age = now.timeIntervalSince(offer.observedAt)
    // A clock that moved backwards makes an answer look impossibly fresh, so
    // treat a negative age as stale rather than as newly observed.
    return age < 0 || age >= lifetime(of: offer)
  }

  public mutating func record(_ offer: RuntimeModelOffer) {
    offers[offer.cli] = offer
  }

  /// Forgets everything, for the owner-driven recheck that already forgets the
  /// recovered `PATH`.
  public mutating func forgetAll() {
    offers.removeAll()
  }
}

/// Runs a listing command on this Mac.
///
/// Standard input is closed so a CLI that would prompt cannot wait for a person,
/// and the command is abandoned rather than allowed to hang the caller. Only the
/// model names are kept from the output; the catalogue also carries runtime
/// internals, which are never logged or recorded.
public struct SystemRuntimeModelListingRunner: RuntimeModelListingRunner {
  private let timeoutSeconds: Int

  public init(timeoutSeconds: Int = RuntimeModelListing.timeoutSeconds) {
    self.timeoutSeconds = timeoutSeconds
  }

  public func listModels(executableURL: URL, arguments: [String]) async
    -> Result<String, RuntimeModelListingFailure>
  {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice

    let expired = FlagBox()
    let watchdog = Self.watchdog(for: process, seconds: timeoutSeconds, expired: expired)
    defer { watchdog.cancel() }

    let seconds = timeoutSeconds
    return await Task.detached(priority: .userInitiated) {
      Self.capture(process, seconds: seconds, expired: expired)
    }.value
  }

  /// Runs the command to completion and reads both streams.
  ///
  /// Synchronous on purpose: it blocks one detached thread rather than the
  /// caller, which is what makes waiting on the process safe to express.
  private static func capture(_ process: Process, seconds: Int, expired: FlagBox) -> Result<
    String, RuntimeModelListingFailure
  > {
    let output = Pipe()
    let errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    do {
      try process.run()
    } catch {
      return .failure(.commandFailed(status: -1, detail: error.localizedDescription))
    }
    // Both streams are drained concurrently: a command that fills one while the
    // reader waits on the other would deadlock instead of answering.
    let drained = DataBox()
    let finished = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
      drained.set(errors.fileHandleForReading.readDataToEndOfFile())
      finished.signal()
    }
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    _ = finished.wait(timeout: .now() + 5)

    if expired.isSet { return .failure(.timedOut(seconds: seconds)) }
    guard process.terminationStatus == 0 else {
      return .failure(
        .commandFailed(
          status: process.terminationStatus,
          detail: String(decoding: drained.value, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    return .success(text)
  }

  /// Ends a command that has outstayed its budget, and records that this is why
  /// it stopped so a kill is never reported as a refusal.
  private static func watchdog(for process: Process, seconds: Int, expired: FlagBox) -> Task<
    Void, Never
  > {
    Task {
      try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
      guard !Task.isCancelled, process.isRunning else { return }
      expired.set()
      process.terminate()
    }
  }
}

/// A boolean two threads may read and write.
final class FlagBox: @unchecked Sendable {
  private let lock = NSLock()
  private var flag = false

  var isSet: Bool {
    lock.lock()
    defer { lock.unlock() }
    return flag
  }

  func set() {
    lock.lock()
    flag = true
    lock.unlock()
  }
}
