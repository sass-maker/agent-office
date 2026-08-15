import Foundation

public enum ManagementInboxKind: String, Sendable, CaseIterable {
  case candidate
  case plan
  case help
  case blocked
  case delivery
  case contract
}

public struct ManagementInboxItem: Identifiable, Sendable, Equatable {
  public var id: String
  public var kind: ManagementInboxKind
  public var employeeID: String
  public var outcomeID: String?
  public var taskID: String?
  public var title: String
  public var consequence: String
  public var urgency: Int
  public var createdAt: Date
}

extension OrganizationState {
  public var managementInbox: [ManagementInboxItem] {
    var items: [ManagementInboxItem] = []
    for employee in employees
    where employee.kind == .ai && employee.effectiveEmploymentState == .candidate {
      items.append(
        ManagementInboxItem(
          id: "candidate:\(employee.id)", kind: .candidate, employeeID: employee.id,
          title: "Review \(employee.name)'s hiring contract",
          consequence: "They are available but cannot receive work until hired.", urgency: 4,
          createdAt: lastSavedAt))
    }
    for outcome in employeeOutcomes {
      switch outcome.status {
      case .proposed:
        items.append(
          ManagementInboxItem(
            id: "plan:\(outcome.id)", kind: .plan, employeeID: outcome.assigneeID,
            outcomeID: outcome.id,
            title: "Review \(employee(outcome.assigneeID)?.name ?? "employee")'s plan",
            consequence: "Execution waits for approval or a narrower instruction.", urgency: 1,
            createdAt: outcome.updatedAt))
      case .waiting:
        items.append(
          ManagementInboxItem(
            id: "help:\(outcome.id)", kind: .help, employeeID: outcome.assigneeID,
            outcomeID: outcome.id,
            taskID: outcome.taskIDs.first(where: { task($0)?.status == .blocked }),
            title: "Answer \(employee(outcome.assigneeID)?.name ?? "employee")",
            consequence: outcome.helpRequest ?? "Work cannot continue without an owner decision.",
            urgency: 0, createdAt: outcome.updatedAt))
      case .delivered:
        items.append(
          ManagementInboxItem(
            id: "delivery:\(outcome.id)", kind: .delivery, employeeID: outcome.assigneeID,
            outcomeID: outcome.id, title: "Review delivered outcome",
            consequence:
              "The employee's commitment remains open until you accept, revise, or close it.",
            urgency: 2, createdAt: outcome.updatedAt))
      case .failed:
        items.append(
          ManagementInboxItem(
            id: "blocked:\(outcome.id)", kind: .blocked, employeeID: outcome.assigneeID,
            outcomeID: outcome.id, title: "Resolve failed outcome",
            consequence: outcome.helpRequest ?? "Retry, redirect, or stop this work.", urgency: 0,
            createdAt: outcome.updatedAt))
      default: break
      }
    }
    return items.sorted {
      if $0.urgency != $1.urgency { return $0.urgency < $1.urgency }
      return $0.createdAt < $1.createdAt
    }
  }

