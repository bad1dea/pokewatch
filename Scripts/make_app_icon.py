#!/usr/bin/env python3
"""Generate the watch and iPhone app icons (1024 × 1024).

Uses the imported Gen V Pikachu sprite when `Scripts/import_sprites.py` has run, otherwise the
fallback pixel art. The generated PNGs are git-ignored: an icon made from game art must not be
committed to the public repository. Watch icons are masked to a circle, iPhone icons to a squircle,
so the art stays inside the inscribed circle.
"""
import json, pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
STILL = ROOT / "PokeWatch/Resources/ImportedStills/gen5/pikachu/normal.png"
PIXEL_ART = ROOT / "PokeWatch/Resources/Sprites/pikachu.pokemon.json"
OUTPUTS = [
    ROOT / "PokeWatch/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    ROOT / "PokeWatch/Phone/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
]
SIZE = 1024
YELLOW = (255, 225, 0)


def sprite():
    if STILL.exists():
        return Image.open(STILL).convert("RGBA"), "imported Gen V sprite"
    d = json.loads(PIXEL_ART.read_text())
    pal = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for k, v in d["palette"].items()}
    rows = d["sprite"]
    im = Image.new("RGBA", (max(map(len, rows)), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in pal:
                im.putpixel((x, y), pal[c])
    return im, "fallback pixel art"


def main():
    art, source = sprite()
    img = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(img)
    ring = 22
    inset = 64
    draw.ellipse([inset, inset, SIZE - inset, SIZE - inset], outline=YELLOW, width=ring)
    # Largest whole-number scale that keeps the sprite inside ~72% of the circle.
    room = int((SIZE - 2 * inset) * 0.72)
    scale = max(1, room // max(art.width, art.height))
    big = art.resize((art.width * scale, art.height * scale), Image.Resampling.NEAREST)
    img.paste(big, ((SIZE - big.width) // 2, (SIZE - big.height) // 2 + scale), big)
    for out in OUTPUTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        img.save(out)
        print(f"{out.relative_to(ROOT)} ({source}, {scale}x)")


main()
