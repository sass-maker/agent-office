import Foundation

/// A durable thing in the organization, named by kind and identifier.
///
/// One type for both purposes: history reads by entity, and leases are held
/// over the same entities. Two near-identical reference types would drift.
public struct OrganizationEntityReference: Codable, Sendable, Equatable, Hashable {
  public enum Kind: String, Codable, Sendable {
    case employee
    case commitment
    case task
    case artifact
    case record
    case connection
    case workspace
  }

  public var kind: Kind
  public var id: String

  public init(kind: Kind, id: String) {
    self.kind = kind
    self.id = id
  }

  public static func employee(_ id: String) -> Self { .init(kind: .employee, id: id) }
  public static func commitment(_ id: String) -> Self { .init(kind: .commitment, id: id) }
  public static func task(_ id: String) -> Self { .init(kind: .task, id: id) }
  public static func artifact(_ id: String) -> Self { .init(kind: .artifact, id: id) }
  public static func record(_ id: String) -> Self { .init(kind: .record, id: id) }
  public static func connection(_ id: String) -> Self { .init(kind: .connection, id: id) }
  public static func workspace(_ id: String) -> Self { .init(kind: .workspace, id: id) }
}

/// The same durable things, named as leases talk about them.
public typealias OrganizationResource = OrganizationEntityReference

/// One accepted organization transition.
///
/// Events are the authoritative history. The snapshot stays the fast read path;
/// this is what explains how the snapshot came to look the way it does.
public struct OrganizationEvent: Codable, Sendable, Equatable {
  public var id: String
  /// Assigned by the journal. Ordering is by sequence, never by timestamp.
  public var sequence: Int
  public var schemaVersion: Int
  public var type: String
  public var actor: OrganizationActor
  public var occurredAt: Date
  public var correlationID: String
  public var causationID: String?
  public var idempotencyKey: String
  public var entities: [OrganizationEntityReference]
  public var payload: OrganizationCommandPayload
  /// Identifiers the command produced, replayed verbatim so reconstruction
  /// cannot invent different ones.
  public var producedIDs: [String]

  // Constructed inside AgentOfficeCore by the command processor, which is the
  // only thing allowed to decide an event's sequence.

  public func references(_ reference: OrganizationEntityReference) -> Bool {
    entities.contains(reference)
  }
}
