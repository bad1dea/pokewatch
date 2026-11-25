#!/usr/bin/env python3
"""Import Pokémon battle sprites of every generation, plus the Pokédex catalog, for PokéWatch.

Adapted from the pokewatch-sprite-kit importer. Downloads at build time from the public
PokeAPI repositories and writes:

    PokeWatch/Resources/ImportedSprites/<style>/<id>/<variant>/sheet.png      1x frames in a grid (paletted)
    PokeWatch/Resources/ImportedSprites/<style>/<id>/<variant>/manifest.json  frame size, grid, timing, source
    PokeWatch/Resources/ImportedStills/<style>/<id>/<variant>.png             first frame (complications, picker)
    .../ImportedSprites/catalog.json and .../ImportedStills/catalog.json      names, categories, types, generation,
                                                                              and which styles exist per Pokémon

Styles are era-accurate: a style only contains the Pokémon that existed in that generation.
gen1 Yellow (still), gen2 Crystal (GIF), gen3 Emerald (APNG), gen4 HeartGold/SoulSilver (APNG),
gen5 Black/White (GIF), modern Showdown (GIF).

Size: Apple caps a watchOS app at 75 MB uncompressed. By default this imports normal colours only
and keeps every other frame of the Modern style (its 3D renders are high frame rate), about 50 MB.
Shiny (--shiny) and full-rate Modern (--full-modern) are meant for a future iPhone companion that
transfers extra packs to the watch; bundling them in the watch app would exceed the cap.

The sprites and catalog text belong to their rights holders. Output folders are git-ignored and
must never be committed to the public repository; CI and TestFlight run this before building.

Usage: Scripts/import_sprites.py [--ids 25 133 ...] [--styles gen1 gen5] [--shiny] [--full-modern] [--jobs 16]
"""
import argparse, csv, hashlib, io, json, math, sys, threading, time, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
CSV_URL = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv"
# style -> (highest national dex number, normal path, shiny path or None). {n} is the dex number.
STYLES = {
    "gen1": (151, "versions/generation-i/yellow/transparent/{n}.png", None),
    "gen2": (251, "versions/generation-ii/crystal/animated/{n}.gif", "versions/generation-ii/crystal/animated/shiny/{n}.gif"),
    "gen3": (386, "versions/generation-iii/emerald/animated/{n}.png", "versions/generation-iii/emerald/animated/shiny/{n}.png"),
    "gen4": (493, "versions/generation-iv/heartgold-soulsilver/animated/{n}.png", "versions/generation-iv/heartgold-soulsilver/animated/shiny/{n}.png"),
    "gen5": (649, "versions/generation-v/black-white/animated/{n}.gif", "versions/generation-v/black-white/animated/shiny/{n}.gif"),
    "modern": (1025, "other/showdown/{n}.gif", "other/showdown/shiny/{n}.gif"),
}
MAX_DEX = 1025
COLUMNS = 10
# Keep every Nth frame per style (durations are merged so the loop length is unchanged).
DECIMATE = {"modern": 2}
STILL_MS = 1000
ENGLISH = "9"


class Missing(Exception):
    """The upstream repository has no file for this sprite."""


def fetch(url, cache):
    if cache.exists():
        return cache.read_bytes()
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "PokeWatch-asset-importer/2.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_bytes(data)
            return data
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise Missing(url) from None
            if attempt == 4:
                raise
            time.sleep(2 ** attempt * (3 if e.code == 429 else 1))
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)


def build_catalog(cache):
    def rows(name):
        text = fetch(f"{CSV_URL}/{name}.csv", cache / "csv" / f"{name}.csv").decode("utf-8")
        return list(csv.DictReader(io.StringIO(text)))
    types = {r["id"]: r["identifier"] for r in rows("types")}
    names = {r["pokemon_species_id"]: r for r in rows("pokemon_species_names") if r["local_language_id"] == ENGLISH}
    by_pokemon = {}
    for r in rows("pokemon_types"):
        by_pokemon.setdefault(r["pokemon_id"], []).append((int(r["slot"]), types[r["type_id"]]))
    catalog = []
    for r in rows("pokemon_species"):
        dex = int(r["id"])
        if dex > MAX_DEX:
            continue
        n = names.get(r["id"], {})
        genus = (n.get("genus") or "").replace(" Pokémon", "").strip()
        catalog.append({
            "dex": dex, "id": r["identifier"], "name": n.get("name") or r["identifier"].title(),
            "genus": genus, "types": [t for _, t in sorted(by_pokemon.get(r["id"], []))],
            "generation": int(r["generation_id"]),
            "evolvesFrom": int(r["evolves_from_species_id"]) if r["evolves_from_species_id"] else None,
            "legendary": r["is_legendary"] == "1", "mythical": r["is_mythical"] == "1",
            "styles": {},
        })
    catalog.sort(key=lambda e: e["dex"])
    return catalog


def save_png(image, path):
    """Paletted PNG when the image has at most 255 colours (exact), RGBA otherwise."""
    path.parent.mkdir(parents=True, exist_ok=True)
    colors = image.getcolors(maxcolors=256)
    if colors is not None:
        image.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)
    else:
        image.save(path, optimize=True)


