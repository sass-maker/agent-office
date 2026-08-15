import Foundation

extension OrganizationState {
  /// Puts one employee into a work state.
  ///
  /// Every engine needs this and each used to keep its own copy, which made the
  /// meaning of "working" a per-engine detail rather than an organization rule.
  mutating func setEmployee(_ employeeID: String, status: EmployeeStatus, taskID: String?) {
    guard let index = employees.firstIndex(where: { $0.id == employeeID }) else { return }
    employees[index].status = status
    employees[index].currentTaskID = taskID
  }

  /// Returns every AI employee to rest, dropping whatever they were holding.
  public mutating func restAIEmployees() {
    for index in employees.indices where employees[index].kind == .ai {
      employees[index].status = .resting
      employees[index].currentTaskID = nil
    }
  }

  /// The recent memory an employee carries into new work.
  func recentMemoryContext(for employeeID: String, limit: Int = 5) -> String {
    let entries =
      knowledge?.memoryEntries
      .filter { $0.employeeID == employeeID }
      .suffix(limit) ?? []
    return entries.map { "Day \($0.dayNumber): \($0.summary)" }.joined(separator: "\n")
  }
}
