# Asset provenance

| Asset | Source | Licence |
| --- | --- | --- |
| Pokémon battle sprites, Gen I–V and Modern (`Resources/ImportedSprites`, `Resources/ImportedStills`) | Downloaded at build time by `Scripts/import_sprites.py` from the public [PokeAPI/sprites](https://github.com/PokeAPI/sprites) repository: Yellow (Gen I), Crystal (II), Emerald (III), HeartGold/SoulSilver (IV), Black/White (V), Showdown (Modern); Pixel comes from Pokémon Showdown's Black/White-style set (`play.pokemonshowdown.com/sprites/gen5`, fan-made past Gen V). Each manifest records the source URL and SHA-256. | © Nintendo / Creatures / GAME FREAK. Public hosting is not a licence to redistribute. These files are **git-ignored and never committed**; they exist only in local and CI build products for personal use. |
| Fallback pixel art (`Resources/Sprites/*.pokemon.json`) | Original art drawn for this project as text grids. Used when sprites weren't imported. | Project's own work (character designs © their owners) |
| Pixel font (`Components/PixelFont.swift`) | Original 5×7 bitmap glyphs defined in code | Project's own work |
| App icon (`Assets.xcassets/AppIcon`) | Generated from the fallback Pikachu by `Scripts/make_app_icon.py` | Project's own work |
| Particles, Pokéball battery, dial, scan lines | Drawn with SwiftUI `Canvas` / `Path` | Project's own work |
| System fonts (SF Pro, SF Pro Rounded, SF Mono) | Apple, through SwiftUI | Apple platform licence |
| SF Symbols | Only chevrons in the pickers; never stand-ins for Pokémon art | Apple platform licence |

The importer is adapted from the pokewatch-sprite-kit importer. The app never downloads anything at
runtime and has no networking code. Importing needs network access once, at build time.

`Documentation/sprite-sheet.png` shows the fallback pixel art in its four expressions.
