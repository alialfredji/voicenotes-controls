# Follow-up integrations

The shipping release controls recording. Legacy API search is archived in
`legacy/` and is not exposed as a command. It reported “Failed to fetch recordings”
on Ali's account. No token setup is required by this release.

## Native navigation, search, and Ask AI

- [x] Open Dictations and Meetings using semantic Accessibility controls.
- [x] Copy the full text of the newest dictation without an API token.
- [x] Search Notes accepts a query and opens native results.
- [x] Ask AI accepts a prompt, opens a new chat, submits once, and verifies the message.
- [x] Verify native search results and an AI response on Voicenotes 2.4.4.
- [ ] Validate offline, empty-account, non-English UI, and active-recording navigation on a separate account.
- [ ] Validate these navigation controls on versions other than 2.4.4.

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
