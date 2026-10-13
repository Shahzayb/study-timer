import Foundation
import Testing

@testable import StudyTimer

/// A whole minute, like every interval Notion stores.
private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_040)

private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

private func stopwatch(start: Date = t0) -> ActiveSession {
  ActiveSession(title: "job", cardIDs: ["card"], target: nil, start: start)
}

private func countdown(minutes: Double = 25) -> ActiveSession {
  ActiveSession(title: "english", cardIDs: ["card"], target: minutes * 60, start: t0)
}

@Suite struct ActiveSessionTests {
  @Test func runningTimeFollowsTheWallClock() {
    #expect(stopwatch().elapsed(at: at(90)) == 90)
  }

  @Test func pauseStopsTimeAndResumeContinues() {
    var session = stopwatch()
    session.pause(at: at(600))
    #expect(!session.isRunning)
    #expect(session.elapsed(at: at(900)) == 600)
    session.resume(at: at(900))
    #expect(session.elapsed(at: at(1000)) == 700)
  }

  @Test func repeatedPauseOrResumeChangesNothing() {
    var session = stopwatch()
    session.pause(at: at(600))
    session.pause(at: at(700))
    #expect(session.pausedAt == at(600))
    session.resume(at: at(900))
    session.resume(at: at(950))
    #expect(session.elapsed(at: at(1000)) == 700)
  }

  @Test func sleepPausesAndWakeLeavesItPaused() {
    var session = stopwatch()
    session.pause(at: at(300))
    let wake = at(300 + 8 * 3600)
    #expect(!session.isRunning)
    #expect(session.elapsed(at: wake) == 300)
  }

  @Test func relaunchAfterCrashPausesAtLastHeartbeat() {
    var session = stopwatch()
    session.beat(at: at(30))
    session.beat(at: at(60))
    // Killed at 75 s, relaunched at 500 s.
    let restored = session.restored()
    #expect(!restored.isRunning)
    #expect(restored.pausedAt == at(60))
    #expect(restored.elapsed(at: at(500)) == 60)
  }

  @Test func relaunchAfterCleanQuitPausesAtQuit() {
    var session = stopwatch()
    session.beat(at: at(42))
    #expect(session.restored().elapsed(at: at(900)) == 42)
  }

  @Test func relaunchKeepsAPausedSession() {
    var session = stopwatch()
    session.pause(at: at(100))
    session.beat(at: at(200))
    #expect(session.restored().elapsed(at: at(900)) == 100)
  }

  @Test func savedSessionDecodesUnchanged() throws {
    var session = countdown()
    session.pause(at: at(1600))
    let decoded = try JSONDecoder().decode(
      ActiveSession.self, from: JSONEncoder().encode(session))
    #expect(decoded == session)
    #expect(decoded.targetReached(at: at(2000)) == at(1500))
  }

  @Test func countdownCountsOvertimePastTheTarget() {
    let session = countdown()
    #expect(session.overtime(at: at(1499)) == nil)
    #expect(session.overtime(at: at(1560)) == 60)
    #expect(session.targetReached(at: at(1499)) == nil)
    #expect(session.targetReached(at: at(1560)) == at(1500))
  }

  @Test func stopwatchHasNoTarget() {
    let session = stopwatch()
    #expect(session.overtime(at: at(99_999)) == nil)
    #expect(session.targetReached(at: at(99_999)) == nil)
  }

  @Test func targetMomentSurvivesPauses() {
    var session = countdown()
    session.pause(at: at(600))
    session.resume(at: at(900))
    #expect(session.targetReached(at: at(1799)) == nil)
    #expect(session.targetReached(at: at(1800)) == at(1800))
    session.pause(at: at(2000))
    session.resume(at: at(2500))
    #expect(session.targetReached(at: at(3000)) == at(1800))
    #expect(session.overtime(at: at(3000)) == 700)
  }

  @Test func alarmIsDueOnceTheRunningSegmentReachesTheTarget() {
    var session = countdown()
    session.pause(at: at(600))
    session.resume(at: at(900))
    #expect(!session.alarmDue(at: at(1799)))
    #expect(session.alarmDue(at: at(1800)))
    #expect(session.alarmDue(at: at(2400)))
  }

  @Test func resumeInOvertimeDoesNotRingAgain() {
    var session = countdown()
    session.pause(at: at(1600))
    #expect(!session.alarmDue(at: at(1650)))
    session.resume(at: at(1700))
    #expect(!session.alarmDue(at: at(1800)))
  }

  @Test func restoredOvertimeDoesNotRing() {
    var session = countdown()
    session.beat(at: at(1600))
    session = session.restored()
    session.resume(at: at(5000))
    #expect(!session.alarmDue(at: at(5001)))
  }

  @Test func stopwatchNeverRings() {
    #expect(!stopwatch().alarmDue(at: at(100_000)))
  }

  @Test func commitWhileRunningEndsNowAndPausesMoveTheStart() {
    var session = stopwatch()
    session.pause(at: at(600))
    session.resume(at: at(900))
    #expect(session.commitInterval(at: at(1500)) == DateInterval(start: at(300), end: at(1500)))
  }

  @Test func commitWhilePausedEndsAtThePause() {
    var session = stopwatch()
    session.pause(at: at(1200))
    #expect(session.commitInterval(at: at(5000)) == DateInterval(start: at(0), end: at(1200)))
  }

  @Test func commitWithOvertimeKeepsAllActiveTime() {
    let session = countdown()
    #expect(session.commitInterval(at: at(1620)) == DateInterval(start: at(0), end: at(1620)))
  }

  @Test func commitEndsAtTheMinuteAndRoundsTheActiveTime() {
    let session = stopwatch(start: at(10))
    #expect(session.commitInterval(at: at(99)) == DateInterval(start: at(0), end: at(60)))
    #expect(session.commitInterval(at: at(119)) == DateInterval(start: at(-60), end: at(60)))
  }

  @Test func commitRoundsHalfAMinuteUp() {
    let session = stopwatch()
    #expect(session.commitInterval(at: at(89.9)) == DateInterval(start: at(0), end: at(60)))
    #expect(session.commitInterval(at: at(90)) == DateInterval(start: at(-60), end: at(60)))
  }

  @Test func plannedOnlyEndsAtTheMinuteTheTargetWasReached() {
    var session = countdown()
    session.pause(at: at(30))
    session.resume(at: at(55))
    let interval = session.commitInterval(at: at(2000), plannedOnly: true)
    #expect(interval == DateInterval(start: at(0), end: at(1500)))
    #expect(interval?.duration == 1500)
  }

  @Test func plannedOnlyEndsWhenTheTargetWasReached() {
    var session = countdown()
    session.pause(at: at(600))
    session.resume(at: at(900))
    let interval = session.commitInterval(at: at(2000), plannedOnly: true)
    #expect(interval == DateInterval(start: at(300), end: at(1800)))
    #expect(interval?.duration == 1500)
  }

  @Test func plannedOnlyNeedsAReachedTarget() {
    #expect(countdown().commitInterval(at: at(1000), plannedOnly: true) == nil)
    #expect(stopwatch().commitInterval(at: at(5000), plannedOnly: true) == nil)
  }

  @Test func underHalfAMinuteCannotCommit() {
    var session = stopwatch()
    session.pause(at: at(29.9))
    #expect(session.commitInterval(at: at(100)) == nil)
  }
}
