import Foundation

/// The resolved property IDs of the sessions and cards data sources. IDs survive renames in Notion.
struct NotionSchema: Equatable, Sendable {
  var sessionsID: String
  var sessionsName: String
  var titleID: String
  var dateID: String
  var relationID: String
  var cardsDataSourceID: String
  var cardTitleID: String
  /// Nil when the cards have no `Status` select. Ranking then skips the "Doing" tie-break.
  var cardStatusID: String?
}

struct SessionRow: Equatable, Sendable {
  var id: String
  var title: String
  var start: Date
  var end: Date
  var cardIDs: [String]
}

struct CardRow: Equatable, Sendable {
  var id: String
  var name: String
  var status: String?
}

enum NotionError: Error, Equatable {
  case offline(String)
  case http(status: Int, message: String)
  case missingProperty(String)
  case badID
  case unreadable(String)

  /// One short line for the UI, from the error table in the plan's UI spec.
  var text: String {
    switch self {
    case .offline: "Offline"
    case .http(401, _): "Key rejected"
    case .http(403, _), .http(404, _): "Database not shared"
    case .http(429, _), .http(500..., _): "Notion unavailable"
    case .http: "Notion rejected the row"
    case .missingProperty: "Database missing a property"
    case .badID: "Not a data source ID"
    case .unreadable: "Unexpected Notion response"
    }
  }

  /// The full message for a tooltip.
  var detail: String {
    switch self {
    case .offline(let message), .missingProperty(let message), .unreadable(let message): message
    case .http(let status, let message): "\(status): \(message)"
    case .badID: "A data source ID holds only hex digits and dashes."
    }
  }
}

/// Notion REST access. Title, date, and relation properties resolve by type. Card `Status` resolves by name.
struct NotionClient: Sendable {
  let apiKey: String
  var session: URLSession = .shared

  func discover(sessionsID: String) async throws -> NotionSchema {
    let sessions = try await dataSource(sessionsID)
    let relation = try sessions.property(ofType: "relation")
    guard let cardsID = relation.relation?.dataSourceId else {
      throw NotionError.missingProperty("The relation in \(sessions.name) has no data source.")
    }
    let cards = try await dataSource(cardsID)
    let status = cards.properties.values.first {
      $0.name == "Status" && ($0.type == "select" || $0.type == "status")
    }
    return NotionSchema(
      sessionsID: sessionsID,
      sessionsName: sessions.name,
      titleID: try sessions.property(ofType: "title").id,
      dateID: try sessions.property(ofType: "date").id,
      relationID: relation.id,
      cardsDataSourceID: cardsID,
      cardTitleID: try cards.property(ofType: "title").id,
      cardStatusID: status?.id
    )
  }

  /// Sessions that start on or after `since`. Rows without a readable start are skipped.
  func sessions(_ schema: NotionSchema, since: Date) async throws -> [SessionRow] {
    let filter = Query.Filter(
      property: schema.dateID, date: .init(onOrAfter: since.formatted(.iso8601)))
    return try await query(schema.sessionsID, filter: filter).compactMap { page in
      let properties = page.byID
      guard let date = properties[schema.dateID]?.date, let start = NotionDate.parse(date.start)
      else { return nil }
      return SessionRow(
        id: page.id,
        title: properties[schema.titleID]?.title?.plainText ?? "",
        start: start,
        end: date.end.flatMap(NotionDate.parse) ?? start,
        cardIDs: properties[schema.relationID]?.relation?.map(\.id) ?? []
      )
    }
  }

  func cards(_ schema: NotionSchema) async throws -> [CardRow] {
    try await query(schema.cardsDataSourceID, filter: nil).map { page in
      let properties = page.byID
      let status = schema.cardStatusID.flatMap { properties[$0] }
      return CardRow(
        id: page.id,
        name: properties[schema.cardTitleID]?.title?.plainText ?? "",
        status: (status?.select ?? status?.status)?.name
      )
    }
  }

