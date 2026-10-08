#!/usr/bin/env python3
"""Bake every hedge glyph into a sprite sheet, so the renderer can rustle hundreds of leaves cheaply.

For each plant profile (assets/fonts/<font>_geometry.json) this writes assets/sprites/<font>.png: 16 cells across,
2 rows. Row 0 is the fill (white, so the renderer can tint it; watercolour grain from assets/watercolor; darker
toward the edges for a little depth); row 1 is the ink (white strokes, tinted with the ink colour). Every cell maps
glyph units x -0.6..0.6, y -0.05..1.15 (y up, the stalk at y = 0) onto CELL pixels.

    python3 tools/bake_leaf_sprites.py [hedgemoss hedgeholly ...]   (no names = every font; note make_ivy_sprites.py
                                                                     redraws hedgeivy.png afterwards)
"""
import sys
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 160
SS = 4                      # supersampling
X0, Y1, SPAN = -0.6, 1.15, 1.2
INK_WIDTH = 0.045           # in glyph units


def to_px(point, scale):
    x, y = point
    return ((x - X0) / SPAN * CELL * scale, (Y1 - y) / SPAN * CELL * scale)


def main():
    masks = [Image.open(p).convert('L').resize((CELL, CELL)) for p in sorted(glob.glob(os.path.join(ROOT, 'assets/watercolor/mask_*.png')))]
    os.makedirs(os.path.join(ROOT, 'assets/sprites'), exist_ok=True)
    only = set(sys.argv[1:])
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets/fonts/*_geometry.json'))):
        if only and os.path.basename(path).replace('_geometry.json', '') not in only:
            continue
        glyphs = json.load(open(path))['glyphs']
        sheet = Image.new('RGBA', (CELL * len(glyphs), CELL * 2), (0, 0, 0, 0))
        for index, glyph in enumerate(glyphs):
            big = CELL * SS
            # fill: the shape, its watercolour grain, and a darker rim
            shape = Image.new('L', (big, big), 0)
            draw = ImageDraw.Draw(shape)
            for polygon in glyph['fill']:
                if len(polygon) >= 3:
                    draw.polygon([to_px(p, SS) for p in polygon], fill=255)
            shape = shape.resize((CELL, CELL), Image.LANCZOS)
            inner = shape.filter(ImageFilter.GaussianBlur(5))
            grain = masks[index % len(masks)] if masks else Image.new('L', (CELL, CELL), 255)
            fill = Image.new('RGBA', (CELL, CELL))
            fp, sp, ip, gp = fill.load(), shape.load(), inner.load(), grain.load()
            for y in range(CELL):
                for x in range(CELL):
                    a = sp[x, y]
                    if a == 0:
                        continue
                    depth = ip[x, y] / 255.0                    # 1 deep inside, lower at the edge
                    tone = int(255 * (0.74 + 0.26 * depth) * (0.86 + 0.14 * gp[x, y] / 255.0))
                    fp[x, y] = (tone, tone, tone, int(a * (0.80 + 0.20 * gp[x, y] / 255.0)))
            sheet.paste(fill, (index * CELL, 0))
            # ink: every outline and vein the glyph carries
            ink = Image.new('L', (big, big), 0)
            draw = ImageDraw.Draw(ink)
            width = max(1, int(INK_WIDTH / SPAN * CELL * SS))
            for line in glyph['ink']:
                if len(line) >= 2:
                    draw.line([to_px(p, SS) for p in line], fill=255, width=width, joint='curve')
            ink = ink.resize((CELL, CELL), Image.LANCZOS)
            ink_rgba = Image.new('RGBA', (CELL, CELL), (255, 255, 255, 0))
            ink_rgba.putalpha(ink)
            sheet.paste(ink_rgba, (index * CELL, CELL))
        name = os.path.basename(path).replace('_geometry.json', '')
        sheet.save(os.path.join(ROOT, 'assets/sprites', name + '.png'), optimize=True)
        print(name, sheet.size)


if __name__ == '__main__':
    main()
