#!/usr/bin/env python3
"""Compare two directories of captures (tools/golden_capture.gd): exact equality, differing pixels, max channel
difference, mean absolute difference, a crude SSIM; writes <out>/<name>_diff.png (differences amplified on grey) and
<out>/comparison.json.

    python3 tools/image_compare.py BASELINE_DIR CANDIDATE_DIR [OUT_DIR] [--tolerance N]

Exit 0 when every image in BASELINE exists in CANDIDATE and no channel differs by more than --tolerance (default 0:
pixel-exact). A similarity score never excuses a visible change; it only helps locate one.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    # global luminance SSIM on 8x8 blocks: a diagnostic, not a gate
    la = a[..., :3].mean(axis=2)
    lb = b[..., :3].mean(axis=2)
    h, w = (la.shape[0] // 8) * 8, (la.shape[1] // 8) * 8
    la = la[:h, :w].reshape(h // 8, 8, w // 8, 8)
    lb = lb[:h, :w].reshape(h // 8, 8, w // 8, 8)
    ma, mb = la.mean(axis=(1, 3)), lb.mean(axis=(1, 3))
    va, vb = la.var(axis=(1, 3)), lb.var(axis=(1, 3))
    cov = ((la - ma[:, None, :, None]) * (lb - mb[:, None, :, None])).mean(axis=(1, 3))
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma**2 + mb**2 + c1) * (va + vb + c2))
    return float(s.mean())


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    tol = 0
    if "--tolerance" in sys.argv:
        tol = int(sys.argv[sys.argv.index("--tolerance") + 1])
        args = [a for a in args if a != str(tol)]
    if len(args) < 2:
        print(__doc__)
        return 2
    base, cand = Path(args[0]), Path(args[1])
    out = Path(args[2]) if len(args) > 2 else cand / "compare"
    out.mkdir(parents=True, exist_ok=True)
    results, failed = {}, 0
    for bp in sorted(base.glob("*.png")):
        cp = cand / bp.name
        if not cp.exists():
            results[bp.stem] = {"missing": True}
            failed += 1
            continue
        a = np.asarray(Image.open(bp).convert("RGB"), dtype=np.int16)
        b = np.asarray(Image.open(cp).convert("RGB"), dtype=np.int16)
        if a.shape != b.shape:
            results[bp.stem] = {"size_mismatch": [list(a.shape), list(b.shape)]}
            failed += 1
            continue
        d = np.abs(a - b)
        per_px = d.max(axis=2)
        r = {
            "exact": bool(per_px.max() == 0),
            "diff_pixels": int((per_px > 0).sum()),
            "diff_pixels_over_tol": int((per_px > tol).sum()),
            "max_channel_diff": int(per_px.max()),
            "mean_abs_diff": round(float(d.mean()), 4),
            "ssim": round(ssim(a.astype(np.float64), b.astype(np.float64)), 5),
        }
        if not r["exact"]:
            vis = np.clip(128 + (b - a).mean(axis=2) * 8, 0, 255).astype(np.uint8)
            vis[per_px > 0] = np.where(per_px[per_px > 0] > tol, 255, 200)
            Image.fromarray(vis).save(out / f"{bp.stem}_diff.png")
        if r["max_channel_diff"] > tol:
            failed += 1
        results[bp.stem] = r
    (out / "comparison.json").write_text(json.dumps({"tolerance": tol, "failed": failed, "images": results}, indent=2))
    for k, r in results.items():
        flag = "ok " if r.get("max_channel_diff", 999) <= tol else "BAD"
        print(f"{flag} {k:22s} {r}")
    print(f"{len(results)} images, {failed} over tolerance {tol} -> {out / 'comparison.json'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
