import Foundation
import Testing

@testable import StudyTimer

private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

private func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

private func session(
  _ id: String, _ title: String = "s", from start: Double, to end: Double, cards: [String]
) -> SessionRow {
  SessionRow(id: id, title: title, start: hoursAgo(start), end: hoursAgo(end), cardIDs: cards)
}

private let english = CardRow(id: "en", name: "English", status: "Doing")
private let job = CardRow(id: "job", name: "Job Search", status: "Doing")
private let swift = CardRow(id: "sw", name: "Swift", status: nil)
private let algebra = CardRow(id: "la", name: "Linear Algebra", status: "Backlog")

@Suite struct DayStatsTests {
  @Test func countsOnlyThePartInsideTheWindow() {
    let stats = DayStats(
      sessions: [
        session("inside", from: 2, to: 1, cards: ["en"]),
        session("crossing", from: 25, to: 23, cards: ["en"]),
        session("before", from: 30, to: 29, cards: ["en"]),
      ], cards: [english], now: now)
    #expect(stats.total == 2 * 3600)
    #expect(stats.rows.map(\.id) == ["inside", "crossing"])
    #expect(stats.rows.map(\.seconds) == [3600, 3600])
  }

  @Test func aMultiCardSessionCountsOncePerCardAndOnceInTheTotal() {
    let stats = DayStats(
      sessions: [session("a", from: 3, to: 2, cards: ["en", "job", "en"])], cards: [english, job],
      now: now)
    #expect(stats.total == 3600)
    #expect(stats.bars.map(\.name) == ["English", "Job Search"])
    #expect(stats.bars.map(\.seconds) == [3600, 3600])
  }

  @Test func sessionsWithoutACardShareOneBar() {
    let stats = DayStats(
      sessions: [
        session("a", from: 5, to: 4.5, cards: []), session("b", from: 3, to: 2.5, cards: []),
        session("c", from: 2, to: 0, cards: ["en"]),
      ], cards: [english], now: now)
    #expect(stats.bars.map(\.name) == ["English", "No card"])
    #expect(stats.bars.last?.isNoCard == true)
    #expect(stats.bars.last?.seconds == 3600)
  }

  @Test func rowsRunNewestFirstAndNameUnknownCards() {
    let stats = DayStats(
      sessions: [
        session("old", from: 10, to: 9, cards: ["gone"]),
        session("new", from: 2, to: 1, cards: ["en"]),
      ], cards: [english], now: now)
    #expect(stats.rows.map(\.id) == ["new", "old"])
    #expect(stats.rows.last?.cardNames == ["Unknown card"])
  }

  @Test func futureAndBackwardSessionsDoNotCount() {
    let stats = DayStats(
      sessions: [
        session("future", from: -2, to: -3, cards: ["en"]),
        session("backward", from: 1, to: 2, cards: ["en"]),
      ], cards: [english], now: now)
    #expect(stats.total == 0)
    #expect(stats.rows.isEmpty)
    #expect(stats.bars.isEmpty)
  }
}

@Suite struct RankingTests {
  @Test func recentUseOutranksOlderFrequentUse() {
    let sessions = [
      session("a", from: 2, to: 1, cards: ["sw"]),
      session("b", from: 21 * 24, to: 21 * 24 - 1, cards: ["en"]),
      session("c", from: 21 * 24 + 2, to: 21 * 24 + 1, cards: ["en"]),
      session("d", from: 21 * 24 + 4, to: 21 * 24 + 3, cards: ["en"]),
    ]
    let ranked = rankCards([english, swift], sessions: sessions, now: now)
    #expect(ranked.map(\.id) == ["sw", "en"])
  }

  @Test func tiesPutDoingFirstThenSortByName() {
    let ranked = rankCards([swift, job, algebra, english], sessions: [], now: now)
    #expect(ranked.map(\.name) == ["English", "Job Search", "Linear Algebra", "Swift"])
  }

  @Test func withoutStatusTiesSortByName() {
    let plain = [job, english, algebra].map { CardRow(id: $0.id, name: $0.name, status: nil) }
    #expect(
      rankCards(plain, sessions: [], now: now).map(\.name) == [
        "English", "Job Search", "Linear Algebra",
      ])
  }

  @Test func sessionsOlderThanNinetyDaysDoNotCount() {
    let sessions = [session("a", from: 91 * 24, to: 91 * 24 - 1, cards: ["sw"])]
    #expect(rankCards([swift, english], sessions: sessions, now: now).map(\.id) == ["en", "sw"])
  }
}

@Suite struct DefaultTitleTests {
  @Test func usesTheLatestSessionOfTheFirstCard() {
    let sessions = [
      session("a", "drill 11", from: 30, to: 29, cards: ["sw"]),
      session("b", "drill 12", from: 5, to: 4, cards: ["sw", "en"]),
      session("c", "english", from: 1, to: 0, cards: ["en"]),
    ]
    #expect(defaultTitle(firstCard: swift, sessions: sessions) == "drill 12")
  }

  @Test func fallsBackToTheCardName() {
    let sessions = [session("a", "", from: 2, to: 1, cards: ["la"])]
    #expect(defaultTitle(firstCard: algebra, sessions: sessions) == "Linear Algebra")
  }

  @Test func isEmptyWithoutACard() {
    #expect(defaultTitle(firstCard: nil, sessions: []) == "")
  }
}

@Suite struct FormatTests {
  @Test(arguments: [(0.0, "0m"), (59.0, "0m"), (45 * 60.0, "45m"), (10_740.0, "2h 59m")])
  func hoursMinutesRoundsDown(seconds: Double, text: String) {
    #expect(hoursMinutes(seconds) == text)
  }
}
