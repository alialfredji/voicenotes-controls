import AppKit
import ApplicationServices

// Read-only feasibility probe. Never outputs note titles or transcripts.
func value(_ node: AXUIElement, _ attribute: String) -> Any? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(node, attribute as CFString, &result) == .success else { return nil }
    return result
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.voicenotes.app").first else {
    print("not-running"); exit(0)
}
print("accessibility-trusted=\(AXIsProcessTrusted()) pid=\(app.processIdentifier)")
var visited = 0
func walk(_ node: AXUIElement, _ depth: Int) {
    guard depth < 18, visited < 2000 else { return }
    visited += 1
    let role = value(node, "AXRole") as? String ?? "?"
    let safeTitles = ["Start recording", "Stop recording", "Cancel recording", "Open Voicenotes"]
    let title = value(node, "AXTitle") as? String ?? ""
    if ["AXButton", "AXWindow", "AXImage"].contains(role) || (role == "AXMenuItem" && safeTitles.contains(title)) {
        var attributes: CFArray?
        AXUIElementCopyAttributeNames(node, &attributes)
        let keys = attributes as? [String] ?? []
        var fields: [String: String] = ["role": role, "depth": String(depth)]
        for key in keys where ["AXIdentifier", "AXDescription", "AXHelp", "AXTitle", "AXEnabled", "AXSubrole", "AXValue", "AXAttributedDescription"].contains(key) {
            if key == "AXTitle" && !safeTitles.contains(title) { continue }
            if let v = value(node, key) {
                if let attributed = v as? NSAttributedString { fields[key] = attributed.string }
                else { fields[key] = String(describing: v) }
            }
        }
        var actions: CFArray?
        AXUIElementCopyActionNames(node, &actions)
        fields["actions"] = String(describing: actions as? [String] ?? [])
        let data = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
    for child in value(node, "AXChildren") as? [AXUIElement] ?? [] { walk(child, depth + 1) }
}
walk(AXUIElementCreateApplication(app.processIdentifier), 0)
