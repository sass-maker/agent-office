import Foundation

extension OrganizationState {
  /// Re-applies every hired employee's working contract with a different
  /// execution provider.
  ///
  /// Changing how the organization runs is a contract change for each employee,
  /// so it goes through the same revisioned update the owner's edits use rather
  /// than writing the provider directly onto contracts.
  public mutating func applyExecutionProvider(
    _ provider: EmployeeExecutionProvider,
    reason: String,
    actorID: String = "owner"
  ) {
    for contract in workingContracts
    where employee(contract.employeeID)?.effectiveEmploymentState == .hired {
      try? updateWorkingContract(
        employeeID: contract.employeeID,
        role: contract.role,
        responsibility: contract.responsibility,
        managerID: contract.managerID,
        assignedSkillIDs: contract.assignedSkillIDs,
        declaredConnectionIDs: contract.declaredConnectionIDs,
        capabilityGrants: contract.capabilityGrants,
        executionProvider: provider,
        modelName: contract.modelName,
        boundaries: contract.boundaries,
        reviewPolicy: contract.reviewPolicy,
        actorID: actorID,
        reason: reason
      )
    }
  }
}
