#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

./scripts/rebuild-local-stack.sh
./scripts/live-check.sh

echo "INTEGRATION_OK"
