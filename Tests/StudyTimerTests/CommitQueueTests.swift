import Foundation
import Testing

@testable import StudyTimer

@Suite struct CommitQueueTests {
  @Test(arguments: [(1, 30.0), (2, 60.0), (3, 120.0), (4, 300.0), (12, 300.0)])
  func backoffFollowsThePlan(failures: Int, seconds: TimeInterval) {
    #expect(retryDelay(afterFailures: failures) == seconds)
  }

  @Test func onlyRequestErrorsArePermanent() {
    for status in [400, 401, 403, 404] {
      #expect(NotionError.http(status: status, message: "").isPermanent)
    }
    for status in [409, 500, 503] {
      #expect(!NotionError.http(status: status, message: "").isPermanent)
    }
    #expect(!NotionError.offline("").isPermanent)
    #expect(!NotionError.unreadable("").isPermanent)
    #expect(!NotionError.rateLimited(retryAfter: nil, message: "").isPermanent)
  }

  @Test func aRowMatchesWithTheSameTitleWithinAMinute() {
    let start = Date(timeIntervalSince1970: 1_791_779_400)
    let commit = PendingCommit(
      title: "drill", cardIDs: [], interval: DateInterval(start: start, duration: 600),
      dataSourceID: "aaaa")
    func row(_ title: String, _ offset: TimeInterval) -> SessionRow {
      SessionRow(
        id: "p", title: title, start: start.addingTimeInterval(offset),
        end: start.addingTimeInterval(600), cardIDs: [])
    }
    #expect(commit.matches(row("drill", -60)))
    #expect(commit.matches(row("drill", 59)))
    #expect(!commit.matches(row("drill", 61)))
    #expect(!commit.matches(row("Drill", 0)))
  }

  @Test func aCommitSurvivesTheDiskRoundTrip() throws {
    var commit = PendingCommit(
      title: "drill", cardIDs: ["c1"],
      interval: DateInterval(start: Date(timeIntervalSince1970: 1_791_779_400), duration: 600),
      dataSourceID: "aaaa", attempts: 2)
    commit.failure = Failure(text: "Key rejected", detail: "401: nope")
    let data = try JSONEncoder().encode([commit])
    #expect(try JSONDecoder().decode([PendingCommit].self, from: data) == [commit])
  }
}
