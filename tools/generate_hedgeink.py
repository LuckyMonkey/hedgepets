#!/usr/bin/env python3
"""Generate the original HedgePets botanical font and its fill geometry.

The glyphs are sampled from small parametric curves below.  No external art,
font, or binary input is used.  The JSON is the same source geometry that the
Godot renderer uses for watercolor fills; the TTF contains ink rings and veins.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path
from typing import Iterable, Sequence


ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "fonts"
FONT_DIR.mkdir(parents=True, exist_ok=True)
FONT_PATH = FONT_DIR / "HedgeInk.ttf"
GEOMETRY_PATH = FONT_DIR / "hedgeink_geometry.json"

EM = 1000
FIRST_CODEPOINT = 0xE000
ADVANCE = 900

Point = tuple[float, float]


def rotate(point: Point, angle: float) -> Point:
    c = math.cos(angle)
    s = math.sin(angle)
    return point[0] * c - point[1] * s, point[0] * s + point[1] * c


def translate(points: Sequence[Point], offset: Point, scale: float = 1.0, angle: float = 0.0) -> list[Point]:
    return [
        (rotate((point[0] * scale, point[1] * scale), angle)[0] + offset[0],
         rotate((point[0] * scale, point[1] * scale), angle)[1] + offset[1])
        for point in points
    ]


def leaf_shape(width: float, power: float, bend: float, skew: float, asymmetry: float, phase: float) -> tuple[list[Point], list[list[Point]]]:
    """Return a closed leaf contour and its center/secondary vein paths."""
    left: list[Point] = []
    right: list[Point] = []
    centerline: list[Point] = []
    samples = 18
    for index in range(samples):
        u = index / (samples - 1)
        center_x = bend * math.sin(math.pi * u) + 0.018 * math.sin(math.pi * 2.0 * u + phase)
        width_at_u = width * (math.sin(math.pi * u) ** power)
        left_width = width_at_u * (1.0 + asymmetry * (u - 0.5))
        right_width = width_at_u * (1.0 - asymmetry * (u - 0.5))
        centerline.append((center_x, u))
        left.append((center_x - left_width * (1.0 + skew * u), u))
        right.append((center_x + right_width * (1.0 - skew * u), u))

    contour = left + list(reversed(right))
    veins: list[list[Point]] = [centerline]
    for u in (0.34, 0.56, 0.73):
        center_x = bend * math.sin(math.pi * u) + 0.018 * math.sin(math.pi * 2.0 * u + phase)
        width_at_u = width * (math.sin(math.pi * u) ** power)
        veins.append([(center_x, u), (center_x - width_at_u * 0.68, u + 0.13)])
        veins.append([(center_x, u), (center_x + width_at_u * 0.68, u + 0.13)])
    return contour, veins


def circle(center: Point, radius: float, segments: int = 18) -> list[Point]:
    return [
        (center[0] + math.cos(math.tau * i / segments) * radius,
         center[1] + math.sin(math.tau * i / segments) * radius)
        for i in range(segments)
    ]


def ellipse(center: Point, radii: Point, segments: int = 20) -> list[Point]:
    return [
        (center[0] + math.cos(math.tau * i / segments) * radii[0],
         center[1] + math.sin(math.tau * i / segments) * radii[1])
        for i in range(segments)
    ]


def stem_curve(kind: str = "straight") -> list[Point]:
    points: list[Point] = []
    for index in range(18):
        u = index / 17.0
        if kind == "curved":
            x = 0.13 * math.sin(math.pi * u * 0.9)
        elif kind == "tendril":
            x = 0.18 * math.sin(math.tau * 1.1 * u) * u
        else:
            x = 0.02 * math.sin(math.pi * u)
        points.append((x, u))
    return points


def add_leaf(parts: dict, params: tuple[float, float, float, float, float, float], offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    contour, veins = leaf_shape(*params)
    parts["fill"].append(translate(contour, offset, scale, angle))
    parts["ink"].append(translate(contour, offset, scale, angle))
    parts["ink"].extend(translate(vein, offset, scale, angle) for vein in veins)


def add_stem(parts: dict, path: Sequence[Point], offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    parts["ink"].append(translate(path, offset, scale, angle))


LEAF_SIMPLE = (0.32, 0.82, 0.018, 0.04, 0.06, 0.3)
LEAF_NARROW = (0.22, 0.62, -0.028, 0.02, -0.08, 1.2)
LEAF_ROUND = (0.38, 1.38, 0.018, -0.02, 0.1, 2.2)
LEAF_POINTED = (0.30, 0.55, -0.018, 0.06, -0.12, 0.7)
LEAF_BENT = (0.30, 0.86, 0.115, 0.03, 0.24, 1.8)


def glyph(name: str, category: str) -> dict:
    return {"name": name, "category": category, "fill": [], "ink": []}


def build_glyphs() -> list[dict]:
    glyphs: list[dict] = []

    item = glyph("leaf_simple", "leaf")
    add_leaf(item, LEAF_SIMPLE)
    glyphs.append(item)

    item = glyph("leaf_narrow", "leaf")
    add_leaf(item, LEAF_NARROW)
    glyphs.append(item)

    item = glyph("leaf_round", "leaf")
    add_leaf(item, LEAF_ROUND)
    glyphs.append(item)

    item = glyph("leaf_pointed", "leaf")
    add_leaf(item, LEAF_POINTED)
    glyphs.append(item)

    item = glyph("leaf_bent", "leaf")
    add_leaf(item, LEAF_BENT)
    glyphs.append(item)

    item = glyph("leaf_pair", "cluster")
    add_stem(item, stem_curve())
    add_leaf(item, LEAF_SIMPLE, (-0.055, 0.23), 0.62, -0.78)
    add_leaf(item, LEAF_NARROW, (0.045, 0.46), 0.60, 0.72)
    glyphs.append(item)

    item = glyph("leaf_pair_alternating", "cluster")
    add_stem(item, stem_curve("curved"))
    add_leaf(item, LEAF_POINTED, (-0.06, 0.28), 0.56, -0.92)
    add_leaf(item, LEAF_ROUND, (0.07, 0.53), 0.55, 0.80)
    glyphs.append(item)

    item = glyph("three_leaf_cluster", "cluster")
    add_stem(item, stem_curve("curved"))
    add_leaf(item, LEAF_SIMPLE, (-0.05, 0.20), 0.48, -0.92)
    add_leaf(item, LEAF_NARROW, (0.05, 0.40), 0.48, 0.78)
    add_leaf(item, LEAF_BENT, (-0.01, 0.61), 0.48, -0.28)
    glyphs.append(item)

    item = glyph("stem_segment", "stem")
    add_stem(item, stem_curve())
    glyphs.append(item)

    item = glyph("curved_stem", "stem")
    add_stem(item, stem_curve("curved"))
    glyphs.append(item)

    item = glyph("branch_fork", "branch")
    add_stem(item, [(0.0, 0.0), (0.0, 0.96)])
    add_stem(item, [(0.0, 0.45), (-0.28, 0.82)])
    add_stem(item, [(0.0, 0.58), (0.25, 0.92)])
    glyphs.append(item)

    item = glyph("tendril", "stem")
    add_stem(item, stem_curve("tendril"))
    glyphs.append(item)

    item = glyph("bud", "bud")
    add_stem(item, [(0.0, 0.0), (0.0, 0.56)])
    item["fill"].append(ellipse((0.0, 0.70), (0.14, 0.20), 18))
    item["ink"].append(item["fill"][-1])
    glyphs.append(item)

    item = glyph("simple_flower", "flower")
    add_stem(item, [(0.0, 0.0), (0.0, 0.55)])
    for index in range(5):
        angle = math.tau * index / 5.0
        add_leaf(item, LEAF_ROUND, (0.0, 0.67), 0.28, angle)
    item["fill"].append(circle((0.0, 0.67), 0.085, 14))
    item["ink"].append(item["fill"][-1])
    glyphs.append(item)

    item = glyph("berry_cluster", "berry")
    add_stem(item, [(0.0, 0.0), (0.0, 0.63)])
    for center in ((-0.13, 0.64), (0.08, 0.76), (0.18, 0.57)):
        item["fill"].append(circle(center, 0.095, 16))
        item["ink"].append(item["fill"][-1])
    glyphs.append(item)

    item = glyph("seed_pod", "seed")
    add_stem(item, [(0.0, 0.0), (0.0, 0.54)])
    item["fill"].append(ellipse((0.0, 0.70), (0.13, 0.27), 20))
    item["ink"].append(item["fill"][-1])
    item["ink"].append([(0.0, 0.49), (0.0, 0.90)])
    glyphs.append(item)

    return glyphs


def lobed_leaf_shape(width: float, bend: float, lobes: int, phase: float) -> tuple[list[Point], list[list[Point]]]:
    """Broad angular ivy leaf with deterministic side lobes."""
    left: list[Point] = []
    right: list[Point] = []
    centerline: list[Point] = []
    samples = 24
    for index in range(samples):
        u = index / (samples - 1)
        center_x = bend * math.sin(math.pi * u) + 0.015 * math.sin(math.pi * 2.0 * u + phase)
        base_width = width * (math.sin(math.pi * u) ** 0.70)
        lobe = 0.78 + 0.30 * (0.5 + 0.5 * math.sin(math.pi * lobes * u + phase))
        left.append((center_x - base_width * lobe * (1.0 + 0.08 * u), u))
        right.append((center_x + base_width * (1.04 - 0.08 * u) * lobe, u))
        centerline.append((center_x, u))
    veins: list[list[Point]] = [centerline]
    for u in (0.28, 0.48, 0.68, 0.82):
        center_x = bend * math.sin(math.pi * u)
        width_at_u = width * (math.sin(math.pi * u) ** 0.70)
        veins.append([(center_x, u), (center_x - width_at_u * 0.75, u + 0.11)])
        veins.append([(center_x, u), (center_x + width_at_u * 0.75, u + 0.11)])
    return left + list(reversed(right)), veins


def add_lobed_leaf(parts: dict, width: float, bend: float, lobes: int, phase: float, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    contour, veins = lobed_leaf_shape(width, bend, lobes, phase)
    parts["fill"].append(translate(contour, offset, scale, angle))
    parts["ink"].append(translate(contour, offset, scale, angle))
    parts["ink"].extend(translate(vein, offset, scale, angle) for vein in veins)


def add_clover_rosette(parts: dict, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    add_stem(parts, [(0.0, 0.0), (0.0, 0.52)], offset, scale, angle)
    for center in ((-0.14, 0.65), (0.14, 0.65), (0.0, 0.80)):
        petal = translate(circle(center, 0.14, 16), offset, scale, angle)
        parts["fill"].append(petal)
        parts["ink"].append(petal)


def add_fern_frond(parts: dict, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    add_stem(parts, stem_curve("curved"), offset, scale, angle)
    for index in range(6):
        u = 0.18 + index * 0.12
        side = -1.0 if index % 2 == 0 else 1.0
        add_leaf(parts, LEAF_NARROW, (side * 0.025, u), 0.34 * scale, side * 1.04 + angle)


def add_moss_rosette(parts: dict, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0, height: float = 0.55, leaves: int = 9) -> None:
    """Star moss: a short stem crowned with a rosette of tiny pointed leaves."""
    add_stem(parts, [(0.0, 0.0), (0.02, height * 0.5), (0.0, height)], offset, scale, angle)
    for index in range(leaves):
        a = math.tau * index / leaves + 0.3
        tip = (math.sin(a) * 0.05, height + math.cos(a) * 0.02)
        contour, veins = leaf_shape(0.2, 0.7, 0.0, 0.0, 0.0, 0.6 + index)
        part = translate(contour, (0.0, 0.0), 0.3, 0.0)
        part = translate(part, (0.0, 0.0), 1.0, a * 0.55 - math.pi * 0.0 if False else (a - math.pi) * 0.5)
        part = translate(part, tip)
        parts["fill"].append(translate(part, offset, scale, angle))
        parts["ink"].append(translate(part, offset, scale, angle))


def add_feather_moss(parts: dict, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    """Feather moss: a curving stem with tiny alternate leaflets, like a fern a hundred times smaller."""
    stem = [(0.12 * math.sin(math.pi * u * 0.8), u * 0.95) for u in [i / 16 for i in range(17)]]
    add_stem(parts, stem, offset, scale, angle)
    for index in range(12):
        u = 0.15 + index * 0.065
        x = 0.12 * math.sin(math.pi * u * 0.8 / 0.95)
        side = -1.0 if index % 2 == 0 else 1.0
        contour, _ = leaf_shape(0.22, 0.7, 0.0, 0.0, 0.0, index)
        leaf = translate(contour, (x, u), 0.16 * (1.15 - u * 0.6), side * 1.1)
        parts["fill"].append(translate(leaf, offset, scale, angle))
        parts["ink"].append(translate(leaf, offset, scale, angle))


def add_sporophyte(parts: dict, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0, height: float = 0.85) -> None:
    """A moss's 'flower': a hair-thin stalk with a capsule on top."""
    add_stem(parts, [(0.0, 0.0), (0.015, height * 0.5), (0.03, height)], offset, scale, angle)
    capsule = translate(ellipse((0.03, height + 0.06), (0.045, 0.085), 14), offset, scale, angle)
    parts["fill"].append(capsule)
    parts["ink"].append(capsule)


