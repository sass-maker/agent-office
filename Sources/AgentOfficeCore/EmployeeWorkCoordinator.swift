import Foundation

public struct EmployeeOutcomeRunRequest: Sendable {
  public var organization: OrganizationState
  public var outcomeID: String
  public var employeeID: String
  public var contractRevision: Int
  public var expectedOutcomeRevision: Int
  public var expectedTaskRevisions: [String: Int]

  public init(organization: OrganizationState, outcomeID: String) throws {
    guard let outcome = organization.employeeOutcome(outcomeID),
      let employee = organization.employee(outcome.assigneeID)
    else { throw EmployeeOutcomeError.missingEmployee }
    self.organization = organization
    self.outcomeID = outcomeID
    self.employeeID = employee.id
    self.contractRevision = organization.workingContract(for: employee.id)?.revision ?? 0
    self.expectedOutcomeRevision = outcome.effectiveRevision
    self.expectedTaskRevisions = Dictionary(
      uniqueKeysWithValues: outcome.taskIDs.compactMap { id in
        organization.task(id).map { (id, $0.effectiveWorkRevision) }
      })
  }
}

public struct EmployeeOutcomeRunResult: Codable, Sendable, Equatable {
  public var outcomeID: String
  public var employeeID: String
  public var contractRevision: Int
  public var expectedOutcomeRevision: Int
  public var expectedTaskRevisions: [String: Int]
  public var outcome: EmployeeOutcome
  public var tasks: [WorkTask]
  public var artifacts: [Artifact]
  public var blockers: [Blocker]
  public var activity: [Activity]
  public var memoryEntries: [EmployeeMemoryEntry]
  public var employee: Employee

  public init(
    request: EmployeeOutcomeRunRequest, initial: OrganizationState, result: OrganizationState
  ) throws {
    guard let outcome = result.employeeOutcome(request.outcomeID),
      let employee = result.employee(request.employeeID)
    else { throw EmployeeOutcomeError.missingEmployee }
    let initialActivityIDs = Set(initial.activity.map(\.id))
    let initialMemoryIDs = Set(initial.knowledge?.memoryEntries.map(\.id) ?? [])
    self.outcomeID = request.outcomeID
    self.employeeID = request.employeeID
    self.contractRevision = request.contractRevision
    self.expectedOutcomeRevision = request.expectedOutcomeRevision
    self.expectedTaskRevisions = request.expectedTaskRevisions
    self.outcome = outcome
    self.tasks = outcome.taskIDs.compactMap(result.task)
    self.artifacts = result.artifacts.filter { outcome.taskIDs.contains($0.taskID) }
    self.blockers = result.blockers.filter { outcome.taskIDs.contains($0.taskID) }
    self.activity = result.activity.filter { !initialActivityIDs.contains($0.id) }
    self.memoryEntries =
      result.knowledge?.memoryEntries.filter { !initialMemoryIDs.contains($0.id) } ?? []
    self.employee = employee
  }
}

public enum EmployeeRunApplyError: LocalizedError, Equatable {
  case outcomeChanged
  case taskChanged(String)
  case contractChanged

  public var errorDescription: String? {
    switch self {
    case .outcomeChanged:
      "The outcome changed while this result was running. Its stale result was not applied."
    case .taskChanged(let id):
      "Ticket \(id) changed while it was running. Its stale result was not applied."
    case .contractChanged:
      "The employee's working contract changed while work was running. Review and resume the outcome."
    }
  }
}

