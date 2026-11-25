#!/usr/bin/env bash
# Capture every face (active + simulated Always-On), each Pokémon, and settings
# from the Ultra 3 simulator into Documentation/Screenshots.
# Data on screen comes from --demo (the simulator has no battery or Health data);
# the Always-On shots use --dimmed, which renders the reduced-luminance design
# but is NOT the system's real Always-On state.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
OUT="$ROOT/Documentation/Screenshots"
mkdir -p "$OUT"
[[ "${SKIP_BUILD:-0}" == 1 ]] || "$ROOT/Scripts/build.sh"
UDID=$(sim_udid)
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "10:09" 2>/dev/null || true
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-watchsimulator/PokeWatch.app"

shot() { # name, wait, args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" --demo --time 10:09 "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1
  echo "  $name"
}

i=1
for face in electric yellow minimal sleeping pokedex analog; do
  n=$(printf "%02d" $i)
  if [[ $face == sleeping ]]; then shot "face-$n-$face" 4 --face "$face"; else shot "face-$n-$face" 4 --face "$face" --mood happy; fi
  shot "face-$n-$face-aod" 3 --face "$face" --dimmed
  i=$((i+1))
done
for p in pikachu eevee gengar snorlax charmander squirtle bulbasaur mew umbreon psyduck; do
  shot "pokemon-$p" 3 --face electric --pokemon "$p" --mood calm
done
shot "variant-yellow-mono" 3 --face yellow --palette monochrome
shot "variant-yellow-pika" 3 --face yellow --palette pikaYellow
shot "mood-celebrating" 3 --face electric --mood celebrating
shot "mood-tired" 3 --face pokedex --pokemon squirtle --mood tired
shot "customize" 4 --settings
echo "Saved to $OUT"
