"""Colour grade for the approved ronin art: warmer brighter skin, lifted coat, glowing rift arm.

Done as plain image processing instead of re-generation because img2img either barely changes the
picture or redraws the character into someone else.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SKIN_SHADOW = np.array([150, 82, 64])
SKIN_LIGHT = np.array([250, 190, 150])
COAT_LIFT = np.array([20, 24, 62])
CYAN = np.array([52, 229, 255])


def grade(img: Image.Image) -> Image.Image:
    a = np.array(img.convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]

    skin = (r > 100) & (r - g > 40) & (b < r) & (b > g - 10)
    lum = (0.3 * r + 0.59 * g + 0.11 * b)[..., None]
    t = np.clip((lum - 60) / 90, 0, 1)
    a = np.where(skin[..., None], SKIN_SHADOW + (SKIN_LIGHT - SKIN_SHADOW) * t, a)

    total = r + g + b
    coat = (np.maximum(np.maximum(r, g), b) < 80) & (b >= r) & (total > 24)
    # The hair is as dark as the coat; keep the head out of the lift so it stays black.
    figure_rows = np.where((total < 200).any(axis=1))[0]
    head_end = figure_rows[0] + int(0.2 * (figure_rows[-1] - figure_rows[0]))
    coat[:head_end] = False
    a = np.where(coat[..., None], a + COAT_LIFT, a)

    hair = (r > 150) & (b > 150) & (g < 90)
    a = np.where(hair[..., None], np.array([255, 70, 200]), a)

    cyan = (g > 170) & (b > 150) & (r < 120)
    a = np.where(cyan[..., None], np.minimum(a * 1.1 + 15, 255), a)
    glow = Image.fromarray((cyan * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))
    glow = np.array(glow).astype(float)[..., None] / 255.0
    a = a + glow * CYAN * 0.55 * (~cyan[..., None])

    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


if __name__ == "__main__":
    grade(Image.open(sys.argv[1])).save(Path(sys.argv[2]))
