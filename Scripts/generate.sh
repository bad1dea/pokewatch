#!/usr/bin/env bash
# Regenerate PokeWatch.xcodeproj from project.yml.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
[[ -x "$XCODEGEN" ]] || { echo "XcodeGen not found. Install: brew install xcodegen (or set XCODEGEN=path)" >&2; exit 1; }
"$XCODEGEN" generate --spec project.yml --quiet
echo "Generated $ROOT/PokeWatch.xcodeproj"
