import AppKit

@main
@MainActor
enum Main {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // `--regular` adds a Dock icon so computer use can list and target the app.
    app.setActivationPolicy(CommandLine.arguments.contains("--regular") ? .regular : .accessory)
    app.mainMenu = editMenu()
    withExtendedLifetime(delegate) { app.run() }
  }

  /// Text fields get ⌘X, ⌘C, ⌘V, ⌘A, and ⌘Z only through menu key equivalents, and this app has no menu bar.
  private static func editMenu() -> NSMenu {
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    edit.addItem(.separator())
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(
      withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

    let menu = NSMenu()
    // The first item is the app menu. Without a submenu, macOS shows Edit in its place.
    menu.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = NSMenu(
      title: "Study Timer")
    menu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit
    return menu
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var statusBar: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusBar = StatusBarController(model: model)
    model.launch()
  }

  func applicationWillTerminate(_ notification: Notification) {
    model.prepareToQuit()
  }
}
