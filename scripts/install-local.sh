#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node_ready() {
  command -v node >/dev/null && node -e 'const [m,n]=process.versions.node.split(".").map(Number);process.exit(m>22||(m===22&&n>=14)?0:1)'
}
if ! node_ready; then
  if [[ -x "$HOME/.nvm/versions/node/v24.19.0/bin/node" ]]; then
    export PATH="$HOME/.nvm/versions/node/v24.19.0/bin:$PATH"
  fi
fi
if ! node_ready; then
  echo "Node 22.14 or newer is required. Select it in your terminal, then rerun this script."
  exit 1
fi
rtk npm ci
rtk npm run install:local
rtk open /Applications/Raycast.app
echo "Installed Voicenotes Local. Open Raycast and run Recording Setup and Status."
