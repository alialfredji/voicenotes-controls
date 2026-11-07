#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/node-env.sh
echo "Submitting a public pull request for Raycast Store review."
echo "See docs/STORE-SUBMISSION.md and docs/STORE-PR.md for submission details."
npm run lint
npm run build
npm run publish
