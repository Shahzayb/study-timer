import SwiftUI

struct PressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}

/// A 28 pt circular icon button with a hover fill and a tooltip.
struct IconButton: View {
  let symbol: String
  let label: String
  let action: () -> Void
  // `@State` is a macro in this SDK, and its plugin ships only with Xcode.
  private let hovering = State(initialValue: false)

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 28, height: 28)
        .background(Circle().fill(Color.primary.opacity(hovering.wrappedValue ? 0.12 : 0)))
        .contentShape(Circle())
    }
    .buttonStyle(PressStyle())
    .onHover { hovering.wrappedValue = $0 }
    .help(label)
    .accessibilityLabel(label)
  }
}

/// The 44 pt header of a sub-screen. The back chevron answers Esc.
struct SubHeader<Trailing: View>: View {
  var title: String?
  let back: () -> Void
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(spacing: 2) {
      IconButton(symbol: "chevron.left", label: "Back", action: back)
        .keyboardShortcut(.cancelAction)
      if let title {
        Text(title).font(.headline)
      }
      Spacer(minLength: 0)
      trailing
    }
    .padding(.horizontal, 8)
    .frame(height: 44)
  }
}

/// A load that failed with nothing to show: an icon, the error line, and Retry.
struct FailureView: View {
  let failure: Failure
  let retry: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: failure.isOffline ? "wifi.exclamationmark" : "exclamationmark.triangle")
        .font(.system(size: 30))
        .foregroundStyle(.secondary)
      Text(failure.text)
        .font(.callout.weight(.medium))
        .foregroundStyle(.secondary)
        .help(failure.detail)
      Button("Retry", action: retry)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// A 54 pt circular session control. A prominent one fills with its tint.
struct RoundButton: View {
  let symbol: String
  let label: String
  var tint: Color = .accentColor
  var prominent = false
  let action: () -> Void
  private let hovering = State(initialValue: false)

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .frame(width: 54, height: 54)
        .background(
          Circle().fill(
            prominent
              ? AnyShapeStyle(tint.opacity(hovering.wrappedValue ? 0.85 : 1))
              : AnyShapeStyle(Color.primary.opacity(hovering.wrappedValue ? 0.16 : 0.1)))
        )
        .contentShape(Circle())
    }
    .buttonStyle(PressStyle())
    .onHover { hovering.wrappedValue = $0 }
    .help(label)
    .accessibilityLabel(label)
  }
}

/// `mm:ss` under an hour, `h:mm:ss` from an hour.
func clock(_ seconds: TimeInterval) -> String {
  let s = max(0, Int(seconds))
  return s >= 3600
    ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    : String(format: "%02d:%02d", s / 60, s % 60)
}

extension SubHeader where Trailing == EmptyView {
  init(title: String? = nil, back: @escaping () -> Void) {
    self.init(title: title, back: back) { EmptyView() }
  }
}

/// The oldest commit that failed for good, on Start and Stats. Retry shows a spinner while it runs.
struct FailedCommitBanner: View {
  @Bindable var model: AppModel
  let commit: PendingCommit

  var body: some View {
    let failure = commit.failure ?? Failure(text: "Not saved", detail: "")
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
      VStack(alignment: .leading, spacing: 1) {
        Text("\"\(commit.title)\" not saved").font(.callout.weight(.medium)).lineLimit(1)
        Text(failure.text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      .help(failure.detail)
      Spacer(minLength: 4)
      if model.queue.badge(commit.id) == .sending {
        ProgressView().controlSize(.small).frame(width: 28, height: 28)
      } else {
        IconButton(symbol: "arrow.clockwise", label: "Retry") { model.queue.retry(commit.id) }
      }
      if model.armed == .commit(commit.id) {
        Button("Discard", role: .destructive) { model.discardPressed(.commit(commit.id)) }
          .buttonStyle(.borderedProminent)
          .tint(.red)
          .controlSize(.small)
          .help("Press again to discard")
      } else {
        IconButton(symbol: "xmark", label: "Discard") {
          model.discardPressed(.commit(commit.id))
        }
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, 4)
    .padding(.vertical, 6)
    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.12)))
  }
}

/// The sync state of a queued row: sending, waiting for a retry, or failed for good.
struct SyncBadge: View {
  let badge: CommitQueue.Badge

  var body: some View {
    switch badge {
    case .sending:
      ProgressView().controlSize(.mini).help("Saving to Notion")
    case .queued:
      Image(systemName: "icloud.slash").foregroundStyle(.orange).help("Not in Notion yet")
    case .failed:
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).help("Not saved")
    }
  }
}
