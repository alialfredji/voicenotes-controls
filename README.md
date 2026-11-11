# Voicenotes Controls

An unofficial Raycast extension for recording, navigation, search, and Ask AI in the Voicenotes Mac app.
No API token needed.

## Commands

- **Start Recording** — opens Voicenotes and starts recording.
- **Stop and Save Recording** — stops recording for saving and transcription.
- **Cancel Recording** — cancels recording, keeping Voicenotes’ discard confirmation.
- **Open Dictations** — opens your dictation history.
- **Open Meetings** — opens your meetings.
- **Copy Latest Dictation** — copies the newest dictation's full text.
- **Search Notes** — enter a query to open native search results.
- **Ask AI** — enter a prompt to submit it in a new Voicenotes chat.
- **Recording Setup and Status** — checks compatibility, permissions, and recording state.

## Install

Requires macOS **14+**, [Raycast](https://www.raycast.com/), Voicenotes
**2.4.2, 2.4.3, or 2.4.4**, and [Node.js](https://nodejs.org/) **22.22.2+** with npm.
**Xcode is not required** when using the release download.

1. Download **voicenotes-controls-0.2.0-macos.zip** from [Releases](https://github.com/alialfredji/voicenotes-controls/releases/latest) and unzip it.
2. Open Terminal and run:

   ```sh
   cd ~/Downloads/voicenotes-controls-0.2.0
   bash install.sh
   ```

3. Sign into Voicenotes, then run **Recording Setup and Status** in Raycast and
   grant the requested Accessibility access.
4. Set Voicenotes’ Cancel Recording shortcut to **Option+C**.

The installer includes native builds for Apple Silicon and Intel. Other
Voicenotes versions are blocked until validated. Not yet available in the
Raycast Store; updates require downloading and installing a new release.

Navigation, copying, search, and Ask AI require **Voicenotes 2.4.4** and its English UI.
They use the app's signed-in session. Search runs as the query is entered; Ask AI
submits once in a new chat. Unsent prompts are preserved. Copy reads the first
entry in the app's newest-first Dictation list; an empty or unrecognized list
leaves the clipboard unchanged.

The latest release includes all nine commands. To update an existing installation,
download the latest macOS ZIP and run its installer again.

## Planned

- Wider app-version and Cancel shortcut support.

See [TODO.md](TODO.md) for the remaining integrations and compatibility checks.

## Development

Building from source requires Xcode with Swift 6, in addition to Node.js and npm.

```sh
git clone https://github.com/alialfredji/voicenotes-controls.git
cd voicenotes-controls
npm ci
npm run dev
```

Before submitting changes, run `npm test`, `npm run typecheck`, and `npm run lint`.
Build releases with `npm run build` followed by `npm run package`.
See [compatibility notes](docs/COMPATIBILITY.md) for testing details and use
[GitHub Issues](https://github.com/alialfredji/voicenotes-controls/issues) for bugs.

## License

[MIT](LICENSE). Based on [Parzival’s Voicenotes extension](UPSTREAM.md), with
recording controls maintained by Ali Alfredji. Not affiliated with Voicenotes or Raycast.
