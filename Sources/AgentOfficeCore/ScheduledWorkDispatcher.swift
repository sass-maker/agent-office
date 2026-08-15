import Foundation

/// What a dispatch attempt did, in the caller's terms.
public enum ScheduledDispatchOutcome: Sendable, Equatable {
  case dispatched(occurrenceID: String, commitmentID: String)
  case notDue(occurrenceID: String)
  case skippedNotReady(occurrenceID: String, reason: String)
  /// Could run, but a bounded capacity condition is in the way. It stays due.
  case waiting(occurrenceID: String, reason: String)
}

/// What the host knows about capacity that the organization cannot see for
/// itself, such as whether an employee's runtime is reachable right now.
public struct DispatchCapacity: Sendable, Equatable {
  public var runtimeIsAvailable: Bool
  public var runtimeUnavailableReason: String?

  public init(runtimeIsAvailable: Bool = true, runtimeUnavailableReason: String? = nil) {
    self.runtimeIsAvailable = runtimeIsAvailable
    self.runtimeUnavailableReason = runtimeUnavailableReason
  }

  public static let available = DispatchCapacity()
}

extension OrganizationState {
  /// Occurrences whose window is open right now.
  ///
  /// Open means started and not yet past its flexibility: a window that has
  /// already passed is reconciliation's business, not dispatch's.
  public func dueOccurrences(now: Date) -> [ScheduledOccurrence] {
    scheduledOccurrences
      .filter { occurrence in
        !occurrence.status.isTerminal
          && occurrence.actual == nil
          && now >= occurrence.window.start
          && now <= occurrence.window.latestAcceptableStart
      }
      .sorted { $0.window.start < $1.window.start }
  }

  /// Prepares one due occurrence for execution.
  ///
  /// Returns what happened rather than throwing on the ordinary cases: an
  /// employee who is busy or a commitment that has already finished is a normal
  /// state of the world, not an error.
  @discardableResult
  public mutating func beginScheduledWork(
    _ occurrenceID: String,
    now: Date,
    sessionID: String? = nil,
    runtimeKind: String? = nil,
    capacity: DispatchCapacity = .available
  ) -> ScheduledDispatchOutcome {
    guard let occurrence = scheduledOccurrence(occurrenceID) else {
      return .notDue(occurrenceID: occurrenceID)
    }
    guard now >= occurrence.window.start, now <= occurrence.window.latestAcceptableStart,
      occurrence.actual == nil, !occurrence.status.isTerminal
    else { return .notDue(occurrenceID: occurrenceID) }

    let commitmentID: String
    switch occurrence.origin.subject {
    case .commitment(let id):
      commitmentID = id
    case .recurringResponsibility(let dutyID):
      // A responsibility becomes an occurrence of itself, which carries the
      // canonical commitment the rest of the pipeline understands.
      guard let occurrenceID = try? beginDutyOccurrence(dutyID: dutyID, now: now),
        let canonical = dutyOccurrence(occurrenceID)?.canonicalOutcomeID
      else {
        return .skippedNotReady(
          occurrenceID: occurrenceID,
          reason: "This recurring responsibility could not be started right now.")
      }
      commitmentID = canonical
    }
    guard let commitment = employeeOutcome(commitmentID), !commitment.status.isTerminal else {
      return .skippedNotReady(
        occurrenceID: occurrenceID,
        reason: "The commitment this occurrence points at is no longer open.")
    }
    guard employee(occurrence.origin.employeeID)?.effectiveEmploymentState == .hired else {
      return .skippedNotReady(
        occurrenceID: occurrenceID,
        reason: "This employee is not currently hired, so nothing was started.")
    }
    if let waiting = capacityRefusal(occurrence, commitment: commitment, capacity: capacity) {
      return waiting
    }

    try? startOccurrence(
      occurrenceID, at: now, sessionID: sessionID, runtimeKind: runtimeKind)
    return .dispatched(occurrenceID: occurrenceID, commitmentID: commitmentID)
  }

