import AppKit
import ApplicationServices
func get(_ n: AXUIElement, _ a: String) -> Any? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(n, a as CFString, &v) == .success else { return nil }
    return v
}
func children(_ n: AXUIElement) -> [AXUIElement] { get(n,"AXChildren") as? [AXUIElement] ?? [] }
func nodes(_ n: AXUIElement, _ depth: Int = 0) -> [AXUIElement] {
    guard depth < 15 else { return [] }
    return [n] + children(n).flatMap { nodes($0,depth+1) }
}
func label(_ n: AXUIElement) -> String { (get(n,"AXAttributedDescription") as? NSAttributedString)?.string ?? "" }
let globalCancel = CommandLine.arguments.contains("--test-cancel-global")
let cancelTest = CommandLine.arguments.contains("--test-cancel") || globalCancel
guard (CommandLine.arguments.contains("--test-race") || cancelTest), AXIsProcessTrusted(), let app = NSRunningApplication.runningApplications(withBundleIdentifier:"com.voicenotes.app").first else { exit(1) }
let root = AXUIElementCreateApplication(app.processIdentifier)
func menu(_ title: String) -> AXUIElement? { nodes(root).first { get($0,"AXRole") as? String == "AXMenuItem" && get($0,"AXTitle") as? String == title } }
guard menu("Stop recording") == nil, menu("Start recording") != nil else { print("refused: not idle"); exit(1) }
let candidates = nodes(root).filter { n in
    let siblings=children(n)
    return siblings.contains { get($0,"AXIdentifier") as? String == "mic" } && siblings.contains { label($0) == "Ask anything" }
}.flatMap { n in children(n).filter { get($0,"AXRole") as? String == "AXButton" && (get($0,"AXIdentifier") as? String ?? "").isEmpty && label($0).isEmpty } }
guard candidates.count == 1, let start=candidates.first else { print("refused: ambiguous start \(candidates.count)"); exit(1) }
print("found unique Start candidate using mic/Ask anything semantic siblings")
print("start=\(AXUIElementPerformAction(start,kAXPressAction as CFString).rawValue)")
Thread.sleep(forTimeInterval:2)
print("recording=\(menu("Stop recording") != nil)")
if cancelTest {
    let source = CGEventSource(stateID: .privateState)
    for down in [true,false] {
        let event = CGEvent(keyboardEventSource:source,virtualKey:8,keyDown:down)!
        event.flags = .maskAlternate
        if globalCancel { event.post(tap:.cghidEventTap) }
        else { event.postToPid(app.processIdentifier) }
    }
    print("targeted-cancel-dispatched")
} else {
    print("stale-start=\(AXUIElementPerformAction(start,kAXPressAction as CFString).rawValue)")
}
Thread.sleep(forTimeInterval:2)
print("recording-after-stale-start=\(menu("Stop recording") != nil)")
for n in nodes(root) where get(n,"AXRole") as? String == "AXButton" {
    let id=get(n,"AXIdentifier") as? String ?? ""
    if ["stop.fill","pause.fill"].contains(id) || !label(n).isEmpty { print("button id=\(id) label=\(label(n))") }
}
if let stop=nodes(root).first(where: { get($0,"AXIdentifier") as? String == "stop.fill" }) {
    print("explicit-stop=\(AXUIElementPerformAction(stop,kAXPressAction as CFString).rawValue)")
    Thread.sleep(forTimeInterval:2)
    print("idle=\(menu("Start recording") != nil)")
}
