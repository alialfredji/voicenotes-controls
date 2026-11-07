import AppKit
import ApplicationServices
func get(_ n: AXUIElement, _ a: String) -> Any? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(n,a as CFString,&v) == .success else { return nil }
    return v
}
func nodes(_ n: AXUIElement, _ depth: Int = 0) -> [AXUIElement] {
    guard depth < 18 else { return [] }
    return [n] + (get(n,"AXChildren") as? [AXUIElement] ?? []).flatMap { nodes($0,depth+1) }
}
guard CommandLine.arguments.contains("--test-capture"), let app=NSRunningApplication.runningApplications(withBundleIdentifier:"com.voicenotes.app").first else { exit(1) }
let root=AXUIElementCreateApplication(app.processIdentifier)
guard nodes(root).contains(where:{ get($0,"AXTitle") as? String == "Stop recording" }) else { print("refused: not recording"); exit(1) }
if let expand=nodes(root).first(where:{ (get($0,"AXAttributedDescription") as? NSAttributedString)?.string == "Expand recording panel" }) {
    _ = AXUIElementPerformAction(expand,kAXPressAction as CFString)
    Thread.sleep(forTimeInterval:0.5)
}
guard let pause=nodes(root).first(where:{ get($0,"AXIdentifier") as? String == "pause.fill" }) else { print("pause unavailable"); exit(1) }
print("pause-action=\(AXUIElementPerformAction(pause,kAXPressAction as CFString).rawValue)")
Thread.sleep(forTimeInterval:0.5)
for n in nodes(root) where get(n,"AXRole") as? String == "AXButton" {
    let id=get(n,"AXIdentifier") as? String ?? ""
    if ["stop.fill","play.fill","pause.fill"].contains(id) { print("id=\(id) label=\((get(n,"AXAttributedDescription") as? NSAttributedString)?.string ?? "")") }
}
