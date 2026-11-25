#!/usr/bin/env python3
"""Generate the 1024×1024 app icon from the Pikachu sprite definition.

watchOS masks icons to a circle, so the art is kept inside the inscribed circle.
Usage: Scripts/make_app_icon.py
"""
import json, pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITE = ROOT / "PokeWatch/Resources/Sprites/pikachu.pokemon.json"
OUT = ROOT / "PokeWatch/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

def hexrgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

d = json.loads(SPRITE.read_text())
pal = {k: hexrgb(v) for k, v in d["palette"].items()}
rows = d["sprite"]; w = max(map(len, rows)); h = len(rows)
size = 1024
img = Image.new("RGB", (size, size), (0, 0, 0))
dr = ImageDraw.Draw(img)
# Thin ring in electric yellow, flat.
ring = 18
dr.ellipse([60, 60, size - 60, size - 60], outline=(255, 225, 0), width=ring)
scale = 26
ox = (size - w * scale) // 2 + scale
oy = (size - h * scale) // 2 + 10
for y, row in enumerate(rows):
    for x, c in enumerate(row):
        if c in pal:
            dr.rectangle([ox + x * scale, oy + y * scale, ox + (x + 1) * scale - 1, oy + (y + 1) * scale - 1], fill=pal[c])
OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print(OUT)
