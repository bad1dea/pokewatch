# Shared settings for the build scripts. Source, don't execute.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME=PokeWatch
BUNDLE_ID=ng.khuo.pokewatch.watchkitapp
SIM_NAME="${SIM_NAME:-PokeWatch Ultra 3}"
SIM_TYPE="${SIM_TYPE:-com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-3-49mm}"
DERIVED="${DERIVED:-$ROOT/build/DerivedData}"
XCODEGEN="${XCODEGEN:-$(command -v xcodegen || echo "$HOME/bin/xg/xcodegen/bin/xcodegen")}"

# Newest installed watchOS simulator runtime.
sim_runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json,sys
rts=[r for r in json.load(sys.stdin)["runtimes"] if r["platform"]=="watchOS" and r["isAvailable"]]
rts.sort(key=lambda r:[int(x) for x in r["version"].split(".")])
print(rts[-1]["identifier"] if rts else "")'
}

# UDID of our dedicated simulator, created on first use.
sim_udid() {
  local udid
  udid=$(xcrun simctl list devices -j | python3 -c '
import json,sys
name=sys.argv[1]
for rt,devs in json.load(sys.stdin)["devices"].items():
    for d in devs:
        if d["name"]==name and d["isAvailable"]: print(d["udid"]); sys.exit()' "$SIM_NAME")
  if [[ -z "$udid" ]]; then
    local rt; rt=$(sim_runtime)
    [[ -n "$rt" ]] || { echo "No watchOS simulator runtime. Run: xcodebuild -downloadPlatform watchOS" >&2; exit 1; }
    udid=$(xcrun simctl create "$SIM_NAME" "$SIM_TYPE" "$rt")
  fi
  echo "$udid"
}
