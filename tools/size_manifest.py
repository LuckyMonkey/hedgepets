#!/usr/bin/env python3
"""Size manifest for a web export: every artifact's raw / gzip-6 / brotli-9 bytes, the first-load total, and the bake
cache's composition (from build/cache_manifest.json, written by tools/bake_cache.gd). Writes JSON and prints a summary.

    python3 tools/size_manifest.py EXPORT_DIR [OUT_JSON]      (default OUT_JSON = EXPORT_DIR/size_manifest.json)

First load = index.html + index.js + index.wasm + index.pck + the audio worklets (what the browser fetches before the
game runs). Real transfer depends on the server: fridge's nginx sends gzip (measure there with curl/wget).
"""
import gzip, json, os, sys

try:
    import brotli
except ImportError:
    brotli = None

FIRST_LOAD = ("index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js", "index.audio.position.worklet.js")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    d = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(d, "size_manifest.json")
    arts = {}
    for f in sorted(os.listdir(d)):
        p = os.path.join(d, f)
        if not os.path.isfile(p) or f.endswith(".json"):
            continue
        b = open(p, "rb").read()
        arts[f] = {"raw": len(b), "gzip6": len(gzip.compress(b, 6)), "br9": len(brotli.compress(b, quality=9)) if brotli else None}
    first = {k: sum(arts[f][k] or 0 for f in FIRST_LOAD if f in arts) for k in ("raw", "gzip6", "br9")}
    cache = None
    if os.path.exists("build/cache_manifest.json"):
        m = json.load(open("build/cache_manifest.json"))
        cache = {"file_bytes": m["file_bytes"], "by_label": m["by_label"], "entries": len(m["entries"])}
    json.dump({"artifacts": arts, "first_load": first, "cache": cache}, open(out, "w"), indent=1)
    for f, a in arts.items():
        print(f"{f:34s} raw {a['raw']:>11,}  gzip6 {a['gzip6']:>11,}  br9 {a['br9'] or 0:>11,}")
    print(f"first load: raw {first['raw']:,}  gzip6 {first['gzip6']:,}  br9 {first['br9']:,}  -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
