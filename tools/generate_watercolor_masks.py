#!/usr/bin/env python3
"""Generate deterministic, dependency-light watercolor pigment masks."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "watercolor"
SIZE = 256
COUNT = 10


def make_mask(seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx = SIZE * (0.50 + rng.uniform(-0.035, 0.035))
    cy = SIZE * (0.50 + rng.uniform(-0.035, 0.035))
    rx = SIZE * rng.uniform(0.43, 0.49)
    ry = SIZE * rng.uniform(0.43, 0.49)
    radial = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    body = np.clip(1.0 - (radial - 0.77) / 0.22, 0.0, 1.0)
    edge_pool = np.exp(-((radial - 0.84) ** 2) / 0.010)

    low = Image.fromarray((rng.random((24, 24)) * 255).astype(np.uint8), "L")
    low = low.resize((SIZE, SIZE), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(4.5))
    low_noise = np.asarray(low, dtype=np.float32) / 255.0

    blotches = np.zeros((SIZE, SIZE), dtype=np.float32)
    for _ in range(10):
        bx = rng.uniform(0.12, 0.88) * SIZE
        by = rng.uniform(0.12, 0.88) * SIZE
        sx = rng.uniform(11.0, 42.0)
        sy = rng.uniform(10.0, 38.0)
        strength = rng.uniform(0.20, 0.62)
        blotches += strength * np.exp(-(((xx - bx) / sx) ** 2 + ((yy - by) / sy) ** 2))

    grain = rng.normal(0.0, 0.045, (SIZE, SIZE)).astype(np.float32)
    gaps = np.zeros((SIZE, SIZE), dtype=np.float32)
    for _ in range(7):
        gx = rng.uniform(0.12, 0.88) * SIZE
        gy = rng.uniform(0.12, 0.88) * SIZE
        gs = rng.uniform(4.0, 13.0)
        gaps += np.exp(-(((xx - gx) ** 2 + (yy - gy) ** 2) / (2.0 * gs * gs))) * rng.uniform(0.12, 0.32)

    alpha = body * (0.30 + 0.30 * low_noise + blotches + edge_pool * 0.24 + grain - gaps)
    alpha = np.clip(alpha, 0.0, 0.92)
    alpha[radial > 1.02] = 0.0
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[:, :, :3] = 255
    rgba[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for index in range(COUNT):
        path = OUT_DIR / f"mask_{index:02d}.png"
        make_mask(4100 + index * 97).save(path)
        print(path)


if __name__ == "__main__":
    main()
