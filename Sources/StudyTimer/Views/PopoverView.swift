import SwiftUI

/// The popover root at the fixed size from the plan's UI spec.
struct PopoverView: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      switch model.screen {
      case .connect: ConnectView(model: model)
      case .start: StartView(model: model)
      case .active: ActiveView(model: model)
      case .finish: FinishView(model: model)
      case .stats: StatsView(model: model)
      case .settings: SettingsView(model: model)
      }
    }
    .frame(width: 340, height: 400)
  }
}

struct Footer: View {
  @Bindable var model: AppModel
  private let hovering = State(initialValue: false)

  var body: some View {
    HStack(spacing: 4) {
      Button {
        model.openStats()
      } label: {
        HStack(spacing: 6) {
          if let stats = model.stats(at: .now) {
            Text(hoursMinutes(stats.total)).fontWeight(.semibold).monospacedDigit()
            if model.queue.firstFailure != nil {
              SyncBadge(badge: .failed)
            } else if model.queue.hasWaiting {
              SyncBadge(badge: .queued)
            }
          } else if model.statsFailure != nil {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
          } else {
            ProgressView().controlSize(.mini)
          }
          Text("24h").foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(Color.primary.opacity(hovering.wrappedValue ? 0.12 : 0)))
        .contentShape(Capsule())
      }
      .buttonStyle(PressStyle())
      .onHover { hovering.wrappedValue = $0 }
      .help("Last 24 hours")
      Spacer()
      if model.refreshing {
        ProgressView().controlSize(.small)
      }
      IconButton(symbol: "gearshape", label: "Settings") { model.openSettings() }
        .keyboardShortcut(",", modifiers: .command)
    }
    .padding(.horizontal, 8)
    .frame(height: 44)
  }
}
