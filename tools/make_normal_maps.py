#!/usr/bin/env python3
"""Normal maps for the leaf sprite sheets, so Godot's 2D lights can shape every leaf (a gentle dome, a raised
midrib, sunken veins) and leaves glint as they turn in the wind.

For each assets/sprites/<name>.png this writes assets/sprites/<name>_n.png with the same layout: row 0 (the fill)
gets a height field from the leaf's own shape (thicker in the middle) with the ink row's lines pressed in as veins;
row 1 (the ink) stays flat.

    python3 tools/make_normal_maps.py
"""
import glob
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 160
STRENGTH = 3.2


def normals_from_height(height):
    gy, gx = np.gradient(height)
    nx, ny, nz = -gx * STRENGTH, -gy * STRENGTH, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def main():
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets/sprites/*.png'))):
        if path.endswith('_n.png') or os.path.basename(path).startswith(('grass', 'lawn')):
            continue
        sheet = Image.open(path).convert('RGBA')
        w, h = sheet.size
        out = np.zeros((h, w, 4), dtype=np.uint8)
        out[..., 0], out[..., 1], out[..., 2], out[..., 3] = 128, 128, 255, 255   # flat everywhere by default
        for col in range(w // CELL):
            fill = sheet.crop((col * CELL, 0, (col + 1) * CELL, CELL)).getchannel('A')
            ink = sheet.crop((col * CELL, CELL, (col + 1) * CELL, 2 * CELL)).getchannel('A')
            dome = np.asarray(fill.filter(ImageFilter.GaussianBlur(22)), dtype=np.float32) / 255.0
            dome = dome * dome   # rounder in the middle, falling to the edges
            veins = np.asarray(ink.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
            height = dome * 14.0 - veins * 1.6
            out[0:CELL, col * CELL:(col + 1) * CELL, 0:3] = normals_from_height(height)
        Image.fromarray(out, 'RGBA').save(path.replace('.png', '_n.png'), optimize=True)
        print(os.path.basename(path).replace('.png', '_n.png'))


if __name__ == '__main__':
    main()
