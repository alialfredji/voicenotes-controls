## Summary

Add Voicenotes Controls: Start Recording, Stop and Save Recording, Cancel Recording,
and Recording Setup and Status for the official Voicenotes Mac app.

Start opens the app when closed, waits for usable controls, and starts recording
once. Repeated Start leaves capture running; Stop and Cancel cannot start capture.
The controller observes Accessibility state, serializes commands, and uses explicit
Start/Stop buttons. Cancel preserves Voicenotes' native discard confirmation.

## Native implementation and compatibility

The reviewed Swift source is built using the official Raycast Swift package
plugins, for arm64 and x86_64. The supported app is Voicenotes 2.4.2 / 2.4.3. Setup requires
Accessibility permission and the verified Option+C Cancel binding. This extension
does not capture audio, extract sessions, or request Screen Recording permission.

The source derives from Parzival's MIT-licensed Voicenotes search extension with
retained attribution. Legacy API search is archived and excluded from this release.
Native app search/listing and Ask AI are documented follow-ups rather than token-based
commands in this submission.

## Validation

See docs/COMPATIBILITY.md and TODO.md for the precise live checks and limitations.
Store acceptance and clean-account/physical Intel compatibility are not assumed.
