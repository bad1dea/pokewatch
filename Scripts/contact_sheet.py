#!/usr/bin/env python3
"""Contact sheet of screenshots as they look on the watch (device mask applied).

Usage: Scripts/contact_sheet.py MASK.png OUT.png COLUMNS SHOT.png [SHOT.png ...]
"""
import sys
from PIL import Image

mask = Image.open(sys.argv[1]).getchannel("A")
out, cols, shots = sys.argv[2], int(sys.argv[3]), sys.argv[4:]
w, h = mask.size
pad = 12
rows = (len(shots) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (w + pad) + pad, rows * (h + pad) + pad), (38, 38, 42))
for i, p in enumerate(shots):
    im = Image.open(p).convert("RGB")
    sheet.paste(im, (pad + (i % cols) * (w + pad), pad + (i // cols) * (h + pad)), mask)
sheet.save(out)
print(out)
