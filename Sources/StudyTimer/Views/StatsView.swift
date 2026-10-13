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
          let top = stats.bars.first?.seconds ?? 1
          VStack(spacing: 12) {
            ForEach(stats.bars) { CardBar(bar: $0, share: $0.seconds / top) }
          }
          Divider()
          VStack(spacing: 12) {
            ForEach(stats.rows) { StatRow(row: $0) }
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

private struct CardBar: View {
  let bar: DayStats.Bar
  let share: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(bar.name).font(.callout.weight(.medium)).lineLimit(1)
        Spacer()
        Text(hoursMinutes(bar.seconds)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.primary.opacity(0.08))
          Capsule()
            .fill(bar.isNoCard ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .frame(width: max(6, geometry.size.width * share))
        }
      }
      .frame(height: 6)
    }
  }
}

private struct StatRow: View {
  let row: DayStats.Row

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
      Text(hoursMinutes(row.seconds)).font(.callout).monospacedDigit()
    }
  }
}
