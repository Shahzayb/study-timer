import AppKit
import UserNotifications

/// The countdown alarm: a looping sound in the app and a notification banner from the system.
@MainActor
final class Alarm: NSObject, UNUserNotificationCenterDelegate {
  /// Runs when the owner clicks the notification.
  var onOpen: () -> Void = {}
  private var sound: NSSound?
  private static let requestID = "alarm"

  /// Call once at launch. A restored session is paused, so a banner left from a crash or quit must not fire.
  func activate() {
    UNUserNotificationCenter.current().delegate = self
    cancel()
  }

  func ring(_ name: String) {
    sound?.stop()
    // A copy, because `NSSound(named:)` shares one instance with the Settings preview.
    sound = NSSound(named: name)?.copy() as? NSSound
    sound?.loops = true
    sound?.play()
  }

  func silence() {
    sound?.stop()
    sound = nil
  }

  /// The system asks only once, so later calls return at once.
  func requestPermission() {
    Task {
      _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    }
  }

  /// Replaces any pending banner with one `seconds` from now. The banner is silent because the app plays the sound.
  func schedule(after seconds: TimeInterval, title: String) {
    let content = UNMutableNotificationContent()
    content.title = "Time's up"
    content.body = title
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
    let request = UNNotificationRequest(
      identifier: Self.requestID, content: content, trigger: trigger)
    Task { try? await UNUserNotificationCenter.current().add(request) }
  }

  func cancel() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [Self.requestID])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    await MainActor.run { onOpen() }
  }
}
