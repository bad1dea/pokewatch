#!/usr/bin/env bash
# Build for the watch simulator (default) or a device.
#   Scripts/build.sh                 simulator, Debug
#   Scripts/build.sh device          device, Release (needs DEVELOPMENT_TEAM)
source "$(dirname "$0")/env.sh"
cd "$ROOT"
"$ROOT/Scripts/generate.sh"
if [[ "${1:-sim}" == "device" ]]; then
  : "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple team ID}"
  xcodebuild -project PokeWatch.xcodeproj -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=watchOS' -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build | tee "$ROOT/build/build-device.log" | grep -E "warning:|error:|BUILD" || true
else
  mkdir -p "$ROOT/build"
  xcodebuild -project PokeWatch.xcodeproj -scheme "$SCHEME" -configuration Debug \
    -destination "platform=watchOS Simulator,id=$(sim_udid)" -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build 2>&1 | tee "$ROOT/build/build-sim.log" \
    | grep -E "warning:|error:|BUILD" || true
fi
grep -q "BUILD SUCCEEDED" "$ROOT/build/build-${1:-sim}.log"
