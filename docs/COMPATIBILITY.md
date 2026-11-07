# Compatibility and validation

Validated locally on **7 November 2026** against `/Applications/Voicenotes.app`,
bundle ID `com.voicenotes.app`, **2.4.2**, and Raycast **2.11.1.0**. Built with the
Mac's Node **24.19.0** and Apple Swift tools. No public distribution was performed.

## Outcome and adapter

Start, Stop and Save, Cancel, Search Notes, and Recording Setup and Status are
installed as **Voicenotes Local**. Raycast diagnostics ran with actual helper
permissions and displayed Accessibility Granted / Event posting Granted.
Recording commands were exercised without configuring any search token.

The earlier menu-only blocker was resolved by using different controls. The
[menu-toggle investigation](menu-toggle-investigation.md) remains historical
evidence of why the menu item is never pressed by the production controller.

| Action/state | Actual selector and behavior |
| --- | --- |
| Start | In the main window (`AXIdentifier=main`), find the unique unlabeled button sharing a parent with `mic` and the attributed label `Ask anything`. Press its AX action. No coordinates, button indexes, or menu-toggle actions. The retained button was pressed again during capture and did not stop it. |
| Stop | Recording panel `AXButton`, `AXIdentifier=stop.fill`, attributed label `Stop`. If collapsed, press the attributed-label `Expand recording panel` button first, then reacquire Stop. |
| Active | Status menu says `Stop recording`, accompanied by Pause/Stop controls or the collapsed-panel Expand control. |
| Paused | Status menu says `Stop recording`; panel exposes `stop.fill` / `Stop` and `play.fill` / `Play`. Play was observed after a manual Pause action. |
| Idle | Exactly one `Start recording` menu item and no active Stop controls. |
| Cancel | Read only `mac_shortcut_settings_v2`'s `cancel_recording` entry; require exactly ALT+C. Focus the actual Voicenotes process, recheck active capture, then post one complete Option+C key pair globally. Target-process-only posting was tested and did not trigger the global shortcut. |
| Confirmation | Recognize native `AXDialog` / sheet, including Voicenotes' Yes, cancel / No, continue alert; surface it and send no further capture action. |
| Processing/unknown | Inconsistent or missing controls refuse mutation. A menu state by itself is insufficient for dispatch. |

The app exposes no authoritative recording-session identifier through the
inspected controls. The extension never invents one or persists a recording Boolean.
Its independently observed controls and state are reacquired under a native
cross-process lock. The Start/Stop actions are explicit, so a stale action cannot
invert into the opposite command as the menu toggle did. No broad guarantee
against all possible manual replacement of sessions is made.

## Live checks

| Check | Evidence/result |
| --- | --- |
| Raycast installation | Five compiled entry points and the native helper installed in `~/.config/raycast/extensions/voicenotes-local`; commands launched from Raycast's own Run Command UI. |
| Actual Raycast permissions | Recording Setup and Status displayed idle, version 2.4.2, Accessibility Granted, Event posting Granted, and Start/Cancel available. Rechecked after restart. |
| Start from idle | Raycast Start produced active Pause/Stop controls. |
| Repeated Start | Raycast Start during capture left it recording. Four simultaneous native Start processes produced exactly one `dispatched:true` and three `Already recording; capture continues`, all successful. |
| Stop/save | Raycast Stop ended capture; the resulting note had playback and transcript controls, title `Raycast second save test note`, and transcript containing `Raycast Second Save Test`. This is observed in-app save evidence; the command itself reports only capture termination/processing. |
| Stop idle | Repeated Raycast Stop left the app idle; native no-action result also confirmed no dispatch. |
| Cancel active | Raycast Cancel opened Voicenotes' native `Are you sure you want to cancel this recording?` prompt for the longer disposable session. The test selected Yes, cancel. Capture ended; the previously saved second-save test note remained the newest visible entry and no cancellation-test entry appeared in the visible recent list after settling. |
| Pending confirmation | Native Cancel returned `confirmation-pending`, `dispatched:false`, and `Complete the pending decision in Voicenotes`; existing native prompt remained. No extra discard prompt was created. |
| Cancel idle | Raycast Cancel left the app idle. No saved notes were deleted. |
| Raycast closed/hidden main window | Capture remained active with no Raycast windows. The automatically collapsed Voicenotes panel remained observable and Stop expanded it automatically. |
| Manual app controls | The manual Pause AX action changed the panel from Pause to Play; helper reported `paused`. Raycast Stop then ended capture. Direct Start/Stop probe actions were observed by fresh subsequent snapshots. |
| Raycast restart | Old Raycast PID 92660 exited, new PID 66266 launched; Voicenotes capture continued. Raycast Stop worked after restart. The development watcher had been stopped. |
| App not running | After native Quit completely / Quit confirmation, Stop and Cancel each returned `not-running`, `dispatched:false`, and did not launch the app. Raycast Start then launched Voicenotes and entered recording. |
| Lock timeout | Holding the actual lock from another process caused a bounded refusal without dispatch. |
| Owner death | Killing a process holding the actual lock released it; another process acquired the same file lock without stale-file deletion. |
| Search preference isolation | Launching Search Notes showed only its API-token setup form. Diagnostics and recording ran without filling that form. Original search implementation and actions were retained. |

