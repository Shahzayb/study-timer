import AppKit
import Observation
import ServiceManagement

/// One short line for the UI, with the full message for a tooltip.
struct Failure: Codable, Equatable, Sendable {
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
  enum Screen { case connect, start, active, finish, stats, settings }
  enum Mode: String { case stopwatch, countdown }

  /// What an armed Discard removes: the session on Finish, or a failed commit in the banner.
  enum DiscardTarget: Equatable {
    case session
    case commit(UUID)
  }

  /// The last schema discovery, shown on Connect and in Settings.
  enum Check: Equatable {
    case idle
    case checking
    case ok(String)
    case failed(Failure)
  }

  static let liveSessionsID = "<redacted>"
  static let presets = [25, 45, 60, 90]
  /// `--fast-countdown` runs countdown minutes as seconds for manual testing.
  static let minuteLength: TimeInterval =
    CommandLine.arguments.contains("--fast-countdown") ? 1 : 60

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
  /// Mirrors the system login item, so a change in System Settings shows here too.
  private(set) var launchAtLogin = false
  private(set) var loginFailure: Failure?

  /// The session in progress. Every change goes to disk, so a quit or crash keeps it.
  private(set) var session: ActiveSession? {
    didSet { Persistence.save(session) }
  }
  /// The first Discard press arms it for 3 s. A second press discards.
  private(set) var armed: DiscardTarget?
  private(set) var ringing = false

  /// The Start form. The title follows the suggestion until the owner edits it.
  var search = "" {
    didSet { if search != oldValue { highlightID = firstMatchID } }
  }
  private(set) var selectedIDs: [String] = []
  var highlightID: String?
  private(set) var title = ""
  var mode: Mode {
    didSet { defaults.set(mode.rawValue, forKey: "mode") }
  }
  var minutes: Int {
    didSet { defaults.set(minutes, forKey: "minutes") }
  }
  var customMinutes: String
  /// Bumped to move keyboard focus into the search field.
  private(set) var focusToken = 0