def holly_leaf_shape(width: float, spikes: int, bend: float, phase: float) -> tuple[list[Point], list[list[Point]]]:
    """A glossy holly leaf: an oval with sharp spines along the edge and a spined tip."""
    left: list[Point] = []
    right: list[Point] = []
    centerline: list[Point] = []
    samples = 60
    for index in range(samples):
        u = index / (samples - 1)
        center_x = bend * math.sin(math.pi * u)
        base = width * (math.sin(math.pi * min(1.0, u * 1.02)) ** 0.75)
        wave = abs(math.sin(math.pi * spikes * u + phase))
        spike = 1.0 + 0.32 * wave ** 6 - 0.12 * (1.0 - wave)       # sharp points, scooped between
        left.append((center_x - base * spike, u))
        right.append((center_x + base * spike, u))
        centerline.append((center_x, u))
    left.append((bend * 0.0, 1.05))
    return left + list(reversed(right)), [centerline]


def add_holly_leaf(parts: dict, width: float = 0.3, spikes: int = 3, bend: float = 0.03, phase: float = 0.4, offset: Point = (0.0, 0.0), scale: float = 1.0, angle: float = 0.0) -> None:
    contour, veins = holly_leaf_shape(width, spikes, bend, phase)
    parts["fill"].append(translate(contour, offset, scale, angle))
    parts["ink"].append(translate(contour, offset, scale, angle))
    parts["ink"].extend(translate(vein, offset, scale, angle) for vein in veins)


