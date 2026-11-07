#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .native-tests
xcrun swiftc -O native/VoicenotesControl.swift tools/NativeTestMain.swift -o .native-tests/voicenotes-control
codesign --force --sign - --identifier com.alialfredji.raycast.voicenotes-control .native-tests/voicenotes-control
