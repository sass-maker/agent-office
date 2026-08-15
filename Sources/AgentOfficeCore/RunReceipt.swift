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
  case blocked
  case failed
  case skipped
  /// The runtime never started, so nothing was observed either way.
  case neverRan

  public var isHonestSuccess: Bool { self == .changed || self == .quiet }
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

  public init(
    kind: RunResultKind,
    summary: String,
    evidenceIDs: [String] = [],
    usage: RunUsage = .unknown
  ) {
    self.kind = kind
    self.summary = summary
    self.evidenceIDs = evidenceIDs
    self.usage = usage
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
    case .blocked: "Started but could not continue."
    case .failed: "Did not finish."
    case .skipped: "Skipped before it ran."
    case .neverRan: "Never started, so nothing was observed."
    }
  }
}
