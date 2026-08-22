import Foundation

/// What a run cost, when that is knowable.
///
/// Three-valued on purpose: a runtime that reports nothing yields `unknown`,
/// never zero, because zero is a claim.
public enum RunUsage: Codable, Sendable, Equatable {
  case observed(description: String)
  case unknown
  case notApplicable
}

/// What a run actually amounted to.
public enum RunResultKind: String, Codable, Sendable, CaseIterable {
  /// Ran and changed something.
  case changed
  /// Ran and found nothing to change. A valid, successful outcome.
  case quiet
  /// Ran, did its part, and handed a decision back to the owner.
  ///
  /// Deliberately distinct from `blocked`: nothing is wrong, and the employee is
  /// not stuck on something it could fix. Collapsing the two would tell an owner
  /// to go fix a runtime when what is actually needed is an answer.
  case waitingForOwner
  case blocked
  case failed
  case skipped
  /// The owner or the organization stopped this before it could finish.
  ///
  /// Distinct from `skipped`, which is a window passed over without anyone
  /// deciding anything.
  case cancelled
  /// The runtime never started, so nothing was observed either way.
  case neverRan

  public var isHonestSuccess: Bool { self == .changed || self == .quiet }

  /// Whether the next move belongs to the owner rather than to the employee.
  public var awaitsOwner: Bool {
    self == .waitingForOwner || self == .blocked || self == .failed
  }
}

/// Who has to act next, and what the act is.
///
/// Recorded rather than inferred from the state, because "delivered" and "the
/// owner still has to accept it" are two different facts and only the second
/// one tells the owner whether anything is waiting on them.
public struct ReceiptNextAction: Codable, Sendable, Equatable {
  /// Who the next move belongs to.
  public enum Owner: String, Codable, Sendable, CaseIterable {
    /// The human who runs the organization.
    case owner
    /// The same employee, on its next window.
    case employee
    /// The employee named as reviewer for this work.
    case reviewer
    /// Nothing is outstanding. Said explicitly so an empty next action cannot
    /// be mistaken for "we did not look".
    case nobody

    public var displayName: String {
      switch self {
      case .owner: "You"
      case .employee: "The employee"
      case .reviewer: "The reviewer"
      case .nobody: "Nobody"
      }
    }
  }

  public var owner: Owner
  public var detail: String

  public init(owner: Owner, detail: String) {
    self.owner = owner
    self.detail = detail
  }

  public static let nothingOutstanding = ReceiptNextAction(
    owner: .nobody, detail: "Nothing is waiting on anyone.")

  /// One line naming who and what, for a surface that has room for a sentence.
  public var statement: String { "\(owner.displayName): \(detail)" }
}

/// Who owned the run and what powered it.
public struct ReceiptWork: Codable, Sendable, Equatable {
  public var employeeID: String
  public var subject: ScheduleSubject
  public var runtimeKind: String?
  public var modelName: String?
  /// Capabilities and connections the run actually used, by reference.
  public var authorityUsed: [String]

  public init(
    employeeID: String,
    subject: ScheduleSubject,
    runtimeKind: String? = nil,
    modelName: String? = nil,
    authorityUsed: [String] = []
  ) {
    self.employeeID = employeeID
    self.subject = subject
    self.runtimeKind = runtimeKind
    self.modelName = modelName
    self.authorityUsed = authorityUsed
  }
}

/// What the run produced.
public struct ReceiptResult: Codable, Sendable, Equatable {
  public var kind: RunResultKind
  public var summary: String
  public var evidenceIDs: [String]
  public var usage: RunUsage
  /// What is outstanding, and whose move it is.
  ///
  /// Optional so receipts written before this existed decode unchanged; when it
  /// is absent the surfaces say so rather than guessing.
  public var nextAction: ReceiptNextAction?

  public init(
    kind: RunResultKind,
    summary: String,
    evidenceIDs: [String] = [],
    usage: RunUsage = .unknown,
    nextAction: ReceiptNextAction? = nil
  ) {
    self.kind = kind
    self.summary = summary
    self.evidenceIDs = evidenceIDs
    self.usage = usage
    self.nextAction = nextAction
  }

  /// What this run can be checked against, stated even when the answer is
  /// nothing.
  ///
  /// "No evidence" is a finding an owner needs to see. Rendering an empty list
  /// as blank space would read as though the surface had simply not looked.
  public var evidenceStatement: String {
    evidenceIDs.isEmpty
      ? "No evidence was produced by this run."
      : "Evidence: \(evidenceIDs.joined(separator: ", "))"
  }
}

/// The honest record of one terminal occurrence.
public struct RunReceipt: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var occurrenceID: String
  /// Why this was scheduled, in the owner's terms.
  public var scheduledReason: String
  public var scheduledWindow: OccurrenceWindow
  public var actual: OccurrenceActual?
  public var work: ReceiptWork
  public var result: ReceiptResult
  public var createdAt: Date

  public init(
    occurrenceID: String,
    scheduledReason: String,
    scheduledWindow: OccurrenceWindow,
    actual: OccurrenceActual?,
    work: ReceiptWork,
    result: ReceiptResult,
    createdAt: Date = Date()
  ) {
    self.id = "receipt-\(occurrenceID)"
    self.occurrenceID = occurrenceID
    self.scheduledReason = scheduledReason
    self.scheduledWindow = scheduledWindow
    self.actual = actual
    self.work = work
    self.result = result
    self.createdAt = createdAt
  }

  public var observedDuration: TimeInterval? { actual?.duration }

  /// A one-line answer to "did anything happen?" that never overstates.
  public var headline: String {
    switch result.kind {
    case .changed: "Ran and changed something."
    case .quiet: "Ran and found nothing to change."
    case .waitingForOwner: "Ran and handed a decision back to you."
    case .blocked: "Started but could not continue."
    case .failed: "Did not finish."
    case .skipped: "Skipped before it ran."
    case .cancelled: "Stopped before it finished."
    case .neverRan: "Never started, so nothing was observed."
    }
  }

  /// Whose move it is now, said explicitly even when the receipt predates the
  /// field.
  public var nextAction: ReceiptNextAction {
    result.nextAction
      ?? ReceiptNextAction(
        owner: result.kind.awaitsOwner ? .owner : .nobody,
        detail: result.kind.awaitsOwner
          ? "This run recorded no next action. Read the summary and decide."
          : "This run recorded no next action, and nothing appears outstanding."
      )
  }
}
