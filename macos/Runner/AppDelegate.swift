import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var wakeActivity: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    wakeActivity = ProcessInfo.processInfo.beginActivity(
      options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled],
      reason: "Exibindo cifras no Minhas Cifras"
    )
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
