import Foundation

/// Local state in `~/Library/Application Support/Study Timer/`. Notion holds everything else.
enum Persistence {
  private static var directory: URL {
    URL.applicationSupportDirectory.appending(path: "Study Timer")
  }

  private static var sessionFile: URL { directory.appending(path: "active-session.json") }
  private static var queueFile: URL { directory.appending(path: "commit-queue.json") }

  static func loadSession() -> ActiveSession? { load(ActiveSession.self, from: sessionFile) }

  /// Nil removes the file.
  static func save(_ session: ActiveSession?) { write(session, to: sessionFile) }

  static func loadQueue() -> [PendingCommit] { load([PendingCommit].self, from: queueFile) ?? [] }

  /// An empty queue removes the file.
  static func saveQueue(_ commits: [PendingCommit]) {
    write(commits.isEmpty ? nil : commits, to: queueFile)
  }

  private static func load<T: Decodable>(_ type: T.Type, from file: URL) -> T? {
    guard let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  private static func write(_ value: (some Encodable)?, to file: URL) {
    do {
      guard let value else {
        try? FileManager.default.removeItem(at: file)
        return
      }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONEncoder().encode(value).write(to: file, options: .atomic)
    } catch {
      NSLog("Study Timer: \(file.lastPathComponent) could not be saved: \(error)")
    }
  }
}
