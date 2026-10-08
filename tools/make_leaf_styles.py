#!/usr/bin/env python3
"""More plants for pets and seedbeds, in the ivy sheet's layout (16 cells, row 0 fill, row 1 ink; glyph units
x -0.6..0.6, y -0.05..1.15, stalk at y = 0; see make_ivy_sprites.py):

    hedgeoak    lobed oak leaves; cell 13 an acorn          (Hazel the squirrel)
    hedgepine   needle sprays;    cell 13 a little cone      (Spruce the moose)
    hedgesage   soft felted ovals; cell 13 a sprig of bloom  (Rascal the raccoon)

Cells 0-7 leaves, 8-11 stems, 12/14/15 buds and berries. The fill is white (tinted by the pet's palette; the
cell-13 bloom by profile.flower_color).

    python3 tools/make_leaf_styles.py && python3 tools/make_normal_maps.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

from make_ivy_sprites import CELL, SS, SPAN, px

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def mirror_outline(half):
    """A leaf from its right half [(x, y) from stalk to tip]: right side up, left side back down."""
    return half + [(-x, y) for x, y in reversed(half)]


def oak_leaf(size, lean, rng):
    lobes = rng.choice([4, 5])
    half, tips = [], []
    for i in range(121):
        t = i / 120
        env = math.sin(math.pi * min(1.0, t * 1.05)) ** 0.8 * (0.9 + 0.25 * t)
        wave = 0.62 + 0.38 * abs(math.sin(lobes * math.pi * t + 0.4)) ** 0.7
        w = 0.30 * size * env * wave
        y = 0.04 + t * 1.0 * size
        half.append((w, y))
        if abs(math.sin(lobes * math.pi * t + 0.4)) > 0.995 and 0.1 < t < 0.95:
            tips.append((w, y))
    pts = mirror_outline(half)
    a = math.radians(lean)
    rot = lambda p: (p[0] * math.cos(a) + p[1] * math.sin(a), -p[0] * math.sin(a) + p[1] * math.cos(a))
    veins = [[(0, 0.0), (0, 0.04 + size * 0.98)]]
    for w, y in tips:
        for s in (1, -1):
            veins.append([(0, y - 0.1 * size), (s * w * 0.85, y)])
    return [rot(p) for p in pts], [[rot(p) for p in v] for v in veins]


def sage_leaf(size, lean, rng):
    half = []
    for i in range(81):
        t = i / 80
        w = 0.24 * size * math.sin(math.pi * t) ** 0.65 * (1.0 - 0.25 * t)
        w *= 1.0 + 0.04 * math.sin(t * 40 + rng.random())            # a soft, crinkled edge
        half.append((w, 0.05 + t * 1.02 * size))
    a = math.radians(lean)
    rot = lambda p: (p[0] * math.cos(a) + p[1] * math.sin(a), -p[0] * math.sin(a) + p[1] * math.cos(a))
    veins = [[(0, 0.05), (0, 0.05 + 0.95 * size)]]
    for k in range(1, 6):
        y = 0.05 + k * 0.16 * size
        for s in (1, -1):
            veins.append([(0, y), (s * 0.15 * size, y + 0.1 * size)])
    return [rot(p) for p in mirror_outline(half)], [[rot(p) for p in v] for v in veins]


def pine_spray(size, lean, rng):
    """Needles as thin quads along a twig. Returns a list of polygons and the twig line."""
    a = math.radians(lean)
    rot = lambda p: (p[0] * math.cos(a) + p[1] * math.sin(a), -p[0] * math.sin(a) + p[1] * math.cos(a))
    twig = [(0.0, 0.0), (0.02, 0.5 * size), (0.0, 1.05 * size)]
    polys = []
    n = 26
    for k in range(n):
        t = 0.08 + 0.9 * k / n
        y = t * size
        length = 0.32 * size * (1.0 - 0.55 * t) * rng.uniform(0.85, 1.1)
        for s in (1, -1):
            ang = math.radians(rng.uniform(38, 58))
            tip = (s * math.sin(ang) * length, y + math.cos(ang) * length)
            nrm = (math.cos(ang) * 0.014, -s * math.sin(ang) * 0.014)
            polys.append([rot((nrm[0], y + nrm[1])), rot(tip), rot((-nrm[0], y - nrm[1]))])
    tipcap = [(0.0, 1.05 * size)]
    for k in range(5):
        ang = math.radians(-30 + 15 * k)
        polys.append([rot((-0.012, 1.0 * size)), rot((math.sin(ang) * 0.12 * size, (1.0 + math.cos(ang) * 0.12) * size)), rot((0.012, 1.0 * size))])
    return polys, [rot(p) for p in twig + tipcap]


def bloom(kind):
    """Cell 13: an acorn, a cone, or a sprig of small florets. Returns polygons (fill) and lines (ink)."""
    if kind == 'oak':
        nut = [(math.cos(t) * 0.17, 0.42 + math.sin(t) * 0.24) for t in [i / 40 * math.tau for i in range(40)]]
        cap = [(math.cos(t) * 0.21, 0.6 + math.sin(t) * 0.11) for t in [i / 40 * math.tau for i in range(20, 40)] + [0.0]]
        cap = [(x, max(y, 0.56)) for x, y in [(math.cos(t) * 0.21, 0.6 + math.sin(t) * 0.12) for t in [i / 40 * math.tau for i in range(41)]]]
        return [nut, cap], [nut + [nut[0]], cap + [cap[0]], [(0, 0.72), (0.03, 0.82)]]
    if kind == 'pine':
        polys, lines = [], []
        for row in range(6):
            y = 0.25 + row * 0.1
            w = 0.18 * math.sin(math.pi * (row + 0.7) / 6.6)
            for s in (-1, 0, 1):
                cx = s * w * 0.6
                sc = [(cx + math.cos(t) * w * 0.55, y + math.sin(t) * 0.07) for t in [i / 16 * math.tau for i in range(16)]]
                polys.append(sc)
                lines.append(sc + [sc[0]])
        return polys, lines
    polys, lines = [], []
    lines.append([(0, 0.0), (0, 0.85)])
    for k in range(7):
        y = 0.35 + k * 0.08
        for s in (1, -1):
            cx = s * (0.06 + 0.02 * (k % 2))
            c = [(cx + math.cos(t) * 0.05, y + math.sin(t) * 0.045) for t in [i / 12 * math.tau for i in range(12)]]
            polys.append(c)
            lines.append(c + [c[0]])
    return polys, lines


def render(kind):
    rng = random.Random({'oak': 31, 'pine': 41, 'sage': 51}[kind])
    sheet = Image.new('RGBA', (CELL * 16, CELL * 2), (0, 0, 0, 0))
    w_ink = int(0.022 / SPAN * CELL * SS)
    w_vein = int(0.014 / SPAN * CELL * SS)
    for index in range(16):
        big = CELL * SS
        fill, ink, veins = (Image.new('L', (big, big), 0) for _ in range(3))
        fd, idr, vd = ImageDraw.Draw(fill), ImageDraw.Draw(ink), ImageDraw.Draw(veins)
        if index == 13:
            polys, lines = bloom(kind)
            for p in polys:
                fd.polygon([px(x, y) for x, y in p], fill=255)
            for ln in lines:
                idr.line([px(x, y) for x, y in ln], fill=255, width=w_ink, joint='curve')
        elif index in (8, 9, 10, 11):
            curl = [(0.0, 0.0)] + [(0.18 * math.sin(t * 0.9) * (t / 6), t * 0.16) for t in range(1, 7)]
            idr.line([px(x, y) for x, y in curl], fill=255, width=w_ink, joint='curve')
        elif index in (12, 14, 15):
            for k in range(3 if index == 14 else 1):
                x, y = (-0.12 + 0.12 * k, 0.55 + 0.08 * (k % 2)) if index == 14 else (0.0, 0.55)
                r = 0.09 if index == 14 else 0.16
                fd.ellipse([px(x - r, y + r), px(x + r, y - r)], fill=255)
                idr.ellipse([px(x - r, y + r), px(x + r, y - r)], outline=255, width=w_ink)
        else:
            size = rng.uniform(0.85, 1.0)
            lean = rng.uniform(-12, 12)
            if kind == 'pine':
                polys, twig = pine_spray(size, lean, rng)
                for p in polys:
                    fd.polygon([px(x, y) for x, y in p], fill=255)
                idr.line([px(x, y) for x, y in twig], fill=255, width=w_ink, joint='curve')
                for p in polys[::3]:                                   # a few needles inked, not all
                    idr.line([px(*p[0]), px(*p[1])], fill=255, width=max(1, w_vein // 2))
            else:
                outline, vlines = (oak_leaf if kind == 'oak' else sage_leaf)(size, lean, rng)
                pts = [px(x, y) for x, y in outline]
                fd.polygon(pts, fill=255)
                idr.line(pts + [pts[0]], fill=255, width=w_ink if kind == 'oak' else int(w_ink * 0.7), joint='curve')
                for v in vlines:
                    vd.line([px(x, y) for x, y in v], fill=255, width=w_vein, joint='curve')
        fill = fill.resize((CELL, CELL), Image.LANCZOS)
        ink = ink.resize((CELL, CELL), Image.LANCZOS)
        veins = veins.resize((CELL, CELL), Image.LANCZOS)
        inner = fill.filter(ImageFilter.GaussianBlur(6 if kind != 'pine' else 2))
        cell = Image.new('RGBA', (CELL, CELL))
        cp, fp, ip, vp = cell.load(), fill.load(), inner.load(), veins.load()
        for y in range(CELL):
            for x in range(CELL):
                a = fp[x, y]
                if a == 0:
                    continue
                depth = ip[x, y] / 255.0
                tone = 0.70 + 0.30 * depth
                tone = min(1.0, tone + (0.22 if kind != 'sage' else 0.12) * vp[x, y] / 255.0)
                if kind == 'sage':
                    tone = min(1.0, tone + 0.05 * math.sin(x * 1.7 + y * 2.3))   # felted
                v = int(255 * tone)
                cp[x, y] = (v, v, v, a)
        sheet.paste(cell, (index * CELL, 0))
        ink_rgba = Image.new('RGBA', (CELL, CELL), (255, 255, 255, 0))
        ink_rgba.putalpha(ink)
        sheet.paste(ink_rgba, (index * CELL, CELL))
    sheet.save(os.path.join(ROOT, 'assets/sprites/hedge%s.png' % kind), optimize=True)
    print('hedge' + kind, sheet.size)


if __name__ == '__main__':
    for k in ('oak', 'pine', 'sage'):
        render(k)
