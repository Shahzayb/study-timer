import AppKit
import SwiftUI

/// First run: the popover shows this screen while no API key is stored.
struct ConnectView: View {
  @Bindable var model: AppModel
  @FocusState private var keyFocused: Bool

  private var checking: Bool { model.check == .checking }

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 76, height: 76)
      Text("Connect Notion")
        .font(.title2.weight(.semibold))
        .padding(.top, 20)
      SecureField("API key", text: $model.keyDraft, prompt: Text("Notion API key"))
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .controlSize(.large)
        .focused($keyFocused)
        .disabled(checking)
        .padding(.top, 24)
      TextField("Data source ID", text: $model.sourceDraft, prompt: Text("Data source ID"))
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .controlSize(.large)
        .disabled(checking)
        .padding(.top, 8)
      Group {
        if case .failed(let failure) = model.check {
          Label(failure.text, systemImage: "xmark.circle.fill")
            .foregroundStyle(.red)
            .help(failure.detail)
        } else {
          Text(" ")
        }
      }
      .font(.callout.weight(.medium))
      .frame(height: 30)
      Button {
        Task { await model.connect() }
      } label: {
        ZStack {
          Text("Connect").opacity(checking ? 0 : 1)
          if checking {
            ProgressView().controlSize(.small)
          }
        }
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .keyboardShortcut(.defaultAction)
      .disabled(model.keyDraft.isEmpty || model.sourceDraft.isEmpty || checking)
      Spacer(minLength: 0)
      HStack {
        Link(
          "Get a key",
          destination: URL(
            string: "https://developers.notion.com/guides/get-started/personal-access-tokens")!
        )
        .font(.callout)
        Spacer()
        IconButton(symbol: "power", label: "Quit") { NSApp.terminate(nil) }
      }
    }
    .padding(.horizontal, 28)
    .padding(.bottom, 8)
    .onAppear { keyFocused = true }
    .onChange(of: model.keyDraft) { model.clearFailure() }
    .onChange(of: model.sourceDraft) { model.clearFailure() }
    // The field loses focus while it is disabled during the check.
    .onChange(of: checking) { _, now in keyFocused = !now }
  }
}
