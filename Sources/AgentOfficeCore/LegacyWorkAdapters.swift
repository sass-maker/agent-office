import Foundation

extension OrganizationState {
  /// Fills in the optional fields that documents written before the canonical
  /// outcome model predate. Every field is filled independently and only when
  /// the persisted document left it absent, so the migration is idempotent.
  public mutating func migrateCanonicalOutcomeDefaults() {
    guard knowledge != nil else { return }
    backfillEmployeeOutcomeDefaults()
    backfillTaskDefaults()
  }

  private mutating func backfillEmployeeOutcomeDefaults() {
    for index in knowledge!.employeeOutcomes.indices {
      var outcome = knowledge!.employeeOutcomes[index]
      if outcome.queuePosition == nil {
        outcome.queuePosition =
          knowledge!.employeeOutcomes[..<index].filter { $0.assigneeID == outcome.assigneeID }.count
      }
      Self.backfillOutcomeClassification(&outcome)
      Self.backfillOutcomeCollections(&outcome)
      knowledge!.employeeOutcomes[index] = outcome
    }
  }

  private static func backfillOutcomeClassification(_ outcome: inout EmployeeOutcome) {
    if outcome.priority == nil { outcome.priority = .normal }
    if outcome.source == nil { outcome.source = .owner }
    if outcome.planStatus == nil { outcome.planStatus = inferredPlanStatus(for: outcome) }
    if outcome.accountableEmployeeID == nil { outcome.accountableEmployeeID = outcome.assigneeID }
  }

  private static func inferredPlanStatus(for outcome: EmployeeOutcome) -> OutcomePlanStatus {
    guard !outcome.taskIDs.isEmpty else { return .notStarted }
    return [.queued, .planning].contains(outcome.status) ? .drafting : .approved
  }

  private static func backfillOutcomeCollections(_ outcome: inout EmployeeOutcome) {
    if outcome.acceptanceCriteria == nil { outcome.acceptanceCriteria = [] }
    if outcome.managementMessages == nil { outcome.managementMessages = [] }
    if outcome.deliveries == nil { outcome.deliveries = [] }
    if outcome.revisions == nil { outcome.revisions = [] }
    if outcome.outcomeRevision == nil { outcome.outcomeRevision = 0 }
  }

  private mutating func backfillTaskDefaults() {
    for index in tasks.indices {
      guard let outcome = employeeOutcomes.first(where: { $0.taskIDs.contains(tasks[index].id) })
      else { continue }
      if tasks[index].accountableEmployeeID == nil {
        tasks[index].accountableEmployeeID = outcome.effectiveAccountableEmployeeID
      }
      if tasks[index].requiredSkillIDs == nil {
        tasks[index].requiredSkillIDs = outcome.selectedSkillIDs
      }
      if tasks[index].requiredConnectionIDs == nil {
        tasks[index].requiredConnectionIDs = (tasks[index].requiredSkillIDs ?? []).flatMap {
          skill($0)?.requiredConnectionIDs ?? []
        }
      }
      if tasks[index].workRevision == nil { tasks[index].workRevision = 0 }
    }
  }

  public mutating func prepareFirstContentMission(now: Date = Date()) throws -> [String] {
    let existing = employeeOutcomes.filter { $0.effectiveSource == .legacyWorkday }
    if !existing.isEmpty { return existing.map(\.id) }
    let templates: [(String, String, String, [String])] = [
      (
        "nia", "Identify the audience question",
        "Use the company brief to identify the most useful question and evidence boundary for the current mission.",
        [
          "Name one concrete reader question.",
          "Distinguish supplied facts from evidence still needed.",
        ]
      ),
      (
        "theo", "Draft the first useful article",
        "Turn the company mission and available evidence into one clear, reviewable local draft.",
        ["Answer the audience question directly.", "Keep unsupported claims out of the draft."]
      ),
      (
        "maya", "Review the content mission",
        "Review the team's local artifacts against the organization mission and prepare one owner handoff.",
        ["State whether the mission is met.", "Name the next owner decision."]
      ),
    ]
    return try templates.map { employeeID, outcome, context, criteria in
      try createEmployeeOutcome(
        employeeID: employeeID, outcome: outcome, context: context, acceptanceCriteria: criteria,
        priority: .normal, source: .legacyWorkday, sourceID: "first-content-mission", now: now)
    }
  }

