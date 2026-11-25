# Adding a Pokémon

Characters are data. Add `<id>.pokemon.json` and it appears everywhere: picker, faces, complications.

Two ways to install a file:

- **Bundled**: put it in `PokeWatch/Resources/Sprites/` and rebuild.
- **Drop-in, no rebuild**: copy it into the app's `Documents/Characters/` folder (Xcode › Devices ›
  PokéWatch › container, or `xcrun simctl get_app_container <udid> ng.khuo.pokewatch data`).
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
