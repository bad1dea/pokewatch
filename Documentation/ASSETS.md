# Asset provenance

| Asset | Source | Licence |
| --- | --- | --- |
| Pokémon sprites (`Resources/Sprites/*.pokemon.json`) | Original pixel art made for this project, stored as text grids and rasterized at runtime. No game sprites, ripped assets or official artwork were used or traced. | Project's own work. Character designs are © Nintendo / Creatures / GAME FREAK; fan art for personal, non-commercial use. |
| Pixel font (`Components/PixelFont.swift`) | Original 5×7 bitmap glyphs defined in code | Project's own work |
| App icon (`Assets.xcassets/AppIcon`) | Generated from the Pikachu sprite by `Scripts/make_app_icon.py` | Project's own work |
| Particles, Pokéball battery, dial, scan lines | Drawn with SwiftUI `Canvas` / `Path` | Project's own work |
| System fonts (SF Pro, SF Pro Rounded, SF Mono) | Apple, through SwiftUI | Apple platform licence |
| SF Symbols | Only chevrons in the pickers; never stand-ins for Pokémon art | Apple platform licence |

Nothing is downloaded at runtime and nothing is hotlinked. The app has no networking code.

`Documentation/sprite-sheet.png` shows every character in its four expressions.
