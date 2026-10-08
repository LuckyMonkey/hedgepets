#!/usr/bin/env python3
"""Grass tufts and weeds for the garden lawn: assets/sprites/grass.png, 12 cells of 128x128 in a row.
Cells 0-7: grass tufts (white, tinted by the shader; darker at the base). 8: dandelion (yellow head). 9: clover tuft.
10: daisy. 11: seed-head grass. Each tuft's base sits at the bottom centre of its cell.

    python3 tools/make_grass_sprites.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL, SS = 128, 4


def blade(draw, x0, h, lean, width, rng, tone=255):
    pts_l, pts_r = [], []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        x = x0 + lean * t * t * h
        y = CELL * SS - t * h
        w = width * (1 - t) ** 0.8
        pts_l.append((x - w / 2, y))
        pts_r.append((x + w / 2, y))
    draw.polygon(pts_l + pts_r[::-1], fill=(tone, tone, tone, 255))


def main():
    rng = random.Random(11)
    sheet = Image.new('RGBA', (CELL * 12, CELL), (0, 0, 0, 0))
    for c in range(12):
        big = Image.new('RGBA', (CELL * SS, CELL * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        cx = CELL * SS / 2
        if c < 8 or c == 11:
            n = rng.randint(26, 40) if c < 6 else rng.randint(40, 56)     # many fine blades: lawn, not a shrub
            for b in range(n):
                h = rng.uniform(0.35, 0.98) * CELL * SS * (0.9 if c < 6 else 0.7)
                blade(d, cx + rng.uniform(-0.3, 0.3) * CELL * SS, h, rng.uniform(-0.55, 0.55), rng.uniform(5, 11), rng,
                      tone=rng.randint(185, 255))
            if c == 11:   # seed heads
                for b in range(3):
                    x = cx + rng.uniform(-0.15, 0.15) * CELL * SS
                    top = CELL * SS * rng.uniform(0.05, 0.2)
                    d.line([(x, CELL * SS), (x + rng.uniform(-20, 20), top)], fill=(235, 235, 220, 255), width=6)
                    d.ellipse([x - 14, top - 40, x + 14, top + 10], fill=(225, 215, 170, 255))
        elif c == 8:      # dandelion: leaves + yellow head
            for b in range(6):
                blade(d, cx + rng.uniform(-30, 30), CELL * SS * 0.35, rng.uniform(-0.9, 0.9), 34, rng, 210)
            d.line([(cx, CELL * SS), (cx + 10, CELL * SS * 0.25)], fill=(200, 210, 170, 255), width=8)
            r = CELL * SS * 0.09
            d.ellipse([cx + 10 - r, CELL * SS * 0.25 - r, cx + 10 + r, CELL * SS * 0.25 + r], fill=(255, 205, 40, 255))
        elif c == 9:      # clover tuft
            for b in range(5):
                x = cx + rng.uniform(-0.25, 0.25) * CELL * SS
                y = CELL * SS * rng.uniform(0.45, 0.75)
                d.line([(x, CELL * SS), (x, y)], fill=(200, 220, 190, 255), width=6)
                for k in range(3):
                    a = k * 2.1 + rng.uniform(-0.2, 0.2)
                    px, py = x + math.cos(a) * 26, y + math.sin(a) * 18
                    d.ellipse([px - 24, py - 20, px + 24, py + 20], fill=(235, 240, 230, 255))
        elif c == 10:     # daisy
            for b in range(5):
                blade(d, cx + rng.uniform(-25, 25), CELL * SS * 0.3, rng.uniform(-0.8, 0.8), 26, rng, 215)
            fx, fy = cx, CELL * SS * 0.3
            d.line([(cx, CELL * SS), (fx, fy)], fill=(200, 215, 180, 255), width=7)
            for k in range(12):
                a = k * math.tau / 12
                d.ellipse([fx + math.cos(a) * 34 - 14, fy + math.sin(a) * 34 - 14, fx + math.cos(a) * 34 + 14, fy + math.sin(a) * 34 + 14], fill=(255, 255, 250, 255))
            d.ellipse([fx - 18, fy - 18, fx + 18, fy + 18], fill=(250, 200, 50, 255))
        small = big.resize((CELL, CELL), Image.LANCZOS)
        sheet.paste(small, (c * CELL, 0))
    sheet.save(os.path.join(ROOT, 'assets/sprites/grass.png'), optimize=True)
    print('grass', sheet.size)


if __name__ == '__main__':
    main()
