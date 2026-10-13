import AppKit
import Observation

/// State shared by every popover screen.
@MainActor
@Observable
final class AppModel {
  enum Screen { case connect, start, settings }

  /// The last schema discovery, shown on Connect and in Settings.
  enum Check: Equatable {
    case idle
    case checking
    case ok(String)
    case failed(String, detail: String)
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

  var alarmSound: String {
    didSet { defaults.set(alarmSound, forKey: "alarmSound") }
  }
  var launchAtLogin: Bool {
    didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
  }

  @ObservationIgnored private let defaults = UserDefaults.standard
  @ObservationIgnored private var settingsReturn = Screen.start
  @ObservationIgnored private var checkGeneration = 0

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

  /// Checks the stored key and data source.
  func launch() {
    guard let apiKey else { return }
    let source = dataSourceID
    Task { await discover(key: apiKey, source: source) }
  }

  func connect() async {
    let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard await discover(key: key, source: dataSourceID), save(key: key) else { return }
    screen = .start
  }

  func clearFailure() {
    if case .failed = check { check = .idle }
  }

  func openSettings() {
    if screen != .settings { settingsReturn = screen }
    screen = .settings
  }

  /// Leaves a sub-screen. Returns false on a root screen, where Esc closes the popover instead.
  func goBack() -> Bool {
    guard screen == .settings else { return false }
    closeSettings()
    return true
  }

  /// Back reverts a field that has not passed discovery, then rechecks the values in use.
  func closeSettings() {
    screen = settingsReturn
    guard keyDraft != apiKey ?? "" || sourceDraft != dataSourceID else { return }
    keyDraft = apiKey ?? ""
    sourceDraft = dataSourceID
    launch()
  }

  /// Saves edited Notion fields once they pass schema discovery.
  func commitDrafts() async {
    let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    let source = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, key != apiKey || source != dataSourceID else { return }
    guard await discover(key: key, source: source), save(key: key) else { return }
    dataSourceID = source
    sourceDraft = source
    defaults.set(source, forKey: "dataSourceID")
  }

  private func save(key: String) -> Bool {
    do {
      try Keychain.save(key)
    } catch {
      check = .failed("Keychain error", detail: "\(error)")
      return false
    }
    apiKey = key
    keyDraft = key
    return true
  }

  /// Only the latest discovery may update the state, so a slow answer cannot overwrite a newer one.
  private func discover(key: String, source: String) async -> Bool {
    checkGeneration += 1
    let generation = checkGeneration
    check = .checking
    do {
      let schema = try await NotionClient(apiKey: key).discover(sessionsID: source)
      guard generation == checkGeneration else { return false }
      self.schema = schema
      check = .ok(schema.sessionsName)
      return true
    } catch {
      guard generation == checkGeneration else { return false }
      let failure = error as? NotionError ?? .unreadable("\(error)")
      check = .failed(failure.text, detail: failure.detail)
      return false
    }
  }
}
