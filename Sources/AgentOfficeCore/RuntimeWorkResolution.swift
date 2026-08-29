import Foundation

/// What Office OS has actually observed about the runtimes installed on this
/// Mac.
///
/// Passed into the work engines rather than probed by them, so the runtime
/// policy stays a pure decision over stated facts and a test can describe a
/// machine it is not running on.
public struct RuntimeHealthSnapshot: Sendable, Equatable {
  private var observed: [RuntimeDriverKind: RuntimeAvailability]

  public init(_ observed: [RuntimeDriverKind: RuntimeAvailability] = [:]) {
    self.observed = observed
  }

  /// No real runtime is known to work.
  ///
  /// This is the default the engines assume when a caller says nothing, because
  /// the fail-closed direction is refusing to work — never quietly rehearsing.
  /// An employee left on Auto is blocked under this snapshot rather than being
  /// handed Practice mode.
  public static let practiceOnly = RuntimeHealthSnapshot()

  /// Describes the two local agent CLIs, which is all automatic resolution is
  /// ever allowed to choose between.
  public static func localAgents(
    codex: RuntimeAvailability = .unavailable(reason: "Codex was not found on this Mac."),
    claudeCode: RuntimeAvailability = .unavailable(reason: "Claude Code was not found on this Mac.")
  ) -> RuntimeHealthSnapshot {
    RuntimeHealthSnapshot([.localCodex: codex, .localClaudeCode: claudeCode])
  }

  /// Health as the resolver reads it.
  ///
  /// Practice mode is always reported as available because it installs nothing
  /// and so can never be missing. That is not a loophole: rule 7 forbids
  /// *choosing* a rehearsal automatically, which `AutoSelectableRuntime`
  /// enforces structurally, and reporting Demo as broken would only hide an
  /// owner's own explicit rehearsal behind a reason that is not true.
  public var availability: [RuntimeDriverKind: RuntimeAvailability] {
    var all = observed
    all[.demo] = .available
    return all
  }

  public func availability(of kind: RuntimeDriverKind) -> RuntimeAvailability {
    availability[kind]
      ?? .unavailable(reason: "Office OS has not confirmed that this runtime works.")
  }

  /// Whether anything real could be chosen automatically right now.
  public var hasHealthyRealRuntime: Bool {
    AutoSelectableRuntime.allCases.contains { availability(of: $0.driverKind).isAvailable }
  }
}

extension OrganizationState {
  /// The runtime an employee last actually finished work on. Rule 2.
  ///
  /// Read from receipts rather than from the binding, because a binding records
  /// intent and a receipt records what happened. Only an honest success counts:
  /// a runtime that blocked or failed has not earned being reused.
  public func lastSuccessfulRuntimeKind(for employeeID: String) -> RuntimeDriverKind? {
    runReceipts
      .filter { $0.work.employeeID == employeeID && $0.result.kind.isHonestSuccess }
      .sorted { $0.createdAt < $1.createdAt }
      .last
      .flatMap { $0.work.runtimeKind }
      .map(RuntimeDriverKind.init(rawValue:))
  }

  /// The runtime an already-open commitment started on. Rule 6.
  ///
  /// Only an unfinished commitment pins anything; a delivered or terminal one
  /// has nothing left to protect from a runtime change.
  public func pinnedRuntimeKind(forCommitment commitmentID: String?) -> RuntimeDriverKind? {
    guard let commitmentID, let outcome = employeeOutcome(commitmentID),
      !outcome.status.isTerminal, outcome.status != .delivered,
      let runtime = outcome.runtime
    else { return nil }
    return RuntimeDriverKind(rawValue: runtime.kind)
  }

  /// Everything the runtime policy is allowed to consider for one employee,
  /// gathered from canonical organization state.
  public func runtimeSelectionInputs(
    for employeeID: String,
    health: RuntimeHealthSnapshot,
    commitmentID: String? = nil
  ) -> RuntimeSelectionInputs {
    let contract = workingContract(for: employeeID)
    let package = employee(employeeID)?.packageID.flatMap {
      employeePackage(id: $0, version: employee(employeeID)?.packageVersion)
    }
    // A contract is the canonical statement of what the owner chose. An
    // organization that predates working contracts has still made a choice —
    // the org-wide execution mode — so that stands in rather than being read as
    // Auto, which would silently widen the owner's decision.
    let explicit =
      contract.map(\.executionProvider) ?? EmployeeExecutionProvider(executionMode)
    return RuntimeSelectionInputs(
      explicitChoice: explicit.explicitDriverKind,
      lastSuccessful: lastSuccessfulRuntimeKind(for: employeeID),
      packagePreference: package?.preferredProvider.explicitDriverKind,
      activeCommitmentRuntime: pinnedRuntimeKind(forCommitment: commitmentID),
      health: health.availability,
      contractModel: RuntimeModelChoice(modelName: contract?.modelName),
      packageModel: RuntimeModelChoice(modelName: package?.defaultModelName)
    )
  }

