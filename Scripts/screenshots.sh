#!/usr/bin/env bash
# Capture the layout matrix from the Ultra 3 simulator into Documentation/Screenshots:
# every face (12h short time/date, 24h long time/date, simulated Always-On), every Pokémon,
# every sprite style, shiny, and customization. Also saves the device mask so
# Scripts/check_clipping.py can flag anything drawn under the rounded corners.
#
# Data comes from --demo (the simulator has no battery or Health data). The Always-On
# shots use --dimmed: the reduced-luminance design, not the system's real Always-On state.
source "$(dirname "$0")/env.sh"
cd "$ROOT"
OUT="$ROOT/Documentation/Screenshots"
rm -rf "$OUT"; mkdir -p "$OUT" "$ROOT/build"
[[ "${SKIP_BUILD:-0}" == 1 ]] || "$ROOT/Scripts/build.sh"
UDID=$(sim_udid)
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-watchsimulator/PokeWatch.app"

shot() { # name, wait, args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" --demo "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1
  echo "  $name"
}

shot face-01-electric 4 --face electric --mood happy --time 10:09 --12h
xcrun simctl io "$UDID" screenshot --type=png --mask=alpha "$ROOT/build/device-mask.png" >/dev/null 2>&1

i=1
for face in electric yellow minimal sleeping pokedex analog; do
  n=$(printf "%02d" $i)
  mood=(--mood happy); [[ $face == sleeping ]] && mood=(--time 10:09)
  shot "face-$n-$face" 3 --face "$face" "${mood[@]}" --time 10:09 --12h --date 2026-11-24
  shot "face-$n-$face-long" 3 --face "$face" "${mood[@]}" --time 23:58 --24h --date 2026-09-30
  shot "face-$n-$face-12h-long" 3 --face "$face" "${mood[@]}" --time 12:58 --12h --date 2026-12-31
  shot "face-$n-$face-aod" 3 --face "$face" --dimmed --time 10:09 --12h
  i=$((i+1))
done
for p in pikachu eevee gengar snorlax charmander squirtle bulbasaur mew umbreon psyduck \
         charizard mewtwo lucario dragonite jigglypuff espeon; do
  shot "pokemon-$p" 3 --face electric --pokemon "$p" --mood calm --time 10:09 --12h
done
for s in gen1 gen2 gen3 gen4 gen5 modern; do
  shot "style-$s" 3 --face electric --style "$s" --mood calm --time 10:09 --12h
done
shot "style-gen5-shiny" 3 --face electric --style gen5 --shiny --time 10:09 --12h
shot "variant-yellow-mono" 3 --face yellow --palette monochrome --time 10:09 --12h
shot "variant-yellow-pika" 3 --face yellow --palette pikaYellow --time 10:09 --12h
shot "mood-celebrating" 3 --face electric --mood celebrating --time 10:09 --12h
shot "mood-tired" 3 --face pokedex --pokemon squirtle --mood tired --time 10:09 --12h
shot "customize" 4 --settings
echo "Saved to $OUT"
if python3 -c "import PIL" 2>/dev/null; then
  python3 "$ROOT/Scripts/check_clipping.py" "$ROOT/build/device-mask.png" "$OUT"/face-*.png "$OUT"/pokemon-*.png "$OUT"/style-*.png
else
  echo "Pillow not installed here: run Scripts/check_clipping.py build/device-mask.png Documentation/Screenshots/*.png elsewhere."
fi
