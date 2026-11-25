#!/usr/bin/env python3
"""Render every *.pokemon.json sprite (open / blink / happy / tired eyes) to a contact sheet.

Mirrors the eye-expression rules in PokeWatch/Characters/SpriteRasterizer.swift so the
artwork can be reviewed on any machine without Xcode.
Usage: Scripts/preview_sprites.py [out.png]
"""
import json, sys, pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "PokeWatch/Resources/Sprites"
SCALE = 8
EXPR = ["open", "closed", "happy", "tired"]

def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def raster(defn, expr):
    rows = defn["sprite"]
    w = max(len(r) for r in rows)
    grid = [list(r.ljust(w, ".")) for r in rows]
    eyes = defn["eyes"]; keys = set(eyes["keys"])
    h = len(grid)
    def is_eye(x, y):
        return 0 <= y < h and 0 <= x < w and grid[y][x] in keys
    out = [row[:] for row in grid]
    for y in range(h):
        for x in range(w):
            if grid[y][x] not in keys or expr == "open":
                continue
            below, above = is_eye(x, y + 1), is_eye(x, y - 1)
            if expr == "closed":
                out[y][x] = eyes["line"] if not below else eyes["fill"]
            elif expr == "happy":
                left, right = is_eye(x - 1, y), is_eye(x + 1, y)
                if not above and not below and y > 0 and left and right:
                    out[y][x] = eyes["fill"]; out[y - 1][x] = eyes["line"]
                else:
                    out[y][x] = eyes["line"] if not above else eyes["fill"]
            elif expr == "tired":
                if not above and below:
                    out[y][x] = eyes["line"]
    return out, w, h

def main():
    files = sorted(SPRITES.glob("*.pokemon.json"))
    defs = [json.loads(f.read_text()) for f in files]
    cell = 24 * SCALE + 16
    sheet = Image.new("RGB", (cell * len(EXPR), cell * len(defs)), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for i, defn in enumerate(defs):
        pal = {k: hexrgb(v) for k, v in defn["palette"].items()}
        bad = {c for r in defn["sprite"] for c in r if c != "." and c not in pal}
        widths = {len(r) for r in defn["sprite"]}
        if bad or len(widths) > 1:
            print(f"{defn['id']}: unknown keys {bad} widths {widths}")
        for j, e in enumerate(EXPR):
            g, w, h = raster(defn, e)
            ox, oy = j * cell + 8, i * cell + 8
            for y in range(h):
                for x in range(w):
                    c = g[y][x]
                    if c in pal:
                        d.rectangle([ox + x*SCALE, oy + y*SCALE, ox + (x+1)*SCALE - 1, oy + (y+1)*SCALE - 1], fill=pal[c])
        d.text((4, i * cell + 2), defn["id"], fill=(255, 255, 255))
    out = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "Documentation/sprite-sheet.png")
    sheet.save(out)
    print(out)

main()
