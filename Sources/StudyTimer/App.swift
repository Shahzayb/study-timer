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
    withExtendedLifetime(delegate) { app.run() }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusBar: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusBar = StatusBarController()
  }
}