extension OrganizationState {
  public mutating func apply(_ result: EmployeeOutcomeRunResult) throws {
    guard
      let outcomeIndex = knowledge?.employeeOutcomes.firstIndex(where: { $0.id == result.outcomeID }
      ),
      knowledge!.employeeOutcomes[outcomeIndex].effectiveRevision == result.expectedOutcomeRevision
    else { throw EmployeeRunApplyError.outcomeChanged }
    if result.contractRevision > 0,
      workingContract(for: result.employeeID)?.revision != result.contractRevision
    {
      throw EmployeeRunApplyError.contractChanged
    }
    for (taskID, expectedRevision) in result.expectedTaskRevisions {
      guard task(taskID)?.effectiveWorkRevision == expectedRevision else {
        throw EmployeeRunApplyError.taskChanged(taskID)
      }
    }
    knowledge!.employeeOutcomes[outcomeIndex] = result.outcome
    for resultTask in result.tasks {
      if let index = tasks.firstIndex(where: { $0.id == resultTask.id }) {
        tasks[index] = resultTask
      } else {
        tasks.append(resultTask)
      }
    }
    for artifact in result.artifacts where !artifacts.contains(where: { $0.id == artifact.id }) {
      artifacts.append(artifact)
    }
    for blocker in result.blockers {
      if let index = blockers.firstIndex(where: { $0.id == blocker.id }) {
        blockers[index] = blocker
      } else {
        blockers.append(blocker)
      }
    }
    activity.append(
      contentsOf: result.activity.filter { event in !activity.contains(where: { $0.id == event.id })
      })
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    let existingMemoryIDs = Set(knowledge?.memoryEntries.map(\.id) ?? [])
    knowledge?.memoryEntries.append(
      contentsOf: result.memoryEntries.filter { !existingMemoryIDs.contains($0.id) })
    if let employeeIndex = employees.firstIndex(where: { $0.id == result.employeeID }) {
      employees[employeeIndex].status = result.employee.status
      employees[employeeIndex].currentTaskID = result.employee.currentTaskID
    }
  }
}

public actor EmployeeWorkCoordinator {
  public typealias Operation =
    @Sendable (EmployeeOutcomeRunRequest) async throws -> EmployeeOutcomeRunResult
  public typealias Completion =
    @MainActor @Sendable (Result<EmployeeOutcomeRunResult, Error>) async -> Void

  private var tasksByEmployee: [String: Task<Void, Never>] = [:]
  private var concurrencyLimit: Int

  public init(concurrencyLimit: Int = 2) {
    self.concurrencyLimit = min(max(concurrencyLimit, 1), 4)
  }

  public func setConcurrencyLimit(_ value: Int) {
    concurrencyLimit = min(max(value, 1), 4)
  }

  public func submit(
    _ request: EmployeeOutcomeRunRequest, operation: @escaping Operation,
    completion: @escaping Completion
  ) -> Bool {
    guard tasksByEmployee[request.employeeID] == nil, tasksByEmployee.count < concurrencyLimit
    else { return false }
    tasksByEmployee[request.employeeID] = Task { [weak self] in
      let result: Result<EmployeeOutcomeRunResult, Error>
      do { result = .success(try await operation(request)) } catch { result = .failure(error) }
      await self?.finish(employeeID: request.employeeID)
      await completion(result)
    }
    return true
  }

  public func cancel(employeeID: String) {
    tasksByEmployee[employeeID]?.cancel()
    tasksByEmployee[employeeID] = nil
  }

  public func cancelAll() {
    for task in tasksByEmployee.values { task.cancel() }
    tasksByEmployee.removeAll()
  }

  public var activeEmployeeIDs: Set<String> { Set(tasksByEmployee.keys) }
  public var activeCount: Int { tasksByEmployee.count }

  private func finish(employeeID: String) {
    tasksByEmployee[employeeID] = nil
  }
}

extension EmployeeOutcomeEngine {
  public func execute(
    _ request: EmployeeOutcomeRunRequest,
    runner: any EmployeeRunner,
    store: LocalOrganizationStore,
    now: Date = Date(),
    authorizedCapabilities: Set<String>? = nil,
    runtimeHealth: RuntimeHealthSnapshot = .practiceOnly
  ) async throws -> EmployeeOutcomeRunResult {
    let result = await run(
      request.organization, outcomeID: request.outcomeID, runner: runner, store: store, now: now,
      runtimeHealth: runtimeHealth,
      options: EmployeeOutcomeRunOptions(
        persistsTransitions: false, authorizedCapabilities: authorizedCapabilities))
    if Task.isCancelled { throw CancellationError() }
    return try EmployeeOutcomeRunResult(
      request: request, initial: request.organization, result: result)
  }
}