def add_berries(parts: dict, centers: Sequence[Point], radius: float) -> None:
    for center in centers:
        parts["fill"].append(circle(center, radius, 16))
        parts["ink"].append(parts["fill"][-1])


def build_moss_holly_glyphs(species: str) -> list[dict]:
    """HedgeMoss and HedgeHolly: the same 16 semantic slots (0-7 leaves and clusters, 8-11 stems, 12 bud, 13 the
    bloom, 14 berries, 15 seed), with their own plant."""
    glyphs: list[dict] = []
    moss = species == "HedgeMoss"

    def slot(name: str, category: str, draw) -> None:
        item = glyph(name, category)
        draw(item)
        glyphs.append(item)

    if moss:
        slot("leaf_simple", "leaf", lambda i: add_moss_rosette(i))
        slot("leaf_narrow", "leaf", lambda i: add_moss_rosette(i, height=0.75, leaves=7))
        slot("leaf_round", "leaf", lambda i: add_moss_rosette(i, height=0.42, leaves=11))
        slot("leaf_pointed", "leaf", lambda i: add_feather_moss(i))
        slot("leaf_bent", "leaf", lambda i: add_feather_moss(i, angle=0.25))
        slot("leaf_pair", "cluster", lambda i: (add_moss_rosette(i, (-0.14, 0.0), 0.9, 0.18), add_moss_rosette(i, (0.14, 0.0), 0.8, -0.2)))
        slot("leaf_pair_alternating", "cluster", lambda i: (add_feather_moss(i, (-0.08, 0.0), 0.9, 0.2), add_moss_rosette(i, (0.16, 0.0), 0.7, -0.25)))
        slot("three_leaf_cluster", "cluster", lambda i: [add_moss_rosette(i, (x, 0.0), sc, a) for x, sc, a in ((-0.2, 0.7, 0.3), (0.0, 0.95, 0.0), (0.2, 0.75, -0.3))])
    else:
        slot("leaf_simple", "leaf", lambda i: add_holly_leaf(i))
        slot("leaf_narrow", "leaf", lambda i: add_holly_leaf(i, 0.24, 4, -0.03, 1.1))
        slot("leaf_round", "leaf", lambda i: add_holly_leaf(i, 0.34, 3, 0.05, 2.0))
        slot("leaf_pointed", "leaf", lambda i: add_holly_leaf(i, 0.27, 3, -0.06, 0.9))
        slot("leaf_bent", "leaf", lambda i: add_holly_leaf(i, 0.3, 4, 0.11, 1.7))
        slot("leaf_pair", "cluster", lambda i: (add_stem(i, stem_curve("curved")), add_holly_leaf(i, 0.26, 3, 0.03, 0.4, (0.0, 0.3), 0.7, 0.8), add_holly_leaf(i, 0.26, 3, -0.03, 1.4, (0.0, 0.45), 0.7, -0.7)))
        slot("leaf_pair_alternating", "cluster", lambda i: (add_holly_leaf(i, 0.28, 3, 0.03, 0.4, (0.0, 0.0), 0.9, 0.0), add_berries(i, ((-0.1, 0.18), (0.04, 0.24), (0.12, 0.14)), 0.065)))
        slot("three_leaf_cluster", "cluster", lambda i: [add_holly_leaf(i, 0.26, 3, 0.02, ph, (0.0, 0.08), 0.75, a) for a, ph in ((-0.8, 0.3), (0.0, 1.2), (0.8, 2.1))])
    slot("stem_segment", "stem", lambda i: add_stem(i, stem_curve("straight")))
    slot("curved_stem", "stem", lambda i: add_stem(i, stem_curve("curved")))
    slot("branch_fork", "branch", lambda i: (add_stem(i, [(0.0, 0.0), (0.0, 0.96)]), add_stem(i, [(0.0, 0.45), (-0.28, 0.82)])))
    slot("tendril", "stem", lambda i: add_stem(i, stem_curve("tendril")))
    if moss:
        slot("bud", "bud", lambda i: add_sporophyte(i, height=0.45))
        slot("simple_flower", "flower", lambda i: [add_sporophyte(i, (x, 0.0), 1.0, a, h) for x, a, h in ((-0.1, 0.25, 0.7), (0.0, 0.0, 0.85), (0.1, -0.22, 0.75))])
        slot("berry_cluster", "berry", lambda i: [add_sporophyte(i, (x, 0.0), 1.0, a, 0.6) for x, a in ((-0.06, 0.15), (0.06, -0.15))])
        slot("seed_pod", "seed", lambda i: add_sporophyte(i, height=0.95))
    else:
        slot("bud", "bud", lambda i: add_berries(i, ((0.0, 0.62),), 0.1))
        slot("simple_flower", "flower", lambda i: (add_stem(i, [(0.0, 0.0), (0.0, 0.5)]), add_berries(i, ((-0.11, 0.6), (0.08, 0.68), (0.13, 0.5), (-0.02, 0.45)), 0.09)))
        slot("berry_cluster", "berry", lambda i: add_berries(i, ((-0.13, 0.64), (0.08, 0.76), (0.18, 0.57)), 0.095))
        slot("seed_pod", "seed", lambda i: add_berries(i, ((0.0, 0.6), (0.1, 0.48)), 0.08))
    return glyphs


