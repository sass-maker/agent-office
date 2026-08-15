import Foundation

/// What a dispatch attempt did, in the caller's terms.
public enum ScheduledDispatchOutcome: Sendable, Equatable {
  case dispatched(occurrenceID: String, commitmentID: String)
  case notDue(occurrenceID: String)
  case skippedNotReady(occurrenceID: String, reason: String)
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
    _ occurrenceID: String, now: Date, sessionID: String? = nil, runtimeKind: String? = nil
  ) -> ScheduledDispatchOutcome {
    guard let occurrence = scheduledOccurrence(occurrenceID) else {
      return .notDue(occurrenceID: occurrenceID)
    }
    guard now >= occurrence.window.start, now <= occurrence.window.latestAcceptableStart,
      occurrence.actual == nil, !occurrence.status.isTerminal
    else { return .notDue(occurrenceID: occurrenceID) }

    guard case .commitment(let commitmentID) = occurrence.origin.subject else {
      return .skippedNotReady(
        occurrenceID: occurrenceID,
        reason: "Recurring responsibilities are still started from their own surface.")
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
