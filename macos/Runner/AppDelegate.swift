import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// 'lgit', keyAELaunchedAsLogInItem. Spelled out because the constant lives
  /// in a header Swift does not otherwise need.
  private static let launchedAsLoginItem = AEKeyword(0x6C67_6974)

  private var statusItem: NSStatusItem?
  private var startedHidden = false

  /// False while active time is on: closing the window then hides the app
  /// instead of ending the recording (SPEC §9.9). With it off, nothing here
  /// changes how the app behaves.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !PresenceMonitor.shared.isTracking
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    let launch = NSAppleEventManager.shared().currentAppleEvent
    startedHidden =
      launch?.paramDescriptor(forKeyword: AppDelegate.launchedAsLoginItem)?.booleanValue == true
    super.applicationWillFinishLaunching(notification)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    PresenceMonitor.shared.onTrackingChanged = { [weak self] tracking in
      self?.setStatusItemVisible(tracking)
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(windowWillClose),
      name: NSWindow.willCloseNotification, object: mainFlutterWindow)
    if startedHidden {
      mainFlutterWindow?.orderOut(nil)
      NSApp.setActivationPolicy(.accessory)
    }
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    showWindow()
    return true
  }

  @objc private func windowWillClose() {
    guard PresenceMonitor.shared.isTracking else { return }
    NSApp.setActivationPolicy(.accessory)
  }

  @objc private func showWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
  }

  private func setStatusItemVisible(_ visible: Bool) {
    guard visible else {
      if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
      statusItem = nil
      NSApp.setActivationPolicy(.regular)
      return
    }
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = NSImage(
      systemSymbolName: "timeline.selection", accessibilityDescription: "time-log")
    let menu = NSMenu()
    let open = NSMenuItem(
      title: "Open time-log", action: #selector(showWindow), keyEquivalent: "")
    open.target = self
    menu.addItem(open)
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit time-log", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
    item.menu = menu
    statusItem = item
  }
}
