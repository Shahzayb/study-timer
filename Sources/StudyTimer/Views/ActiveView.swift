import SwiftUI

struct ActiveView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      if let session = model.session {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
          RingTimer(session: session, ringing: model.ringing, now: context.date)
        }
        .frame(width: 188, height: 188)
        .padding(.top, 24)
        SessionLabels(title: session.title, cards: model.cardNames(session.cardIDs))
          .padding(.top, 14)
        Spacer(minLength: 0)
        SessionControls(model: model, session: session)
          .padding(.bottom, 16)
      } else {
        Spacer(minLength: 0)
      }
      Divider()
      Footer(model: model)
    }
  }
}

/// The title over the cards, one truncated line each.
struct SessionLabels: View {
  let title: String
  let cards: [String]

  var body: some View {
    VStack(spacing: 2) {
      Text(title).font(.headline).lineLimit(1)
      Text(cards.joined(separator: " · "))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(.horizontal, 24)
  }
}

private struct RingTimer: View {
  let session: ActiveSession
  let ringing: Bool
  let now: Date
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let elapsed = session.elapsed(at: now)
    let over = session.overtime(at: now)
    let progress: Double =
      if over != nil {
        1
      } else if let target = session.target {
        max(0, 1 - elapsed / target)
      } else {
        elapsed.truncatingRemainder(dividingBy: 3600) / 3600
      }

    ZStack {
      Circle().stroke(Color.primary.opacity(0.1), lineWidth: 12)
      Circle()
        .trim(from: 0, to: max(progress, 0.002))
        .stroke(
          AngularGradient(
            colors: over == nil ? Brand.ring(scheme) : Brand.overtime,
            center: .center, startAngle: .zero, endAngle: .degrees(360 * max(progress, 0.05))),
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .opacity(session.isRunning ? 1 : 0.3)
      VStack(spacing: 2) {
        statusIcon(over: over).frame(height: 18)
        Text(timeText(elapsed: elapsed, over: over))
          .font(.system(size: 42, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(over == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.orange))
          .opacity(session.isRunning ? 1 : 0.45)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(caption(over: over))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(height: 18)
      }
      .padding(.horizontal, 22)
    }
  }

  private func timeText(elapsed: TimeInterval, over: TimeInterval?) -> String {
    if let over { return "+" + clock(over) }
    if let target = session.target { return clock((target - elapsed).rounded(.up)) }
    return clock(elapsed)
  }

  private func caption(over: TimeInterval?) -> String {
    if !session.isRunning { return "PAUSED" }
    if over != nil { return "OVERTIME" }
    if let target = session.target { return "\(Int(target / AppModel.minuteLength)) MIN" }
    return "ELAPSED"
  }

  @ViewBuilder private func statusIcon(over: TimeInterval?) -> some View {
    if ringing {
      Image(systemName: "bell.fill")
        .foregroundStyle(.orange)
        .symbolEffect(.wiggle, options: .repeating)
    } else if over != nil, session.isRunning {
      Image(systemName: "bell.slash.fill").foregroundStyle(.secondary)
    } else {
      Color.clear
    }
  }
}

private struct SessionControls: View {
  @Bindable var model: AppModel
  let session: ActiveSession

  var body: some View {
    HStack(spacing: 22) {
      if model.ringing {
        RoundButton(
          symbol: "bell.slash.fill", label: "Mute alarm (M)", tint: .orange, prominent: true
        ) {
          model.mute()
        }
        .keyboardShortcut("m", modifiers: [])
      }
      if session.isRunning {
        RoundButton(symbol: "pause.fill", label: "Pause (Space)") { model.pause() }
          .keyboardShortcut(.space, modifiers: [])
      } else {
        RoundButton(symbol: "play.fill", label: "Resume (Space)", prominent: true) {
          model.resume()
        }
        .keyboardShortcut(.space, modifiers: [])
      }
      RoundButton(
        symbol: "checkmark", label: "Finish (↩)", prominent: session.isRunning && !model.ringing
      ) {
        model.openFinish()
      }
      .keyboardShortcut(.return, modifiers: [])
    }
  }
}
