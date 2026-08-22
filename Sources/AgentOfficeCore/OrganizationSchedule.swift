import Foundation

public enum ScheduleError: LocalizedError, Equatable {
  case missingPolicy(String)
  case missingOccurrence(String)
  case occurrenceAlreadyFinished(String)

  public var errorDescription: String? {
    switch self {
    case .missingPolicy(let id):
      "There is no schedule \(id) to change."
    case .missingOccurrence(let id):
      "There is no scheduled occurrence \(id) to change."
    case .occurrenceAlreadyFinished(let id):
      "Occurrence \(id) has already finished. Changing the schedule does not rewrite what happened."
    }
  }
}

extension OrganizationState {
  public var schedulePolicies: [SchedulePolicy] { knowledge?.schedulePolicies ?? [] }
  public var scheduledOccurrences: [ScheduledOccurrence] { knowledge?.scheduledOccurrences ?? [] }
  public var runReceipts: [RunReceipt] { knowledge?.runReceipts ?? [] }

  public func schedulePolicy(_ id: String) -> SchedulePolicy? {
    schedulePolicies.first { $0.id == id }
  }

  public func scheduledOccurrence(_ id: String) -> ScheduledOccurrence? {
    scheduledOccurrences.first { $0.id == id }
  }

  public func runReceipt(forOccurrence occurrenceID: String) -> RunReceipt? {
    runReceipts.first { $0.occurrenceID == occurrenceID }
  }

  public func occurrences(forPolicy policyID: String) -> [ScheduledOccurrence] {
    scheduledOccurrences.filter { $0.origin.policyID == policyID }
      .sorted { $0.window.start < $1.window.start }
  }

  @discardableResult
  public mutating func addSchedulePolicy(_ policy: SchedulePolicy) -> SchedulePolicy {
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    if let index = knowledge?.schedulePolicies.firstIndex(where: { $0.id == policy.id }) {
      knowledge?.schedulePolicies[index] = policy
    } else {
      knowledge?.schedulePolicies.append(policy)
    }
    return policy
  }

  /// Pauses or resumes a policy without deleting it or anything it produced.
  public mutating func setSchedulePolicyPaused(_ policyID: String, _ paused: Bool) throws {
    guard let index = knowledge?.schedulePolicies.firstIndex(where: { $0.id == policyID }) else {
      throw ScheduleError.missingPolicy(policyID)
    }
    knowledge?.schedulePolicies[index].isPaused = paused
  }

  /// Creates the occurrences a policy implies inside a horizon.
  ///
  /// Identifiers derive from policy and instant, so running this again — after a
  /// restart, a retry, a clock change, or a timezone change — re-derives the
  /// same occurrences instead of duplicating them. Occurrences that already
  /// exist are never rewritten, so a completed run cannot be reset by
  /// regeneration.
  @discardableResult
  public mutating func generateOccurrences(
    forPolicy policyID: String, from: Date, through horizon: Date
  ) throws -> [ScheduledOccurrence] {
    guard let policy = schedulePolicy(policyID) else {
      throw ScheduleError.missingPolicy(policyID)
    }
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    var created: [ScheduledOccurrence] = []
    for instant in policy.instants(from: from, through: horizon) {
      let id = ScheduledOccurrence.identifier(policyID: policy.id, instant: instant)
      guard scheduledOccurrence(id) == nil else { continue }
      let occurrence = ScheduledOccurrence(
        id: id,
        origin: OccurrenceOrigin(
          policyID: policy.id, employeeID: policy.employeeID, subject: policy.subject),
        window: OccurrenceWindow(
          start: instant,
          duration: policy.plan.expectedDuration,
          flexibility: policy.plan.flexibility
        )
      )
      knowledge?.scheduledOccurrences.append(occurrence)
      created.append(occurrence)
    }
    return created
  }

  /// Records that a run actually started. Planned times are left alone.
  public mutating func startOccurrence(
    _ occurrenceID: String, at start: Date, sessionID: String? = nil, runtimeKind: String? = nil
  ) throws {
    try updateUnfinishedOccurrence(occurrenceID) { occurrence in
      occurrence.status = .running
      occurrence.actual = OccurrenceActual(
        startedAt: start, runtimeSessionID: sessionID, runtimeKind: runtimeKind)
    }
  }

