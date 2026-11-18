#!/usr/bin/env python3
"""Build every Ennvo brand asset from the designer's SVG.

`tooling/brand_icon.svg` is the icon the designer supplied: a blue gradient
square with the white `e` of the brand. Everything the app shows is drawn
from it, at full quality, with the standard library only:

    assets/brand/ennvo_logo.png           the icon: gradient + white e
    assets/brand/ennvo_mark_white.png     the white e on transparent
    assets/brand/ennvo_logo_on_black.png  the white e on opaque black
    android/.../mipmap-*/ic_launcher.png  the legacy launcher icon
    android/.../ic_launcher_foreground    the adaptive foreground (the mark)
    android/.../ic_launcher_monochrome    the themed icon (the silhouette)
    ios/.../AppIcon.appiconset/*.png      every iOS size

The SVG only carries `M`, `C` and `Z`, so the path is flattened into line
segments and filled with the even-odd rule on a scanline rasteriser. It is
rendered at 2x and box filtered down, which gives smooth edges without a
single dependency.

Run it from the project root:

    python tooling/make_brand_from_svg.py
"""

from __future__ import annotations

import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from make_launcher_icons import (  # noqa: E402
    LEGACY_DENSITIES,
    RES,
    ROOT,
    place,
    read_png,
    resize,
    write_png,
)

SVG = os.path.join(ROOT, "tooling", "brand_icon.svg")
BRAND = os.path.join(ROOT, "assets", "brand")

LOGO = os.path.join(BRAND, "ennvo_logo.png")
MARK = os.path.join(BRAND, "ennvo_mark_white.png")
ON_BLACK = os.path.join(BRAND, "ennvo_logo_on_black.png")

IOS_ICON_DIR = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

# The icon is drawn at this size and every smaller size is filtered down from
# it, so a 48 px launcher icon is as clean as the 1024 px one.
MASTER = 1024

# The mark is rendered at twice the master and filtered down: that is what
# gives the curves their smooth edge.
SUPERSAMPLE = 2

# The share of the adaptive canvas the mark takes. The mark of the SVG sits
# in the middle of its square (it is about 55% wide and 62% high), so the
# whole canvas is scaled up a little: at 0.72 the "e" ends up the same share
# of the visible icon as it has in the legacy one, and it still fits inside
# the 66 dp safe circle Android promises.
ADAPTIVE_SCALE = 0.72


# ---------------------------------------------------------------------------
#  The gradient of the icon
# ---------------------------------------------------------------------------
def gradient_stops(svg: str) -> list[tuple[float, tuple[int, int, int]]]:
    """The stops of the background gradient of the SVG."""
    stops: list[tuple[float, tuple[int, int, int]]] = []
    for match in re.finditer(
        r'<stop\s+offset="([\d.]+)"\s+stop-color="#([0-9A-Fa-f]{6})"', svg
    ):
        offset = float(match.group(1))
        value = match.group(2)
        stops.append(
            (
                offset,
                (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)),
            )
        )
    if not stops:
        raise SystemExit("the SVG carries no gradient stops")
    return sorted(stops)


def gradient_color(
    stops: list[tuple[float, tuple[int, int, int]]], t: float
) -> tuple[int, int, int]:
    """The colour of the gradient at `t` (0..1), interpolated in sRGB."""
    t = max(0.0, min(1.0, t))
    for index in range(len(stops) - 1):
        start_offset, start = stops[index]
        end_offset, end = stops[index + 1]
        if start_offset <= t <= end_offset:
            span = end_offset - start_offset
            local = 0.0 if span <= 0 else (t - start_offset) / span
            return (
                int(round(start[0] + (end[0] - start[0]) * local)),
                int(round(start[1] + (end[1] - start[1]) * local)),
                int(round(start[2] + (end[2] - start[2]) * local)),
            )
    return stops[-1][1]


