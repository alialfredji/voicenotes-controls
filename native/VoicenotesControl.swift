import AppKit
import ApplicationServices
import Darwin

enum State: String, CaseIterable { case notRunning = "not-running", idle, recording, paused, finalizing, confirmation = "confirmation-pending", unknown }
enum Command: String, CaseIterable { case start, stop, cancel }
enum Decision: Equatable { case launch, dispatch, noAction, busy, refuse }
func decide(_ command: Command, _ state: State) -> Decision {
    switch state {
    case .notRunning: return command == .start ? .launch : .noAction
    case .idle: return command == .start ? .dispatch : .noAction
    case .recording, .paused: return command == .start ? .noAction : .dispatch
    case .finalizing, .confirmation: return .busy
    case .unknown: return .refuse
    }
}
struct Observation: Codable {
    var state: String
    var timestamp = ISO8601DateFormatter().string(from: Date())
    var appVersion: String?
    var accessibility = AXIsProcessTrusted()
    var eventPosting = CGPreflightPostEventAccess()
    var controls: [String: Bool] = [:]
    var evidence: [String] = []
}
struct Result: Codable {
    var ok: Bool
    var message: String
    var observation: Observation
    var dispatched = false
}
struct Failure: Error { let message: String }
func read(_ node: AXUIElement, _ name: String) -> Any? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(node, name as CFString, &v) == .success else { return nil }
    return v
}
func children(_ n: AXUIElement) -> [AXUIElement] { read(n, "AXChildren") as? [AXUIElement] ?? [] }
func text(_ n: AXUIElement, _ key: String) -> String { read(n, key) as? String ?? "" }
func label(_ n: AXUIElement) -> String {
    (read(n, "AXAttributedDescription") as? NSAttributedString)?.string ?? text(n, "AXDescription")
}
func enabled(_ n: AXUIElement) -> Bool { (read(n, "AXEnabled") as? NSNumber)?.boolValue == true }
func tree(_ root: AXUIElement) -> [AXUIElement] {
    var result: [AXUIElement] = []
    func visit(_ n: AXUIElement, _ depth: Int) {
        guard depth < 20, result.count < 2500 else { return }
        result.append(n)
        for c in children(n) { visit(c, depth + 1) }
    }
    visit(root, 0)
    return result
}
func unique(_ nodes: [AXUIElement]) -> AXUIElement? { nodes.count == 1 ? nodes[0] : nil }
let bundleID = "com.voicenotes.app"
let appURL = URL(fileURLWithPath: "/Applications/Voicenotes.app")
let supportedVersions = ["2.4.2"]
func runningApp() -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first }
func cancelConfigured() -> Bool {
    // Read only the public shortcut setting, never account/session preferences.
    let defaults = UserDefaults(suiteName: bundleID)
    guard let data = defaults?.data(forKey: "mac_shortcut_settings_v2"),
          let settings = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
          let action = settings.first(where: { $0["action"] as? String == "cancel_recording" }),
          let shortcut = action["shortcut"] as? [String: Any],
          let keys = shortcut["keys"] as? [String] else { return false }
    return Set(keys) == Set(["ALT", "C"]) && keys.count == 2
}
struct Snapshot {
    var observation: Observation
    var start: AXUIElement?
    var stop: AXUIElement?
    var back: AXUIElement?
    var home: AXUIElement?
    var openMenu: AXUIElement?
    var confirmation: AXUIElement?
    var expand: AXUIElement?
}
func snapshot() -> Snapshot {
    let version = Bundle(url: appURL)?.infoDictionary?["CFBundleShortVersionString"] as? String
    var out = Snapshot(observation: Observation(state: State.unknown.rawValue, appVersion: version))
    guard let app = runningApp() else {
        out.observation.state = State.notRunning.rawValue
        out.observation.evidence = [version == nil ? "Voicenotes is not installed at /Applications/Voicenotes.app" : "No running Voicenotes process"]
        return out
    }
    guard app.bundleURL?.standardizedFileURL == appURL.standardizedFileURL, version.map(supportedVersions.contains) == true else {
        out.observation.evidence = ["Unsupported app path or version; validated version: 2.4.2"]
        return out
    }
    guard AXIsProcessTrusted() else {
        out.observation.evidence = ["Accessibility permission is required for Raycast and its native helper"]
        return out
    }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 1)
    let nodes = tree(root)
    let menuItems = nodes.filter { text($0, "AXRole") == "AXMenuItem" }
    let startMenus = menuItems.filter { text($0, "AXTitle") == "Start recording" }
    let stopMenus = menuItems.filter { text($0, "AXTitle") == "Stop recording" }
    out.openMenu = unique(menuItems.filter { text($0, "AXTitle") == "Open Voicenotes" && enabled($0) })
    let windows = read(root, "AXWindows") as? [AXUIElement] ?? []
    let main = windows.first { text($0, "AXIdentifier") == "main" }
    let mainNodes = main.map(tree) ?? []
    out.back = unique(mainNodes.filter { text($0, "AXRole") == "AXButton" && label($0) == "Back" && enabled($0) })
    out.home = unique(mainNodes.filter { text($0, "AXRole") == "AXButton" && label($0) == "Home" && enabled($0) })
    // Exact semantic sibling signature. No screen coordinates or stored indexes.
    let parents = mainNodes.filter { n in
        let c = children(n)
        return c.contains { text($0,"AXIdentifier") == "mic" } && c.contains { label($0) == "Ask anything" }
    }
    out.start = unique(parents.flatMap { n in children(n).filter {
        text($0,"AXRole") == "AXButton" && text($0,"AXIdentifier").isEmpty && label($0).isEmpty && enabled($0)
    } })
    let stopButtons = nodes.filter { text($0,"AXRole") == "AXButton" && text($0,"AXIdentifier") == "stop.fill" && label($0) == "Stop" && enabled($0) }
    out.stop = unique(stopButtons)
    out.expand = unique(nodes.filter { text($0,"AXRole") == "AXButton" && label($0) == "Expand recording panel" && enabled($0) })
    let isPaused = nodes.contains {
        text($0,"AXRole") == "AXButton" && text($0,"AXIdentifier") == "play.fill" && label($0) == "Play"
    } && out.stop != nil
    let isRecording = nodes.contains { text($0,"AXRole") == "AXButton" && text($0,"AXIdentifier") == "pause.fill" && label($0) == "Pause" }
    out.confirmation = nodes.first {
        text($0,"AXRole") == "AXSheet" || text($0,"AXRole") == "AXDialog" || text($0,"AXSubrole") == "AXDialog"
    } ?? windows.first { window in
        let contents = tree(window)
        return contents.contains { text($0,"AXRole") == "AXButton" && text($0,"AXTitle") == "Yes, cancel" }
            && contents.contains { text($0,"AXRole") == "AXButton" && text($0,"AXTitle") == "No, continue" }
    }
    out.observation.controls = ["start": out.start != nil, "stop": out.stop != nil || out.expand != nil, "cancel": cancelConfigured() && CGPreflightPostEventAccess()]
    if out.confirmation != nil {
        out.observation.state = State.confirmation.rawValue
        out.observation.evidence = ["Native sheet/dialog requires a decision in Voicenotes"]
    } else if stopMenus.count == 1 && out.stop != nil && (isRecording || isPaused) {
        out.observation.state = isPaused ? State.paused.rawValue : State.recording.rawValue
        out.observation.evidence = ["Status menu: Stop recording", "Recording panel: explicit Stop and \(isPaused ? "Play (paused)" : "Pause") buttons"]
    } else if stopMenus.count == 1 && out.expand != nil {
        out.observation.state = State.recording.rawValue
        out.observation.evidence = ["Status menu: Stop recording", "Collapsed active recording panel exposes Expand recording panel"]
    } else if stopMenus.count == 1 && out.stop == nil {
        out.observation.state = State.finalizing.rawValue
        out.observation.evidence = ["Status menu says Stop recording but capture controls are unavailable; processing/startup may be in progress"]
    } else if startMenus.count == 1 && stopMenus.isEmpty && stopButtons.isEmpty {
        out.observation.state = State.idle.rawValue
        out.observation.evidence = ["Status menu: Start recording", "No active capture controls"]
    } else {
        out.observation.evidence = ["Menu and capture controls do not match a validated recording state"]
    }
    return out
}
func press(_ node: AXUIElement) throws {
    guard enabled(node) else { throw Failure(message:"The control changed or is disabled. No retry was sent; check Voicenotes.") }
    guard AXUIElementPerformAction(node, kAXPressAction as CFString) == .success else {
        throw Failure(message:"Voicenotes did not accept the control action. No retry was sent; check its current state.")
    }
}
func waitFor(_ predicate: (Snapshot) -> Bool, seconds: Double) -> Snapshot {
    let deadline = Date().addingTimeInterval(seconds)
    var s = snapshot()
    while !predicate(s) && Date() < deadline { Thread.sleep(forTimeInterval:0.15); s = snapshot() }
    return s
}
func withLock<T>(_ operation: () throws -> T) throws -> T {
    let folder = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Voicenotes Raycast Local")
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
    let file = folder.appendingPathComponent("recording.lock")
    let fd = Darwin.open(file.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { throw Failure(message:"Cannot open the recording command lock.") }
    defer { Darwin.close(fd) }
    let deadline = Date().addingTimeInterval(3)
    while flock(fd, LOCK_EX | LOCK_NB) != 0 {
        guard errno == EWOULDBLOCK, Date() < deadline else { throw Failure(message:"Another recording command is still running. Try again after it finishes.") }
        Thread.sleep(forTimeInterval:0.05)
    }
    defer { flock(fd, LOCK_UN) }
    // The kernel owns this lock and releases it on process death. File contents are diagnostic only.
    ftruncate(fd,0)
    let owner = "pid=\(getpid()) acquired=\(ISO8601DateFormatter().string(from:Date()))\n"
    owner.withCString { _ = Darwin.write(fd,$0,strlen($0)) }
    return try operation()
}
func execute(_ command: Command) throws -> Result {
    try withLock {
        var s = snapshot()
        var state = State(rawValue:s.observation.state) ?? .unknown
        if decide(command,state) == .launch {
            guard FileManager.default.fileExists(atPath:appURL.path) else { throw Failure(message:"Install the official Voicenotes app in /Applications first.") }
            let open = Process(); open.executableURL = URL(fileURLWithPath:"/usr/bin/open"); open.arguments = ["-g",appURL.path]
            try open.run(); open.waitUntilExit()
            s = waitFor({ $0.observation.state != State.notRunning.rawValue && $0.observation.state != State.unknown.rawValue },seconds:5)
            state = State(rawValue:s.observation.state) ?? .unknown
        }
        switch decide(command,state) {
        case .noAction:
            return Result(ok:true,message: command == .start ? "Already recording; capture continues" : (state == .notRunning ? "Voicenotes is not running; nothing changed" : "No active recording; nothing changed"),observation:s.observation)
        case .busy:
            if state == .confirmation { runningApp()?.activate(options:[])
                if let dialog=s.confirmation { AXUIElementPerformAction(dialog,kAXRaiseAction as CFString) }
            }
            return Result(ok:false,message:state == .confirmation ? "Complete the pending decision in Voicenotes" : "Voicenotes is processing or starting capture; try again shortly",observation:s.observation)
        case .refuse, .launch:
            return Result(ok:false,message:s.observation.evidence.joined(separator:". "),observation:s.observation)
        case .dispatch: break
        }
        if command == .start {
            if s.start == nil, let open=s.openMenu { try press(open); s = snapshot() }
            if s.start == nil, let back=s.back { try press(back); s = snapshot() }
            if s.start == nil, let home=s.home { try press(home); s = snapshot() }
            guard s.observation.state == State.idle.rawValue, let start=s.start else {
                return Result(ok:false,message:"Start control unavailable. Open Voicenotes, sign in, and go to Home; then check Recording Setup and Status.",observation:s.observation)
            }
            // This is the Start-only window button, never the mutable status-menu toggle.
            try press(start)
        } else if command == .stop {
            if s.stop == nil, let expand=s.expand {
                try press(expand)
                s = waitFor({ $0.stop != nil || $0.observation.state == State.idle.rawValue },seconds:2)
            }
            if s.observation.state == State.idle.rawValue {
                return Result(ok:true,message:"Capture already ended; nothing changed",observation:s.observation)
            }
            guard let stop=s.stop else { throw Failure(message:"Explicit Stop control is unavailable; no shortcut toggle was sent.") }
            try press(stop)
        } else {
            guard cancelConfigured(), CGPreflightPostEventAccess() else {
                return Result(ok:false,message:"Cancel requires the verified Option+C shortcut in Voicenotes Settings and Accessibility event-posting permission. No keys were sent.",observation:s.observation)
            }
            guard let app=runningApp() else { throw Failure(message:"Voicenotes closed before cancellation; no keys were sent.") }
            app.activate(options:[])
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            func appIsFrontmost() -> Bool {
                // NSWorkspace's cached frontmostApplication can stay stale in a
                // short-lived CLI. AXFrontmost is read from the target process.
                (read(appElement,"AXFrontmost") as? NSNumber)?.boolValue == true
            }
            let focusDeadline = Date().addingTimeInterval(1)
            while !appIsFrontmost() && Date() < focusDeadline {
                Thread.sleep(forTimeInterval:0.05)
            }
            guard appIsFrontmost() else {
                throw Failure(message:"Could not focus Voicenotes for Cancel; no keys were sent.")
            }
            // Cancel-only global hotkey, read from settings above. It can never start capture.
            // Flags are attached to complete key events; no modifier key is left held.
            guard [State.recording.rawValue,State.paused.rawValue].contains(snapshot().observation.state) else {
                return Result(ok:false,message:"Capture changed before cancellation; nothing was sent",observation:snapshot().observation)
            }
            let source = CGEventSource(stateID:.privateState)
            for down in [true,false] {
                guard let event=CGEvent(keyboardEventSource:source,virtualKey:8,keyDown:down) else { throw Failure(message:"Could not construct the Cancel hotkey.") }
                event.flags = .maskAlternate; event.post(tap:.cghidEventTap)
            }
        }
        let after = waitFor({ snap in
            command == .start ? snap.observation.state == State.recording.rawValue : [State.idle.rawValue,State.confirmation.rawValue].contains(snap.observation.state)
        },seconds:6)
        if after.observation.state == State.confirmation.rawValue {
            runningApp()?.activate(options:[])
            return Result(ok:false,message:"Confirm the pending decision in Voicenotes",observation:after.observation,dispatched:true)
        }
        let expected = command == .start ? State.recording.rawValue : State.idle.rawValue
        guard after.observation.state == expected else {
            return Result(ok:false,message:"Action sent once, but its result is uncertain. Check Voicenotes; no automatic retry was sent.",observation:after.observation,dispatched:true)
        }
        let message: String
        switch command {
        case .start: message = "Recording started in Voicenotes"
        case .stop: message = "Recording stopped; Voicenotes is processing it"
        case .cancel: message = "Recording cancelled in Voicenotes"
        }
        return Result(ok:true,message:message,observation:after.observation,dispatched:true)
    }
}
func selfTest() {
    var state: State = .idle
    var actions: [Command] = []
    for command: Command in [.start,.start,.stop,.stop,.cancel,.start,.cancel,.cancel] {
        if decide(command,state) == .dispatch {
            actions.append(command)
            state = command == .start ? .recording : .idle
        }
    }
    guard actions == [.start,.stop,.start,.cancel], state == .idle else { fatalError("Repeated command sequence inverted capture") }
    for blocked: State in [.unknown,.confirmation,.finalizing] {
        for command in Command.allCases {
            guard decide(command,blocked) != .dispatch && decide(command,blocked) != .launch else { fatalError("Unsafe mutation while state is uncertain or busy") }
        }
    }
    guard decide(.stop,.notRunning) == .noAction, decide(.cancel,.notRunning) == .noAction,
          decide(.start,.notRunning) == .launch, decide(.start,.paused) == .noAction,
          decide(.stop,.paused) == .dispatch, decide(.cancel,.paused) == .dispatch else { fatalError("Startup or paused-session invariant failed") }
    print("PASS: repeated-command scenario, uncertain/busy guards, startup and paused-session invariants")
}

let argument = CommandLine.arguments.dropFirst().first ?? "status"
if argument == "--self-test" { selfTest(); exit(0) }
let result: Result
do {
    if argument == "status" { result = Result(ok:true,message:"Voicenotes recording diagnostics",observation:snapshot().observation) }
    else if argument == "request-accessibility" {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        result = Result(ok:true,message:"Grant Accessibility permission, then refresh status",observation:snapshot().observation)
    } else if let command=Command(rawValue:argument) { result = try execute(command) }
    else { throw Failure(message:"Unknown command") }
} catch { result = Result(ok:false,message:(error as? Failure)?.message ?? error.localizedDescription,observation:snapshot().observation) }
let data = try JSONEncoder().encode(result)
print(String(data:data,encoding:.utf8)!)
