# Voicenotes Controls

An unofficial Raycast extension for recording with the official Voicenotes Mac
app. Voicenotes captures audio, transcribes, and stores your notes.

## Commands

| Command                    | Behavior                                                                                                         |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Start Recording            | Opens Voicenotes if needed, waits for usable controls, and starts capture once. An existing recording continues. |
| Stop and Save Recording    | Ends capture using the explicit Stop control. Voicenotes handles saving and transcription.                       |
| Cancel Recording           | Cancels the active capture, preserving Voicenotes’ native discard confirmation.                                  |
| Recording Setup and Status | Shows app version, observed recording state, available controls, and permission status.                          |

No API token, Obsidian integration, or separate audio recorder is needed.

## Use

1. Install and sign into the official Voicenotes app in `/Applications`.
2. Run Recording Setup and Status and grant Accessibility access if requested.
3. Run Start Recording. The same command opens the app, waits for readiness, then
   starts; you do not have to run it a second time after the app opens.
4. Speak a short phrase, then run Stop and Save Recording. Check the resulting
   note in Voicenotes after processing.
5. To discard a disposable session, run Cancel Recording and answer any native
   Yes, cancel / No, continue prompt yourself.

Keep Cancel Recording configured as **Option+C** in Voicenotes Settings → Shortcuts.
The extension verifies this setting and refuses unsupported bindings. Optional
Raycast aliases: `vn start`, `vn stop`, `vn cancel`; assign hotkeys in Raycast Settings.

## Permissions and compatibility

- **Validated app:** Voicenotes **2.4.2 / 2.4.3**, macOS only. Other app versions refuse
  capture actions until their controls have been validated.
- **Accessibility:** grant Raycast and/or VoicenotesNative the access requested by
  macOS. Diagnostics reads actual access; refresh it after making changes.
- This extension does not request Screen Recording access. Voicenotes retains its
  own microphone and system-audio permissions.
- Recording continues when Raycast closes. Start/Stop/Cancel read actual app state,
  serialize capture actions, dispatch once, and verify the observed transition.
- Collapsed recording panels and paused recordings are handled by explicit controls.
- Stop confirms capture ended. It does not claim remote saving or transcription
  has already finished. On an uncertain outcome, inspect Voicenotes before retrying.

## Search and Ask AI: planned follow-ups

Native **text search and note listing**, and a separate **Ask AI** command, are
planned in [TODO.md](TODO.md). The intended flow reuses the logged-in Mac app:
open it, wait for the correct field, enter the supplied text, and invoke its native
search or chat action. These are not part of this release.

The inherited API-based Search Notes command reported “Failed to fetch recordings”
and is excluded from this release. A local `legacy/` reference copy is retained in
the development workspace and is excluded from the source and compiled packages.
There is no token setup screen in this release.

## Install from source

Store publication requires Raycast review. For local development, use Node
**22.22.2+**, npm, and Xcode with the Swift 6 toolchain. This build was tested with
Node 24.19.0 and Xcode 27.2. End users installing an accepted Store release do not
need these development tools.

```sh
npm ci
npm run dev
```

You can stop the development process afterward; the local installation remains.
On Ali's existing Mac, the documented convenience installer also selects the
installed Node 24 runtime when needed:

```sh
rtk bash scripts/install-local.sh
```

## Build, package, and submit

```sh
npm test
npm run lint
npm run build
npm run package
```

Raycast's supported Swift package pipeline builds the reviewed native source for
arm64 and x86_64. No opaque helper executable is committed under assets. The
standalone test runner is built separately in the ignored `.native-tests` folder.

The packaging command creates clean source and compiled archives, release metadata,
and SHA-256 checksums under `releases/`. See [Store submission](docs/STORE-SUBMISSION.md)
for the exact publication steps and [test evidence](docs/COMPATIBILITY.md) for scope
and limitations. The archives are release candidates, not proof of Store acceptance.

## Recovery and removal

If diagnostics reports a native decision pending, finish that decision in
Voicenotes. If a command times out, check the app before retrying. Closing Raycast
never owns or ends a capture. After an app update or permission change, refresh
status and follow its message.

Disable/uninstall Voicenotes Controls in Raycast Settings → Extensions. Development
files, if retained, are under `~/.config/raycast/extensions/voicenotes-local`.
The optional lock is under `~/Library/Application Support/Voicenotes Raycast Local`.
Removing the extension does not remove Voicenotes recordings.

## Attribution

Based on Parzival's MIT-licensed Voicenotes extension; see [UPSTREAM.md](UPSTREAM.md)
and [LICENSE](LICENSE). Recording controls and native app automation are maintained
by Ali Alfredji. This project is not affiliated with Voicenotes or Raycast.
