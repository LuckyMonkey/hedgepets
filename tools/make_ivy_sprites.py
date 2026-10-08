#!/usr/bin/env python3
"""Draw real ivy for the ivy profile: lobed leaves with a heart-shaped base, a fine dark outline and pale veins,
plus the white five-petal flower - the look in hedgepetsGoal.jpg. Same layout as bake_leaf_sprites.py (16 cells,
row 0 fill, row 1 ink, glyph units x -0.6..0.6, y -0.05..1.15, stalk at y = 0), so the renderer is unchanged.

    python3 tools/make_ivy_sprites.py      (after bake_leaf_sprites.py; overwrites assets/sprites/hedgeivy.png)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL, SS = 160, 4
X0, Y1, SPAN = -0.6, 1.15, 1.2


def px(x, y, s=SS):
    return ((x - X0) / SPAN * CELL * s, (Y1 - y) / SPAN * CELL * s)


def catmull(points, steps=10):
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[(i - 1) % n], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    return out


def ivy_leaf(lobes, size, lean, rng):
    """Outline of an ivy leaf in polar form: the radius swells into 3 or 5 rounded points (the top one longest),
    with a heart notch at the stalk. Returns (outline, vein centre, vein directions)."""
    R = 0.5 * size
    lean_r = math.radians(lean)
    lobe_set = [(0.0, 0.40), (62.0, 0.27), (-62.0, 0.27), (118.0, 0.12), (-118.0, 0.12)] if lobes == 5 else [(0.0, 0.40), (66.0, 0.24), (-66.0, 0.24)]
    lobe_set = [(math.radians(d) + lean_r + rng.uniform(-0.06, 0.06), h * rng.uniform(0.9, 1.1)) for d, h in lobe_set]
    pts = []
    for i in range(200):
        th = -math.pi + math.tau * i / 200.0                    # 0 = straight up, +-pi = the stalk
        bump = 0.0
        for at, height in lobe_set:
            d = abs((th - at + math.pi) % math.tau - math.pi)
            bump = max(bump, height * math.exp(-d / 0.30))       # pointed tips, broad rounded dips
        r = R * (0.64 + bump)
        r *= 1.0 - 0.45 * math.exp(-((abs(th) - math.pi) / 0.30) ** 2)   # the heart notch at the stalk
        pts.append((math.sin(th) * r, math.cos(th) * r))
    lowest = min(y for _, y in pts)
    cy = -lowest + 0.02
    pts = [(x, y + cy) for x, y in pts]
    tips = [(at, 1.0 + h) for at, h in lobe_set]
    return pts, (0.0, cy), tips


def flower(size):
    pts = []
    for i in range(5):
        a = math.tau * i / 5 + math.pi / 2
        for k in range(10):
            t = k / 9
            ang = a + (t - 0.5) * 1.15
            r = size * 0.36 * math.sin(math.pi * t) ** 0.6
            pts.append((math.cos(ang) * r, 0.62 + math.sin(ang) * r))
    return pts


def main():
    rng = random.Random(1977)
    sheet = Image.new('RGBA', (CELL * 16, CELL * 2), (0, 0, 0, 0))
    variants = [(5, 1.0, 0), (5, 0.95, -8), (3, 1.0, 6), (5, 0.9, 10), (3, 0.92, -10), (5, 1.0, 4), (5, 0.96, -4), (3, 1.0, 0)]
    for index in range(16):
        big = CELL * SS
        fill = Image.new('L', (big, big), 0)
        ink = Image.new('L', (big, big), 0)
        veins = Image.new('L', (big, big), 0)
        fd, idr, vd = ImageDraw.Draw(fill), ImageDraw.Draw(ink), ImageDraw.Draw(veins)
        w_ink = int(0.022 / SPAN * CELL * SS)
        w_vein = int(0.014 / SPAN * CELL * SS)
        if index == 13:                                                  # the white flower
            pts = [px(x, y) for x, y in flower(1.0)]
            fd.polygon(pts, fill=255)
            idr.line(pts + [pts[0]], fill=255, width=w_ink, joint='curve')
        elif index in (8, 9, 10, 11):                                    # stems, forks, tendrils
            curl = [(0.0, 0.0)] + [(0.18 * math.sin(t * 0.9) * (t / 6), t * 0.16) for t in range(1, 7)]
            idr.line([px(x, y) for x, y in curl], fill=255, width=w_ink, joint='curve')
        elif index in (12, 14, 15):                                      # bud, berries, pod
            for k in range(3 if index == 14 else 1):
                x, y = (-0.12 + 0.12 * k, 0.55 + 0.08 * (k % 2)) if index == 14 else (0.0, 0.55)
                r = 0.09 if index == 14 else 0.16
                fd.ellipse([px(x - r, y + r), px(x + r, y - r)], fill=255)
                idr.ellipse([px(x - r, y + r), px(x + r, y - r)], outline=255, width=w_ink)
        else:
            lobes, size, lean = variants[index % len(variants)]
            outline, (cx, cy), tips = ivy_leaf(lobes, size, lean, rng)
            pts = [px(x, y) for x, y in outline]
            fd.polygon(pts, fill=255)
            idr.line(pts + [pts[0]], fill=255, width=w_ink, joint='curve')
            for a, l in tips:                                          # pale veins from the centre to each lobe
                vd.line([px(0.0, 0.03), px(cx, cy), px(cx + math.sin(a) * l * size * 0.40, cy + math.cos(a) * l * size * 0.40)], fill=255, width=w_vein, joint='curve')
        fill = fill.resize((CELL, CELL), Image.LANCZOS)
        ink = ink.resize((CELL, CELL), Image.LANCZOS)
        veins = veins.resize((CELL, CELL), Image.LANCZOS)
        inner = fill.filter(ImageFilter.GaussianBlur(6))
        cell = Image.new('RGBA', (CELL, CELL))
        cp, fp, ip, vp = cell.load(), fill.load(), inner.load(), veins.load()
        for y in range(CELL):
            for x in range(CELL):
                a = fp[x, y]
                if a == 0:
                    continue
                depth = ip[x, y] / 255.0
                tone = 0.70 + 0.30 * depth                            # darker toward the edge, lit in the middle
                tone = min(1.0, tone + 0.22 * vp[x, y] / 255.0)        # veins are paler than the leaf
                v = int(255 * tone)
                cp[x, y] = (v, v, v, a)
        sheet.paste(cell, (index * CELL, 0))
        ink_rgba = Image.new('RGBA', (CELL, CELL), (255, 255, 255, 0))
        ink_rgba.putalpha(ink)
        sheet.paste(ink_rgba, (index * CELL, CELL))
    sheet.save(os.path.join(ROOT, 'assets/sprites/hedgeivy.png'), optimize=True)
    print('hedgeivy', sheet.size)


if __name__ == '__main__':
    main()
