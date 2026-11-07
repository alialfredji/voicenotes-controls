# Follow-up integrations

The shipping release controls recording. Legacy API search is archived in
`legacy/` and is not exposed as a command. It reported “Failed to fetch recordings”
on Ali's account. No token setup is required by this release.

## Native text search and listing

- [ ] Inspect the existing Voicenotes app's native Search control and result states.
- [ ] Add a Raycast command accepting a text query: open Voicenotes, wait for its
      search controls, place the query in the verified field, and run native search.
- [ ] With no query, open the app's note list so users can browse all notes.
- [ ] Verify title/transcript matching and filtering behavior before promising it.
- [ ] Keep active recordings and native confirmations intact; never type into a
      previously focused app or guess undocumented URL actions.
- [ ] Reuse the app's existing authenticated session through its UI. Do not extract
      its sessions, require an Obsidian token, or add an external search backend.

## Native Ask AI

- [ ] Inspect “Ask anything” / “Ask AI” controls and their actual submit action.
- [ ] Add a separate Raycast command accepting a question, opening the app, waiting
      for the correct chat field, entering that question, and submitting once.
- [ ] Decide and document whether the command opens chat or submits immediately;
      an empty question should open chat without inventing or submitting content.
- [ ] Verify the entered question and response in the existing app, including
      hidden windows and an already active recording.

## Wider compatibility

- [ ] Investigate near-immediate Stop during native capture startup; the app once
      ignored its enabled Stop action. Preserve honest uncertainty and avoid replaying toggles.

- [ ] Test another clean Mac/account, including first-run Accessibility permission.
- [ ] Validate on physical Intel hardware; the native module is compiled for both
      arm64 and x86_64, but cross-compilation is not an Intel runtime test.
- [ ] Validate future Voicenotes versions before extending the version allowlist.
- [ ] Support configured Cancel shortcuts beyond the verified Option+C binding.
- [ ] Exercise offline save/reconnection and a complete machine reboot.

## Upstream SDK maintenance

- [ ] Track audit findings in Raycast SDK 2.11.1 CLI/debugger dependencies; assess
      upstream fixes before a public release rather than force-downgrading the SDK.
