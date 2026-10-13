import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Owns the menu bar item, its popover, and the ⌃⌥S hotkey.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let model: AppModel
  private let popover = NSPopover()
  private var hotKey: HotKey?
  private var clickMonitor: Any?

  init(model: AppModel) {
    self.model = model
    super.init()
    if let button = statusItem.button {
      button.image = Glyph.ring(progress: 0.8, knob: true)
      button.setAccessibilityLabel("Study Timer")
      button.target = self
      button.action = #selector(toggle)
      button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    let host = NSHostingController(rootView: PopoverView(model: model))
    host.sizingOptions = [.preferredContentSize]
    popover.contentViewController = host
    popover.behavior = .transient
    popover.delegate = self

    hotKey = HotKey(keyCode: kVK_ANSI_S, modifiers: controlKey | optionKey) { [weak self] in
      self?.toggle()
    }
    if hotKey == nil { NSLog("Study Timer: ⌃⌥S is taken by another app") }
    if model.screen == .connect { showWhenPlaced() }
  }

  @objc func toggle() {
    if popover.isShown {
      popover.performClose(nil)
    } else {
      show()
    }
  }

  /// The status item slides into the menu bar after launch. The popover opens once it stops moving.
  private func showWhenPlaced(last: NSRect = .zero, tries: Int = 30) {
    let frame = statusItem.button?.window?.frame ?? .zero
    if frame.height > 0, frame == last { return show() }
    guard tries > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.showWhenPlaced(last: frame, tries: tries - 1)
    }
  }

  private func show() {
    guard let button = statusItem.button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    // A status item click cannot activate the app, so the popover takes the keyboard as a non-activating panel.
    let window = popover.contentViewController?.view.window
    (window as? NSPanel)?.styleMask.insert(.nonactivatingPanel)
    window?.makeKey()
  }

  /// Esc inside a text field reaches the popover before the Back button. On a sub-screen, Esc means Back.
  func popoverShouldClose(_ popover: NSPopover) -> Bool {
    guard let event = NSApp.currentEvent, event.type == .keyDown,
      event.keyCode == UInt16(kVK_Escape)
    else { return true }
    return !model.goBack()
  }

  func popoverWillShow(_ notification: Notification) {
    statusItem.button?.highlight(true)
    // A transient popover in an inactive app never sees clicks in other apps.
    clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
      [weak self] _ in
      MainActor.assumeIsolated { self?.popover.performClose(nil) }
    }
  }

  func popoverDidClose(_ notification: Notification) {
    statusItem.button?.highlight(false)
    if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    clickMonitor = nil
  }
}

/// Menu bar glyphs, drawn as template images so they follow the menu bar appearance.
enum Glyph {
  /// The app mark: a ring that fills clockwise from 12 o'clock. The idle glyph is 80% with a knob.
  static func ring(progress: Double, knob: Bool) -> NSImage {
    let size: CGFloat = 16
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
      let width: CGFloat = 2.2
      let radius = size / 2 - width / 2 - 1
      let center = NSPoint(x: rect.midX, y: rect.midY)
      let track = NSBezierPath()
      track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
      track.lineWidth = width
      NSColor.black.withAlphaComponent(0.3).setStroke()
      track.stroke()

      let p = min(max(progress, 0), 1)
      guard p > 0 else { return true }
      let end = 90 - 360 * p
      let arc = NSBezierPath()
      arc.appendArc(
        withCenter: center, radius: radius, startAngle: 90, endAngle: end, clockwise: true)
      arc.lineWidth = width
      arc.lineCapStyle = .round
      NSColor.black.setStroke()
      arc.stroke()
      if knob {
        let a = end * .pi / 180
        let k = NSPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: k.x - 2.4, y: k.y - 2.4, width: 4.8, height: 4.8)).fill()
      }
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Study Timer"
    return image
  }
}