def build_species_glyphs(species: str) -> list[dict]:
    """Build the shared semantic slots with species-specific geometry."""
    if species == "HedgeInk":
        return build_glyphs()
    if species in ("HedgeMoss", "HedgeHolly"):
        return build_moss_holly_glyphs(species)

    glyphs: list[dict] = []
    if species == "HedgeIvy":
        leaf_a = lambda item: add_lobed_leaf(item, 0.38, 0.02, 3, 0.2)
        leaf_b = lambda item: add_lobed_leaf(item, 0.31, 0.10, 4, 1.1)
        leaf_c = lambda item: add_lobed_leaf(item, 0.43, -0.03, 3, 2.0)
    elif species == "HedgeJasmine":
        leaf_a = lambda item: add_leaf(item, LEAF_POINTED)
        leaf_b = lambda item: add_leaf(item, LEAF_NARROW)
        leaf_c = lambda item: add_leaf(item, (0.28, 1.10, 0.05, 0.0, 0.04, 2.4))
    elif species == "HedgeClover":
        leaf_a = lambda item: add_clover_rosette(item)
        leaf_b = lambda item: add_clover_rosette(item, (0.0, 0.03), 0.82, 0.05)
        leaf_c = lambda item: add_leaf(item, (0.26, 1.25, 0.0, 0.0, 0.0, 1.4))
    else:  # HedgeFern
        leaf_a = lambda item: add_leaf(item, LEAF_NARROW)
        leaf_b = lambda item: add_leaf(item, (0.18, 0.55, -0.02, 0.0, -0.06, 0.7))
        leaf_c = lambda item: add_leaf(item, (0.20, 0.70, 0.03, 0.01, 0.05, 1.7))

    item = glyph("leaf_simple", "leaf")
    leaf_a(item)
    glyphs.append(item)
    item = glyph("leaf_narrow", "leaf")
    leaf_b(item)
    glyphs.append(item)
    item = glyph("leaf_round", "leaf")
    leaf_c(item)
    glyphs.append(item)
    item = glyph("leaf_pointed", "leaf")
    add_leaf(item, LEAF_POINTED if species != "HedgeIvy" else (0.32, 0.62, 0.03, 0.05, -0.08, 0.4))
    glyphs.append(item)
    item = glyph("leaf_bent", "leaf")
    add_leaf(item, LEAF_BENT if species != "HedgeClover" else (0.25, 0.95, 0.08, 0.0, 0.1, 2.1))
    glyphs.append(item)

    item = glyph("leaf_pair", "cluster")
    add_stem(item, stem_curve("curved" if species in ("HedgeIvy", "HedgeJasmine") else "straight"))
    leaf_a(item)
    add_leaf(item, LEAF_NARROW, (0.05, 0.44), 0.58, 0.76)
    glyphs.append(item)
    item = glyph("leaf_pair_alternating", "cluster")
    add_stem(item, stem_curve("curved"))
    add_leaf(item, LEAF_POINTED, (-0.06, 0.27), 0.58, -0.84)
    leaf_b(item)
    glyphs.append(item)
    item = glyph("three_leaf_cluster", "cluster")
    if species == "HedgeClover":
        add_clover_rosette(item, scale=0.9)
        add_clover_rosette(item, (0.0, 0.23), 0.72, 0.0)
    elif species == "HedgeFern":
        add_fern_frond(item, scale=0.80)
    else:
        add_stem(item, stem_curve("curved"))
        leaf_a(item)
        add_leaf(item, LEAF_NARROW, (0.05, 0.38), 0.50, 0.80)
        add_leaf(item, LEAF_BENT, (-0.02, 0.62), 0.48, -0.26)
    glyphs.append(item)

    item = glyph("stem_segment", "stem")
    add_stem(item, stem_curve("straight" if species == "HedgeClover" else "curved"))
    glyphs.append(item)
    item = glyph("curved_stem", "stem")
    add_stem(item, stem_curve("curved" if species != "HedgeFern" else "straight"))
    glyphs.append(item)
    item = glyph("branch_fork", "branch")
    add_stem(item, [(0.0, 0.0), (0.0, 0.96)])
    add_stem(item, [(0.0, 0.45), (-0.28, 0.82)])
    add_stem(item, [(0.0, 0.58), (0.25, 0.92)])
    glyphs.append(item)
    item = glyph("tendril", "stem")
    add_stem(item, stem_curve("tendril" if species != "HedgeFern" else "curved"))
    glyphs.append(item)
    item = glyph("bud", "bud")
    add_stem(item, [(0.0, 0.0), (0.0, 0.56)])
    item["fill"].append(ellipse((0.0, 0.70), (0.14, 0.20), 18))
    item["ink"].append(item["fill"][-1])
    glyphs.append(item)
    item = glyph("simple_flower", "flower")
    add_stem(item, [(0.0, 0.0), (0.0, 0.55)])
    for index in range(5):
        add_leaf(item, LEAF_ROUND if species != "HedgeFern" else LEAF_NARROW, (0.0, 0.67), 0.28, math.tau * index / 5.0)
    item["fill"].append(circle((0.0, 0.67), 0.085, 14))
    item["ink"].append(item["fill"][-1])
    glyphs.append(item)
    item = glyph("berry_cluster", "berry")
    add_stem(item, [(0.0, 0.0), (0.0, 0.63)])
    berry_scale = 0.78 if species == "HedgeClover" else 1.0
    for center in ((-0.13, 0.64), (0.08, 0.76), (0.18, 0.57)):
        item["fill"].append(circle((center[0] * berry_scale, center[1]), 0.095 * berry_scale, 16))
        item["ink"].append(item["fill"][-1])
    glyphs.append(item)
    item = glyph("seed_pod", "seed")
    if species == "HedgeFern":
        add_fern_frond(item, scale=0.72)
    else:
        add_stem(item, [(0.0, 0.0), (0.0, 0.54)])
        item["fill"].append(ellipse((0.0, 0.70), (0.13, 0.27), 20))
        item["ink"].append(item["fill"][-1])
        item["ink"].append([(0.0, 0.49), (0.0, 0.90)])
    glyphs.append(item)
    return glyphs


