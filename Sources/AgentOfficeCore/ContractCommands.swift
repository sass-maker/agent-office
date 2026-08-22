import Foundation

/// A revision the owner makes to one employee's working contract.
///
/// The whole contract travels as one payload rather than a command per field.
/// The domain already revises a contract as a single versioned document, so a
/// field-at-a-time boundary would let one owner intent land half applied and
/// would give the journal several events for a single revision.
public struct WorkingContractRevision: Codable, Sendable, Equatable {
  public var employeeID: String
  public var role: String
  public var responsibility: String
  public var managerID: String?
  public var assignedSkillIDs: [String]
  public var declaredConnectionIDs: [String]
  public var capabilityGrants: [String]
  public var executionProvider: EmployeeExecutionProvider
  public var modelName: String?
  public var boundaries: AutonomyBoundaries
  public var reviewPolicy: PlanReviewPolicy
  public var reason: String
  /// The contract revision this edit was made against.
  ///
  /// Recorded so history says which contract the owner was looking at, and so
  /// two submissions of the same edit derive the same idempotency key.
  public var baseRevision: Int

  /// A revision always starts from the contract as it stands, and the caller
  /// changes what it means to change.
  ///
  /// There is deliberately no field-by-field initializer: the contract is one
  /// document, and building a revision from loose arguments is how a caller
  /// silently resets the fields it did not mean to touch.
  public init(revising contract: WorkingContract, reason: String) {
    employeeID = contract.employeeID
    role = contract.role
    responsibility = contract.responsibility
    managerID = contract.managerID
    assignedSkillIDs = contract.assignedSkillIDs
    declaredConnectionIDs = contract.declaredConnectionIDs
    capabilityGrants = contract.capabilityGrants
    executionProvider = contract.executionProvider
    modelName = contract.modelName
    boundaries = contract.boundaries
    reviewPolicy = contract.reviewPolicy
    self.reason = reason
    baseRevision = contract.revision
  }

  public static let eventType = "employment.contract-revised"

  /// Stable across retries of the same edit: the employee plus the revision the
  /// edit was made against. Once the revision is applied the contract has moved
  /// on, so the owner's next edit derives a different key.
  public var idempotencyKey: String {
    "contract-revision:\(employeeID):\(baseRevision)"
  }
}

extension OrganizationState {
  /// Applies a working-contract revision.
  ///
  /// It reuses the same revisioned update the owner's editor already called, so
  /// there is one set of contract rules rather than a second contract system.
  /// The records that update writes derive their identifiers from the employee,
  /// the change and the timestamp, so a journalled revision replays exactly.
  mutating func apply(_ revision: WorkingContractRevision, now: Date) throws {
    try updateWorkingContract(
      employeeID: revision.employeeID,
      role: revision.role,
      responsibility: revision.responsibility,
      managerID: revision.managerID,
      assignedSkillIDs: revision.assignedSkillIDs,
      declaredConnectionIDs: revision.declaredConnectionIDs,
      capabilityGrants: revision.capabilityGrants,
      executionProvider: revision.executionProvider,
      modelName: revision.modelName,
      boundaries: revision.boundaries,
      reviewPolicy: revision.reviewPolicy,
      reason: revision.reason,
      now: now
    )
  }
}
