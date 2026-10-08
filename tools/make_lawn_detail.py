#!/usr/bin/env python3
"""A tileable close-up of lawn seen from above: thousands of tiny blades, light and dark, multiplied over the
lawn's colour patches by shaders/lawn.gdshader so the ground has grain at pet scale. assets/sprites/lawn_detail.png

    python3 tools/make_lawn_detail.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 512


def main():
    rng = random.Random(7)
    img = Image.new('L', (SIZE, SIZE), 214)
    d = ImageDraw.Draw(img)
    for _ in range(14000):
        x, y = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        a = rng.uniform(0, math.tau)
        length = rng.uniform(5, 15)
        tone = rng.choice([rng.randint(120, 170), rng.randint(235, 255), rng.randint(190, 230)])
        w = rng.choice([1, 1, 2])
        for ox in (-SIZE, 0, SIZE):                                 # wrap, so it tiles
            for oy in (-SIZE, 0, SIZE):
                d.line([(x + ox, y + oy), (x + ox + math.cos(a) * length, y + oy + math.sin(a) * length)], fill=tone, width=w)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(ROOT, 'assets/sprites/lawn_detail.png'), optimize=True)
    print('lawn_detail', img.size)


if __name__ == '__main__':
    main()
