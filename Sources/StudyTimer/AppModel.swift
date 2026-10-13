import AppKit
import Observation

/// One short line for the UI, with the full message for a tooltip.
struct Failure: Equatable {
  var text: String
  var detail: String
  var isOffline = false

  init(text: String, detail: String) {
    self.text = text
    self.detail = detail
  }

  init(_ error: Error) {
    let notion = error as? NotionError ?? .unreadable("\(error)")
    text = notion.text
    detail = notion.detail
    if case .offline = notion { isOffline = true }
  }
}

/// State shared by every popover screen.
@MainActor
@Observable
final class AppModel {
  enum Screen { case connect, start, stats, settings }

  /// The last schema discovery, shown on Connect and in Settings.
  enum Check: Equatable {
    case idle
    case checking
    case ok(String)
    case failed(Failure)
  }

  static let liveSessionsID = "<redacted>"

  static let sounds: [String] =
    ((try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? [])
    .map { ($0 as NSString).deletingPathExtension }
    .sorted()

  var screen: Screen

  /// The Notion values in use. Edits wait in the drafts until they pass schema discovery.
  private(set) var apiKey: String?
  private(set) var dataSourceID: String
  private(set) var schema: NotionSchema?
  private(set) var check = Check.idle
  var keyDraft: String
  var sourceDraft: String

  /// Sessions of the last 90 days and all cards. Nil until the first load.
  private(set) var sessions: [SessionRow]?
  private(set) var cards: [CardRow]?
  private(set) var sessionsFailure: Failure?
  private(set) var cardsFailure: Failure?
  private(set) var loadingSessions = false
  private(set) var loadingCards = false

  var alarmSound: String {
    didSet { defaults.set(alarmSound, forKey: "alarmSound") }
  }
  var launchAtLogin: Bool {
    didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
  }

  @ObservationIgnored private let defaults = UserDefaults.standard
  @ObservationIgnored private var returnScreen = Screen.start
  @ObservationIgnored private var checkGeneration = 0
  @ObservationIgnored private var sessionsLoadedAt: Date?
  @ObservationIgnored private var cardsLoadedAt: Date?
  @ObservationIgnored private var sessionsTask: Task<Void, Never>?
  @ObservationIgnored private var cardsTask: Task<Void, Never>?

  init() {
    let defaults = UserDefaults.standard
    let source = defaults.string(forKey: "dataSourceID") ?? Self.liveSessionsID
    let key = Keychain.read()
    dataSourceID = source
    sourceDraft = source
    apiKey = key
    keyDraft = key ?? ""
    screen = key == nil ? .connect : .start
    alarmSound = defaults.string(forKey: "alarmSound") ?? "Glass"
    launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
  }

  var refreshing: Bool { loadingSessions || loadingCards || check == .checking }

  func stats(at now: Date) -> DayStats? {
    sessions.map { DayStats(sessions: $0, cards: cards ?? [], now: now) }
  }

  /// Why stats cannot load: the last query failed, or discovery did.
  var statsFailure: Failure? {
    if let sessionsFailure { return sessionsFailure }
    if schema == nil, case .failed(let failure) = check { return failure }
    return nil
  }

  // MARK: Navigation

  func openStats() { open(.stats) }

  func openSettings() { open(.settings) }

  /// Leaves a sub-screen. Returns false on a root screen, where Esc closes the popover instead.
  func goBack() -> Bool {
    switch screen {
    case .stats: screen = returnScreen
    case .settings: closeSettings()
    case .connect, .start: return false
    }
    return true
  }

  private func open(_ subScreen: Screen) {
    if screen == .connect || screen == .start { returnScreen = screen }
    screen = subScreen
  }

  /// Back reverts a field that has not passed discovery, then rechecks the values in use.
  private func closeSettings() {
    screen = returnScreen
    guard keyDraft != apiKey ?? "" || sourceDraft != dataSourceID else { return }
    keyDraft = apiKey ?? ""
    sourceDraft = dataSourceID
    launch()
  }

  // MARK: Connection

  /// Checks the stored key and data source, then loads data.
  func launch() {
    guard let apiKey else { return }
    let source = dataSourceID
    Task {
      if let schema = await discover(key: apiKey, source: source) { use(schema) }
    }
  }

  func popoverWillOpen() {
    if schema == nil {
      if check != .checking { launch() }
    } else {
      refresh()
    }
  }

  func retry() {
    if schema == nil { launch() } else { refresh(force: true) }
  }

  func connect() async {
    let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let schema = await discover(key: key, source: dataSourceID), save(key: key) else {
      return
    }
    use(schema)
    screen = .start
  }

  func clearFailure() {
    if case .failed = check { check = .idle }
  }

  /// Saves edited Notion fields once they pass schema discovery.
  func commitDrafts() async {
    let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    let source = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, key != apiKey || source != dataSourceID else { return }
    guard let schema = await discover(key: key, source: source), save(key: key) else { return }
    dataSourceID = source
    sourceDraft = source
    defaults.set(source, forKey: "dataSourceID")
    use(schema)
  }

  private func save(key: String) -> Bool {
    do {
      try Keychain.save(key)
    } catch {
      check = .failed(Failure(text: "Keychain error", detail: "\(error)"))
      return false
    }
    apiKey = key
    keyDraft = key
    return true
  }

  /// Only the latest discovery may update the state, so a slow answer cannot overwrite a newer one.
  private func discover(key: String, source: String) async -> NotionSchema? {
    checkGeneration += 1
    let generation = checkGeneration
    check = .checking
    do {
      let schema = try await NotionClient(apiKey: key).discover(sessionsID: source)
      guard generation == checkGeneration else { return nil }
      check = .ok(schema.sessionsName)
      return schema
    } catch {
      guard generation == checkGeneration else { return nil }
      check = .failed(Failure(error))
      return nil
    }
  }

  // MARK: Data

  /// A new schema drops the data of the old one and cancels its queries.
  private func use(_ schema: NotionSchema) {
    if schema != self.schema {
      self.schema = schema
      sessionsTask?.cancel()
      cardsTask?.cancel()
      sessions = nil
      cards = nil
      sessionsFailure = nil
      cardsFailure = nil
      sessionsLoadedAt = nil
      cardsLoadedAt = nil
      loadingSessions = false
      loadingCards = false
    }
    refresh()
  }

  /// Sessions reload after 30 s and cards after 10 min, so opening the popover stays cheap.
  func refresh(force: Bool = false) {
    guard let schema, let apiKey else { return }
    let client = NotionClient(apiKey: apiKey)
    let now = Date()
    if !loadingSessions, force || isStale(sessionsLoadedAt, after: 30, now: now) {
      loadingSessions = true
      sessionsTask = Task {
        do {
          let rows = try await client.sessions(schema, since: now.addingTimeInterval(-90 * 86_400))
          guard !Task.isCancelled else { return }
          sessions = rows
          sessionsLoadedAt = Date()
          sessionsFailure = nil
        } catch {
          guard !Task.isCancelled else { return }
          sessionsFailure = Failure(error)
        }
        loadingSessions = false
      }
    }
    if !loadingCards, force || isStale(cardsLoadedAt, after: 600, now: now) {
      loadingCards = true
      cardsTask = Task {
        do {
          let rows = try await client.cards(schema)
          guard !Task.isCancelled else { return }
          cards = rows
          cardsLoadedAt = Date()
          cardsFailure = nil
        } catch {
          guard !Task.isCancelled else { return }
          cardsFailure = Failure(error)
        }
        loadingCards = false
      }
    }
  }

  private func isStale(_ loadedAt: Date?, after seconds: TimeInterval, now: Date) -> Bool {
    loadedAt.map { now.timeIntervalSince($0) > seconds } ?? true
  }
}