  // MARK: Requests

  private func dataSource(_ id: String) async throws -> DataSource {
    try await send("GET", "data_sources/\(try checked(id))", body: nil)
  }

  /// Follows `next_cursor` until the last page. Notion returns at most 100 rows per call.
  private func query(_ id: String, filter: Query.Filter?) async throws -> [Page] {
    var pages: [Page] = []
    var cursor: String?
    repeat {
      let body = Query(filter: filter, startCursor: cursor, pageSize: 100)
      let list: PageList = try await send(
        "POST", "data_sources/\(try checked(id))/query", body: try Self.encoder.encode(body))
      pages += list.results
      cursor = list.hasMore ? list.nextCursor : nil
    } while cursor != nil
    return pages
  }

  private func checked(_ id: String) throws -> String {
    guard !id.isEmpty, id.allSatisfy({ $0.isHexDigit || $0 == "-" }) else {
      throw NotionError.badID
    }
    return id
  }

  private func send<T: Decodable>(_ method: String, _ path: String, body: Data?) async throws -> T {
    var request = URLRequest(
      url: URL(string: "https://api.notion.com/v1/\(path)")!, timeoutInterval: 20)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("2025-09-03", forHTTPHeaderField: "Notion-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError {
      throw NotionError.offline(error.localizedDescription)
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      let message = (try? Self.decoder.decode(ErrorBody.self, from: data))?.message ?? ""
      throw NotionError.http(status: status, message: message)
    }
    do {
      return try Self.decoder.decode(T.self, from: data)
    } catch {
      throw NotionError.unreadable("\(error)")
    }
  }

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
  }()
}

/// Parses the three forms Notion returns: with milliseconds, without them, and date-only.
enum NotionDate {
  static func parse(_ string: String) -> Date? {
    if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) {
      return date
    }
    if let date = try? Date.ISO8601FormatStyle().parse(string) { return date }
    // A date-only value has no time zone. It means local midnight.
    return try? Date.ISO8601FormatStyle(timeZone: .current).year().month().day().parse(string)
  }
}

// MARK: Wire format

private struct Query: Encodable {
  struct Filter: Encodable {
    struct OnOrAfter: Encodable {
      let onOrAfter: String
    }
    let property: String
    let date: OnOrAfter
  }

  let filter: Filter?
  let startCursor: String?
  let pageSize: Int
}

private struct DataSource: Decodable {
  struct Property: Decodable {
    struct Relation: Decodable {
      let dataSourceId: String
    }
    let id: String
    let name: String
    let type: String
    let relation: Relation?
  }

  let title: [RichText]
  let properties: [String: Property]

  var name: String { title.plainText }

  /// Exactly one property MUST have the type. Two date properties, for example, leave the choice ambiguous.
  func property(ofType type: String) throws -> Property {
    let matches = properties.values.filter { $0.type == type }
    guard matches.count == 1 else {
      throw NotionError.missingProperty(
        matches.isEmpty
          ? "\(name) has no \(type) property."
          : "\(name) has \(matches.count) \(type) properties. The app needs exactly one.")
    }
    return matches[0]
  }
}

private struct RichText: Decodable {
  let plainText: String
}

extension [RichText] {
  fileprivate var plainText: String { map(\.plainText).joined() }
}

private struct Page: Decodable {
  struct Property: Decodable {
    struct DateValue: Decodable {
      let start: String
      let end: String?
    }
    struct Reference: Decodable {
      let id: String
    }
    struct Option: Decodable {
      let name: String
    }
    let id: String
    let title: [RichText]?
    let date: DateValue?
    let relation: [Reference]?
    let select: Option?
    let status: Option?
  }

  let id: String
  let properties: [String: Property]

  var byID: [String: Property] {
    Dictionary(properties.values.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }
}

private struct PageList: Decodable {
  let results: [Page]
  let nextCursor: String?
  let hasMore: Bool
}

private struct ErrorBody: Decodable {
  let message: String
}
