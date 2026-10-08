#!/usr/bin/env python3
"""Draw real ivy for the ivy profile: lobed leaves with a heart-shaped base, a fine dark outline and pale veins,
plus the white five-petal flower - the look in hedgepetsGoal.jpg. Same layout as bake_leaf_sprites.py (16 cells,
row 0 fill, row 1 ink, glyph units x -0.6..0.6, y -0.05..1.15, stalk at y = 0), so the renderer is unchanged.

    python3 tools/make_ivy_sprites.py      (after bake_leaf_sprites.py; overwrites assets/sprites/hedgeivy.png)
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL, SS = 160, 4
X0, Y1, SPAN = -0.6, 1.15, 1.2


def px(x, y, s=SS):
    return ((x - X0) / SPAN * CELL * s, (Y1 - y) / SPAN * CELL * s)


class HandInk:
    """Draws like a pen, not a ruler: lines wander a little, swell and thin with pressure, and closed outlines lift
    off once or twice. Same calls as ImageDraw (line, ellipse), so drawing code doesn't change."""

    def __init__(self, image, rng):
        self.d = ImageDraw.Draw(image)
        self.rng = rng

    def line(self, points, fill=255, width=1, joint=None):
        pts = [tuple(p) for p in points]
        if len(pts) < 2:
            return
        closed = pts[0] == pts[-1] or (abs(pts[0][0] - pts[-1][0]) < 1 and abs(pts[0][1] - pts[-1][1]) < 1)
        dense = []
        for a, b in zip(pts, pts[1:]):
            n = max(1, int(math.dist(a, b) / 5.0))
            for k in range(n):
                t = k / n
                dense.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        dense.append(pts[-1])
        r = self.rng
        ph = [r.uniform(0, math.tau) for _ in range(4)]
        amp = width * 0.35
        gaps = set()
        if closed and len(dense) > 40:
            for _ in range(r.randint(0, 2)):                     # where the pen lifted
                g0 = r.randrange(len(dense))
                gaps.update(range(g0, g0 + r.randint(3, 7)))
        prev = None
        for i, (x, y) in enumerate(dense):
            t = i / max(1, len(dense) - 1)
            wob = (math.sin(t * 17 + ph[0]) + 0.5 * math.sin(t * 41 + ph[1])) * amp
            q = (x + wob, y + (math.sin(t * 23 + ph[2]) + 0.5 * math.sin(t * 37 + ph[3])) * amp)
            w = width * (0.65 + 0.5 * (0.5 + 0.5 * math.sin(t * 9 + ph[1])))     # pressure
            if prev is not None and i not in gaps:
                self.d.line([prev, q], fill=fill, width=max(1, int(w)))
                rr = w * 0.5
                self.d.ellipse([q[0] - rr, q[1] - rr, q[0] + rr, q[1] + rr], fill=fill)
            prev = q

    def ellipse(self, box, outline=255, width=1, fill=None):
        (x0, y0), (x1, y1) = (box[0], box[1]) if len(box) == 2 else ((box[0], box[1]), (box[2], box[3]))
        cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, abs(x1 - x0) / 2, abs(y1 - y0) / 2
        pts = [(cx + math.cos(t) * rx, cy + math.sin(t) * ry) for t in [i / 40 * math.tau for i in range(41)]]
        self.line(pts, fill=outline, width=width)


def _noise(size, cells, rng, blur):
    """Smooth value noise in 0..1: a few random values upscaled (blooms) or fine grain (granulation)."""
    small = Image.new('L', (cells, cells))
    small.putdata([rng.randint(0, 255) for _ in range(cells * cells)])
    img = small.resize((size, size), Image.BICUBIC)
    return img.filter(ImageFilter.GaussianBlur(blur)) if blur else img


