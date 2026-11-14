"""Turns a generated illustration into an in-game pixel sprite: cut background, crop, downscale, outline."""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUTLINE = (20, 16, 31, 255)


def cut_background(img: Image.Image, tol: int = 28) -> Image.Image:
    a = np.array(img.convert("RGBA")).astype(int)
    h, w = a.shape[:2]
    bg = np.median(np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]]), axis=0)
    close = np.abs(a[:, :, :3] - bg).max(axis=2) <= tol
    # Flood fill from the border so background-coloured pixels inside the figure survive.
    mask = np.zeros((h, w), bool)
    stack = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if mask[y, x] or not close[y, x]:
            continue
        mask[y, x] = True
        if y > 0: stack.append((y - 1, x))
        if y < h - 1: stack.append((y + 1, x))
        if x > 0: stack.append((y, x - 1))
        if x < w - 1: stack.append((y, x + 1))
    a[mask, 3] = 0
    return Image.fromarray(a.astype(np.uint8))


def to_sprite(img: Image.Image, height: int, colors: int = 16) -> Image.Image:
    img = cut_background(img)
    img = img.crop(img.getbbox())
    w = max(1, round(img.width * height / img.height))
    small = img.resize((w, height), Image.Resampling.BOX)
    a = np.array(small)
    alpha = a[:, :, 3] > 110
    rgb = Image.fromarray(a[:, :, :3]).quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.zeros((height + 2, w + 2, 4), np.uint8)
    out[1:-1, 1:-1, :3] = np.array(rgb)
    out[1:-1, 1:-1, 3] = alpha * 255
    solid = out[:, :, 3] > 0
    ring = np.zeros_like(solid)
    ring[1:, :] |= solid[:-1, :]; ring[:-1, :] |= solid[1:, :]
    ring[:, 1:] |= solid[:, :-1]; ring[:, :-1] |= solid[:, 1:]
    out[ring & ~solid] = OUTLINE
    return Image.fromarray(out)


if __name__ == "__main__":
    src, dst, h = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 48
    to_sprite(Image.open(src), h).save(dst)
