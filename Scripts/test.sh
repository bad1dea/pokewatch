#!/usr/bin/env bash
# Run the unit tests on the watch simulator.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
"$ROOT/Scripts/generate.sh"
mkdir -p "$ROOT/build"
rm -rf "$ROOT/build/Tests.xcresult"
xcodebuild -project PokeWatch.xcodeproj -scheme "$SCHEME" \
  -destination "platform=watchOS Simulator,id=$(sim_udid)" -derivedDataPath "$DERIVED" \
  -resultBundlePath "$ROOT/build/Tests.xcresult" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test 2>&1 | tee "$ROOT/build/test.log" \
  | grep -E "error:|failed|passed|Executed|TEST (SUCCEEDED|FAILED)" || true
grep -q "TEST SUCCEEDED" "$ROOT/build/test.log"
