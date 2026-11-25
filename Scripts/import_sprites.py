#!/usr/bin/env python3
"""Import the battle sprites of every generation for PokéWatch.

Adapted from the pokewatch-sprite-kit importer. Downloads sprites from the public PokeAPI/sprites
repository at build time and writes, per art style, Pokémon and variant:

    PokeWatch/Resources/ImportedSprites/<style>/<id>/<variant>/sheet.png      1x frames in a grid
    PokeWatch/Resources/ImportedSprites/<style>/<id>/<variant>/manifest.json  frame size, grid, timing, source
    PokeWatch/Resources/ImportedStills/<style>/<id>/<variant>.png             first frame, for complications

Styles: gen1 (Yellow, still), gen2 (Crystal, GIF), gen3 (Emerald, APNG), gen4 (HeartGold/SoulSilver,
APNG), gen5 (Black/White, GIF), modern (Showdown, GIF). A Pokémon that didn't exist yet in a
generation is simply absent there; the app falls back to the next style that has it.

Frames are cropped to the union of their alpha bounds so the animation never jitters, and stored
unscaled: the app scales them by whole device pixels to fit each face, which keeps memory small.

The sprites belong to their rights holders. The output folder is git-ignored and must never be
committed to the public repository; CI and TestFlight builds run this script before building.

Usage: Scripts/import_sprites.py [--ids 25 133 ...] [--normal-only] [--cache DIR] [--out DIR]
"""
import argparse, hashlib, io, json, math, sys, time, urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
POKEMON = {25: "pikachu", 133: "eevee", 94: "gengar", 143: "snorlax", 4: "charmander", 7: "squirtle",
           1: "bulbasaur", 151: "mew", 197: "umbreon", 54: "psyduck", 6: "charizard", 150: "mewtwo",
           448: "lucario", 149: "dragonite", 39: "jigglypuff", 196: "espeon"}
ROOT_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
# style -> (highest national dex number, normal path, shiny path or None). {n} is the dex number.
STYLES = {
    "gen1": (151, "versions/generation-i/yellow/transparent/{n}.png", None),
    "gen2": (251, "versions/generation-ii/crystal/animated/{n}.gif", "versions/generation-ii/crystal/animated/shiny/{n}.gif"),
    "gen3": (386, "versions/generation-iii/emerald/animated/{n}.png", "versions/generation-iii/emerald/animated/shiny/{n}.png"),
    "gen4": (493, "versions/generation-iv/heartgold-soulsilver/animated/{n}.png", "versions/generation-iv/heartgold-soulsilver/animated/shiny/{n}.png"),
    "gen5": (649, "versions/generation-v/black-white/animated/{n}.gif", "versions/generation-v/black-white/animated/shiny/{n}.gif"),
    "modern": (1025, "other/showdown/{n}.gif", "other/showdown/shiny/{n}.gif"),
}
COLUMNS = 10
STILL_MS = 1000


def fetch(url, cache):
    if cache.exists():
        return cache.read_bytes()
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "PokeWatch-asset-importer/1.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            with Image.open(io.BytesIO(data)) as im:
                im.verify()
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_bytes(data)
            return data
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def process(data, target, still, url, ident, name, style, variant):
    with Image.open(io.BytesIO(data)) as im:
        frames, durations = [], []
        count = getattr(im, "n_frames", 1)
        for i in range(count):
            im.seek(i)
            frames.append(im.convert("RGBA"))  # Pillow composites GIF/APNG disposal and partial frames.
            d = im.info.get("duration")
            durations.append(STILL_MS if count == 1 else max(20, int(round(d)) if d else 100))
    boxes = [b for b in (f.getchannel("A").getbbox() for f in frames) if b]
    if not boxes:
        raise ValueError("empty animation")
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    fw, fh = union[2] - union[0], union[3] - union[1]
    cols = min(COLUMNS, len(frames))
    rows = math.ceil(len(frames) / cols)
    sheet = Image.new("RGBA", (fw * cols, fh * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f.crop(union), ((i % cols) * fw, (i // cols) * fh))
    target.mkdir(parents=True, exist_ok=True)
    sheet.save(target / "sheet.png", optimize=True)
    still.parent.mkdir(parents=True, exist_ok=True)
    frames[0].crop(union).save(still, optimize=True)
    manifest = {
        "id": name, "dexNumber": ident, "style": style, "variant": variant, "source": url,
        "sha256": hashlib.sha256(data).hexdigest(),
        "frameWidth": fw, "frameHeight": fh, "columns": cols, "frameCount": len(frames),
        "durationsMs": durations, "totalDurationMs": sum(durations),
    }
    (target / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", type=Path, default=ROOT / "PokeWatch/Resources/ImportedSprites")
    p.add_argument("--stills", type=Path, default=ROOT / "PokeWatch/Resources/ImportedStills")
    p.add_argument("--cache", type=Path, default=ROOT / "build/SpriteSource")
    p.add_argument("--normal-only", action="store_true")
    p.add_argument("--ids", type=int, nargs="+", default=list(POKEMON))
    p.add_argument("--styles", nargs="+", default=list(STYLES), choices=list(STYLES))
    a = p.parse_args()
    unknown = set(a.ids) - POKEMON.keys()
    if unknown:
        p.error(f"unknown ids: {sorted(unknown)}")
    results, skipped, failures = [], [], []
    for style in a.styles:
        top, normal_path, shiny_path = STYLES[style]
        for ident in a.ids:
            name = POKEMON[ident]
            if ident > top:
                skipped.append(f"{style}/{name}")
                continue
            variants = [("normal", normal_path)] + ([] if a.normal_only or not shiny_path else [("shiny", shiny_path)])
            for variant, path in variants:
                url = f"{ROOT_URL}/{path.format(n=ident)}"
                ext = path.rsplit(".", 1)[1]
                try:
                    data = fetch(url, a.cache / style / variant / f"{name}.{ext}")
                    m = process(data, a.out / style / name / variant, a.stills / style / name / f"{variant}.png",
                                url, ident, name, style, variant)
                    results.append(m)
                    print(f"{style}/{name}/{variant}: {m['frameCount']} frames {m['frameWidth']}x{m['frameHeight']}")
                except Exception as e:  # noqa: BLE001 - report and continue
                    failures.append({"path": f"{style}/{name}/{variant}", "url": url, "error": str(e)})
                    print(f"FAILED {style}/{name}/{variant}: {e}", file=sys.stderr)
    a.out.mkdir(parents=True, exist_ok=True)
    (a.out / "index.json").write_text(json.dumps({
        "sprites": [f"{r['style']}/{r['id']}/{r['variant']}" for r in results],
        "notInGeneration": skipped, "failures": failures}, indent=2) + "\n")
    print(f"{len(results)} imported, {len(skipped)} not in that generation, {len(failures)} failed")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
