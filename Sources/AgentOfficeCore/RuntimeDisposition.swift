import Foundation

/// Where one employee stands with respect to the runtime they would work on.
///
/// Three states, because a screen that offers only two of them has to lie about
/// the third: an employee can be about to do real work, about to rehearse, or
/// blocked with nothing to run on.
public enum RuntimeStanding: Sendable, Equatable {
  /// A real runtime resolved, so anything this employee produces is real work.
  case real
  /// The owner asked for a rehearsal. Nothing reaches outside the company
  /// folder.
  case rehearsal
  /// No runtime could be selected, so no work can start at all.
  case blocked
}

/// What one employee's screens must say about the runtime they will actually
/// work on.
///
/// The views used to answer this from the organization-wide execution mode,
/// which gets three things wrong: it cannot name Claude Code at all, it labels a
/// contract-driven real run as a rehearsal (and the reverse), and it therefore
/// disagrees with the preflight gates that decide whether the run happens. This
/// resolves the same policy those gates resolve, so a screen and the gate behind
/// it can no longer contradict each other.
public struct RuntimeDisposition: Sendable, Equatable {
  /// The runtime the policy chose, or `nil` when it refused.
  public var runtimeKind: RuntimeDriverKind?

  /// Why nothing could be selected, kept whole rather than flattened to text
  /// because which remedies can help depends on the cause, not on the wording.
  public var refusal: RuntimeSelectionRefusal?

  public init(runtimeKind: RuntimeDriverKind? = nil, refusal: RuntimeSelectionRefusal? = nil) {
    self.runtimeKind = runtimeKind
    self.refusal = refusal
  }

  /// The refusal in the policy's own words, which is what an owner is shown.
  public var refusalReason: String? { refusal?.reason }

  public var standing: RuntimeStanding {
    guard let runtimeKind else { return .blocked }
    return runtimeKind == .demo ? .rehearsal : .real
  }

  public var isBlocked: Bool { standing == .blocked }

  public var isRehearsal: Bool { standing == .rehearsal }

  /// Whether this employee's output will be real work rather than a rehearsal.
  ///
  /// The same question `RuntimePreflight.performsRealWork` answers for a whole
  /// roster, so a screen and a gate agree by construction.
  public var performsRealWork: Bool { standing == .real }

  /// How to name the chosen runtime to an owner, or `nil` when none was chosen.
  public var runtimeName: String? { runtimeKind?.displayName }

  /// Whether the owner still has to hand over the read-only web-research key
  /// before this employee's research can run.
  ///
  /// False for a rehearsal, which never reaches the network, and false when the
  /// employee is blocked, because granting a key cannot supply a missing
  /// runtime — offering the grant there would be a button that resolves
  /// nothing.
  public func needsWebResearchGrant(granted: Bool) -> Bool {
    performsRealWork && !granted
  }
}

extension OrganizationState {
  /// Resolves what one employee's screens should say, using the same policy the
  /// preflight gates use.
  public func runtimeDisposition(
    for employeeID: String,
    health: RuntimeHealthSnapshot,
    commitmentID: String? = nil
  ) -> RuntimeDisposition {
    let outcome = resolveRuntime(for: employeeID, health: health, commitmentID: commitmentID)
    return RuntimeDisposition(
      runtimeKind: outcome.selection?.driverKind, refusal: outcome.refusal)
  }
}

/// An action a waiting research assignment may offer its owner.
///
/// Every case has to be something that can actually change the resolver's
/// answer for this employee. The card previously offered "Use a practice run"
/// whenever the organization-wide mode said Codex and Codex was missing — a
/// question about the organization standing in for a refusal about one
/// employee, so it appeared for people who were not blocked and stayed hidden
/// for people who were.
public enum RuntimeRemedy: Sendable, Equatable {
  /// Hand over the read-only web-research key this employee is waiting on.
  case grantWebResearch

  /// Nothing is blocked and no permission is missing, so the work can simply be
  /// tried again.
  case retry