  /// Finishes an occurrence and writes its receipt.
  ///
  /// The receipt is what makes the terminal state inspectable, so the two are
  /// written together rather than left to drift apart.
  @discardableResult
  public mutating func finishOccurrence(
    _ occurrenceID: String,
    result: ReceiptResult,
    reason: String,
    endedAt: Date,
    modelName: String? = nil
  ) throws -> RunReceipt {
    guard let occurrence = scheduledOccurrence(occurrenceID) else {
      throw ScheduleError.missingOccurrence(occurrenceID)
    }
    guard !occurrence.status.isTerminal else {
      throw ScheduleError.occurrenceAlreadyFinished(occurrenceID)
    }

    var actual = occurrence.actual
    actual?.endedAt = endedAt
    let status: OccurrenceStatus =
      switch result.kind {
      case .changed: .delivered
      case .quiet: .quiet
      // The window is over either way; the receipt is what distinguishes "the
      // employee is stuck" from "the employee is waiting on you".
      case .waitingForOwner: .blocked
      case .blocked: .blocked
      case .failed: .failed
      case .skipped: .skipped
      case .cancelled: .cancelled
      case .neverRan: .missed
      }

    try updateUnfinishedOccurrence(occurrenceID) { value in
      value.status = status
      value.actual = actual
      value.note = reason
    }

    let receipt = RunReceipt(
      occurrenceID: occurrenceID,
      scheduledReason: reason,
      scheduledWindow: occurrence.window,
      actual: actual,
      work: ReceiptWork(
        employeeID: occurrence.origin.employeeID,
        subject: occurrence.origin.subject,
        runtimeKind: actual?.runtimeKind,
        modelName: modelName,
        authorityUsed: workingContract(for: occurrence.origin.employeeID)?.capabilityGrants ?? []
      ),
      result: result,
      createdAt: endedAt
    )
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    if let index = knowledge?.runReceipts.firstIndex(where: { $0.occurrenceID == occurrenceID }) {
      knowledge?.runReceipts[index] = receipt
    } else {
      knowledge?.runReceipts.append(receipt)
    }
    return receipt
  }

  /// Skips a future occurrence, keeping why.
  public mutating func skipOccurrence(_ occurrenceID: String, reason: String) throws {
    try updateUnfinishedOccurrence(occurrenceID) { occurrence in
      occurrence.status = .skipped
      occurrence.note = reason
    }
  }

  public mutating func cancelOccurrence(_ occurrenceID: String, reason: String) throws {
    try updateUnfinishedOccurrence(occurrenceID) { occurrence in
      occurrence.status = .cancelled
      occurrence.note = reason
    }
  }

  /// Moves a future occurrence. Its identity stays with the instant it was
  /// generated for, so history remains traceable to the policy that made it.
  public mutating func moveOccurrence(_ occurrenceID: String, to start: Date) throws {
    try updateUnfinishedOccurrence(occurrenceID) { occurrence in
      occurrence.window.start = start
      occurrence.status = .scheduled
    }
  }

  /// Marks windows that passed without execution as missed.
  ///
  /// Deterministic and idempotent: it never runs work late, and running it again
  /// changes nothing.
  @discardableResult
  public mutating func reconcileMissedOccurrences(now: Date) -> [String] {
    guard knowledge != nil else { return [] }
    var missed: [String] = []
    for index in knowledge!.scheduledOccurrences.indices {
      let occurrence = knowledge!.scheduledOccurrences[index]
      guard !occurrence.status.isTerminal,
        occurrence.actual == nil,
        now > occurrence.window.latestAcceptableStart
      else { continue }
      knowledge!.scheduledOccurrences[index].status = .missed
      knowledge!.scheduledOccurrences[index].note =
        "The window passed without a run. Nothing was executed late."
      missed.append(occurrence.id)
    }
    return missed
  }

  // MARK: - Internals

  private mutating func updateUnfinishedOccurrence(
    _ occurrenceID: String, _ change: (inout ScheduledOccurrence) -> Void
  ) throws {
    guard let index = knowledge?.scheduledOccurrences.firstIndex(where: { $0.id == occurrenceID })
    else { throw ScheduleError.missingOccurrence(occurrenceID) }
    guard !knowledge!.scheduledOccurrences[index].status.isTerminal else {
      throw ScheduleError.occurrenceAlreadyFinished(occurrenceID)
    }
    change(&knowledge!.scheduledOccurrences[index])
  }
}