  public mutating func approveOutcomePlan(
    _ outcomeID: String, actorID: String = "owner", note: String = "Approved as proposed.",
    now: Date = Date()
  ) throws {
    guard let outcome = employeeOutcome(outcomeID), outcome.status == .proposed else {
      throw EmployeeOutcomeError.invalidTransition
    }
    for taskID in outcome.taskIDs { try validateDelegation(taskID: taskID) }
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .approved
      value.planStatus = .approved
      value.managementMessages =
        value.effectiveManagementMessages + [
          OutcomeManagementMessage(actorID: actorID, message: note, createdAt: now)
        ]
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .planApproved, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: note, now: now)
  }

  public mutating func returnOutcomePlan(
    _ outcomeID: String, instruction: String, actorID: String = "owner", now: Date = Date()
  ) throws {
    let message = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { throw EmployeeOutcomeError.emptyReply }
    guard let outcome = employeeOutcome(outcomeID), outcome.status == .proposed else {
      throw EmployeeOutcomeError.invalidTransition
    }
    tasks.removeAll { outcome.taskIDs.contains($0.id) && $0.artifactIDs.isEmpty }
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .queued
      value.planStatus = .returned
      value.context = [value.context, "Owner plan direction: \(message)"].filter { !$0.isEmpty }
        .joined(separator: "\n\n")
      value.taskIDs = []
      value.selectedSkillIDs = []
      value.helpRequest = nil
      value.managementMessages =
        value.effectiveManagementMessages + [
          OutcomeManagementMessage(actorID: actorID, message: message, createdAt: now)
        ]
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .planReturned, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: message, now: now)
  }

  public mutating func replyToOutcome(
    _ outcomeID: String, message input: String, actorID: String = "owner", now: Date = Date()
  ) throws {
    let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { throw EmployeeOutcomeError.emptyReply }
    guard let outcome = employeeOutcome(outcomeID),
      outcome.status == .waiting || outcome.status == .failed
    else { throw EmployeeOutcomeError.invalidTransition }
    let blockedTaskID = outcome.taskIDs.first(where: { task($0)?.status == .blocked })
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = value.taskIDs.isEmpty ? .queued : .approved
      value.helpRequest = nil
      value.managementMessages =
        value.effectiveManagementMessages + [
          OutcomeManagementMessage(
            actorID: actorID, message: message, taskID: blockedTaskID, createdAt: now)
        ]
      value.outcomeRevision = value.effectiveRevision + 1
    }
    for index in blockers.indices where outcome.taskIDs.contains(blockers[index].taskID) {
      blockers[index].resolved = true
    }
    for taskID in outcome.taskIDs {
      guard let index = tasks.firstIndex(where: { $0.id == taskID }),
        tasks[index].status == .blocked
      else { continue }
      tasks[index].status =
        tasks[index].dependencyIDs.allSatisfy { task($0)?.status == .done } ? .ready : .waiting
      tasks[index].workRevision = tasks[index].effectiveWorkRevision + 1
      tasks[index].updatedAt = now
    }
    appendSupervision(
      .ownerReplied, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: message, now: now)
  }

  public mutating func changeOutcomePriority(
    _ outcomeID: String, priority: EmployeeOutcomePriority, actorID: String = "owner",
    now: Date = Date()
  ) throws {
    guard let outcome = employeeOutcome(outcomeID),
      !outcome.status.isTerminal && outcome.status != .delivered
    else { throw EmployeeOutcomeError.invalidTransition }
    let prior = outcome.effectivePriority.rawValue
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.priority = priority
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .redirected, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: "Changed priority from \(prior) to \(priority.rawValue).", now: now)
  }

  public mutating func reorderOutcome(
    _ outcomeID: String, to queuePosition: Int, actorID: String = "owner", now: Date = Date()
  ) throws {
    guard let outcome = employeeOutcome(outcomeID),
      outcome.status == .queued || outcome.status == .approved
    else { throw EmployeeOutcomeError.invalidTransition }
    let peers = employeeOutcomes.filter {
      $0.assigneeID == outcome.assigneeID && $0.id != outcomeID
        && ($0.status == .queued || $0.status == .approved)
    }.sorted { $0.effectiveQueuePosition < $1.effectiveQueuePosition }
    let target = min(max(queuePosition, 0), peers.count)
    var order = peers.map(\.id)
    order.insert(outcomeID, at: target)
    for (position, id) in order.enumerated() {
      _ = updateEmployeeOutcome(id, now: now) {
        $0.queuePosition = position
        $0.outcomeRevision = $0.effectiveRevision + 1
      }
    }
    appendSupervision(
      .redirected, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: "Moved the outcome to queue position \(target + 1).", now: now)
  }

  public mutating func redirectOutcome(
    _ outcomeID: String, outcome newOutcome: String? = nil, context: String? = nil,
    acceptanceCriteria: [String]? = nil, actorID: String = "owner", reason: String,
    now: Date = Date()
  ) throws {
    guard let outcome = employeeOutcome(outcomeID),
      !outcome.status.isTerminal && outcome.status != .delivered
    else { throw EmployeeOutcomeError.invalidTransition }
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      if let newOutcome, !newOutcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        value.outcome = newOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      if let context { value.context = context.trimmingCharacters(in: .whitespacesAndNewlines) }
      if let acceptanceCriteria {
        value.acceptanceCriteria = acceptanceCriteria.map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
      }
      value.managementMessages =
        value.effectiveManagementMessages + [
          OutcomeManagementMessage(actorID: actorID, message: reason, createdAt: now)
        ]
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .redirected, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: reason, now: now)
  }

  public mutating func reassignTicket(
    _ taskID: String, to employeeID: String, reason: String, actorID: String = "owner",
    now: Date = Date()
  ) throws {
    guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }),
      [.waiting, .ready, .blocked].contains(tasks[taskIndex].status)
    else { throw EmployeeOutcomeError.invalidTransition }
    let originalTask = tasks[taskIndex]
    let previous = tasks[taskIndex].assigneeID
    tasks[taskIndex].assigneeID = employeeID
    tasks[taskIndex].accountableEmployeeID = tasks[taskIndex].accountableEmployeeID ?? previous
    tasks[taskIndex].delegationReason = reason
    tasks[taskIndex].workRevision = tasks[taskIndex].effectiveWorkRevision + 1
    tasks[taskIndex].updatedAt = now
    do { try validateDelegation(taskID: taskID) } catch {
      tasks[taskIndex] = originalTask
      throw error
    }
    let outcome = employeeOutcomes.first { $0.taskIDs.contains(taskID) }
    appendSupervision(
      .reassigned, actorID: actorID, employeeID: employeeID, outcomeID: outcome?.id, taskID: taskID,
      message: "Reassigned from \(previous) to \(employeeID): \(reason)", priorValue: previous,
      now: now)
  }

  public mutating func acceptOutcome(
    _ outcomeID: String, note: String = "", actorID: String = "owner", now: Date = Date()
  ) throws {
    guard let outcome = employeeOutcome(outcomeID), outcome.status == .delivered else {
      throw EmployeeOutcomeError.invalidTransition
    }
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .accepted
      value.acceptedByActorID = actorID
      value.acceptedAt = now
      value.acceptanceNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .accepted, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: note.isEmpty ? "Accepted the delivered outcome." : note, now: now)
  }

  public mutating func requestOutcomeRevision(
    _ outcomeID: String, feedback input: String, actorID: String = "owner", now: Date = Date()
  ) throws {
    let feedback = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !feedback.isEmpty else { throw EmployeeOutcomeError.emptyReply }
    guard let outcome = employeeOutcome(outcomeID), outcome.status == .delivered else {
      throw EmployeeOutcomeError.invalidTransition
    }
    let revisionCount = outcome.effectiveRevisions.count
    let limit = workingContract(for: outcome.assigneeID)?.boundaries.maximumRevisions ?? 2
    guard revisionCount < limit else { throw EmployeeOutcomeError.revisionLimitReached }
    let taskID = "\(outcomeID)-revision-\(revisionCount + 1)"
    tasks.append(
      WorkTask(
        id: taskID, title: "Revise \(outcome.outcome)", detail: feedback, kind: .draft,
        status: .ready, assigneeID: outcome.assigneeID, reviewerID: nil,
        dependencyIDs: outcome.taskIDs, artifactIDs: [], revisionCount: revisionCount + 1,
        maxRevisions: limit, updatedAt: now,
        accountableEmployeeID: outcome.effectiveAccountableEmployeeID,
        requiredSkillIDs: outcome.selectedSkillIDs, workRevision: 0))
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .revision
      value.taskIDs.append(taskID)
      value.revisions =
        value.effectiveRevisions + [
          OutcomeRevision(
            feedback: feedback, requestedByActorID: actorID, taskID: taskID, createdAt: now)
        ]
      value.managementMessages =
        value.effectiveManagementMessages + [
          OutcomeManagementMessage(
            actorID: actorID, message: feedback, taskID: taskID, createdAt: now)
        ]
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .revisionRequested, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      taskID: taskID, message: feedback, now: now)
  }

  public mutating func closeOutcome(
    _ outcomeID: String, reason: String, actorID: String = "owner", now: Date = Date()
  ) throws {
    guard let outcome = employeeOutcome(outcomeID), outcome.status == .delivered else {
      throw EmployeeOutcomeError.invalidTransition
    }
    _ = updateEmployeeOutcome(outcomeID, now: now) { value in
      value.status = .closed
      value.acceptanceNote = reason
      value.outcomeRevision = value.effectiveRevision + 1
    }
    appendSupervision(
      .closed, actorID: actorID, employeeID: outcome.assigneeID, outcomeID: outcomeID,
      message: reason, now: now)
  }

  public func validateDelegation(taskID: String) throws {
    guard let task = task(taskID), let employee = employee(task.assigneeID), employee.kind == .ai
    else { throw EmployeeOutcomeError.ineligibleDelegate }
    guard employee.effectiveEmploymentState == .hired else {
      throw EmployeeOutcomeError.ineligibleDelegate
    }
    let contract = workingContract(for: employee.id)
    let skillIDs = Set(
      contract?.assignedSkillIDs ?? assignedSkills(employeeID: employee.id).map(\.id))
    guard Set(task.requiredSkillIDs ?? []).isSubset(of: skillIDs) else {
      throw EmployeeOutcomeError.ineligibleDelegate
    }
    let declared = Set(contract?.declaredConnectionIDs ?? [])
    guard Set(task.requiredConnectionIDs ?? []).isSubset(of: declared) else {
      throw EmployeeOutcomeError.ineligibleDelegate
    }
    let requiredCapabilities = Set(
      (task.requiredConnectionIDs ?? []).compactMap { connectionID in
        knowledge?.connectionDefinitions.first { $0.id == connectionID }?.capabilityID
      })
    guard
      requiredCapabilities.isSubset(
        of: Set(contract?.capabilityGrants ?? employee.capabilityGrants))
    else { throw EmployeeOutcomeError.ineligibleDelegate }
  }

  private mutating func appendSupervision(
    _ kind: SupervisionEventKind, actorID: String, employeeID: String, outcomeID: String? = nil,
    taskID: String? = nil, message: String, priorValue: String? = nil, now: Date
  ) {
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    knowledge?.supervisionEvents.append(
      SupervisionEvent(
        kind: kind, actorID: actorID, employeeID: employeeID, outcomeID: outcomeID, taskID: taskID,
        message: message, priorValue: priorValue, createdAt: now))
    activity.append(
      Activity(
        id: UUID().uuidString, actorID: actorID, kind: kind == .accepted ? .approved : .progress,
        message: message, createdAt: now))
  }
}