  /// Look for the runtime again. The refusal names something that is not on
  /// this Mac right now, so installing or reconnecting it and re-probing is the
  /// remedy that keeps every runtime choice the owner has made.
  case recheckRuntimeInstallations(reason: String)

  /// Move the whole organization to Practice mode.
  ///
  /// Honest about its blast radius: this rewrites every hired employee's
  /// working contract, so it is an escape hatch out of blocked work rather than
  /// a fix for one assignment. Changing one employee's runtime is a contract
  /// edit, which belongs in the contract editor where a revision gets an author
  /// and a reason.
  case rehearseWholeOrganization
}

extension RuntimeDisposition {
  /// Whether the refusal is a commitment already open on a runtime that has
  /// gone. Rewriting contracts cannot move an open commitment, so a rehearsal
  /// is not a way out of this one.
  private var refusalIsAnOpenCommitmentPin: Bool {
    if case .activeCommitmentRuntimeLost = refusal?.cause { return true }
    return false
  }

  /// What to offer an owner looking at work that is waiting on them, best
  /// remedy first.
  public func waitingRemedies(webResearchGranted: Bool) -> [RuntimeRemedy] {
    if let reason = refusalReason {
      var remedies: [RuntimeRemedy] = [.recheckRuntimeInstallations(reason: reason)]
      if !refusalIsAnOpenCommitmentPin { remedies.append(.rehearseWholeOrganization) }
      return remedies
    }
    if needsWebResearchGrant(granted: webResearchGranted) { return [.grantWebResearch] }
    return [.retry]
  }
}

/// One runtime statement for an owner: what will happen, and what that means.
///
/// Assembled here rather than in a view so the wording is decided by the same
/// resolved facts as the work itself, and can be tested without a runtime
/// installed.
public struct RuntimeNotice: Sendable, Equatable {
  public var standing: RuntimeStanding
  public var title: String
  public var detail: String

  public init(standing: RuntimeStanding, title: String, detail: String) {
    self.standing = standing
    self.title = title
    self.detail = detail
  }
}

extension RuntimeDisposition {
  /// The boundary that holds for every real or rehearsed run alike.
  private static let boundaryLine =
    "No self-granted permissions, publishing, spending, or writes outside this company folder."

  /// The runtime line shown above a new research assignment.
  public func researchNotice(employeeName: String, webResearchGranted: Bool) -> RuntimeNotice {
    if let refusal = refusalReason {
      return RuntimeNotice(
        standing: .blocked, title: "No runtime is available", detail: refusal)
    }
    if isRehearsal {
      return RuntimeNotice(
        standing: .rehearsal,
        title: "Practice run — no web",
        detail:
          "No web research will occur. The brief will be clearly marked as a rehearsal based only on your context."
      )
    }
    let runtime = runtimeName ?? "this runtime"
    if webResearchGranted {
      return RuntimeNotice(
        standing: .real,
        title: "Read-only web research granted",
        detail:
          "\(employeeName) may read public web sources while working on \(runtime), and cannot publish, message people, or change external systems."
      )
    }
    return RuntimeNotice(
      standing: .real,
      title: "\(employeeName) will ask before researching",
      detail:
        "This assignment runs on \(runtime) and will wait on your desk until you grant read-only web research."
    )
  }

  /// The runtime chip shown beside the button that assigns an outcome.
  public func assignmentNotice(employeeName: String) -> RuntimeNotice {
    if let refusal = refusalReason {
      return RuntimeNotice(
        standing: .blocked,
        title: "No runtime is available for \(employeeName)",
        detail: refusal
      )
    }
    if isRehearsal {
      return RuntimeNotice(
        standing: .rehearsal,
        title: "Practice with the Demo team",
        detail: Self.boundaryLine
      )
    }
    return RuntimeNotice(
      standing: .real,
      title: "Work with \(runtimeName ?? "the selected runtime")",
      detail: Self.boundaryLine
    )
  }
}
