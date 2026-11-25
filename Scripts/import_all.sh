#!/usr/bin/env bash
# Import every sprite set and generate the app icons. Needs Python 3 with Pillow and network access.
#   watch: normal colours, Modern at half frame rate (fits Apple's 75 MB watch-app cap)
#   phone: everything (shiny, full-rate Modern), shown in the iPhone app and sent to the watch as packs
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${PYTHON:-python3}"
"$PY" Scripts/import_sprites.py "$@"
"$PY" Scripts/import_sprites.py --shiny --full-modern --max-mb 0 \
  --out PokeWatch/Resources/Phone/ImportedSprites --stills PokeWatch/Resources/Phone/ImportedStills "$@"
"$PY" Scripts/make_app_icon.py
