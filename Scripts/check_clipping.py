#!/usr/bin/env python3
"""Fail when any screenshot has lit pixels under the display's rounded corners.

The simulator's plain screenshots are rectangles; the real Ultra display is a superellipse.
This compares each screenshot with the device mask (`simctl io screenshot --mask=alpha`) and
reports lit pixels where the mask hides the screen.

Usage: Scripts/check_clipping.py MASK.png SHOT.png [SHOT.png ...]
"""
import sys
from PIL import Image

LIT = 70          # channel value that counts as a visible pixel
HIDDEN = 230      # mask alpha below this is (partly) hidden
TOLERANCE = 3     # stray anti-aliased pixels allowed


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    mask = Image.open(sys.argv[1]).getchannel("A")
    w, h = mask.size
    hidden = [(x, y) for y in range(h) for x in range(w) if mask.getpixel((x, y)) < HIDDEN]
    bad = 0
    for path in sys.argv[2:]:
        im = Image.open(path).convert("RGB")
        if im.size != (w, h):
            print(f"skip {path}: size {im.size}")
            continue
        px = im.load()
        lit = [(x, y) for (x, y) in hidden if max(px[x, y]) > LIT]
        if len(lit) > TOLERANCE:
            bad += 1
            xs, ys = [p[0] for p in lit], [p[1] for p in lit]
            print(f"CLIPPED {path}: {len(lit)} px in x {min(xs)}-{max(xs)}, y {min(ys)}-{max(ys)}")
    print(f"{len(sys.argv) - 2 - bad} ok, {bad} clipped")
    sys.exit(1 if bad else 0)


main()
