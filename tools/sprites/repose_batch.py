"""Tries the repose method on every pose at two denoise strengths and builds a contact sheet."""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from comfy import repose
from dataset import PROMPT
from hero import ROOT
from poses import POSES

if __name__ == "__main__":
    out = ROOT / "art" / "hero" / "repose"
    files = []
    for denoise in (0.7, 0.8):
        for name in POSES:
            p = repose(PROMPT.replace("character reference sheet, the same character drawn twice side by side, ", ""),
                       7, ROOT / "art/hero/ronin_ref.png", ROOT / f"art/poses/{name}.png",
                       out / f"{name}_d{int(denoise * 100)}.png", denoise=denoise)
            files.append(p)
            print(p, flush=True)
    w, h, cols = 192, 256, 8
    sheet = Image.new("RGB", (w * cols, (h + 18) * 2), (27, 22, 48))
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        x, y = (i % cols) * w, (i // cols) * (h + 18)
        sheet.paste(Image.open(f).convert("RGB").resize((w, h)), (x, y + 18))
        d.text((x + 4, y + 3), f"{i + 1}: {f.stem}", fill=(255, 61, 129))
    sheet.save(ROOT / "art" / "hero" / "_repose_sheet.png")
