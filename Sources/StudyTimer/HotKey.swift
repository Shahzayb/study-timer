import Carbon.HIToolbox

/// A system-wide hotkey. Carbon hotkeys need no Accessibility permission.
@MainActor
final class HotKey {
  private static var actions: [UInt32: () -> Void] = [:]
  private static var handlerInstalled = false
  private var ref: EventHotKeyRef?

  /// Returns nil when another app already owns the combination.
  init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
    Self.installHandler()
    let id = UInt32(Self.actions.count + 1)
    let hotKeyID = EventHotKeyID(signature: OSType(0x5354_4D52), id: id)
    let status = RegisterEventHotKey(
      UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
    guard status == noErr else { return nil }
    Self.actions[id] = action
  }

  private static func installHandler() {
    guard !handlerInstalled else { return }
    handlerInstalled = true
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, _ in
        var id = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
          MemoryLayout<EventHotKeyID>.size, nil, &id)
        let key = id.id
        return MainActor.assumeIsolated {
          guard let action = HotKey.actions[key] else { return OSStatus(eventNotHandledErr) }
          action()
          return noErr
        }
      }, 1, &spec, nil, nil)
  }
}