def clean_path(points: Iterable[Point]) -> list[Point]:
    output: list[Point] = []
    for point in points:
        rounded = (round(point[0], 6), round(point[1], 6))
        if not output or rounded != output[-1]:
            output.append(rounded)
    if len(output) > 1 and output[0] == output[-1]:
        output.pop()
    return output


def geometry_json(glyphs: list[dict], family: str) -> dict:
    result = []
    for index, item in enumerate(glyphs):
        result.append({
            "name": item["name"],
            "category": item["category"],
            "codepoint": FIRST_CODEPOINT + index,
            "fill": [[[round(x, 6), round(y, 6)] for x, y in clean_path(poly)] for poly in item["fill"]],
            "ink": [[[round(x, 6), round(y, 6)] for x, y in clean_path(path)] for path in item["ink"]],
        })
    return {
        "font": family,
        "units_per_em": EM,
        "first_codepoint": FIRST_CODEPOINT,
        "glyphs": result,
    }


def centroid(points: Sequence[Point]) -> Point:
    return (sum(point[0] for point in points) / len(points), sum(point[1] for point in points) / len(points))


def scale_around(points: Sequence[Point], factor: float) -> list[Point]:
    center = centroid(points)
    return [(center[0] + (point[0] - center[0]) * factor, center[1] + (point[1] - center[1]) * factor) for point in points]