# ---------------------------------------------------------------------------
#  The path of the mark
# ---------------------------------------------------------------------------
NUMBER = re.compile(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?")


def flatten_path(path_data: str, scale: float) -> list[list[tuple[float, float]]]:
    """Turns the `M ... C ... Z` path into closed polylines of points."""
    tokens = re.findall(r"[MCZ]|-?\d*\.?\d+(?:[eE][-+]?\d+)?", path_data)

    contours: list[list[tuple[float, float]]] = []
    current: list[tuple[float, float]] = []
    x = y = 0.0
    index = 0

    def number() -> float:
        nonlocal index
        value = float(tokens[index]) * scale
        index += 1
        return value

    while index < len(tokens):
        token = tokens[index]

        if token == "M":
            index += 1
            if current:
                contours.append(current)
            x, y = number(), number()
            current = [(x, y)]
            continue

        if token == "C":
            index += 1
            x1, y1 = number(), number()
            x2, y2 = number(), number()
            x3, y3 = number(), number()

            # The number of line segments follows the size of the curve, so
            # a long sweep stays smooth and a small one stays cheap.
            length = (
                math.hypot(x1 - x, y1 - y)
                + math.hypot(x2 - x1, y2 - y1)
                + math.hypot(x3 - x2, y3 - y2)
            )
            steps = max(6, min(40, int(length / 2.0) + 1))
            start_x, start_y = x, y
            for step in range(1, steps + 1):
                t = step / steps
                mt = 1 - t
                px = (
                    mt * mt * mt * start_x
                    + 3 * mt * mt * t * x1
                    + 3 * mt * t * t * x2
                    + t * t * t * x3
                )
                py = (
                    mt * mt * mt * start_y
                    + 3 * mt * mt * t * y1
                    + 3 * mt * t * t * y2
                    + t * t * t * y3
                )
                current.append((px, py))
            x, y = x3, y3
            continue

        if token == "Z":
            index += 1
            if current:
                if current[0] != current[-1]:
                    current.append(current[0])
                contours.append(current)
                current = []
            continue

        # A stray number: skip it rather than losing the whole path.
        index += 1

    if current:
        contours.append(current)

    return contours


def rasterise(
    contours: list[list[tuple[float, float]]], size: int
) -> bytearray:
    """Fills the contours with the even-odd rule into an alpha mask."""
    alpha = bytearray(size * size)

    # The edges, as (y0, y1, x0, slope).
    edges: list[tuple[float, float, float, float]] = []
    for contour in contours:
        for index in range(len(contour) - 1):
            x0, y0 = contour[index]
            x1, y1 = contour[index + 1]
            if y0 == y1:
                continue
            edges.append((x0, y0, x1, y1))

    for row in range(size):
        sample = row + 0.5
        crossings: list[float] = []
        for x0, y0, x1, y1 in edges:
            if (y0 <= sample < y1) or (y1 <= sample < y0):
                crossings.append(x0 + (sample - y0) * (x1 - x0) / (y1 - y0))
        if not crossings:
            continue
        crossings.sort()
        base = row * size
        for index in range(0, len(crossings) - 1, 2):
            start = max(0, int(math.ceil(crossings[index] - 0.5)))
            end = min(size, int(math.ceil(crossings[index + 1] - 0.5)))
            for column in range(start, end):
                alpha[base + column] = 255

    return alpha


# ---------------------------------------------------------------------------
#  The assets
# ---------------------------------------------------------------------------
def build_mark(svg: str) -> tuple[int, bytearray]:
    """The white `e` on a transparent canvas, at MASTER size."""
    path_match = re.search(r'\sd="([^"]+)"', svg)
    if path_match is None:
        raise SystemExit("the SVG carries no path")

    big = MASTER * SUPERSAMPLE
    contours = flatten_path(path_match.group(1), big / 1024.0)
    mask = rasterise(contours, big)

    # Box filter 2x down: the edge of the mark becomes an alpha ramp instead
    # of a staircase.
    out = bytearray(MASTER * MASTER * 4)
    for y in range(MASTER):
        row0 = (y * 2) * big
        row1 = row0 + big
        for x in range(MASTER):
            total = (
                mask[row0 + x * 2]
                + mask[row0 + x * 2 + 1]
                + mask[row1 + x * 2]
                + mask[row1 + x * 2 + 1]
            )
            level = total // 4
            target = (y * MASTER + x) * 4
            if level:
                out[target] = 255
                out[target + 1] = 255
                out[target + 2] = 255
                out[target + 3] = level
    return MASTER, out


def build_logo(stops, mark: bytearray) -> bytearray:
    """The gradient square with the white mark over it."""
    out = bytearray(MASTER * MASTER * 4)
    for y in range(MASTER):
        for x in range(MASTER):
            red, green, blue = gradient_color(
                stops, (x / (MASTER - 1) + y / (MASTER - 1)) / 2
            )
            target = (y * MASTER + x) * 4
            out[target] = red
            out[target + 1] = green
            out[target + 2] = blue
            out[target + 3] = 255

    for index in range(MASTER * MASTER):
        source = index * 4
        level = mark[source + 3]
        if not level:
            continue
        amount = level / 255
        for channel in range(3):
            background = out[source + channel]
            out[source + channel] = int(background + (255 - background) * amount)
        out[source + 3] = 255

    return out


def build_on_black(mark: bytearray) -> bytearray:
    """The white mark on an opaque black tile."""
    out = bytearray(MASTER * MASTER * 4)
    for index in range(MASTER * MASTER):
        source = index * 4
        level = mark[source + 3]
        out[source] = level
        out[source + 1] = level
        out[source + 2] = level
        out[source + 3] = 255
    return out


def main() -> None:
    if not os.path.exists(SVG):
        raise SystemExit(f"missing the SVG: {SVG}")

    svg = open(SVG, encoding="utf-8").read()
    stops = gradient_stops(svg)

    print("drawing the mark ...")
    _, mark = build_mark(svg)

    print("drawing the icon ...")
    logo = build_logo(stops, mark)

    write_png(MARK, MASTER, MASTER, mark)
    print(f"  {os.path.relpath(MARK, ROOT)}")

    write_png(LOGO, MASTER, MASTER, logo)
    print(f"  {os.path.relpath(LOGO, ROOT)}")

    write_png(ON_BLACK, MASTER, MASTER, build_on_black(mark))
    print(f"  {os.path.relpath(ON_BLACK, ROOT)}")

    # --- the legacy launcher icon -------------------------------------
    for density, size in LEGACY_DENSITIES.items():
        scaled = resize(MASTER, MASTER, logo, size)
        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher.png")
        write_png(path, size, size, scaled)
        print(f"  {os.path.relpath(path, ROOT)}")

    # --- the adaptive icon -------------------------------------------
    for density, legacy in LEGACY_DENSITIES.items():
        factor = legacy / 48.0
        canvas_size = int(round(108 * factor))
        mark_size = max(8, int(round(canvas_size * ADAPTIVE_SCALE)))

        scaled = resize(MASTER, MASTER, mark, mark_size)
        canvas = bytearray(canvas_size * canvas_size * 4)
        place(canvas, canvas_size, scaled, mark_size, (canvas_size - mark_size) // 2)

        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher_foreground.png")
        write_png(path, canvas_size, canvas_size, canvas)
        print(f"  {os.path.relpath(path, ROOT)}")

        # The themed icon only carries the silhouette.
        silhouette = bytearray(mark_size * mark_size * 4)
        for index in range(mark_size * mark_size):
            source = index * 4
            silhouette[source] = 255
            silhouette[source + 1] = 255
            silhouette[source + 2] = 255
            silhouette[source + 3] = scaled[source + 3]
        themed = bytearray(canvas_size * canvas_size * 4)
        place(themed, canvas_size, silhouette, mark_size, (canvas_size - mark_size) // 2)

        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher_monochrome.png")
        write_png(path, canvas_size, canvas_size, themed)
        print(f"  {os.path.relpath(path, ROOT)}")

    # --- the iOS icons ------------------------------------------------
    if not os.path.isdir(IOS_ICON_DIR):
        print("  no iOS icon folder - skipped")
        return

    for name, size in IOS_ICONS.items():
        scaled = resize(MASTER, MASTER, logo, size)
        path = os.path.join(IOS_ICON_DIR, name)
        write_png(path, size, size, scaled)
        print(f"  {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
