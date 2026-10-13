import SwiftUI

/// The timer keeps running here. Save and the interval show the whole minutes Notion will store.
struct FinishView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      SubHeader { _ = model.goBack() }
        .disabled(model.commitState == .saving)
      if let session = model.session {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
          content(session: session, now: context.date)
        }
      }
    }
  }

  private func content(session: ActiveSession, now: Date) -> some View {
    let full = session.commitInterval(at: now)
    let planned = session.commitInterval(at: now, plannedOnly: true)
    let saving = model.commitState == .saving

    return VStack(spacing: 0) {
      Spacer(minLength: 0)
      Text(minutesSeconds(session.elapsed(at: now)))
        .font(.system(size: 44, weight: .semibold, design: .rounded))
        .monospacedDigit()
      if let full {
        Text(timeRange(full.start, full.end))
          .font(.callout)
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .padding(.top, 2)
      }
      if let overtime = session.overtime(at: now) {
        Text("+\(minutesSeconds(overtime)) overtime")
          .font(.callout.weight(.semibold))
          .foregroundStyle(.orange)
          .padding(.top, 6)
      }
      SessionLabels(title: session.title, cards: model.cardNames(session.cardIDs))
        .padding(.top, 20)
      Spacer(minLength: 0)
      if case .failed(let failure) = model.commitState {
        Label(failure.text, systemImage: "xmark.circle.fill")
          .font(.callout.weight(.medium))
          .foregroundStyle(.red)
          .help(failure.detail)
          .padding(.bottom, 8)
      }
      HStack(spacing: 8) {
        discardButton.disabled(saving)
        // Overtime under 30 s rounds away, so a planned-only save would match the full one.
        if let planned, let full, planned.duration < full.duration {
          Button {
            model.save(plannedOnly: true)
          } label: {
            Text("Save \(hoursMinutes(planned.duration))").frame(maxWidth: .infinity)
          }
          .keyboardShortcut(.return, modifiers: .option)
          .help("Save without overtime (⌥↩)")
          .disabled(saving)
        }
        Button {
          model.save(plannedOnly: false)
        } label: {
          ZStack {
            Text("Save \(hoursMinutes(full?.duration ?? 0))").opacity(saving ? 0 : 1)
            if saving {
              ProgressView().controlSize(.small)
            }
          }
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(full == nil || saving)
      }
      .controlSize(.large)
      .padding(.horizontal, 14)
      .padding(.bottom, 14)
    }
  }

  @ViewBuilder private var discardButton: some View {
    if model.discardArmed {
      Button("Discard", role: .destructive) { model.discardPressed() }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .fontWeight(.semibold)
        .keyboardShortcut(.delete, modifiers: .command)
        .help("Press again to discard (⌘⌫)")
    } else {
      Button {
        model.discardPressed()
      } label: {
        Image(systemName: "trash").frame(width: 22)
      }
      .keyboardShortcut(.delete, modifiers: .command)
      .help("Discard session (⌘⌫)")
    }
  }
}

/// `Xm Ys` under an hour, `Xh Ym` from an hour.
private func minutesSeconds(_ seconds: TimeInterval) -> String {
  let s = Int(max(0, seconds))
  return s >= 3600 ? "\(s / 3600)h \(s / 60 % 60)m" : "\(s / 60)m \(s % 60)s"
}
