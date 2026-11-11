# Navigation and AI additions — 12 November 2026

Released in v0.2.0 with all nine commands and a prebuilt macOS installer.

- Installed official app: `com.voicenotes.app`, 2.4.4 (107). REA plist evidence:
  `ev_604ece7366c1ede6e38861d5218b1c1bfd75fc64debd72148646af7dd20ce506`.
  Its plist registers `voicenotes:` but does not document navigation URL paths;
  this implementation uses observed Accessibility controls instead of guessing URLs.
- Native live checks opened Dictation and Meetings, copied full dictation text,
  and entered a search query. Rendered results included matching titles/transcripts.
- Ask AI: setting the field and performing AXConfirm did not submit. The verified
  Up button (`arrow.up`) submits; the helper then checks for the exact prompt in chat.
  Live AI responses were observed. Responses themselves may take longer than submission.
- Start after Ask AI now closes only the verified chat panel. Start and a subsequent
  Stop returned recording and idle observations on 2.4.4. Near-immediate Stop once
  returned uncertainty while recording continued; a fresh status and Stop ended it.
  No automatic action replay was added. The test created a short “New note”.
- Navigation is serialized with recording commands, preserves pending dialogs and
  unsent prompts, and uses app-scoped text fields without clipboard pasting.
- New navigation actions are gated to 2.4.4. English control labels, newest-first
  dictation list order, and full AX transcript text are version-specific assumptions.
- Empty-list parsing and recording state-machine invariants have standalone checks.
  Physical Intel, offline, empty-account and navigation during capture are untested.

- Final local install, TypeScript check, and Raycast lint passed. The actual Raycast
  Open Meetings command opened the Meetings page. Ask AI invoked through Raycast
  displayed the exact submitted prompt and an AI reply.
- A manual history-scroll stress probe made Voicenotes unresponsive (high CPU);
  the app was restarted after confirming the test recording had ended. Copy Latest
  Dictation passed again in the fresh session. Navigation has a 45-second UI timeout
  with no automatic replay. Deep-history scrolling remains an app-side uncertainty.

The following sections are historical validation records.

---

## Current Swift-bridge checks on Voicenotes 2.4.3

- The app updated from 2.4.2 to 2.4.3 during packaging; the allowlist initially
  refused it. The signed app and current controls were inspected before validation.
- A single standalone cold Start opened the closed app, awaited usable controls,
  and entered recording in 2.74 seconds. Stop/Cancel while closed did not launch it.
- Through the actual Raycast/Swift bridge, Start opened the closed app and capture
  was independently observed. The recording status screenshot shows 2.4.3,
  recording, and granted permissions. Raycast Stop subsequently returned the app
  to idle. UI automation post-action errors were not treated as definitive failures
  or successes; the real app state was inspected without replaying an uncertain action.
- A final actual Raycast Start and Cancel sequence on 2.4.3 passed; the app returned
  to idle. There is no search token setup or Search Notes entry in the four-command
  manifest. Both screenshots contain only current diagnostic UI, with no note content.
- A synthetic near-immediate Stop after cold Start once returned uncertainty while
  capture continued; a later fresh Stop ended it. The controller did not claim a
  save or resend a toggle. Very-rapid startup/Stop timing remains a known review item.
- The production build, TypeScript check, native invariants, metadata validation,
  and lint passed. The distribution's native module is universal arm64/x86_64;
  physical Intel/clean-account runtime validation remains deferred.

# Current release candidate: Voicenotes Controls

The current release has four recording/setup commands. Legacy token-based Search
Notes is archived under legacy/ and excluded from the manifest. Native text
search/listing and Ask AI are follow-ups in TODO.md, as requested on 7 November 2026.

The native controller is now built using Raycast official Swift package plugins
from native/Package.swift, for arm64 and x86_64. The standalone CLI under
.native-tests is used only for focused local tests and is not a shipping asset.
The installed app signatures were checked: Voicenotes carries a stapled Developer
ID signature from Coping Hard Inc.; Raycast carries a stapled Developer ID signature
from Raycast Technologies Inc. No application bundles were modified.

Cold-start handling now waits up to 12 seconds for usable app/navigation controls,
then continues the same Start command. Navigation transitions are polled before
selecting the Start-only control. Seeing a process or menu alone is insufficient.

The current pinned Raycast SDK is 2.11.1. npm audit of its production dependency
graph reports 14 findings (9 moderate, 5 high), primarily in the SDK CLI/debugger
toolchain (oclif, react-devtools/Electron and their dependencies). The extension
imports the host-provided Raycast API and its own generated Swift bridge; these
findings have not been demonstrated as reachable from the recording controller.
They remain unresolved upstream dependency findings, not a clean-audit claim.

The evidence below describes the original local implementation. Its historical
five-command/search and standalone-helper details are superseded by this release.
See STORE-SUBMISSION.md for packaging and submission, and TODO.md for untested cases.

---

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

