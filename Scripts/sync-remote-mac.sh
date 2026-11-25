#!/usr/bin/env bash
# For editing on another machine and building on a Mac over SSH: push the tree and run a script there.
#   BUILD_HOST=my-mac Scripts/sync-remote-mac.sh Scripts/test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${BUILD_HOST:?Set BUILD_HOST to the Mac's SSH host}"
REMOTE="${BUILD_DIR:-pokewatch}"
rsync -a --delete --exclude .git --exclude build --exclude PokeWatch.xcodeproj --exclude Documentation/Screenshots \
  "$ROOT/" "$HOST:$REMOTE/"
if [[ $# -gt 0 ]]; then ssh "$HOST" "cd $REMOTE && $*"; fi
