import Foundation

/// One retained step in how something reached its current state.
public struct HistoryEntry: Sendable, Equatable, Identifiable {
  public var id: String
  public var sequence: Int
  public var actorID: String
  public var type: String
  public var occurredAt: Date
}

/// A duration derived from retained records, or an honest admission that
/// nothing supports one.
///
/// `unknown` rather than zero: zero is a measurement, and nothing was measured.
public enum DerivedDuration: Sendable, Equatable {
  case measured(TimeInterval, basis: String)
  case unknown(reason: String)

  public var seconds: TimeInterval? {
    if case .measured(let value, _) = self { return value }
    return nil
  }
}

/// How a commitment actually moved, derived from what was retained.
///
/// Supervision evidence, never a productivity score: it does not rank
/// employees, and it does not treat volume as value.
public struct CommitmentFlowEvidence: Sendable, Equatable {
  public var commitmentID: String
  public var timeToFirstWork: DerivedDuration
  public var timeBlocked: DerivedDuration
  public var timeToDelivery: DerivedDuration
  public var ownerDecisionLatency: DerivedDuration
  /// How many retained records these figures were derived from.
  public var derivedFromRecordCount: Int
}

public struct OrganizationHistoryService: Sendable {
  private let journal: OrganizationJournal

  public init(journal: OrganizationJournal) {
    self.journal = journal
  }

  /// Retained events about one entity, oldest first.
  ///
  /// Returns what was recorded and nothing else: an entity with no events has an
  /// empty history rather than a reconstruction.
  public func history(of reference: OrganizationEntityReference) throws -> [HistoryEntry] {
    try journal.events(referencing: reference).map { event in
      HistoryEntry(
        id: event.id,
        sequence: event.sequence,
        actorID: event.actor.id,
        type: event.type,
        occurredAt: event.occurredAt
      )
    }
  }
}

extension OrganizationState {
  /// Timing derived from the records this organization actually kept.
  ///
  /// Deliberately built from durable records — plan approvals, blockers,
  /// deliveries, acceptance — rather than from a new stream of writes, so it
  /// measures what already happened instead of changing what gets recorded.
  public func flowEvidence(forCommitment commitmentID: String) -> CommitmentFlowEvidence? {
    guard let commitment = employeeOutcome(commitmentID) else { return nil }
    let decisions = supervisionEvents.filter { $0.outcomeID == commitmentID }
      .sorted { $0.createdAt < $1.createdAt }
    let commitmentBlockers = blockers.filter { commitment.taskIDs.contains($0.taskID) }
      .sorted { $0.createdAt < $1.createdAt }

    let planApproved = decisions.first { $0.kind == .planApproved }?.createdAt
    let blockedAt = commitmentBlockers.first?.createdAt
    let ownerReplied = decisions.first { $0.kind == .ownerReplied }?.createdAt
    let deliveredAt = commitment.effectiveDeliveries.last?.createdAt
    let acceptedAt = commitment.acceptedAt

    return CommitmentFlowEvidence(
      commitmentID: commitmentID,
      timeToFirstWork: Self.between(
        commitment.createdAt, planApproved,
        basis: "commitment creation to approved plan",
        missing: "No plan approval was recorded for this commitment."
      ),
      timeBlocked: Self.between(
        blockedAt, ownerReplied,
        basis: "recorded blocker to owner reply",
        missing: "This commitment was never recorded as blocked."
      ),
      timeToDelivery: Self.between(
        commitment.createdAt, deliveredAt,
        basis: "commitment creation to recorded delivery",
        missing: "Nothing has been delivered for this commitment yet."
      ),
      ownerDecisionLatency: Self.between(
        deliveredAt, acceptedAt,
        basis: "delivery to owner acceptance",
        missing: "The owner has not accepted a delivery for this commitment."
      ),
      derivedFromRecordCount: decisions.count + commitmentBlockers.count
        + commitment.effectiveDeliveries.count
    )
  }

  private static func between(
    _ start: Date?, _ end: Date?, basis: String, missing: String
  ) -> DerivedDuration {
    guard let start, let end, end >= start else { return .unknown(reason: missing) }
    return .measured(end.timeIntervalSince(start), basis: basis)
  }
}
