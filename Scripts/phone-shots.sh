#!/usr/bin/env bash
# Screenshots of the iPhone app (every tab, portrait + landscape) from a simulator.
#   Scripts/phone-shots.sh ["iPhone 17 Pro"] ["iPhone 17e"] ...
# Images land in Documentation/Screenshots/Phone/<device>/.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
"$ROOT/Scripts/generate.sh" >/dev/null
devices=("$@"); [[ ${#devices[@]} -gt 0 ]] || devices=("iPhone 17 Pro" "iPhone 17e")
runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json,sys
rts=[r for r in json.load(sys.stdin)["runtimes"] if r["platform"]=="iOS" and r["isAvailable"]]
rts.sort(key=lambda r:[int(x) for x in r["version"].split(".")]); print(rts[-1]["identifier"])')
for name in "${devices[@]}"; do
  type=$(xcrun simctl list devicetypes -j | python3 -c '
import json,sys
n=sys.argv[1]
print(next(d["identifier"] for d in json.load(sys.stdin)["devicetypes"] if d["name"]==n))' "$name")
  udid=$(xcrun simctl create "PokeWatch $name" "$type" "$runtime")
  xcrun simctl boot "$udid"; xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 || true
  out="$ROOT/build/phone-$udid.xcresult"; rm -rf "$out"
  xcodebuild test -project PokeWatch.xcodeproj -scheme PokeWatchPhone -destination "id=$udid" \
    -derivedDataPath "$DERIVED" -resultBundlePath "$out" CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
    2>&1 | grep -E "error:|Test Case .*(passed|failed)|\*\* TEST" || true
  dest="$ROOT/Documentation/Screenshots/Phone/${name// /-}"
  rm -rf "$dest"; mkdir -p "$dest"
  xcrun xcresulttool export attachments --path "$out" --output-path "$dest" >/dev/null
  # Name files after the attachment names.
  python3 - "$dest" <<'PY'
import json, os, subprocess, sys
d = sys.argv[1]
m = json.load(open(os.path.join(d, "manifest.json")))
for test in m:
    for a in test.get("attachments", []):
        src = os.path.join(d, a["exportedFileName"])
        name = a.get("suggestedHumanReadableName", a["exportedFileName"]).split("_")[0]
        if os.path.exists(src):
            dst = os.path.join(d, name + ".png")
            os.rename(src, dst)
            if "-landscape" in name:
                # Captured in the portrait framebuffer; turn upright.
                subprocess.run(["sips", "-r", "90", dst], capture_output=True)
os.remove(os.path.join(d, "manifest.json"))
PY
  xcrun simctl delete "$udid"
  echo "$name: $(ls "$dest" | wc -l | tr -d ' ') screenshots in $dest"
done
