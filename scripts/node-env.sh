#!/bin/bash
# Source this file to select Node without changing the user's shell configuration.
node_ready() {
  command -v node >/dev/null && node -e 'const [m,n,p]=process.versions.node.split(".").map(Number);process.exit(m>22||(m===22&&(n>22||(n===22&&p>=2)))?0:1)'
}
if ! node_ready; then
  if [[ -x "$HOME/.nvm/versions/node/v24.19.0/bin/node" ]]; then
    export PATH="$HOME/.nvm/versions/node/v24.19.0/bin:$PATH"
  fi
fi
if ! node_ready; then
  echo "Node 22.22.2 or newer is required. Select it in your terminal, then rerun this script."
  exit 1
fi
