"""Generates LoRA training candidates: the hero in every pose from poses.py, drawn beside the reference."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from comfy import beside_reference
from hero import ROOT
from poses import POSES

PROMPT = ("character reference sheet, the same character drawn twice side by side, identical outfit, identical colors, "
          "identical hairstyle, young man rift ronin, wild spiky black hair with one bright magenta streak, "
          "warm brown skin, long black high-collar coat, black baggy pants, black boots, fingerless black gloves, "
          "his right forearm covered in glowing cyan hexagon rift cracks, side view facing right, anime style, "
          "clean bold outlines, flat cel shading, plain flat light gray background, no text")

if __name__ == "__main__":
    out = ROOT / "art" / "hero" / "dataset_raw"
    for name in POSES:
        for seed in (3, 17, 29):
            p = beside_reference(PROMPT, seed, ROOT / "art/hero/ronin_ref.png", ROOT / f"art/poses/{name}.png",
                                 out / f"{name}_{seed}.png", control_strength=0.95)
            p.with_name(p.stem + "_full.png").unlink()
            print(p, flush=True)
