import Foundation
import Testing

@testable import StudyTimer

/// Property names differ from the live databases, so every lookup has to go by type or ID.
private let sessionsSource = """
  {"object": "data_source", "id": "aaaa", "title": [{"plain_text": "Study Timer Test"}],
   "properties": {
     "Name": {"id": "title", "name": "Name", "type": "title", "title": {}},
     "When": {"id": "d%3Ab", "name": "When", "type": "date", "date": {}},
     "Minutes": {"id": "m%7C", "name": "Minutes", "type": "formula", "formula": {"expression": "1"}},
     "Cards": {"id": "r%3Ax", "name": "Cards", "type": "relation",
               "relation": {"data_source_id": "cccc", "type": "single_property", "single_property": {}}}
   }}
  """

private let cardsSource = """
  {"object": "data_source", "id": "cccc", "title": [{"plain_text": "My Learning Path"}],
   "properties": {
     "Topic": {"id": "title", "name": "Topic", "type": "title", "title": {}},
     "Priority": {"id": "p", "name": "Priority", "type": "select", "select": {"options": []}},
     "Status": {"id": "s%3D", "name": "Status", "type": "select", "select": {"options": []}}
   }}
  """

private func sessionPage(_ id: String, start: String, end: String?, cards: [String]) -> String {
  let relation = cards.map { "{\"id\": \"\($0)\"}" }.joined(separator: ", ")
  let endJSON = end.map { "\"\($0)\"" } ?? "null"
  return """
    {"object": "page", "id": "\(id)", "properties": {
      "Name": {"id": "title", "type": "title", "title": [{"plain_text": "drill "}, {"plain_text": "12"}]},
      "When": {"id": "d%3Ab", "type": "date", "date": {"start": "\(start)", "end": \(endJSON), "time_zone": null}},
      "Cards": {"id": "r%3Ax", "type": "relation", "relation": [\(relation)], "has_more": false}
    }}
    """
}

private func list(_ pages: [String], next: String?) -> String {
  let cursor = next.map { "\"\($0)\"" } ?? "null"
  return """
    {"object": "list", "results": [\(pages.joined(separator: ", "))],
     "next_cursor": \(cursor), "has_more": \(next != nil)}
    """
}

private let schema = NotionSchema(
  sessionsID: "aaaa", sessionsName: "Study Timer Test", titleID: "title", dateID: "d%3Ab",
  relationID: "r%3Ax", cardsDataSourceID: "cccc", cardTitleID: "title", cardStatusID: "s%3D")

private func client(_ handler: @escaping (NotionStub.Call) throws -> (Int, String)) -> NotionClient
{
  NotionClient(apiKey: "test-key", session: NotionStub.session(handler))
}

@Suite(.serialized) struct NotionClientTests {
  @Test func discoveryResolvesPropertiesByType() async throws {
    let notion = client { call in
      switch call.path {
      case "/v1/data_sources/aaaa": (200, sessionsSource)
      case "/v1/data_sources/cccc": (200, cardsSource)
      default: (404, #"{"message": "not found"}"#)
      }
    }
    #expect(try await notion.discover(sessionsID: "aaaa") == schema)
  }

  @Test func discoveryWithoutStatusSkipsIt() async throws {
    let plainCards = cardsSource.replacingOccurrences(of: "\"Status\"", with: "\"Stage\"")
    let notion = client { call in
      (200, call.path.hasSuffix("aaaa") ? sessionsSource : plainCards)
    }
    #expect(try await notion.discover(sessionsID: "aaaa").cardStatusID == nil)
  }

  @Test func discoveryNeedsADateProperty() async {
    let undated = sessionsSource.replacingOccurrences(
      of: "\"type\": \"date\"", with: "\"type\": \"rich_text\"")
    let notion = client { _ in (200, undated) }
    await #expect(throws: NotionError.missingProperty("Study Timer Test has no date property.")) {
      try await notion.discover(sessionsID: "aaaa")
    }
  }