def source_to_font(points: Sequence[Point]) -> list[tuple[int, int]]:
    return [(int(round(450 + x * 800)), int(round(100 + y * 760))) for x, y in clean_path(points)]


def stroke_band(points: Sequence[Point], width: float = 0.020) -> list[list[Point]]:
    bands: list[list[Point]] = []
    half = width * 0.5
    for start, end in zip(points, points[1:]):
        dx = end[0] - start[0]
        dy = end[1] - start[1]
        length = math.hypot(dx, dy) or 1.0
        nx = -dy / length * half
        ny = dx / length * half
        bands.append([(start[0] + nx, start[1] + ny), (end[0] + nx, end[1] + ny),
                      (end[0] - nx, end[1] - ny), (start[0] - nx, start[1] - ny)])
    return bands


def font_contours(item: dict) -> list[list[tuple[int, int]]]:
    contours: list[list[tuple[int, int]]] = []
    fill_paths = item["fill"]
    for polygon in fill_paths:
        outer = source_to_font(polygon)
        inner = source_to_font(list(reversed(scale_around(polygon, 0.80))))
        if len(outer) >= 3:
            contours.append(outer)
        if len(inner) >= 3:
            contours.append(inner)

    fill_ids = {id(poly) for poly in fill_paths}
    for path in item["ink"]:
        if id(path) in fill_ids:
            continue
        for band in stroke_band(path, 0.021 if len(path) > 3 else 0.026):
            converted = source_to_font(band)
            if len(converted) >= 3:
                contours.append(converted)
    if not contours:
        contours.append(source_to_font([(-0.05, 0.05), (0.05, 0.05), (0.05, 0.90), (-0.05, 0.90)]))
    return contours


