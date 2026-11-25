# Adding a Pokémon

Characters are data: a `<id>.pokemon.json` file (name, personality, voice lines) plus artwork.
Artwork is either imported sprites or fallback pixel art inside the JSON. A character with neither
is not listed.

## With imported sprites (normal case)

1. Add the national dex number and id to `POKEMON` in `Scripts/import_sprites.py` and run it.
   It fetches every generation's sprite that exists for that Pokémon.
2. Add `PokeWatch/Resources/Sprites/<id>.pokemon.json` without `sprite`, `palette`, `eyes` or
   `earRows` (see `charizard.pokemon.json`).
3. Optional: add the id to `CharacterRegistry.builtInOrder` to set its place in the picker.

## Without a rebuild

A JSON file with fallback pixel art can be dropped in without rebuilding: copy it into the app's `Documents/Characters/` folder (Xcode › Devices ›
  PokéWatch › container, or `xcrun simctl get_app_container <udid> ng.khuo.pokewatch.watchkitapp data`).
  A drop-in file with the same `id` as a bundled one replaces it.

Invalid files are skipped (see `CharacterRegistry.rejected`) and never crash the app.

## Format

```json
{
  "id": "pikachu", "name": "Pikachu", "dexNumber": 25, "category": "Mouse", "type": "Electric",
  "entry": "One or two sentences for the Pokédex face.",
  "element": "spark",            // spark sparkle wisp zzz ember bubble leaf psychic moon confused
  "accentHex": "#FFE100",
  "palette": { "K": "#6B4A12", "Y": "#FFD92E", "E": "#241808", "W": "#FFFFFF" },
  "eyes": { "keys": ["E", "W"], "fill": "Y", "line": "K" },
  "earRows": 5,                  // top rows that flick when asleep (0 = none)
  "personality": {
    "idleStyle": "bounce",       // bounce sway float breathe waddle wobble
    "energy": 0.9, "sleepiness": 0.3, "bobSpeed": 2.4, "bobAmplitude": 1.0,
    "blinkInterval": 3.2, "hopHeight": 4,
    "nightOwl": false, "sleepsWhenIdle": false, "stepLover": true
  },
  "lines": { "idle": "", "happy": "", "excited": "", "celebrate": "", "tired": "", "charging": "", "sleep": "", "wake": "" },
  "sprite": [ "..KK..", ".KYYK.", "..." ],
  "order": 11                    // optional position in the picker
}
```

- `.` is transparent; every other character must be a palette key.
- Aim for about 20–27 × 18–21 pixels so it fits every face.
- Eyes: blink, happy and tired are derived from the `eyes.keys` pixels. `fill` paints over a closed
  lid and `line` draws the lid line. Give eyes 2+ rows, or a 3-wide single row.
- Avoid near-black outlines; they vanish on the OLED black. Use a dark tint of the body colour.
- Unknown `idleStyle` or `element` values fall back to defaults.

Preview the art without Xcode: `Scripts/preview_sprites.py out.png` renders every expression.
