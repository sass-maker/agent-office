import Foundation

public enum LeaseAccessMode: String, Codable, Sendable {
  /// Many at once. Reading does not conflict with reading.
  case sharedRead
  /// One at a time, and never alongside a shared read.
  case exclusiveWrite
}

/// A bounded claim over one organization resource.
public struct ResourceLease: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var resource: OrganizationResource
  public var holderEmployeeID: String
  public var mode: LeaseAccessMode
  public var purpose: String
  public var acquiredAt: Date
  public var renewedAt: Date?
  public var expiresAt: Date
  public var releasedAt: Date?

  public init(
    id: String = UUID().uuidString,
    resource: OrganizationResource,
    holderEmployeeID: String,
    mode: LeaseAccessMode,
    purpose: String,
    acquiredAt: Date,
    expiresAt: Date
  ) {
    self.id = id
    self.resource = resource
    self.holderEmployeeID = holderEmployeeID
    self.mode = mode
    self.purpose = purpose
    self.acquiredAt = acquiredAt
    self.renewedAt = nil
    self.expiresAt = expiresAt
    self.releasedAt = nil
  }

  public func isLive(at now: Date) -> Bool { releasedAt == nil && now < expiresAt }
}

public enum LeaseError: LocalizedError, Equatable {
  case heldExclusively(by: String, until: Date, purpose: String)
  case heldByOthers(count: Int, until: Date)
  case missingLease(String)
  case notHolder(String)

  public var errorDescription: String? {
    switch self {
    case .heldExclusively(let holder, let until, let purpose):
      "\(holder) is holding this for ‘\(purpose)’ until \(until.formatted(date: .omitted, time: .shortened)). Nothing was taken from them."
    case .heldByOthers(let count, let until):
      "\(count) other \(count == 1 ? "employee is" : "employees are") reading this until \(until.formatted(date: .omitted, time: .shortened))."
    case .missingLease(let id):
      "There is no lease \(id) to change."
    case .notHolder(let employeeID):
      "\(employeeID) does not hold this lease."
    }
  }
}

extension OrganizationState {
  public var resourceLeases: [ResourceLease] { knowledge?.resourceLeases ?? [] }

  /// Live claims over one resource, most recent first.
  public func liveLeases(on resource: OrganizationResource, now: Date) -> [ResourceLease] {
    resourceLeases
      .filter { $0.resource == resource && $0.isLive(at: now) }
      .sorted { $0.acquiredAt > $1.acquiredAt }
  }

  /// Claims a resource for a bounded time.
  ///
  /// A conflict is refused and names its holder. Nothing is ever preempted:
  /// breaking someone else's lease would make the lease meaningless, and the
  /// interesting cases are owner decisions.
  @discardableResult
  public mutating func acquireLease(
    on resource: OrganizationResource,
    holderEmployeeID: String,
    mode: LeaseAccessMode,
    purpose: String,
    now: Date,
    duration: TimeInterval = 900
  ) throws -> ResourceLease {
    let live = liveLeases(on: resource, now: now)
    if let exclusive = live.first(where: { $0.mode == .exclusiveWrite }) {
      throw LeaseError.heldExclusively(
        by: exclusive.holderEmployeeID, until: exclusive.expiresAt, purpose: exclusive.purpose)
    }
    if mode == .exclusiveWrite, let blocking = live.first {
      throw LeaseError.heldByOthers(count: live.count, until: blocking.expiresAt)
    }

    let lease = ResourceLease(
      resource: resource,
      holderEmployeeID: holderEmployeeID,
      mode: mode,
      purpose: purpose,
      acquiredAt: now,
      expiresAt: now.addingTimeInterval(duration)
    )
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    knowledge?.resourceLeases.append(lease)
    return lease
  }

  /// Extends a live lease held by this employee.
  @discardableResult
  public mutating func renewLease(
    _ leaseID: String, holderEmployeeID: String, now: Date, duration: TimeInterval = 900
  ) throws -> ResourceLease {
    guard let index = knowledge?.resourceLeases.firstIndex(where: { $0.id == leaseID }) else {
      throw LeaseError.missingLease(leaseID)
    }
    guard knowledge!.resourceLeases[index].holderEmployeeID == holderEmployeeID else {
      throw LeaseError.notHolder(holderEmployeeID)
    }
    knowledge!.resourceLeases[index].renewedAt = now
    knowledge!.resourceLeases[index].expiresAt = now.addingTimeInterval(duration)
    return knowledge!.resourceLeases[index]
  }

  public mutating func releaseLease(
    _ leaseID: String, holderEmployeeID: String, now: Date
  ) throws {
    guard let index = knowledge?.resourceLeases.firstIndex(where: { $0.id == leaseID }) else {
      throw LeaseError.missingLease(leaseID)
    }
    guard knowledge!.resourceLeases[index].holderEmployeeID == holderEmployeeID else {
      throw LeaseError.notHolder(holderEmployeeID)
    }
    knowledge!.resourceLeases[index].releasedAt = now
  }

  /// Leases whose time has run out.
  ///
  /// They are reported, not deleted: "who was holding this when it went wrong"
  /// should stay answerable afterwards.
  public func expiredLeases(now: Date) -> [ResourceLease] {
    resourceLeases.filter { $0.releasedAt == nil && now >= $0.expiresAt }
  }
}