  public mutating func linkLegacyWorkToCanonicalOutcomes(now: Date = Date()) {
    guard knowledge != nil else { return }
    for index in knowledge!.researchAssignments.indices
    where knowledge!.researchAssignments[index].canonicalOutcomeID == nil {
      let assignment = knowledge!.researchAssignments[index]
      let existing = employeeOutcomes.first {
        $0.effectiveSource == .legacyResearch && $0.sourceID == assignment.id
      }
      if let existing {
        knowledge!.researchAssignments[index].canonicalOutcomeID = existing.id
        continue
      }
      if let id = try? createEmployeeOutcome(
        employeeID: assignment.assigneeID, outcome: assignment.outcome, context: assignment.context,
        acceptanceCriteria: ["Return evidence, uncertainty, and a recommended next action."],
        source: .legacyResearch, sourceID: assignment.id, now: assignment.createdAt)
      {
        knowledge!.researchAssignments[index].canonicalOutcomeID = id
        mirrorLegacyResearch(assignmentID: assignment.id, from: id, now: now)
      }
    }
    for index in knowledge!.dutyOccurrences.indices
    where knowledge!.dutyOccurrences[index].canonicalOutcomeID == nil {
      let occurrence = knowledge!.dutyOccurrences[index]
      guard let duty = employeeDuty(occurrence.dutyID) else { continue }
      let existing = employeeOutcomes.first {
        $0.effectiveSource == .recurringResponsibility && $0.sourceID == occurrence.id
      }
      if let existing {
        knowledge!.dutyOccurrences[index].canonicalOutcomeID = existing.id
        continue
      }
      if let id = try? createEmployeeOutcome(
        employeeID: occurrence.assigneeID, outcome: duty.title, context: duty.responsibility,
        acceptanceCriteria: ["Deliver one cited owner decision."], source: .recurringResponsibility,
        sourceID: occurrence.id, now: occurrence.createdAt)
      {
        knowledge!.dutyOccurrences[index].canonicalOutcomeID = id
        mirrorLegacyDuty(occurrenceID: occurrence.id, from: id, now: now)
      }
    }
  }

  public mutating func synchronizeLegacyAdapters(outcomeID: String, now: Date = Date()) {
    guard let outcome = employeeOutcome(outcomeID), let sourceID = outcome.sourceID else { return }
    switch outcome.effectiveSource {
    case .legacyResearch: mirrorLegacyResearch(assignmentID: sourceID, from: outcomeID, now: now)
    case .recurringResponsibility:
      mirrorLegacyDuty(occurrenceID: sourceID, from: outcomeID, now: now)
    case .owner, .legacyWorkday: break
    }
  }

  private mutating func mirrorLegacyResearch(
    assignmentID: String, from outcomeID: String, now: Date
  ) {
    guard let outcome = employeeOutcome(outcomeID) else { return }
    _ = updateResearchAssignment(assignmentID, now: now) { assignment in
      assignment.canonicalOutcomeID = outcomeID
      assignment.briefArtifactID = outcome.artifactIDs.first
      assignment.deliveryArtifactID = outcome.artifactIDs.last
      assignment.blockingReason = outcome.helpRequest
      assignment.status = {
        switch outcome.status {
        case .queued, .planning, .proposed, .approved: .queued
        case .working, .revision: .researching
        case .waiting: .waiting
        case .delivered, .accepted, .closed: .delivered
        case .failed: .failed
        case .cancelled: .cancelled
        }
      }()
    }
  }

  private mutating func mirrorLegacyDuty(occurrenceID: String, from outcomeID: String, now: Date) {
    guard let outcome = employeeOutcome(outcomeID), let occurrence = dutyOccurrence(occurrenceID)
    else { return }
    _ = updateDutyOccurrence(occurrenceID, now: now) { value in
      value.canonicalOutcomeID = outcomeID
      value.briefArtifactID = outcome.artifactIDs.first
      value.deliveryArtifactID = outcome.artifactIDs.last
      value.blockingReason = outcome.helpRequest
      value.status = {
        switch outcome.status {
        case .queued, .planning, .proposed, .approved: .queued
        case .working, .revision: .running
        case .waiting, .failed: .blocked
        case .delivered, .accepted, .closed: .delivered
        case .cancelled: .cancelled
        }
      }()
    }
    guard [.delivered, .accepted, .closed].contains(outcome.status),
      let dutyIndex = knowledge?.employeeDuties.firstIndex(where: { $0.id == occurrence.dutyID }),
      knowledge!.employeeDuties[dutyIndex].lastCompletedAt == nil
        || knowledge!.employeeDuties[dutyIndex].lastCompletedAt! < occurrence.createdAt
    else { return }
    knowledge!.employeeDuties[dutyIndex].lastCompletedAt = now
    knowledge!.employeeDuties[dutyIndex].nextDueAt =
      Calendar.current.date(
        byAdding: .day, value: 7, to: knowledge!.employeeDuties[dutyIndex].nextDueAt)
      ?? knowledge!.employeeDuties[dutyIndex].nextDueAt.addingTimeInterval(604_800)
  }
}
