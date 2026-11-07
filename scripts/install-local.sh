#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/node-env.sh
npm ci
npm run install:local
open /Applications/Raycast.app
echo "Installed Voicenotes Controls. Open Raycast and run Recording Setup and Status."
