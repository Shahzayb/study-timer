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
