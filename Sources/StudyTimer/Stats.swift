import Foundation

/// The last 24 hours of sessions. Only the part of a session inside the window counts.
struct DayStats: Equatable {
  struct CardTotal: Equatable, Identifiable {
    /// The card ID. Sessions without a card share one total.
    var id: String
    var name: String
    var seconds: TimeInterval
    var isNoCard: Bool { id.isEmpty }
  }

  struct Row: Equatable, Identifiable {
    var session: SessionRow
    var cardNames: [String]
    var seconds: TimeInterval
    var id: String { session.id }
  }

  static let window: TimeInterval = 86_400

  private(set) var total: TimeInterval = 0
  private(set) var cardTotals: [CardTotal] = []
  private(set) var rows: [Row] = []

  init(sessions: [SessionRow], cards: [CardRow], now: Date) {
    let names = Dictionary(cards.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    let windowStart = now.addingTimeInterval(-Self.window)
    var perCard: [String: TimeInterval] = [:]
    for session in sessions {
      let seconds = min(session.end, now).timeIntervalSince(max(session.start, windowStart))
      guard seconds > 0 else { continue }
      // A session linked to several cards counts toward each card, but once in the total.
      total += seconds
      let ids = Set(session.cardIDs)
      for id in ids.isEmpty ? [""] : ids { perCard[id, default: 0] += seconds }
      rows.append(
        Row(
          session: session, cardNames: session.cardIDs.map { names[$0] ?? "Unknown card" },
          seconds: seconds))
    }
    cardTotals = perCard.map { id, seconds in
      CardTotal(
        id: id, name: id.isEmpty ? "No card" : names[id] ?? "Unknown card", seconds: seconds)
    }
    cardTotals.sort {
      $0.seconds != $1.seconds
        ? $0.seconds > $1.seconds : $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
    rows.sort { $0.session.start > $1.session.start }
  }
}

/// Frecency: each session in the last 90 days adds `0.5^(ageDays / 7)` to its cards.
/// Ties put "Doing" first, then sort by name. Cards without a status tie on name alone.
func rankCards(_ cards: [CardRow], sessions: [SessionRow], now: Date) -> [CardRow] {
  var scores: [String: Double] = [:]
  for session in sessions {
    let ageDays = max(0, now.timeIntervalSince(session.start)) / 86_400
    guard ageDays <= 90 else { continue }
    for id in Set(session.cardIDs) { scores[id, default: 0] += pow(0.5, ageDays / 7) }
  }
  return cards.sorted { a, b in
    let scoreA = scores[a.id] ?? 0
    let scoreB = scores[b.id] ?? 0
    if scoreA != scoreB { return scoreA > scoreB }
    let doingA = a.status == "Doing"
    let doingB = b.status == "Doing"
    if doingA != doingB { return doingA }
    return a.name.localizedStandardCompare(b.name) == .orderedAscending
  }
}

/// The plan's title chain: the latest session title of the first card, then its name, then empty.
func defaultTitle(firstCard: CardRow?, sessions: [SessionRow]) -> String {
  guard let card = firstCard else { return "" }
  let latest = sessions.filter { $0.cardIDs.contains(card.id) && !$0.title.isEmpty }
    .max { $0.start < $1.start }
  return latest?.title ?? card.name
}

/// `2h 59m` from an hour, `45m` below.
func hoursMinutes(_ seconds: TimeInterval) -> String {
  let minutes = Int(max(0, seconds) / 60)
  return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

func timeRange(_ start: Date, _ end: Date) -> String {
  let style = Date.FormatStyle(date: .omitted, time: .shortened)
  return "\(start.formatted(style)) – \(end.formatted(style))"
}