  @ObservationIgnored var closePopover: () -> Void = {}
  @ObservationIgnored let alarm = Alarm()
  let queue = CommitQueue(commits: Persistence.loadQueue(), store: Persistence.saveQueue)
  /// The segment that already rang, so a ring that was muted stays muted.
  @ObservationIgnored private var rangSegment: Date?
  @ObservationIgnored private var titleEdited = false
  @ObservationIgnored private var discardGeneration = 0

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
    let restored = Persistence.loadSession()?.restored()
    session = restored
    screen = key == nil ? .connect : restored == nil ? .start : .active
    alarmSound = defaults.string(forKey: "alarmSound") ?? "Glass"
    let savedMode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .countdown
    let savedMinutes = defaults.object(forKey: "minutes") as? Int ?? 45
    mode = savedMode
    minutes = savedMinutes
    let typed = savedMode == .countdown && !Self.presets.contains(savedMinutes)
    customMinutes = typed ? "\(savedMinutes)" : ""
    queue.apiKey = { [weak self] in self?.apiKey }
    queue.onSent = { [weak self] in self?.refresh(force: true) }
  }

  var refreshing: Bool { loadingSessions || loadingCards || check == .checking }

  /// Queued commits count until a fetched row matches them.
  func stats(at now: Date) -> DayStats? {
    guard let sessions else { return nil }
    let pending = queue.commits.filter { commit in
      commit.dataSourceID == dataSourceID && !sessions.contains(where: commit.matches)
    }
    let rows = pending.map {
      SessionRow(
        id: Self.queuedRowPrefix + $0.id.uuidString, title: $0.title, start: $0.interval.start,
        end: $0.interval.end, cardIDs: $0.cardIDs)
    }
    return DayStats(sessions: sessions + rows, cards: cards ?? [], now: now)
  }

  private static let queuedRowPrefix = "queued:"

  /// The sync badge of a stats row. Rows fetched from Notion have none.
  func badge(forRow id: String) -> CommitQueue.Badge? {
    guard id.hasPrefix(Self.queuedRowPrefix),
      let uuid = UUID(uuidString: String(id.dropFirst(Self.queuedRowPrefix.count)))
    else { return nil }
    return queue.badge(uuid)
  }

  /// Why stats cannot load: the last query failed, or discovery did.
  var statsFailure: Failure? {
    if let sessionsFailure { return sessionsFailure }
    if schema == nil, case .failed(let failure) = check { return failure }
    return nil
  }

  // MARK: Navigation

  func openStats() { open(.stats) }

  func openSettings() {
    readLoginItem()
    open(.settings)
  }

  /// Launch at login is on by default, so the first launch registers the app once.
  func syncLoginItem() {
    guard defaults.bool(forKey: "loginItemOffered") else {
      defaults.set(true, forKey: "loginItemOffered")
      return setLaunchAtLogin(true)
    }
    readLoginItem()
  }

  /// A failure leaves the toggle on the real state, which reverts it.
  func setLaunchAtLogin(_ on: Bool) {
    do {
      if on {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      readLoginItem()
    } catch {
      readLoginItem()
      loginFailure = Failure(
        text: on ? "Could not open at login" : "Could not stop opening at login",
        detail: error.localizedDescription)
    }
  }

  private func readLoginItem() {
    let status = SMAppService.mainApp.status
    launchAtLogin = status == .enabled || status == .requiresApproval
    loginFailure =
      status == .requiresApproval
      ? Failure(
        text: "Approve it in Login Items",
        detail: "System Settings › General › Login Items › Study Timer")
      : nil
  }

  /// Leaves a sub-screen. Returns false on a root screen, where Esc closes the popover instead.
  func goBack() -> Bool {
    switch screen {
    case .stats: screen = returnScreen
    case .settings: closeSettings()
    case .finish: backToActive()
    case .connect, .start, .active: return false
    }
    return true
  }

  private func open(_ subScreen: Screen) {
    if [.connect, .start, .active].contains(screen) { returnScreen = screen }
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
    queue.retryNow()
    if screen == .start {
      focusToken += 1
      if !visibleCards.contains(where: { $0.id == highlightID }) { highlightID = firstMatchID }
    }
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
    screen = session == nil ? .start : .active
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
          if highlightID == nil { highlightID = firstMatchID }
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

  // MARK: Start form

  var rankedCards: [CardRow] { rankCards(cards ?? [], sessions: sessions ?? [], now: Date()) }

  /// Selected cards first, in selection order. Search filters the rest.
  var visibleCards: [CardRow] {
    let ranked = rankedCards
    let selected = selectedIDs.compactMap { id in ranked.first { $0.id == id } }
    let query = search.trimmingCharacters(in: .whitespaces)
    let rest = ranked.filter { card in
      !selectedIDs.contains(card.id)
        && (query.isEmpty
          || card.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
    }
    return selected + rest
  }

  var suggestedTitle: String {
    let first = selectedIDs.first.flatMap { id in cards?.first { $0.id == id } }
    return defaultTitle(firstCard: first, sessions: sessions ?? [])
  }

  /// A typed length outside 1–600 minutes blocks Start.
  var customMinutesInvalid: Bool {
    guard !customMinutes.isEmpty else { return false }
    return Int(customMinutes).map { !(1...600).contains($0) } ?? true
  }

  var canStart: Bool {
    !selectedIDs.isEmpty && !customMinutesInvalid
      && (mode == .stopwatch || Self.presets.contains(minutes) || !customMinutes.isEmpty)
  }

  private var firstMatchID: String? {
    let rows = visibleCards
    return rows.first { !selectedIDs.contains($0.id) }?.id ?? rows.first?.id
  }

  func toggle(_ card: CardRow) {
    if let index = selectedIDs.firstIndex(of: card.id) {
      selectedIDs.remove(at: index)
    } else {
      selectedIDs.append(card.id)
    }
    if !titleEdited { title = suggestedTitle }
  }

  /// An edit sticks across selection changes. Clearing the field hands the title back to the suggestion.
  func editTitle(_ value: String) {
    title = value
    titleEdited = !value.isEmpty
  }

  func moveHighlight(_ delta: Int) {
    let rows = visibleCards
    guard !rows.isEmpty else { return }
    let index = rows.firstIndex { $0.id == highlightID } ?? -delta
    highlightID = rows[max(0, min(rows.count - 1, index + delta))].id
  }

  func toggleHighlighted() {
    guard let id = highlightID, let card = visibleCards.first(where: { $0.id == id }) else {
      return
    }
    toggle(card)
    search = ""
    highlightID = id
  }

  func pick(stopwatch: Bool, minutes value: Int? = nil) {
    mode = stopwatch ? .stopwatch : .countdown
    if let value { minutes = value }
    customMinutes = ""
  }

  func editCustomMinutes(_ text: String) {
    customMinutes = text.filter(\.isNumber)
    if let value = Int(customMinutes), (1...600).contains(value) {
      mode = .countdown
      minutes = value
    }
  }

  private func clearForm() {
    selectedIDs = []
    search = ""
    title = ""
    titleEdited = false
    highlightID = firstMatchID
  }

  // MARK: Session

  func start() {
    guard canStart, session == nil else { return }
    let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    session = ActiveSession(
      title: typed.isEmpty ? suggestedTitle : typed,
      cardIDs: selectedIDs,
      target: mode == .countdown ? TimeInterval(minutes) * Self.minuteLength : nil,
      start: Date()
    )
    if mode == .countdown { alarm.requestPermission() }
    scheduleAlarm()
    clearForm()
    screen = .active
    closePopover()
  }

  /// Also runs on system sleep and screen lock.
  func pause() {
    session?.pause(at: Date())
    mute()
    alarm.cancel()
  }

  func resume() {
    session?.resume(at: Date())
    scheduleAlarm()
  }

  func mute() {
    ringing = false
    alarm.silence()
  }

  /// Runs every 0.5 s while a session exists. A heartbeat every 30 s bounds the time a crash can lose.
  func tick(_ now: Date) {
    guard let session, session.isRunning else { return }
    if session.alarmDue(at: now), rangSegment != session.segmentStart {
      rangSegment = session.segmentStart
      ringing = true
      alarm.ring(alarmSound)
    }
    if now.timeIntervalSince(session.heartbeat) >= 30 { self.session?.beat(at: now) }
  }

  /// A clean quit records the quit moment, so the next launch resumes accounting from there.
  func prepareToQuit() {
    if session?.isRunning == true { session?.beat(at: Date()) }
    alarm.cancel()
  }

  /// A click on the alarm banner shows Active.
  func showActive() {
    guard session != nil else { return }
    armed = nil
    screen = .active
  }

  /// The banner fires when a running countdown reaches its target.
  private func scheduleAlarm() {
    guard let session, session.isRunning, let target = session.target else { return }
    let remaining = target - session.elapsed(at: Date())
    if remaining > 0 { alarm.schedule(after: remaining, title: session.title) }
  }

  func cardNames(_ ids: [String]) -> [String] {
    ids.map { id in cards?.first { $0.id == id }?.name ?? "Unknown card" }
  }

  func openFinish() {
    mute()
    armed = nil
    screen = .finish
  }

  private func backToActive() {
    armed = nil
    screen = .active
  }

  func discardPressed(_ target: DiscardTarget) {
    guard armed == target else {
      armed = target
      discardGeneration += 1
      let generation = discardGeneration
      Task {
        try? await Task.sleep(for: .seconds(3))
        if generation == discardGeneration { armed = nil }
      }
      return
    }
    armed = nil
    switch target {
    case .session: endSession()
    case .commit(let id): queue.discard(id)
    }
  }

  /// Queues the row and shows Start at once. The queue keeps trying until Notion has it.
  func save(plannedOnly: Bool) {
    guard let session, let interval = session.commitInterval(at: Date(), plannedOnly: plannedOnly)
    else { return }
    queue.add(
      PendingCommit(
        title: session.title, cardIDs: session.cardIDs, interval: interval,
        dataSourceID: dataSourceID, schema: schema?.sessionsID == dataSourceID ? schema : nil))
    endSession()
  }

  private func endSession() {
    mute()
    alarm.cancel()
    session = nil
    armed = nil
    screen = .start
    focusToken += 1
  }
}
