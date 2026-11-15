#!/usr/bin/env python3
"""Generate the Android launcher icons and the launch-screen logo.

`assets/brand/ennvo_logo.png` is the single source of truth for the brand
mark. This script resamples it into every density Android asks for:

    * `mipmap-*/ic_launcher.png`            — the legacy launcher icon
    * `mipmap-*/ic_launcher_foreground.png` — the adaptive icon foreground
    * `mipmap-*/ic_launcher_monochrome.png` — the themed (monochrome) icon
    * `drawable-*/splash_logo.png`           — the launch-screen mark

Everything is written with the standard library only, so the icons can be
regenerated on any machine — including a CI runner — without a design tool.

Run it from the project root:

    python tooling/make_launcher_icons.py
"""

from __future__ import annotations

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "brand", "ennvo_logo.png")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Legacy launcher icon: the launcher scales the bitmap to the icon size.
LEGACY_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive icon: the foreground lives on a 108dp canvas and only the middle
# 72dp is guaranteed to be visible, so the mark is drawn at 62% of it.
ADAPTIVE_CANVAS_DP = 108
ADAPTIVE_SCALE = 0.62

# The launch screen shows the mark at 96dp.
SPLASH_DP = 96


# ---------------------------------------------------------------------------
#  A tiny PNG reader / writer (8 bit, non interlaced, RGB or RGBA)
# ---------------------------------------------------------------------------
def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: str) -> tuple[int, int, bytearray]:
    """Reads a PNG and returns `(width, height, RGBA pixels)`."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")

    offset = 8
    width = height = 0
    color_type = 6
    idat = bytearray()

    while offset < len(data):
        (length,) = struct.unpack(">I", data[offset:offset + 4])
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        offset += 12 + length

        if kind == b"IHDR":
            width, height, depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if depth != 8 or interlace != 0:
                raise ValueError("only 8 bit, non interlaced PNGs are supported")
            if color_type not in (2, 6):
                raise ValueError("only RGB and RGBA PNGs are supported")
        elif kind == b"IDAT":
            idat += payload
        elif kind == b"IEND":
            break

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(idat))

    pixels = bytearray(width * height * 4)
    previous = bytearray(stride)
    position = 0

    for y in range(height):
        filter_type = raw[position]
        position += 1
        line = bytearray(raw[position:position + stride])
        position += stride

        if filter_type == 1:
            for x in range(channels, stride):
                line[x] = (line[x] + line[x - channels]) & 0xFF
        elif filter_type == 2:
            for x in range(stride):
                line[x] = (line[x] + previous[x]) & 0xFF
        elif filter_type == 3:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                line[x] = (line[x] + ((left + previous[x]) >> 1)) & 0xFF
        elif filter_type == 4:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                up = previous[x]
                up_left = previous[x - channels] if x >= channels else 0
                line[x] = (line[x] + _paeth(left, up, up_left)) & 0xFF

        row = y * width * 4
        if channels == 4:
            pixels[row:row + width * 4] = line
        else:
            for x in range(width):
                source = x * 3
                target = row + x * 4
                pixels[target] = line[source]
                pixels[target + 1] = line[source + 1]
                pixels[target + 2] = line[source + 2]
                pixels[target + 3] = 255

        previous = line

    return width, height, pixels


def write_png(path: str, width: int, height: int, pixels: bytearray) -> None:
    """Writes an 8 bit RGBA PNG."""
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter: none
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    blob = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(blob)


# ---------------------------------------------------------------------------
#  Resampling
# ---------------------------------------------------------------------------
def resize(
    width: int,
    height: int,
    pixels: bytearray,
    target: int,
    opacity: float = 1.0,
) -> bytearray:
    """Box filters the image down (or up) to `target` x `target`."""
    ratio = target / width
    out = bytearray(target * target * 4)

    for y in range(target):
        source_y0 = int(y / ratio)
        source_y1 = max(source_y0 + 1, int((y + 1) / ratio))
        for x in range(target):
            source_x0 = int(x / ratio)
            source_x1 = max(source_x0 + 1, int((x + 1) / ratio))

            red = green = blue = alpha = 0
            samples = 0
            for source_y in range(source_y0, min(source_y1, height)):
                row = source_y * width * 4
                for source_x in range(source_x0, min(source_x1, width)):
                    offset = row + source_x * 4
                    red += pixels[offset]
                    green += pixels[offset + 1]
                    blue += pixels[offset + 2]
                    alpha += pixels[offset + 3]
                    samples += 1

            if samples == 0:
                continue
            target_offset = (y * target + x) * 4
            out[target_offset] = red // samples
            out[target_offset + 1] = green // samples
            out[target_offset + 2] = blue // samples
            out[target_offset + 3] = int(alpha // samples * opacity)

    return out


def place(
    canvas: bytearray,
    canvas_size: int,
    mark: bytearray,
    mark_size: int,
    offset: int,
) -> None:
    """Draws `mark` on `canvas` at (offset, offset), scaling the alpha."""
    for y in range(mark_size):
        for x in range(mark_size):
            source = (y * mark_size + x) * 4
            alpha = mark[source + 3]
            if alpha == 0:
                continue
            target = ((y + offset) * canvas_size + (x + offset)) * 4
            canvas[target] = mark[source]
            canvas[target + 1] = mark[source + 1]
            canvas[target + 2] = mark[source + 2]
            canvas[target + 3] = alpha


def monochrome(width: int, height: int, pixels: bytearray) -> bytearray:
    """Keeps only the alpha channel — the shape the themed icon uses."""
    out = bytearray(width * height * 4)
    for index in range(width * height):
        alpha = pixels[index * 4 + 3]
        out[index * 4] = 255
        out[index * 4 + 1] = 255
        out[index * 4 + 2] = 255
        out[index * 4 + 3] = alpha
    return out


# ---------------------------------------------------------------------------
#  The generator
# ---------------------------------------------------------------------------
def main() -> None:
    if not os.path.exists(SOURCE):
        raise SystemExit(f"missing source image: {SOURCE}")

    width, height, pixels = read_png(SOURCE)
    print(f"source: {width}x{height}")

    # --- the legacy launcher icon ------------------------------------
    for density, size in LEGACY_DENSITIES.items():
        scaled = resize(width, height, pixels, size)
        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher.png")
        write_png(path, size, size, scaled)
        print(f"  {os.path.relpath(path, ROOT)}")

    # --- the adaptive icon -------------------------------------------
    scale = ADAPTIVE_SCALE
    for density, legacy in LEGACY_DENSITIES.items():
        factor = legacy / 48.0
        canvas_size = int(round(ADAPTIVE_CANVAS_DP * factor))
        mark_size = int(round(canvas_size * scale))

        mark = resize(width, height, pixels, mark_size)
        canvas = bytearray(canvas_size * canvas_size * 4)
        place(canvas, canvas_size, mark, mark_size, (canvas_size - mark_size) // 2)

        path = os.path.join(
            RES, f"mipmap-{density}", "ic_launcher_foreground.png"
        )
        write_png(path, canvas_size, canvas_size, canvas)
        print(f"  {os.path.relpath(path, ROOT)}")

        # The themed icon is the silhouette of the mark.
        silhouette = monochrome(mark_size, mark_size, mark)
        themed = bytearray(canvas_size * canvas_size * 4)
        place(
            themed,
            canvas_size,
            silhouette,
            mark_size,
            (canvas_size - mark_size) // 2,
        )
        path = os.path.join(RES, f"mipmap-{density}", "ic_launcher_monochrome.png")
        write_png(path, canvas_size, canvas_size, themed)

    # --- the launch screen mark --------------------------------------
    for density, legacy in LEGACY_DENSITIES.items():
        factor = legacy / 48.0
        size = int(round(SPLASH_DP * factor))
        scaled = resize(width, height, pixels, size)
        path = os.path.join(RES, f"drawable-{density}", "splash_logo.png")
        write_png(path, size, size, scaled)
        print(f"  {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