def watercolor_cell(fill, veins, rng, base=0.74):
    """A leaf painted in watercolour, as (tone 0..1, alpha 0..255) pixel access: the paint sits slightly off the ink
    line, pools into a darker wet edge where it dried, blooms paler and darker in soft patches, and takes the paper's
    grain; veins stay paler. Returns an 'LA' image (L = tone, A = coverage)."""
    dx, dy = rng.randint(-2, 2), rng.randint(-2, 2)
    paint = ImageChops.offset(fill, dx, dy)                              # misregistered with the line
    paint = paint.filter(ImageFilter.MaxFilter(3)) if rng.random() < 0.5 else paint.filter(ImageFilter.MinFilter(3))
    soft = paint.filter(ImageFilter.GaussianBlur(4))
    bloom = _noise(CELL, 5, rng, 3)
    grain = _noise(CELL, CELL // 2, rng, 0.6)
    out = Image.new('LA', (CELL, CELL))
    op, pp, sp, bp, gp, vp = out.load(), paint.load(), soft.load(), bloom.load(), grain.load(), veins.load()
    for y in range(CELL):
        for x in range(CELL):
            a = pp[x, y]
            if a == 0:
                continue
            depth = sp[x, y] / 255.0
            wet_edge = math.exp(-((depth - 0.5) / 0.14) ** 2)               # a darker rim just inside the edge
            tone = base + 0.18 * depth - 0.2 * wet_edge
            tone *= 0.86 + 0.24 * bp[x, y] / 255.0                         # blooms
            tone *= 0.93 + 0.1 * gp[x, y] / 255.0                          # paper grain
            tone = min(1.0, tone + 0.28 * vp[x, y] / 255.0)                # pale veins
            op[x, y] = (int(255 * max(0.0, min(1.0, tone))), a)
    return out


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
        fd, idr, vd = ImageDraw.Draw(fill), HandInk(ink, rng), ImageDraw.Draw(veins)
        w_ink = int(0.016 / SPAN * CELL * SS)        # a fine pen line
        w_vein = int(0.014 / SPAN * CELL * SS)
        centre = None
        if index == 13:                                                  # the white flower, with a yellow eye
            pts = [px(x, y) for x, y in flower(1.0)]
            fd.polygon(pts, fill=255)
            idr.line(pts + [pts[0]], fill=255, width=w_ink, joint='curve')
            centre = Image.new('L', (big, big), 0)
            ImageDraw.Draw(centre).ellipse([px(-0.085, 0.705), px(0.085, 0.535)], fill=255)
            idr.ellipse([px(-0.085, 0.705), px(0.085, 0.535)], outline=255, width=max(1, w_ink // 2))
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
        centre = centre.resize((CELL, CELL), Image.LANCZOS) if centre is not None else None
        ink = ink.resize((CELL, CELL), Image.LANCZOS)
        veins = veins.resize((CELL, CELL), Image.LANCZOS)
        wc = watercolor_cell(fill, veins, rng)
        cell = Image.new('RGBA', (CELL, CELL))
        cp, wp = cell.load(), wc.load()
        for y in range(CELL):
            for x in range(CELL):
                tone, a = wp[x, y]
                if a == 0:
                    continue
                if index == 13:                                       # the flower keeps its own colours
                    c = centre.getpixel((x, y)) / 255.0
                    petal = (255, 252, 242)
                    yellow = (236, 190, 60)
                    k = 0.8 + 0.2 * tone / 255.0
                    cp[x, y] = tuple(int((petal[i] * (1 - c) + yellow[i] * c) * k) for i in range(3)) + (a,)
                    continue
                cp[x, y] = (tone, tone, tone, a)
        sheet.paste(cell, (index * CELL, 0))
        ink_rgba = Image.new('RGBA', (CELL, CELL), (255, 255, 255, 0))
        ink_rgba.putalpha(ink)
        sheet.paste(ink_rgba, (index * CELL, CELL))
    sheet.save(os.path.join(ROOT, 'assets/sprites/hedgeivy.png'), optimize=True)
    print('hedgeivy', sheet.size)


if __name__ == '__main__':
    main()
