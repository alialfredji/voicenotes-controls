import AppKit
import ApplicationServices
func get(_ n: AXUIElement, _ a: String) -> Any? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(n, a as CFString, &v) == .success else { return nil }
    return v
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.voicenotes.app").first else { exit(1) }
func walk(_ n: AXUIElement, _ path: String, _ depth: Int) {
    guard depth <= 6 else { return }
    let role = get(n, "AXRole") as? String ?? "?"
    let identifier = get(n, "AXIdentifier") as? String ?? ""
    print("\(path) \(role) id=\(identifier)")
    if role == "AXButton" && depth <= 5 {
        var attrs: CFArray?
        AXUIElementCopyAttributeNames(n, &attrs)
        for a in attrs as? [String] ?? [] where !["AXParent", "AXWindow", "AXTopLevelUIElement", "AXChildren", "AXChildrenInNavigationOrder"].contains(a) {
            print("  \(a)=\(String(describing: get(n,a)))")
        }
    }
    for (i,c) in (get(n,"AXChildren") as? [AXUIElement] ?? []).enumerated() { walk(c,"\(path).\(i)", depth+1) }
}
let root = AXUIElementCreateApplication(app.processIdentifier)
for (i,w) in (get(root,"AXWindows") as? [AXUIElement] ?? []).enumerated() { walk(w,"w\(i)",0) }
