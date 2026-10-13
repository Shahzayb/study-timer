import Foundation

/// The timing state of the session in progress. Every method takes the current moment, so tests control time.
struct ActiveSession: Codable, Equatable, Sendable {
  var title: String
  var cardIDs: [String]
  /// The countdown length. A stopwatch has none.
  var target: TimeInterval?
  /// Active time of the finished segments.
  var accumulated: TimeInterval = 0
  /// The start of the running segment. Nil while paused.
  var segmentStart: Date?
  /// The moment of the last pause. Nil while running.
  var pausedAt: Date?
  /// The last moment the app saw the session alive.
  var heartbeat: Date
  /// The moment elapsed time reached the target, once a finished segment crossed it.
  private var reachedAt: Date?

  init(title: String, cardIDs: [String], target: TimeInterval?, start: Date) {
    self.title = title
    self.cardIDs = cardIDs
    self.target = target
    segmentStart = start
    heartbeat = start
  }

  var isRunning: Bool { segmentStart != nil }

  func elapsed(at now: Date) -> TimeInterval {
    accumulated + (segmentStart.map { max(0, now.timeIntervalSince($0)) } ?? 0)
  }

  /// Time past the target. Nil before the target and for a stopwatch.
  func overtime(at now: Date) -> TimeInterval? {
    guard let target else { return nil }
    let over = elapsed(at: now) - target
    return over >= 0 ? over : nil
  }

  /// The moment elapsed time reached the target. Nil before that and for a stopwatch.
  func targetReached(at now: Date) -> Date? {
    if let reachedAt { return reachedAt }
    guard let target, let segmentStart, elapsed(at: now) >= target else { return nil }
    return segmentStart.addingTimeInterval(target - accumulated)
  }

  mutating func pause(at now: Date) {
    guard let segmentStart else { return }
    reachedAt = targetReached(at: now)
    accumulated += max(0, now.timeIntervalSince(segmentStart))
    self.segmentStart = nil
    pausedAt = now
    heartbeat = now
  }

  mutating func resume(at now: Date) {
    guard !isRunning else { return }
    segmentStart = now
    pausedAt = nil
    heartbeat = now
  }

  mutating func beat(at now: Date) {
    heartbeat = now
  }

  /// The session as loaded after a quit, crash, or shutdown. A running one pauses at its last heartbeat.
  func restored() -> ActiveSession {
    var session = self
    session.pause(at: heartbeat)
    return session
  }

  /// The Notion `Interval` at `now`, in whole minutes because Notion drops seconds. Nil when it rounds to zero.
  /// `plannedOnly` ends it when elapsed time reached the target, so its length equals the target.
  func commitInterval(at now: Date, plannedOnly: Bool = false) -> DateInterval? {
    if plannedOnly {
      guard let target, let reached = targetReached(at: now) else { return nil }
      let end = reached.wholeMinute
      return DateInterval(start: end.addingTimeInterval(-target), end: end)
    }
    let moment = pausedAt ?? now
    let active = (elapsed(at: moment) / 60).rounded() * 60
    guard active > 0 else { return nil }
    let end = moment.wholeMinute
    return DateInterval(start: end.addingTimeInterval(-active), end: end)
  }
}

extension Date {
  fileprivate var wholeMinute: Date {
    Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
  }
}
