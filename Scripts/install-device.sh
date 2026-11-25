#!/usr/bin/env bash
# Build signed and install on a paired Apple Watch (developer mode on, paired iPhone/Mac trusted).
#   DEVELOPMENT_TEAM=XXXXXXXXXX Scripts/install-device.sh [device-udid]
# The watch must be visible to `xcrun devicectl list devices`.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple team ID}"
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/Watch/ && /available|connected/ {print $(NF-2); exit}')
fi
[[ -n "$DEVICE" ]] || { echo "No Apple Watch found. See Documentation/INSTALL.md." >&2; exit 1; }
"$ROOT/Scripts/build.sh" device
xcrun devicectl device install app --device "$DEVICE" "$DERIVED/Build/Products/Release-watchos/PokeWatch.app"
echo "Installed on $DEVICE"
