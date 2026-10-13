import SwiftUI

struct StatsView: View {
  @Bindable var model: AppModel

  var body: some View {
    let stats = model.stats(at: .now)
    VStack(spacing: 0) {
      SubHeader(title: "Last 24 hours") {
        _ = model.goBack()
      } trailing: {
        if stats != nil {
          if model.refreshing {
            ProgressView().controlSize(.small).padding(.trailing, 8)
          } else if let failure = model.statsFailure {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .help("\(failure.text). \(failure.detail)")
              .padding(.trailing, 8)
          }
        }
      }
      if let commit = model.queue.firstFailure {
        FailedCommitBanner(model: model, commit: commit)
          .padding(.horizontal, 14)
          .padding(.bottom, 8)
      }
      if let stats {
        content(stats)
      } else if let failure = model.statsFailure {
        FailureView(failure: failure) { model.retry() }
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private func content(_ stats: DayStats) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text(hoursMinutes(stats.total))
          .font(.system(size: 40, weight: .semibold, design: .rounded))
          .monospacedDigit()
        if stats.rows.isEmpty {
          Text("No sessions").foregroundStyle(.secondary)
        } else {
          VStack(spacing: 8) {
            ForEach(stats.cardTotals) { CardTotalRow(total: $0) }
          }
          Divider()
          VStack(spacing: 12) {
            ForEach(stats.rows) { StatRow(row: $0, badge: model.badge(forRow: $0.id)) }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.bottom, 18)
    }
    .scrollIndicators(.never)
  }
}

private struct CardTotalRow: View {
  let total: DayStats.CardTotal

  var body: some View {
    HStack {
      Text(total.name)
        .font(.callout.weight(.medium))
        .foregroundStyle(total.isNoCard ? .secondary : .primary)
        .lineLimit(1)
      Spacer()
      Text(hoursMinutes(total.seconds)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
    }
  }
}

private struct StatRow: View {
  let row: DayStats.Row
  let badge: CommitQueue.Badge?

  var body: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(row.session.title).font(.callout.weight(.medium)).lineLimit(1)
        Text(
          "\(row.cardNames.isEmpty ? "No card" : row.cardNames.joined(separator: ", ")) · \(timeRange(row.session.start, row.session.end))"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }
      Spacer(minLength: 4)
      if let badge { SyncBadge(badge: badge) }
      Text(hoursMinutes(row.seconds)).font(.callout).monospacedDigit()
    }
  }
}
