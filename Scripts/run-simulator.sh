#!/usr/bin/env bash
# Build, install and launch in the Apple Watch Ultra 3 simulator.
# Extra arguments are passed to the app, e.g.:  Scripts/run-simulator.sh --demo --face analog
source "$(dirname "$0")/env.sh"
cd "$ROOT"
"$ROOT/Scripts/build.sh"
UDID=$(sim_udid)
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-watchsimulator/PokeWatch.app"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@"