  @Test func discoveryRejectsAnIDThatIsNotHex() async {
    let notion = client { _ in (200, sessionsSource) }
    await #expect(throws: NotionError.badID) {
      try await notion.discover(sessionsID: "../users")
    }
    #expect(NotionStub.calls.isEmpty)
  }

  @Test func requestsCarryTheVersionAndKey() async throws {
    var headers: [String: String] = [:]
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HeaderSpy.self]
    HeaderSpy.seen = { headers = $0 }
    let notion = NotionClient(apiKey: "test-key", session: URLSession(configuration: configuration))
    _ = try? await notion.discover(sessionsID: "aaaa")
    #expect(headers["Notion-Version"] == "2025-09-03")
    #expect(headers["Authorization"] == "Bearer test-key")
  }

  @Test func sessionsFollowEveryCursor() async throws {
    let notion = client { call in
      call.body["start_cursor"] == nil
        ? (
          200,
          list(
            [
              sessionPage(
                "p1", start: "2026-10-12T09:00:00.000+00:00", end: "2026-10-12T09:45:00.000+00:00",
                cards: ["c1"])
            ], next: "page-2")
        )
        : (
          200,
          list([sessionPage("p2", start: "2026-10-12T11:00:00Z", end: nil, cards: [])], next: nil)
        )
    }
    let rows = try await notion.sessions(schema, since: Date(timeIntervalSince1970: 0))

    #expect(NotionStub.calls.count == 2)
    #expect(NotionStub.calls[1].body["start_cursor"] as? String == "page-2")
    #expect(NotionStub.calls[0].body["page_size"] as? Int == 100)
    #expect(rows.map(\.id) == ["p1", "p2"])
    #expect(rows[0].title == "drill 12")
    #expect(rows[0].cardIDs == ["c1"])
    #expect(rows[0].end.timeIntervalSince(rows[0].start) == 45 * 60)
    #expect(rows[1].end == rows[1].start)
  }

  @Test func sessionsFilterByStartDate() async throws {
    let notion = client { _ in (200, list([], next: nil)) }
    _ = try await notion.sessions(schema, since: Date(timeIntervalSince1970: 1_790_000_000))
    let filter = try #require(NotionStub.calls.first?.body["filter"] as? [String: Any])
    #expect(filter["property"] as? String == "d%3Ab")
    #expect((filter["date"] as? [String: String])?["on_or_after"] == "2026-09-21T14:13:20Z")
  }

  @Test func cardsReadNameAndStatus() async throws {
    let card = """
      {"object": "page", "id": "c1", "properties": {
        "Topic": {"id": "title", "type": "title", "title": [{"plain_text": "English"}]},
        "Status": {"id": "s%3D", "type": "select", "select": {"name": "Doing", "color": "yellow"}}
      }}
      """
    let notion = client { _ in (200, list([card], next: nil)) }
    #expect(try await notion.cards(schema) == [CardRow(id: "c1", name: "English", status: "Doing")])
    #expect(NotionStub.calls.first?.path == "/v1/data_sources/cccc/query")
  }

  @Test(arguments: [
    (401, "Key rejected"), (403, "Database not shared"), (404, "Database not shared"),
    (400, "Notion rejected the row"), (429, "Notion unavailable"), (503, "Notion unavailable"),
  ])
  func httpErrorsMapToTheSpecText(status: Int, text: String) async {
    let notion = client { _ in (status, #"{"object": "error", "message": "nope"}"#) }
    do {
      _ = try await notion.discover(sessionsID: "aaaa")
      Issue.record("Expected an error")
    } catch let error as NotionError {
      #expect(error == .http(status: status, message: "nope"))
      #expect(error.text == text)
    } catch {
      Issue.record("Unexpected \(error)")
    }
  }

  @Test func networkFailureReadsOffline() async {
    let notion = client { _ in throw URLError(.notConnectedToInternet) }
    do {
      _ = try await notion.discover(sessionsID: "aaaa")
      Issue.record("Expected an error")
    } catch let error as NotionError {
      #expect(error.text == "Offline")
    } catch {
      Issue.record("Unexpected \(error)")
    }
  }
}

/// Records request headers. URLProtocol sees them, unlike the body.
private final class HeaderSpy: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var seen: ([String: String]) -> Void = { _ in }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}
  override func startLoading() {
    Self.seen(request.allHTTPHeaderFields ?? [:])
    client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
  }
}

@Suite struct NotionDateTests {
  private let expected = Date(timeIntervalSince1970: 1_791_779_400)  // 2026-10-12T04:30:00Z

  @Test(arguments: [
    "2026-10-12T04:30:00.000Z", "2026-10-12T04:30:00Z",
    "2026-10-12T04:30:00.000+00:00", "2026-10-12T04:30:00+00:00",
  ])
  func parsesEveryTimestampForm(_ string: String) {
    #expect(NotionDate.parse(string) == expected)
  }

  @Test func keepsMilliseconds() {
    #expect(NotionDate.parse("2026-10-12T04:30:00.250Z") == expected.addingTimeInterval(0.25))
  }

  @Test func readsADateOnlyValueAsLocalMidnight() throws {
    let date = try #require(NotionDate.parse("2026-10-12"))
    let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    #expect(parts == DateComponents(year: 2026, month: 10, day: 12, hour: 0, minute: 0))
  }

  @Test func rejectsGarbage() {
    #expect(NotionDate.parse("yesterday") == nil)
  }
}
