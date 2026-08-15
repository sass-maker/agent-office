import Foundation

/// A consequential decision the owner makes about a commitment.
///
/// One payload rather than a bespoke command per decision: they share an actor,
/// a target, and the rule that only the owner may make them.
public enum SupervisionDecision: Codable, Sendable, Equatable {
  case approvePlan(commitmentID: String, note: String)
  case returnPlan(commitmentID: String, instruction: String)
  case replyToHelp(commitmentID: String, message: String)
  case acceptDelivery(commitmentID: String, note: String)
  case requestRevision(commitmentID: String, feedback: String)

  public var commitmentID: String {
    switch self {
    case .approvePlan(let id, _), .returnPlan(let id, _), .replyToHelp(let id, _),
      .acceptDelivery(let id, _), .requestRevision(let id, _):
      id
    }
  }

  public var eventType: String {
    switch self {
    case .approvePlan: "commitment.plan-approved"
    case .returnPlan: "commitment.plan-returned"
    case .replyToHelp: "commitment.help-answered"
    case .acceptDelivery: "commitment.delivery-accepted"
    case .requestRevision: "commitment.revision-requested"
    }
  }
}

extension OrganizationState {
  /// Applies an owner decision.
  ///
  /// The records it writes derive their identifiers from the decision and its
  /// timestamp, so replaying the journalled command reproduces them exactly.
  mutating func apply(_ decision: SupervisionDecision, now: Date) throws {
    switch decision {
    case .approvePlan(let commitmentID, let note):
      try approveOutcomePlan(commitmentID, note: note, now: now)
    case .returnPlan(let commitmentID, let instruction):
      try returnOutcomePlan(commitmentID, instruction: instruction, now: now)
    case .replyToHelp(let commitmentID, let message):
      try replyToOutcome(commitmentID, message: message, now: now)
    case .acceptDelivery(let commitmentID, let note):
      try acceptOutcome(commitmentID, note: note, now: now)
    case .requestRevision(let commitmentID, let feedback):
      try requestOutcomeRevision(commitmentID, feedback: feedback, now: now)
    }
  }
}
