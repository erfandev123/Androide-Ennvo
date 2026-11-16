#!/usr/bin/env python3
"""Build the brand assets of the Ennvo app.

`assets/brand/ennvo_logo.png` is the master file: the Ennvo mark - the white
"e" of the brand on its blue disc - exactly as the web app ships it in
`public/icon-512.png`.

Everything the app shows is derived from it:

    * `assets/brand/ennvo_logo_on_black.png` - the white mark on an opaque
      black tile. The splash screen shows the mark as a black tile, so it
      needs an opaque image: a transparent PNG over the purple splash would
      let the purple bleed through the strokes of the mark.

    * the Android launcher icons - the white mark on the Ennvo purple.

    * the iOS app icons - the white mark on the Ennvo purple.

The white mark is taken out of the master with the brightness of the pixel:
the disc is blue, the mark is white, and the edge between the two is
smooth because the alpha of the edge is kept.

Everything is written with the standard library only, so the assets can be
regenerated on any machine - including a CI runner - without a design tool.

Run it from the project root:

    python tooling/make_brand_assets.py
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from make_launcher_icons import (  # noqa: E402
    LEGACY_DENSITIES,
    RES,
    ROOT,
    SOURCE,
    place,
    read_png,
    resize,
    write_png,
)

BRAND = os.path.join(ROOT, "assets", "brand")
ON_BLACK = os.path.join(BRAND, "ennvo_logo_on_black.png")

IOS_ICON_DIR = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)

# The Ennvo purple. It is the background of the app icon and of the splash.
BRAND_PURPLE = (0x5B, 0x21, 0xB6)

# The iOS icons. iOS icons are never transparent, and the artwork must not
# fill the whole square - the system rounds the corners.
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

# The share of the canvas the mark takes.
ARTWORK = 0.66

# The brightness of the blue disc of the master. Everything brighter than
# that is the white mark.
#
# The disc is a gradient: its darkest blue has a smallest channel of about
# 90 and its lightest one of about 110, so the cut sits above both.
DISC_LEVEL = 150


# ---------------------------------------------------------------------------
#  The white mark out of the master
# ---------------------------------------------------------------------------
def mark_alpha(pixels: bytearray, index: int) -> int:
    """How much of the white mark a pixel of the master carries."""
    source = index * 4
    red = pixels[source]
    green = pixels[source + 1]
    blue = pixels[source + 2]
    alpha = pixels[source + 3]

    # The edge of the disc is a transparent blue, and its colour is bright
    # enough to pass the test below. The alpha of the master takes it out.
    if alpha == 0:
        return 0

    # The mark is white and the disc is blue, so the smallest of the three
    # channels tells them apart.
    level = min(red, green, blue)
    if level <= DISC_LEVEL:
        return 0
    span = 255 - DISC_LEVEL
    value = max(0, min(255, (level - DISC_LEVEL) * 255 / span))
    return int(value * alpha / 255)


def make_on_black(width: int, height: int, pixels: bytearray) -> None:
    """Writes the white mark on an opaque black tile.

    The tile has no alpha at all: it is the picture the splash shows, and it
    sits on the purple of the splash. A transparent PNG would let the
    purple bleed through the strokes of the mark.
    """
    out = bytearray(width * height * 4)
    for index in range(width * height):
        source = index * 4
        level = mark_alpha(pixels, index)
        out[source] = level
        out[source + 1] = level
        out[source + 2] = level
        out[source + 3] = 255

    write_png(ON_BLACK, width, height, out)
    print(f"  {os.path.relpath(ON_BLACK, ROOT)}")


def make_mark(
    width: int,
    height: int,
    pixels: bytearray,
    size: int,
) -> bytearray:
    """The white mark, scaled to `size`, on a transparent canvas."""
    scale = size / width
    out = bytearray(size * size * 4)

    for y in range(size):
        source_y = min(height - 1, int(y / scale))
        for x in range(size):
            source_x = min(width - 1, int(x / scale))
            index = source_y * width + source_x
            level = mark_alpha(pixels, index)
            target = (y * size + x) * 4
            out[target] = level
            out[target + 1] = level
            out[target + 2] = level
            out[target + 3] = 255 if level else 0

    return out


def purple_canvas(size: int) -> bytearray:
    """An opaque Ennvo purple square."""
    canvas = bytearray(size * size * 4)
    for index in range(size * size):
        offset = index * 4
        canvas[offset] = BRAND_PURPLE[0]
        canvas[offset + 1] = BRAND_PURPLE[1]
        canvas[offset + 2] = BRAND_PURPLE[2]
        canvas[offset + 3] = 255
    return canvas


def blend(canvas: bytearray, canvas_size: int, mark: bytearray, mark_size: int) -> None:
    """Draws the white mark over the purple with alpha blending."""
    offset = (canvas_size - mark_size) // 2
    for y in range(mark_size):
        for x in range(mark_size):
            source = (y * mark_size + x) * 4
            alpha = mark[source + 3]
            if alpha == 0:
                continue
            target = ((y + offset) * canvas_size + (x + offset)) * 4
            level = mark[source] / 255
            for channel in range(3):
                background = canvas[target + channel]
                canvas[target + channel] = int(
                    background + (255 - background) * level
                )
            canvas[target + 3] = 255


def make_ios_icons(width: int, height: int, pixels: bytearray) -> None:
    """Writes the iOS app icons: the white mark on the Ennvo purple."""
    if not os.path.isdir(IOS_ICON_DIR):
        print("  no iOS icon folder - skipped")
        return

    for name, size in IOS_ICONS.items():
        mark_size = max(8, int(round(size * ARTWORK)))
        mark = make_mark(width, height, pixels, mark_size)

        canvas = purple_canvas(size)
        blend(canvas, size, mark, mark_size)

        path = os.path.join(IOS_ICON_DIR, name)
        write_png(path, size, size, canvas)
        print(f"  {os.path.relpath(path, ROOT)}")


def main() -> None:
    if not os.path.exists(SOURCE):
        raise SystemExit(f"missing source image: {SOURCE}")

    width, height, pixels = read_png(SOURCE)
    print(f"source: {width}x{height}")

    make_on_black(width, height, pixels)
    make_ios_icons(width, height, pixels)

    # --- the legacy launcher icon -------------------------------------
    # The mark on the purple, the way the app opens.
    for density, size in LEGACY_DENSITIES.items():
        mark_size = max(8, int(round(size * ARTWORK)))
        mark = make_mark(width, height, pixels, mark_size)

        canvas = purple_canvas(size)
        blend(canvas, size, mark, mark_size)

        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher.png")
        write_png(path, size, size, canvas)
        print(f"  {os.path.relpath(path, ROOT)}")

    # --- the adaptive icon ---------------------------------------------
    # The foreground lives on a 108dp canvas and only the middle 72dp is
    # guaranteed to be visible, so the mark is drawn at 62% of it.
    canvas_dp = 108
    scale = 0.62

    for density, legacy in LEGACY_DENSITIES.items():
        factor = legacy / 48.0
        canvas_size = int(round(canvas_dp * factor))
        mark_size = max(8, int(round(canvas_size * scale)))

        mark = make_mark(width, height, pixels, mark_size)
        canvas = bytearray(canvas_size * canvas_size * 4)
        place(canvas, canvas_size, mark, mark_size, (canvas_size - mark_size) // 2)

        path = os.path.join(
            RES, f"mipmap-{density}", "ic_launcher_foreground.png"
        )
        write_png(path, canvas_size, canvas_size, canvas)
        print(f"  {os.path.relpath(path, ROOT)}")

        # The themed icon is the silhouette of the mark.
        themed = bytearray(canvas_size * canvas_size * 4)
        for index in range(mark_size * mark_size):
            source = index * 4
            alpha = mark[source + 3]
            target = source
            themed[target] = 255
            themed[target + 1] = 255
            themed[target + 2] = 255
            themed[target + 3] = alpha
        placed = bytearray(canvas_size * canvas_size * 4)
        place(placed, canvas_size, themed, mark_size, (canvas_size - mark_size) // 2)

        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher_monochrome.png")
        write_png(path, canvas_size, canvas_size, placed)


if __name__ == "__main__":
    main()
