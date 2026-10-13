import Foundation

/// Local state in `~/Library/Application Support/Study Timer/`. Notion holds everything else.
enum Persistence {
  private static var directory: URL {
    URL.applicationSupportDirectory.appending(path: "Study Timer")
  }

  private static var sessionFile: URL { directory.appending(path: "active-session.json") }

  static func loadSession() -> ActiveSession? {
    guard let data = try? Data(contentsOf: sessionFile) else { return nil }
    return try? JSONDecoder().decode(ActiveSession.self, from: data)
  }

  /// Nil removes the file.
  static func save(_ session: ActiveSession?) {
    do {
      guard let session else {
        try? FileManager.default.removeItem(at: sessionFile)
        return
      }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONEncoder().encode(session).write(to: sessionFile, options: .atomic)
    } catch {
      NSLog("Study Timer: the session could not be saved: \(error)")
    }
  }
}
