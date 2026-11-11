import AppKit
import ApplicationServices
import Darwin
#if RAYCAST_BRIDGE
import RaycastSwiftMacros
#endif

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
let supportedVersions = ["2.4.2", "2.4.3", "2.4.4"]
func runningApp() -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first }
func cancelConfigured() -> Bool {
    // Read only the public shortcut setting, never account/session preferences.
    let defaults = UserDefaults(suiteName: bundleID)
    // The Swift bridge may serve multiple commands in one process.
    // Revalidate cross-process preference updates rather than keeping a binding.
    defaults?.synchronize()
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
    // Read the installed plist afresh: Bundle caches could hide an app update
    // while Raycast's generated Swift bridge process is still alive.
    let infoData = try? Data(contentsOf: appURL.appendingPathComponent("Contents/Info.plist"))
    let info = infoData.flatMap { try? PropertyListSerialization.propertyList(from:$0,format:nil) as? [String:Any] }
    let version = info?["CFBundleShortVersionString"] as? String
    var out = Snapshot(observation: Observation(state: State.unknown.rawValue, appVersion: version))
    guard let app = runningApp() else {
        out.observation.state = State.notRunning.rawValue
        out.observation.evidence = [version == nil ? "Voicenotes is not installed at /Applications/Voicenotes.app" : "No running Voicenotes process"]
        return out
    }
    guard app.bundleURL?.standardizedFileURL == appURL.standardizedFileURL, version.map(supportedVersions.contains) == true else {
        out.observation.evidence = ["Unsupported app path or version; supported versions: \(supportedVersions.joined(separator: ", "))"]
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
func startControlsReady(_ s: Snapshot) -> Bool {
    if s.observation.state == State.idle.rawValue {
        return s.start != nil || s.back != nil || s.home != nil
    }
    return ![State.notRunning.rawValue, State.unknown.rawValue].contains(s.observation.state)
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
            let open = Process(); open.executableURL = URL(fileURLWithPath:"/usr/bin/open"); open.arguments = [appURL.path]
            try open.run(); open.waitUntilExit()
            guard open.terminationStatus == 0 else { throw Failure(message:"macOS could not open Voicenotes. Open it manually, then retry Start.") }
            // A process/menu can exist before its controls are ready. Wait for
            // observable controls, then continue this same command exactly once.
            s = waitFor(startControlsReady,seconds:12)
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
            if s.start == nil, let open=s.openMenu {
                try press(open)
                s = waitFor({ $0.start != nil || $0.back != nil || $0.home != nil || $0.observation.state != State.idle.rawValue },seconds:2)
            }
            if s.start == nil, let back=s.back {
                try press(back)
                s = waitFor({ $0.start != nil || $0.home != nil || $0.observation.state != State.idle.rawValue },seconds:3)
            }
            if s.start == nil, let home=s.home {
                try press(home)
                s = waitFor({ $0.start != nil || $0.observation.state != State.idle.rawValue },seconds:3)
            }
            // Ask AI replaces the Home capture bar. Close only that verified
            // chat panel so recording remains usable after an Ask command.
            if s.start == nil, field(mainNodes(),"Ask anything") != nil,
               let close = button(mainNodes(),"Close"), text(close,"AXIdentifier") == "xmark" {
                try press(close)
                s = waitFor({ $0.start != nil || $0.observation.state != State.idle.rawValue },seconds:3)
            }
            if [State.recording.rawValue,State.paused.rawValue].contains(s.observation.state) {
                return Result(ok:true,message:"Already recording; capture continues",observation:s.observation)
            }
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
    guard dictationTranscript(["Dictation","20 words","Today","11:57 PM","Full transcript\nwith two lines","11:55 PM","Older"]) == "Full transcript\nwith two lines",
          dictationTranscript(["Dictation","Yesterday","23:59","Newest"]) == "Newest",
          dictationTranscript(["Dictation","Today"]) == nil,
          dictationTranscript(["Dictation","11:57 PM", " "]) == nil,
          dictationTranscript(["Dictation","11:57 PM"]) == nil else { fatalError("Dictation list parsing failed") }
    let idleWithoutControls = Snapshot(observation: Observation(state: State.idle.rawValue))
    guard !startControlsReady(idleWithoutControls), !startControlsReady(Snapshot(observation: Observation(state: State.notRunning.rawValue))) else {
        fatalError("Cold start proceeded before controls were ready")
    }
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

// Navigation is validated independently of the recording state machine.
// Do not broaden recording compatibility based on a navigation-only check.
struct NavigationRequest: Codable { var action: String; var input: String }
let navigationActions = ["dictations", "meetings", "copy-latest-dictation", "search", "ask"]
func mainNodes() -> [AXUIElement] {
    guard let app = runningApp() else { return [] }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 1)
    let windows = read(root, "AXWindows") as? [AXUIElement] ?? []
    return windows.first(where: { text($0,"AXIdentifier") == "main" }).map(tree) ?? []
}
func awaitNodes(_ predicate: ([AXUIElement]) -> Bool, seconds: Double = 5) throws -> [AXUIElement] {
    let deadline = Date().addingTimeInterval(seconds)
    repeat {
        let nodes = mainNodes()
        if predicate(nodes) { return nodes }
        Thread.sleep(forTimeInterval: 0.1)
    } while Date() < deadline
    throw Failure(message: "Voicenotes controls did not become ready. Check the app before retrying.")
}
func button(_ nodes: [AXUIElement], _ name: String) -> AXUIElement? {
    unique(nodes.filter { text($0,"AXRole") == "AXButton" && label($0) == name && enabled($0) })
}
func field(_ nodes: [AXUIElement], _ placeholder: String) -> AXUIElement? {
    unique(nodes.filter { text($0,"AXRole") == "AXTextField" && text($0,"AXPlaceholderValue") == placeholder && enabled($0) })
}
func setInput(_ field: AXUIElement, _ input: String) throws {
    guard AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, input as CFString) == .success,
          text(field,"AXValue") == input else {
        throw Failure(message: "Voicenotes did not accept the text. Nothing was submitted.")
    }
}
func latestDictation(_ nodes: [AXUIElement]) -> String? {
    // In 2.4.4 the dictation list exposes direct static-text siblings in
    // newest-first order: heading, statistics, day, time, full transcript.
    let lists = nodes.filter { n in
        text(n,"AXRole") == "AXOpaqueProviderGroup" && children(n).contains {
            text($0,"AXRole") == "AXStaticText" && text($0,"AXValue") == "Dictation"
        }
    }
    guard let list = unique(lists) else { return nil }
    let values = children(list).filter { text($0,"AXRole") == "AXStaticText" }.map { text($0,"AXValue") }
    return dictationTranscript(values)
}
func dictationTranscript(_ values: [String]) -> String? {
    guard let index = values.firstIndex(where: { $0.range(of: "^\\d{1,2}:\\d{2}(?:[\\s\\u{00a0}\\u{202f}]*[AP]M)?$", options: .regularExpression) != nil }),
          index + 1 < values.count else { return nil }
    let transcript = values[index + 1]
    return transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : transcript
}
func executeNavigation(_ request: NavigationRequest) throws -> Result {
    guard navigationActions.contains(request.action) else { throw Failure(message:"Unknown navigation command") }
    let input = request.input.trimmingCharacters(in: .whitespacesAndNewlines)
    if ["search", "ask"].contains(request.action) && input.isEmpty {
        throw Failure(message: request.action == "ask" ? "Enter a prompt for Ask AI." : "Enter a search query.")
    }
    return try withLock {
        let data = try Data(contentsOf: appURL.appendingPathComponent("Contents/Info.plist"))
        let info = try PropertyListSerialization.propertyList(from:data,format:nil) as? [String:Any]
        guard info?["CFBundleIdentifier"] as? String == bundleID,
              info?["CFBundleShortVersionString"] as? String == "2.4.4" else {
            throw Failure(message:"Navigation requires the validated Voicenotes 2.4.4 app in /Applications.")
        }
        guard AXIsProcessTrusted() else { throw Failure(message:"Grant Accessibility access in Recording Setup and Status, then retry.") }
        if runningApp() == nil {
            let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/bin/open"); process.arguments = [appURL.path]
            try process.run(); process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw Failure(message:"Could not open Voicenotes.") }
        }
        if mainNodes().isEmpty, let open = snapshot().openMenu { try press(open) }
        _ = try awaitNodes({ !$0.isEmpty }, seconds:12)
        guard let app = runningApp(), app.bundleURL?.standardizedFileURL == appURL.standardizedFileURL else {
            throw Failure(message:"The running Voicenotes app is not the expected installation.")
        }
        guard snapshot().confirmation == nil else { throw Failure(message:"Complete the pending decision in Voicenotes before navigating.") }
        app.activate(options:[])
        func go(_ name: String) throws {
            var nodes = mainNodes()
            if button(nodes,name) == nil, let open = snapshot().openMenu { try press(open); nodes = mainNodes() }
            if button(nodes,name) == nil, let back = button(nodes,"Back") {
                try press(back)
                nodes = try awaitNodes { button($0,name) != nil || button($0,"Show Sidebar") != nil }
            }
            if button(nodes,name) == nil, let sidebar = button(nodes,"Show Sidebar") { try press(sidebar); nodes = mainNodes() }
            guard let target = button(nodes,name) else { throw Failure(message:"Open the Voicenotes main window and sidebar, then retry. Missing control: \(name).") }
            try press(target)
        }
        var message = ""
        switch request.action {
        case "dictations", "copy-latest-dictation":
            try go("Dictation")
            let nodes = try awaitNodes { nodes in nodes.contains { text($0,"AXRole") == "AXStaticText" && text($0,"AXValue") == "Dictation" } }
            if request.action == "copy-latest-dictation" {
                if let list = unique(nodes.filter { n in
                    text(n,"AXRole") == "AXOpaqueProviderGroup" && children(n).contains { text($0,"AXValue") == "Dictation" }
                }) {
                    var actions: CFArray?
                    AXUIElementCopyActionNames(list,&actions)
                    if (actions as? [String] ?? []).contains("AXScrollToTop") {
                        guard AXUIElementPerformAction(list,"AXScrollToTop" as CFString) == .success else {
                            throw Failure(message:"Could not reach the newest dictation. Clipboard unchanged.")
                        }
                    }
                }
                // Wait for asynchronous list loading before declaring it empty.
                let loaded: [AXUIElement]
                do { loaded = try awaitNodes { latestDictation($0) != nil } }
                catch { throw Failure(message:"No dictation is available to copy, or the list could not be read. Clipboard unchanged.") }
                guard let transcript = latestDictation(loaded) else { throw Failure(message:"No dictation is available to copy.") }
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.setString(transcript, forType:.string) else { throw Failure(message:"Could not write to the clipboard.") }
                message = "Latest dictation copied"
            } else { _ = nodes; message = "Opened Dictations" }
        case "meetings":
            try go("Meetings")
            _ = try awaitNodes { nodes in nodes.contains { text($0,"AXRole") == "AXStaticText" && text($0,"AXValue") == "Meetings" } }
            message = "Opened Meetings"
        case "search":
            try go("Search")
            let nodes = try awaitNodes { field($0,"Search") != nil }
            guard let target = field(nodes,"Search") else { throw Failure(message:"Search field unavailable.") }
            try setInput(target,input)
            message = "Search opened in Voicenotes"
        case "ask":
            try go("Home")
            var nodes = mainNodes()
            if field(nodes,"Ask anything") == nil {
                guard let ask = button(nodes,"Ask anything") else { throw Failure(message:"Ask AI control unavailable.") }
                try press(ask)
                nodes = try awaitNodes { field($0,"Ask anything") != nil }
            }
            if let draft = field(nodes,"Ask anything"), !text(draft,"AXValue").isEmpty {
                throw Failure(message:"There is an unsent prompt in Voicenotes. Send or clear it before retrying.")
            }
            // A new chat avoids accidentally adding the prompt to an existing conversation.
            if let compose = button(nodes,"Compose") { try press(compose); nodes = try awaitNodes { button($0,"New chat") != nil } }
            guard let target = field(nodes,"Ask anything") else { throw Failure(message:"Ask AI prompt field unavailable.") }
            guard text(target,"AXValue").isEmpty else { throw Failure(message:"There is an unsent prompt in Voicenotes. Send or clear it before retrying.") }
            try setInput(target,input)
            let ready = try awaitNodes { button($0,"Up") != nil }
            guard let send = button(ready,"Up"), text(send,"AXIdentifier") == "arrow.up" else {
                throw Failure(message:"Prompt entered but Send is unavailable. Check Voicenotes.")
            }
            try press(send)
            do {
                _ = try awaitNodes({ nodes in nodes.contains { text($0,"AXRole") == "AXTextArea" && text($0,"AXValue") == input } })
            } catch { throw Failure(message:"Prompt entered, but submission could not be verified. Check Voicenotes before retrying.") }
            message = "Prompt sent to Voicenotes AI"
        default: throw Failure(message:"Unknown navigation command")
        }
        return Result(ok:true,message:message,observation:Observation(state:"navigation",appVersion:"2.4.4"),dispatched:true)
    }
}

