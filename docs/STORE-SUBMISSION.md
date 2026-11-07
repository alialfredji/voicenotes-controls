# Raycast Store submission

## Release scope

Four macOS recording commands: Start, Stop and Save, Cancel, and Setup/Status.
Native text search/listing and Ask AI are deferred in TODO.md. No token is needed.
The package is `voicenotes-local`, titled **Voicenotes Controls**, owned by the
verified Raycast account **alialfredji**, with Parzival retained in attribution.

## Build and inspect the candidate

From the project directory, with Node 22.22.2+ and Xcode's Swift 6 toolchain:

```sh
npm ci
npm test
npm run lint
npm run build
npm run package
```

The native controller is built through the official Raycast Swift package plugins,
not uploaded as an unexplained executable asset. Package.resolved and
package-lock.json pin dependencies. The distribution build includes both native
architectures; physical Intel and clean-account validation remain listed in TODO.md.

Inspect the source and compiled ZIPs, SHA256SUMS, and RELEASE.json in `releases/`.
The `-macos.zip` archive includes an installer, JavaScript entry points, and the
prebuilt native module. Users run `bash install.sh` with Node/npm installed;
Xcode is only needed when building native code from source. Public Raycast
2.11.1 rejects `.rayext` imports as internal-build-only, so that format is not
used for the downloadable installer.

The source ZIP excludes node_modules, local build caches, credentials, old search
code, and Git metadata. The compiled ZIP contains the Raycast distribution build;
it is not a Store installation link or an npm package to publish.

## Submit to Raycast

```sh
bash scripts/submit-store.sh
```

The script selects a supported Node runtime, validates and builds, then runs
`npm run publish`. Raycast's CLI asks for GitHub authentication when needed and opens a pull request
in `raycast/extensions`. Use docs/STORE-PR.md as the PR description. Review the
public diff, title, screenshots, and license before completing submission. This
project has not automatically sent a public PR or published anything.

Raycast/community reviewers may request changes. After acceptance and merge, the
Store build publishes automatically. This is a review process, not immediate
one-click deployment. Re-running publish can update the same submission.

A separate focused controls extension is proposed because this release has native
recording controls and different setup from the original API search extension.
Reviewers may prefer an upstream contribution; significant upstream changes require
that extension author's sign-off. Do not submit under Parzival's author identity.

## Review points

- Native state is always observed; remembered flags and menu toggles are not used.
- Stop and Cancel while closed/idle do not launch or start capture.
- Start opens the app, waits for real controls, then performs one Start action.
- Cancel uses only the verified configured Option+C binding and keeps native prompts.
- Only Voicenotes 2.4.2 / 2.4.3 is enabled; other releases require validation.
- Only recording state/control metadata is exposed; no note content, sessions,
  microphone data, or account secrets are read by this release.
- Screenshots must show the current extension UI and contain no private notes.
- Check TODO.md and compatibility evidence for tests not yet exercised.

## Official references (checked 7 November 2026)

- https://developers.raycast.com/basics/prepare-an-extension-for-store
- https://developers.raycast.com/basics/publish-an-extension
- https://github.com/raycast/extensions-swift-tools
- https://github.com/raycast/extensions/blob/main/.github/workflows/extensions_build_publish.yml
