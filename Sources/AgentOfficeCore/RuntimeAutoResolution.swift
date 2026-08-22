import Foundation

/// A runtime that automatic resolution is permitted to choose.
///
/// Demo is deliberately **not representable here**. This is the structural half
/// of "never silently substitute Demo": there is no value of this type that
/// denotes rehearsal, so no automatic branch of the resolver — present or
/// future — can produce one. A rehearsal can only enter a selection through
/// `SelectedRuntime.ownerChosen`, which requires the owner to have named it.
public enum AutoSelectableRuntime: String, Codable, Sendable, CaseIterable, Equatable {
  case codex
  case claudeCode

  /// The order used when nothing else has decided: Codex first, then Claude
  /// Code. Both are real runtimes; running out of them is a refusal, not a
  /// reason to fall back to synthetic work.
  public static let preferenceOrder: [AutoSelectableRuntime] = [.codex, .claudeCode]

  public var driverKind: RuntimeDriverKind {
    switch self {
    case .codex: .localCodex
    case .claudeCode: .localClaudeCode
    }
  }

  public var cli: LocalAgentCLI {
    switch self {
    case .codex: .codex
    case .claudeCode: .claudeCode
    }
  }

  public var displayName: String { cli.displayName }

  /// The gate every automatic path goes through.
  ///
  /// Returns `nil` for Demo and for any runtime that is not a locally installed
  /// agent CLI, so an unusable or synthetic runtime cannot be laundered into an
  /// automatic choice by passing its kind in.
  public init?(driverKind: RuntimeDriverKind) {
    switch driverKind {
    case .localCodex: self = .codex
    case .localClaudeCode: self = .claudeCode
    default: return nil
    }
  }
}

/// How a runtime came to be selected.
///
/// The two cases are not interchangeable: `automatic` carries a type that
/// cannot name Demo, and `ownerChosen` is the only route by which a rehearsal
/// can be selected at all.
public enum SelectedRuntime: Sendable, Equatable {
  case automatic(AutoSelectableRuntime)
  case ownerChosen(RuntimeDriverKind)

  public var driverKind: RuntimeDriverKind {
    switch self {
    case .automatic(let runtime): runtime.driverKind
    case .ownerChosen(let kind): kind
    }
  }

  public var wasChosenByOwner: Bool {
    if case .ownerChosen = self { return true }
    return false
  }
}

/// Which of the resolution rules decided, kept so the owner can be shown why
/// this runtime is running rather than being asked to trust it.
public enum RuntimeSelectionRule: String, Codable, Sendable, Equatable {
  /// Rule 1.
  case explicitEmployeeChoice
  /// Rule 2.
  case lastSuccessfulRuntime
  /// Rule 3.
  case packagePreference
  /// Rule 4.
  case firstHealthyRuntime
  /// Rule 6.
  case pinnedToActiveCommitment
}

/// The runtime and model an employee will actually run on.
public struct ResolvedRuntimeSelection: Sendable, Equatable {
  public var runtime: SelectedRuntime
  public var model: RuntimeModelChoice
  public var rule: RuntimeSelectionRule

  public init(runtime: SelectedRuntime, model: RuntimeModelChoice, rule: RuntimeSelectionRule) {
    self.runtime = runtime
    self.model = model
    self.rule = rule
  }

  public var driverKind: RuntimeDriverKind { runtime.driverKind }

  /// Whether this is rehearsal rather than real work.
  ///
  /// True only when the owner asked for it: an automatic selection cannot name
  /// Demo, so a rehearsal always carries the owner's own decision.
  public var isRehearsal: Bool { driverKind == .demo }

  /// What to record on the session and the receipt. Rule 5.
  ///
  /// `modelName` is `nil` for Auto, because the honest record of "no override
  /// was sent" is not the name of whichever model the runtime happened to pick.
  public func receiptWork(
    employeeID: String, subject: ScheduleSubject, authorityUsed: [String] = []
  ) -> ReceiptWork {
    ReceiptWork(
      employeeID: employeeID,
      subject: subject,
      runtimeKind: driverKind.rawValue,
      modelName: model.recordedName,
      authorityUsed: authorityUsed
    )
  }

  /// A one-line explanation for the session record.
  public var evidenceSummary: String {
    let modelText = model.recordedName ?? "the runtime's default model"
    return "Ran on \(driverKind.displayName) with \(modelText) (\(rule.rawValue))."
  }
}

