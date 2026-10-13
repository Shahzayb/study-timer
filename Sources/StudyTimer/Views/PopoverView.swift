import SwiftUI

/// The popover root at the fixed size from the plan's UI spec.
struct PopoverView: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      switch model.screen {
      case .connect: ConnectView(model: model)
      case .start: StartView(model: model)
      case .settings: SettingsView(model: model)
      }
    }
    .frame(width: 340, height: 400)
  }
}

struct StartView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      Divider()
      Footer(model: model)
    }
  }
}

struct Footer: View {
  @Bindable var model: AppModel

  var body: some View {
    HStack(spacing: 4) {
      Spacer()
      IconButton(symbol: "gearshape", label: "Settings") { model.openSettings() }
        .keyboardShortcut(",", modifiers: .command)
    }
    .padding(.horizontal, 8)
    .frame(height: 44)
  }
}