| Action/state       | Actual selector and behavior                                                                                                                                                                                                                                                                           |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Start              | In the main window (`AXIdentifier=main`), find the unique unlabeled button sharing a parent with `mic` and the attributed label `Ask anything`. Press its AX action. No coordinates, button indexes, or menu-toggle actions. The retained button was pressed again during capture and did not stop it. |
| Stop               | Recording panel `AXButton`, `AXIdentifier=stop.fill`, attributed label `Stop`. If collapsed, press the attributed-label `Expand recording panel` button first, then reacquire Stop.                                                                                                                    |
| Active             | Status menu says `Stop recording`, accompanied by Pause/Stop controls or the collapsed-panel Expand control.                                                                                                                                                                                           |
| Paused             | Status menu says `Stop recording`; panel exposes `stop.fill` / `Stop` and `play.fill` / `Play`. Play was observed after a manual Pause action.                                                                                                                                                         |
| Idle               | Exactly one `Start recording` menu item and no active Stop controls.                                                                                                                                                                                                                                   |
| Cancel             | Read only `mac_shortcut_settings_v2`'s `cancel_recording` entry; require exactly ALT+C. Focus the actual Voicenotes process, recheck active capture, then post one complete Option+C key pair globally. Target-process-only posting was tested and did not trigger the global shortcut.                |
| Confirmation       | Recognize native `AXDialog` / sheet, including Voicenotes' Yes, cancel / No, continue alert; surface it and send no further capture action.                                                                                                                                                            |
| Processing/unknown | Inconsistent or missing controls refuse mutation. A menu state by itself is insufficient for dispatch.                                                                                                                                                                                                 |

The app exposes no authoritative recording-session identifier through the
inspected controls. The extension never invents one or persists a recording Boolean.
Its independently observed controls and state are reacquired under a native
cross-process lock. The Start/Stop actions are explicit, so a stale action cannot
invert into the opposite command as the menu toggle did. No broad guarantee
against all possible manual replacement of sessions is made.

## Live checks

| Check                             | Evidence/result                                                                                                                                                                                                                                                                                                                                    |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Raycast installation              | Five compiled entry points and the native helper installed in `~/.config/raycast/extensions/voicenotes-local`; commands launched from Raycast's own Run Command UI.                                                                                                                                                                                |
| Actual Raycast permissions        | Recording Setup and Status displayed idle, version 2.4.2, Accessibility Granted, Event posting Granted, and Start/Cancel available. Rechecked after restart.                                                                                                                                                                                       |
| Start from idle                   | Raycast Start produced active Pause/Stop controls.                                                                                                                                                                                                                                                                                                 |
| Repeated Start                    | Raycast Start during capture left it recording. Four simultaneous native Start processes produced exactly one `dispatched:true` and three `Already recording; capture continues`, all successful.                                                                                                                                                  |
| Stop/save                         | Raycast Stop ended capture; the resulting note had playback and transcript controls, title `Raycast second save test note`, and transcript containing `Raycast Second Save Test`. This is observed in-app save evidence; the command itself reports only capture termination/processing.                                                           |
| Stop idle                         | Repeated Raycast Stop left the app idle; native no-action result also confirmed no dispatch.                                                                                                                                                                                                                                                       |
| Cancel active                     | Raycast Cancel opened Voicenotes' native `Are you sure you want to cancel this recording?` prompt for the longer disposable session. The test selected Yes, cancel. Capture ended; the previously saved second-save test note remained the newest visible entry and no cancellation-test entry appeared in the visible recent list after settling. |
| Pending confirmation              | Native Cancel returned `confirmation-pending`, `dispatched:false`, and `Complete the pending decision in Voicenotes`; existing native prompt remained. No extra discard prompt was created.                                                                                                                                                        |
| Cancel idle                       | Raycast Cancel left the app idle. No saved notes were deleted.                                                                                                                                                                                                                                                                                     |
| Raycast closed/hidden main window | Capture remained active with no Raycast windows. The automatically collapsed Voicenotes panel remained observable and Stop expanded it automatically.                                                                                                                                                                                              |
| Manual app controls               | The manual Pause AX action changed the panel from Pause to Play; helper reported `paused`. Raycast Stop then ended capture. Direct Start/Stop probe actions were observed by fresh subsequent snapshots.                                                                                                                                           |
| Raycast restart                   | Old Raycast PID 92660 exited, new PID 66266 launched; Voicenotes capture continued. Raycast Stop worked after restart. The development watcher had been stopped.                                                                                                                                                                                   |
| App not running                   | After native Quit completely / Quit confirmation, Stop and Cancel each returned `not-running`, `dispatched:false`, and did not launch the app. Raycast Start then launched Voicenotes and entered recording.                                                                                                                                       |
| Lock timeout                      | Holding the actual lock from another process caused a bounded refusal without dispatch.                                                                                                                                                                                                                                                            |
| Owner death                       | Killing a process holding the actual lock released it; another process acquired the same file lock without stale-file deletion.                                                                                                                                                                                                                    |
| Search preference isolation       | Launching Search Notes showed only its API-token setup form. Diagnostics and recording ran without filling that form. Original search implementation and actions were retained.                                                                                                                                                                    |

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
- The documented `scripts/install-local.sh` completed successfully, including
  automatic selection of the installed Node 24 runtime and a clean `npm ci`.
  The installed helper's SHA-256 matched the source build, and the installed
  manifest contained five commands with credentials required only by Search.
- Final Cancel focus validation uses fresh target-process `AXFrontmost`, not
  `NSWorkspace.frontmostApplication`, which proved stale in the short-lived
  helper. After this correction, a final disposable Start → Cancel test returned
  `ok:true`, `dispatched:true`, `state:idle`, and `Recording cancelled in Voicenotes`.

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
- The original workspace plan is not required to install this package.

All test recordings were disposable and created after idle was observed. Saved
test notes were retained for inspection. No unrelated notes, tokens, sessions,
shortcuts, original extension settings, or Voicenotes application files were changed.