/// Why no runtime could be selected.
///
/// Blocking is a first-class outcome. An employee that cannot run is reported as
/// such, because a rehearsal presented as work is worse than no work.
public struct RuntimeSelectionRefusal: Sendable, Equatable {
  public enum Cause: Sendable, Equatable {
    /// Rule 7. Nothing healthy to run on, and Demo is not a stand-in.
    case noHealthyRuntime(checked: [AutoSelectableRuntime])
    /// Rule 1. The owner named a runtime that cannot be used right now.
    case explicitRuntimeUnavailable(RuntimeDriverKind, detail: String)
    /// Rule 6. The runtime this commitment started on is gone.
    case activeCommitmentRuntimeLost(RuntimeDriverKind, detail: String)
  }

  public var cause: Cause

  public init(cause: Cause) {
    self.cause = cause
  }

  public var reason: String {
    switch cause {
    case .noHealthyRuntime(let checked):
      let names = checked.map(\.displayName).joined(separator: " or ")
      return
        "No working runtime is available, so this employee is blocked rather than rehearsing. Install or reconnect \(names), or choose Practice mode deliberately if a rehearsal is what you want."
    case .explicitRuntimeUnavailable(let kind, let detail):
      return
        "This employee is set to \(kind.displayName), which cannot run right now, and Office OS will not swap in a different runtime on your behalf. \(detail)"
    case .activeCommitmentRuntimeLost(let kind, let detail):
      return
        "This commitment started on \(kind.displayName) and cannot be moved to another runtime while it is still open. \(detail)"
    }
  }
}

public enum RuntimeSelectionOutcome: Sendable, Equatable {
  case selected(ResolvedRuntimeSelection)
  case blocked(RuntimeSelectionRefusal)

  public var selection: ResolvedRuntimeSelection? {
    if case .selected(let selection) = self { return selection }
    return nil
  }

  public var refusal: RuntimeSelectionRefusal? {
    if case .blocked(let refusal) = self { return refusal }
    return nil
  }
}

/// Everything resolution is allowed to consider.
///
/// Passed in rather than read from the world so the policy is a pure function
/// that can be tested exhaustively on a machine with no agent CLI installed.
public struct RuntimeSelectionInputs: Sendable {
  /// Rule 1. The runtime the owner named for this employee, if any. This is the
  /// only channel through which Demo can be selected.
  public var explicitChoice: RuntimeDriverKind?
  /// Rule 2. The last runtime that finished work for this employee.
  public var lastSuccessful: RuntimeDriverKind?
  /// Rule 3. What this employee's package prefers.
  public var packagePreference: RuntimeDriverKind?
  /// Rule 6. The runtime an already-open commitment is running on.
  public var activeCommitmentRuntime: RuntimeDriverKind?
  /// Observed health per runtime. A runtime absent from this map is treated as
  /// unavailable, so forgetting to probe one can never read as healthy.
  public var health: [RuntimeDriverKind: RuntimeAvailability]
  /// The model named on the working contract, or `auto`.
  public var contractModel: RuntimeModelChoice
  /// The model the package suggests, used only when the contract says `auto`.
  public var packageModel: RuntimeModelChoice

  public init(
    explicitChoice: RuntimeDriverKind? = nil,
    lastSuccessful: RuntimeDriverKind? = nil,
    packagePreference: RuntimeDriverKind? = nil,
    activeCommitmentRuntime: RuntimeDriverKind? = nil,
    health: [RuntimeDriverKind: RuntimeAvailability] = [:],
    contractModel: RuntimeModelChoice = .auto,
    packageModel: RuntimeModelChoice = .auto
  ) {
    self.explicitChoice = explicitChoice
    self.lastSuccessful = lastSuccessful
    self.packagePreference = packagePreference
    self.activeCommitmentRuntime = activeCommitmentRuntime
    self.health = health
    self.contractModel = contractModel
    self.packageModel = packageModel
  }

  func availability(of kind: RuntimeDriverKind) -> RuntimeAvailability {
    health[kind] ?? .unavailable(reason: "Office OS has not confirmed that this runtime works.")
  }

  func isHealthy(_ kind: RuntimeDriverKind) -> Bool { availability(of: kind).isAvailable }

  /// The model to use once a runtime is chosen. Contract wins over package, and
  /// `auto` means no override is sent at all.
  var resolvedModel: RuntimeModelChoice {
    contractModel.isAuto ? packageModel : contractModel
  }
}

