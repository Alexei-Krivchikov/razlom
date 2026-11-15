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
    # Gaps between the legs and painted floor shadows are background-ish but not connected to the border.
    grey = (a[:, :, :3].max(axis=2) - a[:, :, :3].min(axis=2) < 18) & (a[:, :, :3].min(axis=2) > 110)
    seen = mask.copy()
    for y0, x0 in zip(*np.nonzero(grey & ~mask)):
        if seen[y0, x0]:
            continue
        region, stack = [], [(y0, x0)]
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            region.append((y, x))
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and grey[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(region) > h * w * 0.0004:
            ys, xs = zip(*region)
            mask[list(ys), list(xs)] = True
    a[mask, 3] = 0
    return Image.fromarray(a.astype(np.uint8))


HERO_PALETTE = [
    (14, 11, 24), (30, 26, 58), (44, 39, 82), (61, 54, 112), (52, 50, 66), (82, 80, 100),
    (58, 36, 30), (110, 70, 52), (165, 112, 84), (205, 150, 115),
    (31, 143, 163), (52, 229, 255), (181, 246, 255),
    (160, 30, 90), (255, 61, 129),
    (242, 233, 220),
]
GLOW = {"cyan": ((52, 229, 255), (31, 143, 163)), "magenta": ((255, 61, 129), (160, 30, 90))}


def _glow_masks(rgb: np.ndarray) -> dict:
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    mx, mn = rgb.max(axis=2).astype(int), rgb.min(axis=2).astype(int)
    saturated = (mx - mn > 90) & (mx > 120)
    return {"cyan": saturated & (g > r + 60) & (b > r + 60), "magenta": saturated & (r > g + 80) & (b > g)}


def _nearest(rgb: np.ndarray, palette: list) -> np.ndarray:
    pal = np.array(palette, int)
    px = rgb.astype(int)
    d = ((px[..., None, :] - pal) ** 2).sum(axis=-1)
    # Plain RGB distance puts a dark neutral grey closer to dark skin brown than to the navy coat,
    # so colourless pixels may only land on colourless or cool palette entries.
    warm = (pal[:, 0] > pal[:, 2] + 15) & (pal[:, 0] > pal[:, 1] + 15)
    neutral = px.max(axis=-1) - px.min(axis=-1) < 25
    d[neutral[..., None] & warm] = 1 << 30
    return pal[d.argmin(axis=-1)]


def _largest_blob(solid: np.ndarray) -> np.ndarray:
    # Specks of a painted ground line survive the background cut and would shift the feet anchor.
    h, w = solid.shape
    seen = np.zeros_like(solid)
    best: list = []
    for y0, x0 in zip(*np.nonzero(solid)):
        if seen[y0, x0]:
            continue
        blob, stack = [], [(y0, x0)]
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            blob.append((y, x))
            for ny in (y - 1, y, y + 1):
                for nx in (x - 1, x, x + 1):
                    if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        if len(blob) > len(best):
            best = blob
    keep = np.zeros_like(solid)
    if best:
        ys, xs = zip(*best)
        keep[list(ys), list(xs)] = True
    return keep


def figure_bbox(cut: Image.Image) -> tuple:
    """Bounds of the figure alone. Background left behind a glow halo can reach the image border, and a plain
    getbbox() then spans the whole frame, which rescaled that frame and made the hero jump in size."""
    small = cut.reduce(4)
    blob = _largest_blob(np.array(small)[:, :, 3] > 0)
    ys, xs = np.nonzero(blob)
    box = (xs.min() * 4, ys.min() * 4, (xs.max() + 1) * 4, (ys.max() + 1) * 4)
    # Re-tighten at full resolution inside the coarse box.
    inner = cut.crop(box).getbbox()
    return (box[0] + inner[0], box[1] + inner[1], box[0] + inner[2], box[1] + inner[3])


def to_sprite(img: Image.Image, height: int, palette: list = HERO_PALETTE) -> Image.Image:
    img = cut_background(img)
    img = img.crop(figure_bbox(img))
    w = max(1, round(img.width * height / img.height))
    small = np.array(img.resize((w, height), Image.Resampling.BOX))
    alpha = small[:, :, 3] > 110
    # Glow colours come only from the glow masks below; reached by plain distance they painted reddish knuckles pink.
    glow = {c for pair in GLOW.values() for c in pair}
    rgb = _nearest(small[:, :, :3], [c for c in palette if c not in glow])

    # Thin glowing lines are a few pixels wide in the source and average away to grey when downscaled,
    # so any target pixel whose source block is noticeably glowing is forced to the glow colour.
    full = np.array(img)
    for name, mask in _glow_masks(full[:, :, :3]).items():
        mask &= full[:, :, 3] > 0
        if name == "magenta":
            # The streak is the one large magenta patch; smaller ones are lit knuckles or fringe noise.
            mask = _largest_blob(mask)
        cover = np.array(Image.fromarray(mask.astype(np.uint8) * 255)
                         .resize((w, height), Image.Resampling.BOX)) / 255.0
        bright, deep = GLOW[name]
        rgb[cover > 0.35] = bright
        rgb[(cover > 0.12) & (cover <= 0.35)] = deep
        if name == "magenta" and mask.sum() > 40 and not (cover > 0.12).any():
            # A thin streak averages below threshold after downscaling; keep its two strongest pixels.
            for i in np.argsort(cover, axis=None)[-2:]:
                rgb[np.unravel_index(i, cover.shape)] = bright

    alpha = _largest_blob(alpha)
    out = np.zeros((height + 2, w + 2, 4), np.uint8)
    out[1:-1, 1:-1, :3] = rgb
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
