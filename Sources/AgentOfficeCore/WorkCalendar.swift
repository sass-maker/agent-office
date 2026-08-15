import Foundation

/// What the owner decided should happen to a window that passed unexecuted.
public enum ScheduleCatchUpPolicy: String, Codable, Sendable, CaseIterable {
  /// Leave it missed. Honest, and the default.
  case leaveMissed
  /// Move it into the next window. Still does not run anything late.
  case rescheduleToNextWindow
}

/// One occurrence as the calendar shows it.
public struct CalendarBlock: Sendable, Equatable, Identifiable {
  public var id: String
  public var employeeID: String
  public var employeeName: String
  public var subject: ScheduleSubject
  public var window: OccurrenceWindow
  public var status: OccurrenceStatus
  public var actual: OccurrenceActual?
  /// The receipt's one-line answer to "did anything happen?", when it finished.
  public var receiptHeadline: String?

  /// Text, never colour alone, so status survives a monochrome or high-contrast
  /// reading of the surface.
  public var statusLabel: String {
    switch status {
    case .scheduled: "Scheduled"
    case .ready: "Ready"
    case .waiting: "Waiting"
    case .running: "Running"
    case .quiet: "Ran, nothing to change"
    case .delivered: "Delivered"
    case .blocked: "Blocked"
    case .failed: "Did not finish"
    case .skipped: "Skipped"
    case .cancelled: "Cancelled"
    case .missed: "Missed"
    }
  }

  public var didActuallyRun: Bool { actual?.startedAt != nil }
}

public struct CalendarDay: Sendable, Equatable, Identifiable {
  public var id: Date
  public var date: Date
  public var blocks: [CalendarBlock]
}

extension OrganizationState {
  /// Occurrences grouped by day.
  ///
  /// A projection only: it never authors a block, so an empty week is shown as
  /// an empty week rather than a grid of imagined slots.
  public func calendarDays(
    from: Date, through horizon: Date, timeZoneIdentifier: String = TimeZone.current.identifier
  ) -> [CalendarDay] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

    let blocks =
      scheduledOccurrences
      .filter { $0.window.start >= from && $0.window.start <= horizon }
      .map { occurrence in
        CalendarBlock(
          id: occurrence.id,
          employeeID: occurrence.origin.employeeID,
          employeeName: employee(occurrence.origin.employeeID)?.name
            ?? occurrence.origin.employeeID,
          subject: occurrence.origin.subject,
          window: occurrence.window,
          status: occurrence.status,
          actual: occurrence.actual,
          receiptHeadline: runReceipt(forOccurrence: occurrence.id)?.headline
        )
      }

    let grouped = Dictionary(grouping: blocks) { calendar.startOfDay(for: $0.window.start) }
    return grouped.keys.sorted().map { day in
      CalendarDay(
        id: day,
        date: day,
        blocks: grouped[day, default: []].sorted { $0.window.start < $1.window.start }
      )
    }
  }

  /// Applies each policy's catch-up decision to windows that passed unexecuted.
  ///
  /// Returns the occurrences it rescheduled. Nothing is executed late; a
  /// replacement is a future window, not a retroactive run.
  @discardableResult
  public mutating func applyCatchUpPolicies(now: Date) -> [String] {
    let missedIDs = reconcileMissedOccurrences(now: now)
    guard !missedIDs.isEmpty, knowledge != nil else { return [] }

    var rescheduled: [String] = []
    for missedID in missedIDs {
      guard let missed = scheduledOccurrence(missedID),
        // A replacement that is itself missed stays missed: catching up once is
        // a decision, catching up forever is a loop.
        missed.replacesOccurrenceID == nil,
        let policy = schedulePolicy(missed.origin.policyID),
        policy.catchUp == .rescheduleToNextWindow,
        !policy.isPaused
      else { continue }

      let nextStart = missed.window.start.addingTimeInterval(policy.plan.expectedDuration + 60)
      let replacementID = "\(missedID)-catchup"
      guard scheduledOccurrence(replacementID) == nil else { continue }

      knowledge?.scheduledOccurrences.append(
        ScheduledOccurrence(
          id: replacementID,
          origin: missed.origin,
          window: OccurrenceWindow(
            start: max(nextStart, now),
            duration: missed.window.duration,
            flexibility: missed.window.flexibility
          ),
          note: "Rescheduled after \(missedID) was missed. Nothing was run late.",
          replacesOccurrenceID: missedID
        ))
      rescheduled.append(replacementID)
    }
    return rescheduled
  }
}