def u16(value: int) -> bytes:
    return struct.pack(">H", value & 0xFFFF)


def i16(value: int) -> bytes:
    return struct.pack(">h", max(-32768, min(32767, int(value))))


def u32(value: int) -> bytes:
    return struct.pack(">I", value & 0xFFFFFFFF)


def i32(value: int) -> bytes:
    return struct.pack(">i", int(value))


def checksum(data: bytes) -> int:
    padded = data + b"\0" * ((4 - len(data) % 4) % 4)
    return sum(struct.unpack(f">{len(padded) // 4}I", padded)) & 0xFFFFFFFF


def build_glyph_data(contours: list[list[tuple[int, int]]]) -> bytes:
    if not contours:
        return i16(0) + i16(0) + i16(0) + i16(0) + i16(0) + u16(0)
    points = [point for contour in contours for point in contour]
    x_values = [point[0] for point in points]
    y_values = [point[1] for point in points]
    data = bytearray()
    data += i16(len(contours))
    data += i16(min(x_values)) + i16(min(y_values)) + i16(max(x_values)) + i16(max(y_values))
    end_points = []
    total = 0
    for contour in contours:
        total += len(contour)
        end_points.append(total - 1)
    for end_point in end_points:
        data += u16(end_point)
    data += u16(0)
    for _ in points:
        data += bytes([0x01])  # on-curve, uncompressed x/y deltas
    previous_x = 0
    previous_y = 0
    for x, y in points:
        data += i16(x - previous_x)
        previous_x = x
    for x, y in points:
        data += i16(y - previous_y)
        previous_y = y
    return bytes(data)


def build_cmap(num_glyphs: int) -> bytes:
    first = FIRST_CODEPOINT
    last = FIRST_CODEPOINT + num_glyphs - 2
    seg_count = 2
    search_power = 1
    while search_power * 2 <= seg_count:
        search_power *= 2
    search_range = search_power * 2
    entry_selector = int(math.log2(search_power))
    range_shift = seg_count * 2 - search_range
    format_4 = bytearray()
    # Format-4 Unicode subtables use language 0; the name table carries 0409.
    format_4 += u16(4) + u16(0) + u16(0) + u16(seg_count * 2)
    format_4 += u16(search_range) + u16(entry_selector) + u16(range_shift)
    format_4 += u16(last) + u16(0xFFFF) + u16(0)
    format_4 += u16(first) + u16(0xFFFF)
    # idDelta is signed in the spec but encoded modulo 16 bits.
    format_4 += u16((1 - first) & 0xFFFF) + u16(1)
    format_4 += u16(0) + u16(0)
    format_4[2:4] = u16(len(format_4))
    return u16(0) + u16(1) + u16(3) + u16(1) + u32(12) + bytes(format_4)


def build_name(family: str) -> bytes:
    names = {
        1: family,
        2: "Regular",
        4: f"{family} Regular",
        5: "Version 1.000",
        6: f"{family}-Regular",
    }
    records = []
    storage = bytearray()
    for name_id, value in names.items():
        encoded = value.encode("utf-16-be")
        records.append((3, 1, 0x0409, name_id, len(encoded), len(storage)))
        storage += encoded
    data = bytearray(u16(0) + u16(len(records)) + u16(6 + 12 * len(records)))
    for record in records:
        data += struct.pack(">HHHHHH", *record)
    data += storage
    return bytes(data)


def build_os2(num_glyphs: int) -> bytes:
    data = bytearray()
    data += u16(0) + i16(500) + u16(400) + u16(5) + u16(0)
    for value in (650, 0, 0, 150, 650, 0, 0, 150):
        data += i16(value)
    data += i16(50) + i16(250) + i16(0)
    data += bytes(10)
    data += u32(0) * 4
    data += b"HINK"
    data += u16(0x0040) + u16(FIRST_CODEPOINT) + u16(FIRST_CODEPOINT + num_glyphs - 2)
    data += i16(850) + i16(-150) + i16(100) + u16(900) + u16(200)
    return bytes(data)