/// Decides which runtime an employee runs on, in one place.
///
/// The rules are applied in a fixed order, and each one is a separate, named
/// step so a change in policy is a visible change here rather than a behaviour
/// that drifts across call sites.
public struct RuntimeAutoResolver: Sendable {
  public init() {}

  public func resolve(_ inputs: RuntimeSelectionInputs) -> RuntimeSelectionOutcome {
    let model = inputs.resolvedModel

    // Rule 6, applied first because it is a constraint rather than a
    // preference: a commitment that is already running does not change runtime
    // underneath itself, not even to honour a newer explicit choice.
    if let pinned = inputs.activeCommitmentRuntime {
      // Pinning may only preserve a real runtime, or a rehearsal the owner
      // themselves chose. A commitment pinned to Demo that the owner did not
      // ask for is incoherent state, and continuing it would be the silent
      // rehearsal rule 7 forbids — so it blocks instead.
      guard let runtime = pinnedRuntime(pinned, ownerChose: pinned == inputs.explicitChoice) else {
        return .blocked(
          RuntimeSelectionRefusal(
            cause: .activeCommitmentRuntimeLost(
              pinned,
              detail:
                "Office OS cannot confirm that this employee was set to \(pinned.displayName) when the work started."
            )))
      }
      guard inputs.isHealthy(pinned) else {
        return .blocked(
          RuntimeSelectionRefusal(
            cause: .activeCommitmentRuntimeLost(
              pinned, detail: inputs.availability(of: pinned).reason ?? "")))
      }
      return .selected(
        ResolvedRuntimeSelection(
          runtime: runtime, model: model, rule: .pinnedToActiveCommitment))
    }

    // Rule 1. An explicit choice is preserved, which means it is also allowed
    // to fail. Falling through to another runtime here would be exactly the
    // silent substitution the policy forbids.
    if let explicit = inputs.explicitChoice {
      guard inputs.isHealthy(explicit) else {
        return .blocked(
          RuntimeSelectionRefusal(
            cause: .explicitRuntimeUnavailable(
              explicit, detail: inputs.availability(of: explicit).reason ?? "")))
      }
      return .selected(
        ResolvedRuntimeSelection(
          runtime: .ownerChosen(explicit), model: model, rule: .explicitEmployeeChoice))
    }

    // Rules 2, 3, and 4 are automatic, so each candidate must pass through
    // `AutoSelectableRuntime`. Demo cannot survive that conversion.
    if let selection = automatic(inputs.lastSuccessful, inputs, model, .lastSuccessfulRuntime) {
      return .selected(selection)
    }
    if let selection = automatic(inputs.packagePreference, inputs, model, .packagePreference) {
      return .selected(selection)
    }
    for candidate in AutoSelectableRuntime.preferenceOrder
    where inputs.isHealthy(candidate.driverKind) {
      return .selected(
        ResolvedRuntimeSelection(
          runtime: .automatic(candidate), model: model, rule: .firstHealthyRuntime))
    }

    // Rule 7. Out of real runtimes is a refusal, never a rehearsal.
    return .blocked(
      RuntimeSelectionRefusal(
        cause: .noHealthyRuntime(checked: AutoSelectableRuntime.preferenceOrder)))
  }

  // MARK: - Internals

  private func automatic(
    _ candidate: RuntimeDriverKind?,
    _ inputs: RuntimeSelectionInputs,
    _ model: RuntimeModelChoice,
    _ rule: RuntimeSelectionRule
  ) -> ResolvedRuntimeSelection? {
    guard let candidate,
      let runtime = AutoSelectableRuntime(driverKind: candidate),
      inputs.isHealthy(candidate)
    else { return nil }
    return ResolvedRuntimeSelection(runtime: .automatic(runtime), model: model, rule: rule)
  }

  /// Keeps a pinned runtime's provenance honest.
  ///
  /// Returns `nil` when the pin cannot be justified: not a real runtime, and not
  /// something the owner asked for. Rule 6 preserves a runtime; it does not
  /// invent authority for one.
  private func pinnedRuntime(_ kind: RuntimeDriverKind, ownerChose: Bool) -> SelectedRuntime? {
    if ownerChose { return .ownerChosen(kind) }
    return AutoSelectableRuntime(driverKind: kind).map(SelectedRuntime.automatic)
  }
}
