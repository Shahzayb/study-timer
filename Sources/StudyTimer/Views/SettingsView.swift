import AppKit
import SwiftUI

struct SettingsView: View {
  private enum Field { case key, source }

  @Bindable var model: AppModel
  @FocusState private var focus: Field?

  var body: some View {
    VStack(spacing: 0) {
      SubHeader(title: "Settings") {
        model.closeSettings()
      } trailing: {
        IconButton(symbol: "power", label: "Quit Study Timer") { NSApp.terminate(nil) }
      }
      Form {
        Section {
          SecureField("API key", text: $model.keyDraft, prompt: Text("ntn_…"))
            .focused($focus, equals: .key)
            .help("Stored in your Keychain")
            .onSubmit(validate)
          TextField("Data source", text: $model.sourceDraft)
            .focused($focus, equals: .source)
            .onSubmit(validate)
          if model.check != .idle {
            CheckRow(check: model.check)
          }
        }
        Section {
          Picker("Alarm", selection: $model.alarmSound) {
            ForEach(AppModel.sounds, id: \.self) { Text($0) }
          }
          .onChange(of: model.alarmSound) { NSSound(named: model.alarmSound)?.play() }
          Toggle("Open at login", isOn: $model.launchAtLogin)
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .scrollDisabled(true)
      Label("⌃⌥S", systemImage: "keyboard")
        .font(.callout)
        .foregroundStyle(.secondary)
        .help("Opens Study Timer from anywhere")
        .padding(.bottom, 14)
    }
    .onChange(of: focus) { old, _ in
      if old != nil { validate() }
    }
  }

  private func validate() {
    Task { await model.commitDrafts() }
  }
}

private struct CheckRow: View {
  let check: AppModel.Check

  // Every state keeps one height, so the sections below do not jump while a check runs.
  var body: some View {
    content.frame(height: 20, alignment: .leading)
  }

  @ViewBuilder private var content: some View {
    switch check {
    case .idle:
      EmptyView()
    case .checking:
      HStack(spacing: 6) {
        ProgressView().controlSize(.small)
        Text("Checking…").foregroundStyle(.secondary)
      }
    case .ok(let name):
      Label {
        Text(name)
      } icon: {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
      }
    case .failed(let message, let detail):
      Label(message, systemImage: "xmark.circle.fill")
        .foregroundStyle(.red)
        .help(detail)
    }
  }
}
