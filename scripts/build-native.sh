#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets
xcrun swiftc -O native/VoicenotesControl.swift -o assets/voicenotes-control
codesign --force --sign - --identifier com.alialfredji.raycast.voicenotes-control assets/voicenotes-control