  /// Decides what this employee runs on, for callers that must not invent their
  /// own answer.
  ///
  /// This is the single production entry point for the seven-rule policy. Work
  /// engines call it before running anything, so "which runtime" is answered the
  /// same way whether the work came from the calendar, an owner, or a schedule.
  public func resolveRuntime(
    for employeeID: String,
    health: RuntimeHealthSnapshot,
    commitmentID: String? = nil,
    using resolver: RuntimeAutoResolver = RuntimeAutoResolver()
  ) -> RuntimeSelectionOutcome {
    resolver.resolve(
      runtimeSelectionInputs(for: employeeID, health: health, commitmentID: commitmentID))
  }

  /// Points an employee's binding at the runtime resolution actually chose.
  ///
  /// Keeps the previous runtime as provenance instead of overwriting it, and
  /// does nothing when the binding already names the resolved runtime, so
  /// repeated runs do not accumulate empty history.
  @discardableResult
  public mutating func bindResolvedRuntime(
    _ selection: ResolvedRuntimeSelection, for employeeID: String, now: Date = Date()
  ) -> RuntimeBinding {
    let current = effectiveRuntimeBinding(for: employeeID, now: now)
    guard current.driverKind != selection.driverKind else {
      setRuntimeBinding(current)
      return current
    }
    let rebound = current.rebound(
      to: RuntimeDriverIdentity(kind: selection.driverKind, version: current.driverVersion),
      reason:
        "Runtime resolution chose \(selection.driverKind.displayName) (\(selection.rule.rawValue)).",
      now: now
    )
    setRuntimeBinding(rebound)
    return rebound
  }
}

/// What an owner-facing entry point needs to know before it starts work.
///
/// Preflight asks the seven-rule policy the same question the work engines ask,
/// rather than reading the legacy organization-wide execution mode. Two facts
/// come back: whether anyone is blocked, and whether the work that would run is
/// real rather than a rehearsal the owner asked for. The second is what decides
/// whether the preconditions that only protect real work — a truthful product
/// brief, a read-only web-research grant — apply to this run at all.
public struct RuntimePreflight: Sendable, Equatable {
  /// Why the work cannot start, or `nil` when every employee resolved to a
  /// runtime.
  public var refusal: String?

  /// Whether at least one employee resolved to a real runtime.
  ///
  /// False for a run that is entirely rehearsal: a rehearsal reaches nothing
  /// outside the company folder, so gating it on a real product brief or a web
  /// grant would block work that could not have misused either.
  public var performsRealWork: Bool

  public init(refusal: String? = nil, performsRealWork: Bool = false) {
    self.refusal = refusal
    self.performsRealWork = performsRealWork
  }

  /// Whether the caller must stop and show `refusal` instead of starting work.
  public var isBlocked: Bool { refusal != nil }
}

extension OrganizationState {
  /// Resolves a runtime for every employee this work needs and reports what
  /// preflight found.
  ///
  /// Every employee is resolved even after one refuses, so the answer does not
  /// depend on the order the roster happens to be listed in. The refusal that
  /// is surfaced is the first one, and one blocked employee blocks the run:
  /// starting a shared mission with a silently missing member would be the
  /// partial rehearsal the runtime policy exists to prevent.
  public func runtimePreflight(
    for employeeIDs: [String],
    health: RuntimeHealthSnapshot,
    commitmentID: String? = nil
  ) -> RuntimePreflight {
    var preflight = RuntimePreflight()
    for employeeID in employeeIDs {
      let outcome = resolveRuntime(for: employeeID, health: health, commitmentID: commitmentID)
      if let selection = outcome.selection {
        preflight.performsRealWork = preflight.performsRealWork || !selection.isRehearsal
      } else if preflight.refusal == nil {
        preflight.refusal = outcome.refusal?.reason
      }
    }
    return preflight
  }

  /// Preflight for work that belongs to one employee.
  public func runtimePreflight(
    for employeeID: String,
    health: RuntimeHealthSnapshot,
    commitmentID: String? = nil
  ) -> RuntimePreflight {
    runtimePreflight(for: [employeeID], health: health, commitmentID: commitmentID)
  }
}

extension EmployeeOutcome {
  /// The runtime this commitment is pinned to, if it has started on one.
  public var resolvedRuntimeKind: RuntimeDriverKind? {
    runtime.map { RuntimeDriverKind(rawValue: $0.kind) }
  }

  /// Whether this commitment is running as a rehearsal the owner asked for.
  public var isRehearsal: Bool { resolvedRuntimeKind == .demo }
}