  /// Closes a dispatched occurrence with what the run actually amounted to.
  ///
  /// The result is read from the commitment rather than assumed: a run that
  /// delivered nothing is quiet, not delivered, and a run that never started is
  /// neither.
  @discardableResult
  public mutating func completeScheduledWork(
    _ occurrenceID: String, now: Date, reason: String
  ) -> RunReceipt? {
    guard let occurrence = scheduledOccurrence(occurrenceID), !occurrence.status.isTerminal
    else { return nil }

    let result: ReceiptResult
    if occurrence.actual == nil {
      result = ReceiptResult(
        kind: .neverRan, summary: "The runtime never started for this window.")
    } else if case .commitment(let commitmentID) = occurrence.origin.subject,
      let commitment = employeeOutcome(commitmentID)
    {
      result = Self.result(for: commitment)
    } else {
      result = ReceiptResult(kind: .quiet, summary: "Ran with nothing to change.")
    }
    return try? finishOccurrence(
      occurrenceID, result: result, reason: reason, endedAt: now)
  }

  /// Bounded capacity conditions, each of which leaves the occurrence due
  /// rather than skipping it: the window may still open again on the next pass.
  private mutating func capacityRefusal(
    _ occurrence: ScheduledOccurrence,
    commitment: EmployeeOutcome,
    capacity: DispatchCapacity
  ) -> ScheduledDispatchOutcome? {
    func wait(_ reason: String) -> ScheduledDispatchOutcome {
      _ = try? updateOccurrenceWaiting(occurrence.id, reason: reason)
      return .waiting(occurrenceID: occurrence.id, reason: reason)
    }

    if !capacity.runtimeIsAvailable {
      return wait(
        capacity.runtimeUnavailableReason
          ?? "This employee's runtime is not available right now.")
    }
    // Actually running, not merely queued: one employee runs one thing at a time.
    if employeeOutcomes.contains(where: {
      $0.assigneeID == occurrence.origin.employeeID && $0.status.isActivelyRunning
        && $0.id != commitment.id
    }) {
      let name = employee(occurrence.origin.employeeID)?.name ?? occurrence.origin.employeeID
      return wait("\(name) is already working on something else.")
    }
    let running = employeeOutcomes.filter { $0.status.isActivelyRunning }.count
    if running >= effectiveConcurrencyLimit {
      return wait(
        "The organization is already running \(running) of \(effectiveConcurrencyLimit) allowed at once."
      )
    }
    if commitment.effectivePlanStatus == .proposed {
      return wait("This plan is waiting for your review.")
    }
    let missingConnections = commitment.selectedSkillIDs
      .compactMap { skillID in knowledge?.skillDefinitions.first { $0.id == skillID } }
      .flatMap(\.requiredConnectionIDs)
      .filter { connectionID in
        knowledge?.connectionDefinitions.contains { $0.id == connectionID } != true
      }
    if let missing = missingConnections.first {
      return wait("This work needs the ‘\(missing)’ connection, which is not set up yet.")
    }
    return nil
  }

  private mutating func updateOccurrenceWaiting(_ occurrenceID: String, reason: String) throws {
    guard let index = knowledge?.scheduledOccurrences.firstIndex(where: { $0.id == occurrenceID })
    else { throw ScheduleError.missingOccurrence(occurrenceID) }
    knowledge?.scheduledOccurrences[index].status = .waiting
    knowledge?.scheduledOccurrences[index].note = reason
  }

  private static func result(for commitment: EmployeeOutcome) -> ReceiptResult {
    switch commitment.status {
    case .delivered, .accepted, .closed:
      return ReceiptResult(
        kind: .changed,
        summary: commitment.deliverySummary ?? "Delivered.",
        evidenceIDs: commitment.artifactIDs
      )
    case .waiting:
      return ReceiptResult(
        kind: .blocked,
        summary: commitment.helpRequest ?? "The employee is waiting on a decision."
      )
    case .failed:
      return ReceiptResult(kind: .failed, summary: "The run did not finish.")
    case .cancelled:
      return ReceiptResult(kind: .skipped, summary: "The commitment was cancelled.")
    default:
      // Ran, and there is nothing to show for it yet. That is a valid outcome
      // and must not be reported as a delivery or as a failure.
      return ReceiptResult(kind: .quiet, summary: "Ran with nothing to change.")
    }
  }
}
