#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-4174}"

cd "$ROOT_DIR"

echo "NFT policy playground running at: http://127.0.0.1:${PORT}/playground/"
python3 -m http.server "$PORT"