The live test utility acknowledges only the named local command's one-shot URL
prompt. An accepted UI action alone was not treated as proof; app state and saved
note UI were inspected independently. Some automation attempts encountered stale
or background-window errors and were followed by fresh inspection. They are not
counted as successful tests merely because the URL was opened.

## Code/build checks

- Swift helper compiled and ad-hoc signed with a stable identifier.
- `--self-test` passed repeated-command sequences, unknown/busy refusal, app-startup
  rules, and paused-session dispatch invariants. It does not control the real app.
- `npm run typecheck`, `npm run lint`, and production build passed.
- A lockfile pins the existing upstream dependency family. A compatible audit fix
  removed the initial high finding. Production dependency audit: **0 findings**.
  Full audit still reports **9 moderate development-tool findings** through the
  lint toolchain's minimatch dependency; no forced breaking downgrade was applied.
- Raycast copies assets as 0644. The wrapper restores executable mode only on its
  own helper before launching it. This was tested under Raycast, not assumed from
  a developer-terminal permission grant.

## Boundaries and unexercised cases

- Only Voicenotes **2.4.2** is enabled. Updates fail closed until validated.
- Cancel requires the inspected **Option+C** configuration. Other bindings are not
  guessed or changed.
- Saving and cancellation were verified in the app's visible UI, not by reading
  account sessions or proving server-side persistence/deletion.
- Authenticated Search Notes fetching, title/tag matching, copy, browser links,
  and transcript preview have not been exercised against this account because no
  user-entered search token was provided. Their upstream code is preserved and
  typechecked; this is not a live API-compatibility claim.
- Offline stop/reconnection, live denial/revocation of permissions, missing-app
  removal, a real app-version update, a complete Mac reboot, and a minimized
  main-window case were not exercised. Hidden/collapsed windows and Raycast
  restart were tested. Busy/unknown states are covered by refusal invariants;
  this does not simulate every provider/OS failure.
- A native confirmation ends the short-lived Raycast command with a pending
  message; it does not wait indefinitely or automatically confirm the decision.
- The helper never requests Screen Recording access. Voicenotes retains its own
  capture permissions and ownership of audio, transcription, and storage.

## Source and investigation record

[Upstream](../UPSTREAM.md): raycast/extensions commit
`4b4930b655cfcfac3e47af94d2f41acbfc9a9225`, extension author Parzival, MIT license.
The source extension and applicable repository license were fetched without
cloning unrelated extension implementations.

The package declares the `voicenotes` URL scheme; no supported explicit recording
URL actions or Shortcuts metadata were established. No URL path was guessed.
REA native analysis did not establish additional callable actions because its
Hopper bridge startup timed out. Runtime Accessibility observations, rather than
native pseudocode, justify the implemented adapter. The analysis document was
closed; no app bundle modification or process injection was used.

- [Voicenotes Mac guide](https://help.voicenotes.com/en/articles/11161004-how-to-use-voicenotes-on-mac)
- [Raycast setup](https://developers.raycast.com/basics/getting-started)
- [Original plan](../../raycast-voicenotes-integration-plan.md)

All test recordings were disposable and created after idle was observed. Saved
test notes were retained for inspection. No unrelated notes, tokens, sessions,
shortcuts, original extension settings, or Voicenotes application files were changed.
