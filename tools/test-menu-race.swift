import AppKit
import ApplicationServices

// Disposable capture test only. Does not touch saved notes or account credentials.
func value(_ node: AXUIElement, _ attribute: String) -> Any? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(node, attribute as CFString, &result) == .success else { return nil }
    return result
}
func find(_ node: AXUIElement, _ title: String, _ depth: Int = 0) -> AXUIElement? {
    guard depth < 12 else { return nil }
    if value(node, "AXRole") as? String == "AXMenuItem", value(node, "AXTitle") as? String == title { return node }
    for child in value(node, "AXChildren") as? [AXUIElement] ?? [] {
        if let result = find(child, title, depth + 1) { return result }
    }
    return nil
}
guard CommandLine.arguments.contains("--test-race"), AXIsProcessTrusted(),
      let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.voicenotes.app").first else {
    print("Requires --test-race, running app, and Accessibility permission"); exit(1)
}
let root = AXUIElementCreateApplication(app.processIdentifier)
guard find(root, "Stop recording") == nil, let retainedStart = find(root, "Start recording") else {
    print("Refused: app must be idle with one Start recording menu item"); exit(1)
}
func poll(_ title: String) -> Bool {
    for _ in 0..<50 {
        if find(root, title) != nil { return true }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return false
}
print("initial=idle")
print("first-press=\(AXUIElementPerformAction(retainedStart, kAXPressAction as CFString).rawValue)")
guard poll("Stop recording") else { print("start-transition-unverified"); exit(2) }
print("after-first-press=recording")
Thread.sleep(forTimeInterval: 1.5) // Let startup/debounce finish before exercising the stale control.
print("retained-start-title=\(value(retainedStart, "AXTitle") ?? "unavailable")")
print("second-press=\(AXUIElementPerformAction(retainedStart, kAXPressAction as CFString).rawValue)")
if poll("Start recording") {
    print("after-retained-start-press=idle; UNSAFE: old Start control stopped capture")
} else {
    print("after-retained-start-press=recording-or-unknown")
    if let stop = find(root, "Stop recording") {
        print("cleanup-stop=\(AXUIElementPerformAction(stop, kAXPressAction as CFString).rawValue)")
        print("cleanup-idle=\(poll("Start recording"))")
    }
}