def build_head(x_min: int, y_min: int, x_max: int, y_max: int, adjustment: int = 0) -> bytes:
    data = bytearray()
    data += u32(0x00010000) + u32(0x00010000) + u32(adjustment) + u32(0x5F0F3CF5)
    data += u16(0x000B) + u16(EM)
    data += struct.pack(">qq", 0, 0)
    data += i16(x_min) + i16(y_min) + i16(x_max) + i16(y_max)
    data += u16(0) + u16(8) + i16(2) + i16(1) + i16(0)
    return bytes(data)


def build_hhea(num_glyphs: int) -> bytes:
    data = bytearray()
    data += u32(0x00010000)
    data += i16(850) + i16(-150) + i16(100)
    data += u16(ADVANCE)
    data += i16(0) + i16(0) + i16(850)
    data += i16(1) + i16(0) + i16(0)
    data += i16(0) * 4
    data += i16(0) + u16(num_glyphs)
    return bytes(data)


def build_font(glyphs: list[dict], family: str) -> bytes:
    all_contours = [[source_to_font([(-0.34, 0.06), (0.34, 0.06), (0.34, 0.86), (-0.34, 0.86)])]]
    all_contours.extend(font_contours(item) for item in glyphs)
    glyph_datas = [build_glyph_data(contours) for contours in all_contours]
    loca = bytearray()
    glyf = bytearray()
    offsets = [0]
    max_points = 0
    max_contours = 0
    for contours, data in zip(all_contours, glyph_datas):
        max_points = max(max_points, sum(len(contour) for contour in contours))
        max_contours = max(max_contours, len(contours))
        glyf += data
        while len(glyf) % 4:
            glyf += b"\0"
        offsets.append(len(glyf))
    for offset in offsets:
        loca += u32(offset)

    num_glyphs = len(glyph_datas)
    tables: dict[str, bytes] = {
        "OS/2": build_os2(num_glyphs),
        "cmap": build_cmap(num_glyphs),
        "glyf": bytes(glyf),
        "head": build_head(-400, 0, 850, 900),
        "hhea": build_hhea(num_glyphs),
        "hmtx": b"".join(u16(ADVANCE) + i16(0) for _ in range(num_glyphs)),
        "loca": bytes(loca),
        "maxp": struct.pack(">IH13H", 0x00010000, num_glyphs, max_points, max_contours, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0),
        "name": build_name(family),
        "post": struct.pack(">IIhhhI4I", 0x00030000, 0, -100, 50, 0, 0, 0, 0, 0, 0),
    }
    tables["head"] = build_head(-400, 0, 850, 900, 0)

    tags = sorted(tables)
    num_tables = len(tags)
    power = 1
    while power * 2 <= num_tables:
        power *= 2
    search_range = power * 16
    entry_selector = int(math.log2(power))
    range_shift = num_tables * 16 - search_range
    header = bytearray(struct.pack(">IHHHH", 0x00010000, num_tables, search_range, entry_selector, range_shift))
    offset = 12 + 16 * num_tables
    records: list[tuple[str, int, int, int]] = []
    table_blob = bytearray()
    for tag in tags:
        while offset % 4:
            table_blob += b"\0"
            offset += 1
        value = tables[tag]
        records.append((tag, checksum(value), offset, len(value)))
        table_blob += value
        offset += len(value)
    for tag, table_sum, table_offset, table_length in records:
        header += tag.encode("ascii") + u32(table_sum) + u32(table_offset) + u32(table_length)
    font = bytearray(header + table_blob)
    head_offset = next(record[2] for record in records if record[0] == "head")
    adjustment = (0xB1B0AFBA - checksum(bytes(font))) & 0xFFFFFFFF
    font[head_offset + 8:head_offset + 12] = u32(adjustment)
    return bytes(font)


def main() -> None:
    import sys
    families = sys.argv[1:] or ["HedgeInk", "HedgeIvy", "HedgeJasmine", "HedgeClover", "HedgeFern", "HedgeMoss", "HedgeHolly"]
    for family in families:
        glyphs = build_species_glyphs(family)
        geometry_path = FONT_DIR / f"{family.lower()}_geometry.json"
        font_path = FONT_DIR / f"{family}.ttf"
        geometry_path.write_text(json.dumps(geometry_json(glyphs, family), indent=2) + "\n", encoding="utf-8")
        font_path.write_bytes(build_font(glyphs, family))
        print(f"generated {font_path} ({font_path.stat().st_size} bytes)")
        print(f"generated {geometry_path} ({len(glyphs)} glyphs)")


if __name__ == "__main__":
    main()
