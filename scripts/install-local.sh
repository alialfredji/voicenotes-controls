#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/node-env.sh
rtk npm ci
rtk npm run install:local
rtk open /Applications/Raycast.app
echo "Installed Voicenotes Controls. Open Raycast and run Recording Setup and Status."