func runCommand(_ argument: String) -> String {
let result: Result
do {
    if let data = argument.data(using:.utf8), let request = try? JSONDecoder().decode(NavigationRequest.self,from:data) { result = try executeNavigation(request) }
    else if navigationActions.contains(argument) { result = try executeNavigation(NavigationRequest(action:argument,input:"")) }
    else if argument == "status" { result = Result(ok:true,message:"Voicenotes recording diagnostics",observation:snapshot().observation) }
    else if argument == "request-accessibility" {
        // Apple's exported constant is imported as a mutable C global under
        // Swift 6. Its public CFString value is immutable and documented.
        let options = ["AXTrustedCheckOptionPrompt":true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        result = Result(ok:true,message:"Grant Accessibility permission, then refresh status",observation:snapshot().observation)
    } else if let command=Command(rawValue:argument) { result = try execute(command) }
    else { throw Failure(message:"Unknown command") }
} catch { result = Result(ok:false,message:(error as? Failure)?.message ?? error.localizedDescription,observation:snapshot().observation) }
let data = try! JSONEncoder().encode(result)
return String(data:data,encoding:.utf8)!
}

#if RAYCAST_BRIDGE
@raycast func navigate(action: String, input: String) -> String {
    let data = try! JSONEncoder().encode(NavigationRequest(action:action,input:input))
    return runCommand(String(data:data,encoding:.utf8)!)
}
@raycast func control(command: String) -> String {
    runCommand(command)
}
#endif
