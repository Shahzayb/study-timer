import Foundation
import Network

/// A saved session on its way to Notion. It keeps its data source, so a later Settings change cannot redirect it.
struct PendingCommit: Codable, Equatable, Identifiable, Sendable {
  var id = UUID()
  var title: String
  var cardIDs: [String]
  var interval: DateInterval
  var dataSourceID: String
  /// Nil when the app saved before discovery finished, for example after an offline launch.
  var schema: NotionSchema?
  /// Requests started. After one, a create may have landed, so every later attempt looks for the row first.
  var attempts = 0
  var nextAttempt = Date.distantPast
  /// A permanent failure. The queue stops retrying until the owner presses Retry.
  var failure: Failure?

  /// The same title and a start within ±60 s. Notion drops seconds, so a stored start can differ by under a minute.
  func matches(_ row: SessionRow) -> Bool {
    row.title == title && abs(row.start.timeIntervalSince(interval.start)) <= 60
  }
}

/// The wait after a failed attempt: 30 s, 1 m, 2 m, then every 5 m.
func retryDelay(afterFailures count: Int) -> TimeInterval {
  let delays: [TimeInterval] = [30, 60, 120]
  return (1...delays.count).contains(count) ? delays[count - 1] : 300
}

/// Commits waiting for Notion. Each one is on disk before its first request, so Save never waits.
@MainActor
@Observable
final class CommitQueue {
  enum Badge { case sending, queued, failed }

  private(set) var commits: [PendingCommit] {
    didSet { store(commits) }
  }
  private(set) var sending: Set<UUID> = []

  @ObservationIgnored var apiKey: () -> String? = { nil }
  /// Runs after a row lands, so the stats refresh.
  @ObservationIgnored var onSent: () -> Void = {}
  /// Tests replace the clock.
  @ObservationIgnored var now: () -> Date = Date.init
  @ObservationIgnored private let session: URLSession
  @ObservationIgnored private let store: ([PendingCommit]) -> Void
  @ObservationIgnored private var wake: Task<Void, Never>?
  @ObservationIgnored private var monitor: NWPathMonitor?

  init(
    commits: [PendingCommit], session: URLSession = .shared,
    store: @escaping ([PendingCommit]) -> Void
  ) {
    self.commits = commits
    self.session = session
    self.store = store
  }

  /// The oldest permanent failure, shown in the banner.
  var firstFailure: PendingCommit? { commits.first { $0.failure != nil } }

  /// A commit waits for a retry. A commit in flight does not count, so a quick Save never flashes the badge.
  var hasWaiting: Bool { commits.contains { $0.failure == nil && !sending.contains($0.id) } }

  func badge(_ id: UUID) -> Badge? {
    guard let commit = commits.first(where: { $0.id == id }) else { return nil }
    if sending.contains(id) { return .sending }
    return commit.failure == nil ? .queued : .failed
  }

  /// Sends at launch and whenever the network comes back.
  func start() {
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
      guard path.status == .satisfied else { return }
      Task { @MainActor in self?.retryNow() }
    }
    monitor.start(queue: .main)
    self.monitor = monitor
  }

  func add(_ commit: PendingCommit) {
    commits.append(commit)
    Task { await sendDue() }
  }

  /// Network return and popover open skip the backoff. Permanent failures wait for Retry.
  func retryNow() {
    for index in commits.indices where commits[index].failure == nil {
      commits[index].nextAttempt = .distantPast
    }
    Task { await sendDue() }
  }

  /// The banner's Retry. The failure stays until the attempt ends, so the banner can show a spinner.
  func retry(_ id: UUID) {
    guard let commit = commits.first(where: { $0.id == id }), !sending.contains(id),
      let key = apiKey()
    else { return }
    sending.insert(id)
    Task {
      await attempt(commit, client: NotionClient(apiKey: key, session: session))
      scheduleWake()
    }
  }

  func discard(_ id: UUID) {
    commits.removeAll { $0.id == id }
    scheduleWake()
  }

  /// Sends each due commit in turn, then sleeps until the next one is due.
  func sendDue() async {
    guard let key = apiKey() else { return }
    let client = NotionClient(apiKey: key, session: session)
    for commit in commits
    where commit.failure == nil && commit.nextAttempt <= now() && !sending.contains(commit.id) {
      sending.insert(commit.id)
      await attempt(commit, client: client)
    }
    scheduleWake()
  }

  /// The caller marks the commit as sending first, so two loops never send it twice.
  private func attempt(_ commit: PendingCommit, client: NotionClient) async {
    defer { sending.remove(commit.id) }
    let checkFirst = commit.attempts > 0
    update(commit.id) { $0.attempts += 1 }
    do {
      let schema: NotionSchema
      if let known = commit.schema {
        schema = known
      } else {
        schema = try await client.discover(sessionsID: commit.dataSourceID)
        update(commit.id) { $0.schema = schema }
      }
      if checkFirst {
        let rows = try await client.sessions(
          schema, since: commit.interval.start.addingTimeInterval(-120))
        if rows.contains(where: commit.matches) { return landed(commit.id) }
      }
      try await client.createSession(
        schema, title: commit.title, interval: commit.interval, cardIDs: commit.cardIDs)
      landed(commit.id)
    } catch {
      let notion = error as? NotionError ?? .unreadable("\(error)")
      let failedAt = now()
      update(commit.id) {
        if notion.isPermanent {
          $0.failure = Failure(notion)
        } else {
          $0.failure = nil
          $0.nextAttempt = failedAt.addingTimeInterval(
            notion.retryAfter ?? retryDelay(afterFailures: $0.attempts))
        }
      }
    }
  }

  private func landed(_ id: UUID) {
    commits.removeAll { $0.id == id }
    onSent()
  }

  /// A discarded commit is gone, so the change is skipped.
  private func update(_ id: UUID, _ change: (inout PendingCommit) -> Void) {
    guard let index = commits.firstIndex(where: { $0.id == id }) else { return }
    change(&commits[index])
  }

  private func scheduleWake() {
    wake?.cancel()
    let due = commits.filter { $0.failure == nil && !sending.contains($0.id) }.map(\.nextAttempt)
      .min()
    guard let due else { return }
    let delay = max(1, due.timeIntervalSince(now()))
    wake = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      await self?.sendDue()
    }
  }
}
