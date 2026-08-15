import Foundation

/// What a schedule points at. Schedules never define work; they say when
/// existing work is expected.
public enum ScheduleSubject: Codable, Sendable, Equatable, Hashable {
  case commitment(String)
  case recurringResponsibility(String)

  public var id: String {
    switch self {
    case .commitment(let id): id
    case .recurringResponsibility(let id): id
    }
  }
}

public enum ScheduleRecurrence: Codable, Sendable, Equatable {
  case oneTime
  case everyDays(Int)
  case weekly(weekday: Int)

  /// The next instant at or after `date`, or nil when a one-time schedule is
  /// already past.
  func nextInstant(after date: Date, from start: Date, calendar: Calendar) -> Date? {
    switch self {
    case .oneTime:
      return start > date ? start : nil
    case .everyDays(let days):
      guard days > 0 else { return nil }
      var candidate = start
      while candidate <= date {
        guard let next = calendar.date(byAdding: .day, value: days, to: candidate) else {
          return nil
        }
        candidate = next
      }
      return candidate
    case .weekly(let weekday):
      var candidate = start
      while candidate <= date || calendar.component(.weekday, from: candidate) != weekday {
        guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
        candidate = next
        if candidate.timeIntervalSince(date) > 60 * 60 * 24 * 370 { return nil }
      }
      return candidate
    }
  }
}

/// When work is expected, how long it should take, and how much drift is
/// acceptable.
public struct SchedulePlan: Codable, Sendable, Equatable {
  public var recurrence: ScheduleRecurrence
  public var firstStart: Date
  public var expectedDuration: TimeInterval
  /// How late a run may still start before the window is considered missed.
  public var flexibility: TimeInterval
  public var timeZoneIdentifier: String

  public init(
    recurrence: ScheduleRecurrence,
    firstStart: Date,
    expectedDuration: TimeInterval = 900,
    flexibility: TimeInterval = 900,
    timeZoneIdentifier: String = TimeZone.current.identifier
  ) {
    self.recurrence = recurrence
    self.firstStart = firstStart
    self.expectedDuration = expectedDuration
    self.flexibility = flexibility
    self.timeZoneIdentifier = timeZoneIdentifier
  }

  var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    return calendar
  }
}

/// An owner-authored statement of when existing work is expected.
public struct SchedulePolicy: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var employeeID: String
  public var subject: ScheduleSubject
  public var plan: SchedulePlan
  public var authoredByActorID: String
  public var createdAt: Date
  public var isPaused: Bool
  /// What the owner decided happens to a window that passes unexecuted.
  /// Optional so policies written before catch-up existed still decode.
  public var catchUpPolicy: ScheduleCatchUpPolicy?

  public init(
    id: String = UUID().uuidString,
    employeeID: String,
    subject: ScheduleSubject,
    plan: SchedulePlan,
    createdAt: Date = Date(),
    isPaused: Bool = false,
    catchUp: ScheduleCatchUpPolicy = .leaveMissed
  ) {
    self.authoredByActorID = "owner"
    self.id = id
    self.employeeID = employeeID
    self.subject = subject
    self.plan = plan
    self.createdAt = createdAt
    self.isPaused = isPaused
    self.catchUpPolicy = catchUp
  }

  public var catchUp: ScheduleCatchUpPolicy { catchUpPolicy ?? .leaveMissed }

  /// Scheduled instants inside a horizon.
  ///
  /// Bounded deliberately: an unbounded recurrence would generate forever.
  public func instants(from: Date, through horizon: Date) -> [Date] {
    guard !isPaused, horizon > from else { return [] }
    let calendar = plan.calendar
    var instants: [Date] = []
    if plan.firstStart >= from, plan.firstStart <= horizon { instants.append(plan.firstStart) }
    var cursor = max(from, plan.firstStart.addingTimeInterval(-1))
    while instants.count < 512,
      let next = plan.recurrence.nextInstant(
        after: cursor, from: plan.firstStart, calendar: calendar),
      next <= horizon
    {
      instants.append(next)
      cursor = next
    }
    return instants.sorted()
  }
}

/// How a scheduled occurrence ended, kept deliberately distinct.
public enum OccurrenceStatus: String, Codable, Sendable, CaseIterable {
  case scheduled
  case ready
  case waiting
  case running
  /// Ran and found nothing to change. Not a failure.
  case quiet
  case delivered
  case blocked
  case failed
  case skipped
  case cancelled
  /// The window passed and nothing ran.
  case missed

  public var isTerminal: Bool {
    switch self {
    case .quiet, .delivered, .blocked, .failed, .skipped, .cancelled, .missed: true
    case .scheduled, .ready, .waiting, .running: false
    }
  }
}

/// What actually happened, as opposed to what was planned.
public struct OccurrenceActual: Codable, Sendable, Equatable {
  public var startedAt: Date
  public var endedAt: Date?
  public var runtimeSessionID: String?
  public var runtimeKind: String?

  public init(
    startedAt: Date,
    endedAt: Date? = nil,
    runtimeSessionID: String? = nil,
    runtimeKind: String? = nil
  ) {
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.runtimeSessionID = runtimeSessionID
    self.runtimeKind = runtimeKind
  }

  public var duration: TimeInterval? { endedAt.map { $0.timeIntervalSince(startedAt) } }
}

public struct OccurrenceOrigin: Codable, Sendable, Equatable {
  public var policyID: String
  public var employeeID: String
  public var subject: ScheduleSubject

  public init(policyID: String, employeeID: String, subject: ScheduleSubject) {
    self.policyID = policyID
    self.employeeID = employeeID
    self.subject = subject
  }
}

public struct OccurrenceWindow: Codable, Sendable, Equatable {
  public var start: Date
  public var duration: TimeInterval
  public var flexibility: TimeInterval

  public init(start: Date, duration: TimeInterval, flexibility: TimeInterval) {
    self.start = start
    self.duration = duration
    self.flexibility = flexibility
  }

  /// The last moment a run may still begin before the window counts as missed.
  public var latestAcceptableStart: Date { start.addingTimeInterval(flexibility) }
}

/// One expected run of scheduled work.
public struct ScheduledOccurrence: Codable, Sendable, Equatable, Identifiable {
  public var id: String
  public var origin: OccurrenceOrigin
  public var window: OccurrenceWindow
  public var status: OccurrenceStatus
  public var actual: OccurrenceActual?
  public var note: String?
  /// Set when this occurrence exists because an earlier window was missed. A
  /// replacement is never itself rescheduled, so catching up cannot chain.
  public var replacesOccurrenceID: String?

  public init(
    id: String,
    origin: OccurrenceOrigin,
    window: OccurrenceWindow,
    status: OccurrenceStatus = .scheduled,
    actual: OccurrenceActual? = nil,
    note: String? = nil,
    replacesOccurrenceID: String? = nil
  ) {
    self.id = id
    self.origin = origin
    self.window = window
    self.status = status
    self.actual = actual
    self.note = note
    self.replacesOccurrenceID = replacesOccurrenceID
  }

  /// Derived from policy and instant, so regenerating cannot create a second
  /// occurrence for the same moment.
  public static func identifier(policyID: String, instant: Date) -> String {
    "occurrence-\(policyID)-\(Int(instant.timeIntervalSince1970))"
  }
}
