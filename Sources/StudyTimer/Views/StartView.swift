import AppKit
import SwiftUI

struct StartView: View {
  @Bindable var model: AppModel

  private var titleBinding: Binding<String> {
    Binding(get: { model.title }, set: { model.editTitle($0) })
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        SearchField(
          text: $model.search,
          prompt: "Search cards",
          focusToken: model.focusToken,
          onMove: model.moveHighlight,
          onSubmit: model.toggleHighlighted
        )
        CardList(model: model)
          .frame(maxHeight: .infinity)
        TextField(
          "Title", text: titleBinding,
          prompt: Text(model.suggestedTitle.isEmpty ? "Title" : model.suggestedTitle)
        )
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .controlSize(.large)
        .onSubmit { model.start() }
        DurationPicker(model: model)
        Button {
          model.start()
        } label: {
          Label("Start", systemImage: "play.fill")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!model.canStart)
        .help("Start (⌘↩)")
      }
      .padding(.horizontal, 14)
      .padding(.top, 14)
      .padding(.bottom, 12)
      Divider()
      Footer(model: model)
    }
  }
}

private struct CardList: View {
  @Bindable var model: AppModel

  var body: some View {
    if model.cards == nil {
      if let failure = model.cardsFailure ?? model.statsFailure {
        FailureView(failure: failure) { model.retry() }
      } else {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(
            ["English placeholder", "Job card", "Swift drills", "Linear Algebra"], id: \.self
          ) {
            Text($0).padding(.horizontal, 10).frame(height: 30)
          }
        }
        .redacted(reason: .placeholder)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    } else if model.cards?.isEmpty == true {
      Text("No cards")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      let rows = model.visibleCards
      if rows.isEmpty {
        Label("No match", systemImage: "magnifyingglass")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 2) {
              ForEach(rows, id: \.id) { card in
                CardRowView(
                  name: card.name,
                  selected: model.selectedIDs.contains(card.id),
                  highlighted: model.highlightID == card.id
                )
                .id(card.id)
                .onHover { if $0 { model.highlightID = card.id } }
                .onTapGesture { model.toggle(card) }
              }
            }
            .padding(.bottom, 12)
          }
          .scrollIndicators(.never)
          .mask(
            LinearGradient(
              stops: [.init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
              startPoint: .top, endPoint: .bottom)
          )
          .onChange(of: model.highlightID) { _, id in
            if let id { proxy.scrollTo(id) }
          }
        }
      }
    }
  }
}

private struct CardRowView: View {
  let name: String
  let selected: Bool
  let highlighted: Bool

  var body: some View {
    HStack(spacing: 8) {
      Text(name)
        .fontWeight(selected ? .semibold : .regular)
        .lineLimit(1)
      Spacer(minLength: 4)
      if selected {
        Image(systemName: "checkmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.tint)
      }
    }
    .padding(.horizontal, 10)
    .frame(height: 30)
    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill))
    .contentShape(Rectangle())
  }

  private var fill: AnyShapeStyle {
    if selected { return AnyShapeStyle(Color.accentColor.opacity(highlighted ? 0.3 : 0.2)) }
    if highlighted { return AnyShapeStyle(Color.primary.opacity(0.08)) }
    return AnyShapeStyle(Color.clear)
  }
}

private struct DurationPicker: View {
  @Bindable var model: AppModel

  /// 0 is the stopwatch. -1 is a typed length, which leaves every segment unselected.
  private var choice: Binding<Int> {
    Binding(
      get: {
        if model.mode == .stopwatch { return 0 }
        return model.customMinutes.isEmpty && AppModel.presets.contains(model.minutes)
          ? model.minutes : -1
      },
      set: { value in
        if value == 0 {
          model.pick(stopwatch: true)
        } else if value > 0 {
          model.pick(stopwatch: false, minutes: value)
        }
      }
    )
  }

  var body: some View {
    HStack(spacing: 8) {
      Picker("Length", selection: choice) {
        Image(systemName: "stopwatch").tag(0)
        ForEach(AppModel.presets, id: \.self) { Text("\($0)").tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: .infinity)
      TextField(
        "Minutes",
        text: Binding(get: { model.customMinutes }, set: { model.editCustomMinutes($0) }),
        prompt: Text("min")
      )
      .labelsHidden()
      .textFieldStyle(.roundedBorder)
      .multilineTextAlignment(.center)
      .foregroundStyle(model.customMinutesInvalid ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
      .frame(width: 54)
      .help("1–600 minutes")
    }
    .controlSize(.large)
    .background {
      // ⌘1 picks the stopwatch. ⌘2 to ⌘5 pick the presets.
      Group {
        Button("") { model.pick(stopwatch: true) }.keyboardShortcut("1", modifiers: .command)
        ForEach(Array(AppModel.presets.enumerated()), id: \.offset) { index, preset in
          Button("") { model.pick(stopwatch: false, minutes: preset) }
            .keyboardShortcut(KeyEquivalent(Character("\(index + 2)")), modifiers: .command)
        }
      }
      .opacity(0)
      .accessibilityHidden(true)
    }
  }
}

/// An `NSSearchField`, because SwiftUI fields cannot route ↑, ↓, and ↩ to the card list.
private struct SearchField: NSViewRepresentable {
  @Binding var text: String
  var prompt: String
  var focusToken: Int
  var onMove: (Int) -> Void
  var onSubmit: () -> Void

  func makeNSView(context: Context) -> NSSearchField {
    let field = NSSearchField()
    field.placeholderString = prompt
    field.delegate = context.coordinator
    field.sendsSearchStringImmediately = true
    field.controlSize = .large
    field.font = .systemFont(ofSize: NSFont.systemFontSize(for: .large))
    return field
  }

  func updateNSView(_ field: NSSearchField, context: Context) {
    context.coordinator.parent = self
    if field.stringValue != text { field.stringValue = text }
    if context.coordinator.focusToken != focusToken {
      context.coordinator.focusToken = focusToken
      DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var parent: SearchField
    var focusToken = -1

    init(parent: SearchField) { self.parent = parent }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else { return }
      parent.text = field.stringValue
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool
    {
      switch selector {
      case #selector(NSResponder.moveDown(_:)):
        parent.onMove(1)
        return true
      case #selector(NSResponder.moveUp(_:)):
        parent.onMove(-1)
        return true
      case #selector(NSResponder.insertNewline(_:)):
        parent.onSubmit()
        return true
      default:
        return false
      }
    }
  }
}
