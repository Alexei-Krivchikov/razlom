"""The hero's "passport": one fixed description reused by every generation so the look stays consistent.

The approved base looks are art/concepts/b_rift_ronin_*.png; txt2img from scratch drifts into a different
character, so refinements go through img2img on those images.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from comfy import img2img

HERO = ("young man rift ronin, tall dramatic spiky black hair with bold bright magenta streaks, "
        "warm brown skin with bright highlights, long dark navy coat, "
        "one forearm covered in vividly glowing cyan rift cracks with strong cyan glow, "
        "fingerless gloves, dark sneakers")

STYLE = ("full body game character concept art, side view facing right, fighting stance, anime style, "
         "clean bold outlines, flat cel shading, limited palette of dark navy, neon magenta #FF3D81 "
         "and electric cyan #34E5FF accents, plain flat light gray background, no text, single character, centered")

ROOT = Path(__file__).resolve().parents[2]

if __name__ == "__main__":
    out = ROOT / "art" / "concepts" / "refined"
    for base in ("11", "23"):
        src = ROOT / "art" / "concepts" / f"b_rift_ronin_{base}.png"
        for denoise in (0.35, 0.5):
            for seed in (5, 9):
                p = out / f"ronin{base}_d{int(denoise * 100)}_s{seed}.png"
                print(img2img(f"{HERO}, {STYLE}", seed, src, p, denoise=denoise), flush=True)
