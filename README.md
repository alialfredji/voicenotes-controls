# Voicenotes Local for Raycast

Installed locally on Ali's Mac and tested with **Voicenotes 2.4.2** and
**Raycast 2.11.1.0**. Open Raycast and choose commands under **Voicenotes Local**.
No terminal process needs to remain running.

## Try it

1. Run **Recording Setup and Status**. Accessibility and event posting should say Granted.
2. Run **Start Recording**, speak a short recognizable phrase, and continue using other apps.
3. Run Start again: the existing recording should continue.
4. Run **Stop and Save Recording**. Check the new entry in Voicenotes after processing.
5. Start another disposable session and run **Cancel Recording**. If Voicenotes asks
   “Are you sure you want to cancel this recording?”, select **Yes, cancel** or
   **No, continue** yourself. The extension leaves this native decision intact.
6. Stop or Cancel while idle: no new recording should start.

Stop confirms capture ended; Voicenotes owns saving, transcription, and remote
persistence. The command never claims that remote saving is complete.

Optional aliases/hotkeys can be added in Raycast Settings → Extensions → Voicenotes
Local. Suggested aliases: `vn start`, `vn stop`, `vn cancel`. No existing hotkeys
were changed.

## Setup and compatibility

- Install and sign into the official `/Applications/Voicenotes.app`.
- Grant Raycast/native-helper Accessibility permission if diagnostics requests it.
  Use the diagnostic command's Request Accessibility Access or Open Accessibility
  Settings actions, grant the indicated process access, and refresh.
- Keep Voicenotes Settings → Shortcuts → Cancel Recording set to **Option+C**.
  The helper checks the actual setting and refuses to send keys if it differs.
- This adapter is deliberately limited to **2.4.2**. After an app update, diagnostics
  refuses recording mutations until the new version's controls have been validated.
- The extension itself does not need Screen Recording permission. Voicenotes owns
  its microphone/system-audio permissions.
- Commands handle the collapsed recording panel automatically. Start can return
  from a note detail to Home. Ambiguous controls, dialogs, processing, missing
  permissions, and timeouts produce an error instead of a blind toggle.

## Reinstall or rebuild

Source: `/Users/alialfredji/dev/vibe-code/raycast-voicenotes`.
Installed files: `~/.config/raycast/extensions/voicenotes-local`.

Requires Apple's command-line Swift tools, RTK, and Node **22.14+**. This Mac's
Node 24 installation is selected automatically by the setup script if needed.

```sh
cd /Users/alialfredji/dev/vibe-code/raycast-voicenotes
rtk bash scripts/install-local.sh
```

This runs `npm ci`, compiles/ad-hoc signs the helper, and uses Raycast's local
development build installation. It does not publish to the Store. The installed
commands survived a Raycast restart with the development watcher stopped.
For source changes use `rtk npm run dev` with Node 22.14+, or rerun the setup script.
An app/OS restart needs no watcher; open Voicenotes/Raycast normally, or let Start
launch Voicenotes. A complete machine reboot was not exercised.

## Optional note search

**Search Notes** retains Parzival's title search, tag filter, transcript preview,
copying, and browser links. Only that command requests a Voicenotes API token from
Settings → Integrations → Obsidian. Recording and diagnostics need no token.
Existing credentials were not read or copied. Authenticated search was not tested
without a user-entered token. Full transcript-text matching is not promised.
The original Store extension remains available and unchanged if already installed;
the fork's distinct **Voicenotes Local** title separates them.

## Validation and implementation

See [compatibility and test evidence](docs/COMPATIBILITY.md) and [upstream attribution](UPSTREAM.md).
The extension and upstream code are MIT licensed; see [LICENSE](LICENSE).

The helper uses a Start-only window button, the recording panel's explicit Stop
button, and the verified Cancel-only hotkey. It reads fresh app state and serializes
mutations with a kernel-owned file lock. Process death releases the lock; leftover
lock-file contents are never recording truth. It sends each capture action once,
checks the outcome, and never retries a toggle. The mutable menu toggle is not used.

```sh
rtk npm test
rtk npm run typecheck
rtk npm run lint
rtk npm run build
```

The last command produces a standalone compiled extension in `dist/`. Tests never
need account credentials. Live test utilities under `tools/` can create disposable
recordings; read them before running. `inspect-accessibility.swift` is read-only.

## Recovery and removal

On an uncertain result, inspect Voicenotes before retrying. No recording is owned
by the extension process, so closing Raycast does not stop capture. If a native
decision is pending, finish it in Voicenotes. After rebuilding, macOS may require
renewed Accessibility access; diagnostics reports the actual permission state.

To remove: disable/uninstall **Voicenotes Local** in Raycast Settings → Extensions.
If its development files remain, remove only
`~/.config/raycast/extensions/voicenotes-local` while Raycast is closed. Optional
cleanup: remove this source directory and
`~/Library/Application Support/Voicenotes Raycast Local` (contains only the lock).
Voicenotes recordings and the original search extension are separate. Test-created
saved notes were retained so you can inspect them; no unrelated notes were deleted.