def process(data, target, still, url, entry, style, variant, step=1):
    with Image.open(io.BytesIO(data)) as im:
        frames, durations = [], []
        count = getattr(im, "n_frames", 1)
        for i in range(count):
            im.seek(i)
            frames.append(im.convert("RGBA"))  # Pillow composites GIF/APNG disposal and partial frames.
            d = im.info.get("duration")
            durations.append(STILL_MS if count == 1 else max(20, int(round(d)) if d else 100))
    if step > 1 and len(frames) > step:
        frames = frames[::step]
        durations = [sum(durations[i:i + step]) for i in range(0, len(durations), step)]
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
    save_png(sheet, target / "sheet.png")
    save_png(frames[0].crop(union), still)
    manifest = {
        "id": entry["id"], "dexNumber": entry["dex"], "style": style, "variant": variant, "source": url,
        "sha256": hashlib.sha256(data).hexdigest(),
        "frameWidth": fw, "frameHeight": fh, "columns": cols, "frameCount": len(frames),
        "durationsMs": durations, "totalDurationMs": sum(durations),
    }
    (target / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", type=Path, default=ROOT / "PokeWatch/Resources/ImportedSprites")
    p.add_argument("--stills", type=Path, default=ROOT / "PokeWatch/Resources/ImportedStills")
    p.add_argument("--cache", type=Path, default=ROOT / "build/SpriteSource")
    p.add_argument("--shiny", action="store_true", help="also import shiny variants (too large for the watch app)")
    p.add_argument("--full-modern", action="store_true", help="keep every Modern frame (too large for the watch app)")
    p.add_argument("--ids", type=int, nargs="+", help="national dex numbers (default: all)")
    p.add_argument("--styles", nargs="+", default=list(STYLES), choices=list(STYLES))
    p.add_argument("--jobs", type=int, default=16)
    p.add_argument("--max-mb", type=float, default=64,
                   help="fail when sprites + stills exceed this (the watch app as a whole must stay under 75 MB)")
    a = p.parse_args()

    catalog = build_catalog(a.cache)
    wanted = set(a.ids) if a.ids else {e["dex"] for e in catalog}
    entries = [e for e in catalog if e["dex"] in wanted]

    tasks = []
    for style in a.styles:
        top, normal_path, shiny_path = STYLES[style]
        for e in entries:
            if e["dex"] > top:
                continue
            variants = [("normal", normal_path)] + ([("shiny", shiny_path)] if a.shiny and shiny_path else [])
            for variant, path in variants:
                tasks.append((style, e, variant, path))

    lock = threading.Lock()
    missing, failures, done = [], [], [0]

    def run(task):
        style, e, variant, path = task
        url = f"{SPRITES_URL}/{path.format(n=e['dex'])}"
        ext = path.rsplit(".", 1)[1]
        try:
            data = fetch(url, a.cache / style / variant / f"{e['id']}.{ext}")
            step = 1 if a.full_modern else DECIMATE.get(style, 1)
            process(data, a.out / style / e["id"] / variant, a.stills / style / e["id"] / f"{variant}.png",
                    url, e, style, variant, step)
            with lock:
                e["styles"].setdefault(style, []).append(variant)
        except Missing:
            with lock:
                missing.append(f"{style}/{e['id']}/{variant}")
        except Exception as ex:  # noqa: BLE001 - report and continue
            with lock:
                failures.append({"path": f"{style}/{e['id']}/{variant}", "url": url, "error": str(ex)})
        with lock:
            done[0] += 1
            if done[0] % 250 == 0:
                print(f"  {done[0]}/{len(tasks)}", flush=True)

    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        for f in as_completed([pool.submit(run, t) for t in tasks]):
            f.result()

    for e in entries:
        for v in e["styles"].values():
            v.sort()
    listed = [e for e in entries if e["styles"]]
    for folder in (a.out, a.stills):
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "catalog.json").write_text(json.dumps(listed, ensure_ascii=False, separators=(",", ":")) + "\n")
    (a.out / "index.json").write_text(json.dumps({"missingUpstream": sorted(missing), "failures": failures}, indent=1) + "\n")
    def megabytes(folder):
        return sum(f.stat().st_size for f in folder.rglob("*") if f.is_file()) / 1e6
    total = megabytes(a.out) + megabytes(a.stills)
    print(f"sprites {megabytes(a.out):.1f} MB, stills {megabytes(a.stills):.1f} MB")
    if total > a.max_mb:
        print(f"TOO LARGE: {total:.1f} MB > {a.max_mb} MB budget (Apple caps watch apps at 75 MB)", file=sys.stderr)
        raise SystemExit(2)
    print(f"{len(tasks) - len(missing) - len(failures)} imported, {len(missing)} missing upstream, "
          f"{len(failures)} failed; {len(listed)} Pokémon in the catalog")
    for f in failures[:10]:
        print(f"FAILED {f['path']}: {f['error']}", file=sys.stderr)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
