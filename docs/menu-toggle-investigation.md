# Compatibility and feasibility evidence

Historical menu-only investigation. The blocker below was superseded by the
window-button adapter; see [current validation](COMPATIBILITY.md).

Checked on 7 November 2026 on Ali's Mac.

## Identity

- Official target path: `/Applications/Voicenotes.app`
- Bundle ID: `com.voicenotes.app`; installed version: **2.4.2**
- Raycast version: **2.11.1.0**
- REA inspected Info.plist: SHA-256 `a1a307fb9c9b8018c5e282367e3ab34b37ff5847a8ce01338443f0334e98f2fb`.
- Info.plist declares the `voicenotes` URL scheme but no `NSAppleScriptEnabled`
  or `OSAScriptingDefinition` entry. This does not prove that no automation
  interface exists; no supported explicit recording URL action was established.

## Observed behavior

1. The status menu (`AXMenuBar` 2 in System Events) includes “Start recording”
   while idle and “Stop recording” during capture. The app was initially idle.
2. Pressing Start through Accessibility initiated capture and hid the main window.
   Menu state remained readable without an on-screen main window.
3. Pressing Stop ended capture after asynchronous processing. The app subsequently
   showed a new note with playback and transcript controls. This is local visible
   save evidence, not a remote-persistence guarantee or a test using a deliberate
   recognizable spoken phrase. The full saved-note acceptance test remains open.
4. During capture, a system-dialog panel exposed buttons identified as `pause.fill`
   and `stop.fill`, alongside two unlabeled buttons. No semantically identifiable
   Cancel control was established.
5. A foreground Option+C test ended a second disposable capture and the menu
   returned to Start. No confirmation was observed in this test. Absence of a saved
   note from that session was not independently established, so successful discard
   is not claimed. No shortcuts were changed.
6. Swift's Accessibility trust check returned true in this terminal. Actual
   Raycast permission inheritance was not tested.

## Decisive stale-control race

`tools/test-menu-race.swift --test-race` retains the actual AX element found by
the exact “Start recording” title, starts capture, waits for the recording menu
state and a 1.5-second startup interval, then presses the retained reference.

Observed output:

```text
initial=idle
first-press=0
after-first-press=recording
retained-start-title=Stop recording
second-press=0
after-retained-start-press=idle; UNSAFE: old Start control stopped capture
```

`0` is Accessibility's successful action-dispatch return code. The resulting menu
state, rather than that return code alone, establishes the observed transition.
An earlier immediate second press did not end capture within five seconds; an
explicit cleanup Stop then restored idle. Startup/debounce is a possible
explanation, not an established cause. The delayed test above demonstrates that
the retained control can invert the intended Start action.

**Conclusion:** this menu item is unsuitable as a reliable separate Start action.
Checking state again immediately before dispatch reduces the race window but does
not eliminate it. Locking extension processes does not serialize manual app actions.
The plan explicitly treats an unresolved race that can invert capture as a blocker.

## Validation boundaries

The standalone Swift probes compiled and ran. No production controller, extension,
or keyboard adapter was shipped, and no dependencies were installed. No existing
recording was interrupted: captures were started only after idle was observed.
Test-created notes were retained; unrelated notes were not deleted.

Not exercised: end-to-end commands through Raycast, missing-permission paths,
app restart, minimized windows, offline saving/reconnection, concurrent extension
commands, pause/finalizing semantics, search API regression, or remote save/discard
verification. Hidden main-window menu inspection was observed, but does not by
itself validate the complete hidden/minimized acceptance case.

## Sources

- The original workspace plan defined the safety gate; it is not required to install this package.
- [Voicenotes Mac guide](https://help.voicenotes.com/en/articles/11161004-how-to-use-voicenotes-on-mac): documents a shared Start/Stop shortcut and Cancel shortcut; does not establish atomic separate actions.
- [Raycast setup](https://developers.raycast.com/basics/getting-started): Node 22.14+ and local extension-development prerequisites.

These documentation pages were checked during this run. No private account
sessions or API tokens were inspected or copied.
