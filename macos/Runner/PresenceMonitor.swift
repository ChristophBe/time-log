import Cocoa
import CoreGraphics
import FlutterMacOS
import ServiceManagement

/// The native half of active time (SPEC §9.9).
///
/// One predicate decides everything: on the console, not locked, screens awake,
/// not asleep. Every notification recomputes it, and so does `currentState`,
/// which Dart calls on each heartbeat. That second path is what still catches a
/// lock if the distributed notification never arrives.
final class PresenceMonitor: NSObject, FlutterStreamHandler {
  static let shared = PresenceMonitor()

  private(set) var isTracking = false {
    didSet { onTrackingChanged?(isTracking) }
  }

  /// Lets the app delegate follow the setting: the status item, and whether
  /// closing the window quits.
  var onTrackingChanged: ((Bool) -> Void)?

  private var sink: FlutterEventSink?
  private var channels: [NSObject] = []
  private var isObserving = false
  private var activityToken: NSObjectProtocol?

  private var screensAwake = true
  private var systemAwake = true
  private var lockNotified = false
  private var lastActive: Bool?

  func attach(to messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(name: "time_log/presence", binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    let events = FlutterEventChannel(name: "time_log/presence/events", binaryMessenger: messenger)
    events.setStreamHandler(self)
    channels = [methods, events]
  }

  // MARK: FlutterStreamHandler

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  // MARK: Channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "currentState":
      result(payload(active: computeActive(), reason: currentReason()))
    case "setTracking":
      let arguments = call.arguments as? [String: Any]
      let enabled = arguments?["enabled"] as? Bool ?? false
      setTracking(enabled)
      if arguments?["updateLoginItem"] as? Bool == true {
        updateLoginItem(enabled)
      }
      result(nil)
    case "loginItemStatus":
      result(loginItemStatus())
    case "openLoginItemSettings":
      SMAppService.openSystemSettingsLoginItems()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setTracking(_ enabled: Bool) {
    guard enabled != isTracking else { return }
    isTracking = enabled
    if enabled {
      startObserving()
      // App Nap throttles a hidden app's timers, and a heartbeat that arrives
      // late looks exactly like a crash (SPEC §9.9, rule 4).
      activityToken = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep,
        reason: "Recording active time")
    } else if let token = activityToken {
      ProcessInfo.processInfo.endActivity(token)
      activityToken = nil
    }
  }

  private func updateLoginItem(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      NSLog("time-log: login item: \(error)")
    }
  }

  private func loginItemStatus() -> String {
    switch SMAppService.mainApp.status {
    case .enabled: return "enabled"
    case .requiresApproval: return "requiresApproval"
    case .notRegistered: return "notRegistered"
    default: return "unavailable"
    }
  }

  // MARK: Observing

  private func startObserving() {
    guard !isObserving else { return }
    isObserving = true

    let workspace = NSWorkspace.shared.notificationCenter
    let observe: [(NSNotification.Name, Selector)] = [
      (NSWorkspace.screensDidSleepNotification, #selector(screensDidSleep)),
      (NSWorkspace.screensDidWakeNotification, #selector(screensDidWake)),
      (NSWorkspace.willSleepNotification, #selector(systemWillSleep)),
      (NSWorkspace.didWakeNotification, #selector(systemDidWake)),
      (NSWorkspace.sessionDidBecomeActiveNotification, #selector(recompute)),
      (NSWorkspace.sessionDidResignActiveNotification, #selector(recompute)),
      (NSWorkspace.willPowerOffNotification, #selector(willPowerOff)),
    ]
    for (name, selector) in observe {
      workspace.addObserver(self, selector: selector, name: name, object: nil)
    }

    let distributed = DistributedNotificationCenter.default()
    distributed.addObserver(
      self, selector: #selector(screenLocked),
      name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
    distributed.addObserver(
      self, selector: #selector(screenUnlocked),
      name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
  }

  @objc private func screensDidSleep() {
    screensAwake = false
    recompute()
  }

  @objc private func screensDidWake() {
    screensAwake = true
    recompute()
  }

  @objc private func systemWillSleep() {
    systemAwake = false
    recompute()
  }

  @objc private func systemDidWake() {
    systemAwake = true
    recompute()
  }

  @objc private func screenLocked() {
    lockNotified = true
    recompute()
  }

  @objc private func screenUnlocked() {
    lockNotified = false
    recompute()
  }

  /// Not latched into the predicate, because a logout can be cancelled. The next
  /// heartbeat finds the computer still active, and the session carries on.
  @objc private func willPowerOff() {
    lastActive = false
    send(active: false, reason: "logout")
  }

  /// Emits only on a change, so Dart hears about edges rather than noise.
  @objc private func recompute() {
    let active = computeActive()
    guard active != lastActive else { return }
    lastActive = active
    send(active: active, reason: currentReason())
  }

  // MARK: State

  private var session: [String: Any] {
    CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
  }

  private var onConsole: Bool {
    session[kCGSessionOnConsoleKey as String] as? Bool ?? true
  }

  /// The dictionary key is undocumented and only present while locked, so the
  /// notification counts too: either one is enough.
  private var locked: Bool {
    lockNotified || session["CGSSessionScreenIsLocked"] as? Bool == true
  }

  private func computeActive() -> Bool {
    onConsole && !locked && screensAwake && systemAwake
  }

  private func currentReason() -> String {
    if !onConsole { return "switchUser" }
    if locked { return "lock" }
    return "sleep"
  }

  private func send(active: Bool, reason: String) {
    sink?(payload(active: active, reason: reason))
  }

  private func payload(active: Bool, reason: String) -> [String: Any] {
    [
      "active": active,
      "reason": reason,
      "atMillis": Int(Date().timeIntervalSince1970 * 1000),
    ]
  }
}
