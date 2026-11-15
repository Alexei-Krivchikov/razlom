"""Pixelizes the chosen Wan clip frames into res://sprites/hero/<anim>_<i>.png.

Every clip starts from the same stance, so its first frame fixes the scale and the feet position; frames are
placed relative to it instead of being re-anchored one by one, which kept the hero from sliding or changing size.
"""

from pathlib import Path

from PIL import Image

from pixelize import cut_background, figure_bbox, to_sprite

ROOT = Path(__file__).resolve().parents[2]
WAN = ROOT / "art/hero/wan"
OUT = ROOT / "sprites/hero"
HEIGHT = 48
# Wide enough for the hero lying flat behind the feet in the death clip.
CANVAS = (112, 60)
# Godot places this canvas pixel on the hero's feet; Player.gd mirrors it as SPRITE_ANCHOR.
ANCHOR = (56, 56)

# anim -> (clip folder, clip frame indices), or a list of (clip, frame) pairs stitched from several clips;
# a stitched animation takes its scale from the first clip. The punch peaks are listed in Player.PUNCH_PEAK.
FRAMES = {
    "idle": ("idle_1", range(16, 32, 2)),
    "walk": ("walk_1", range(9, 22)),
    "punch0": ("combo_1", range(4, 16)),
    "punch1": ("combo_1", range(15, 25)),
    # Crouch, then the rise cut at the elbow-under-fist finish, then the return; the last two return frames
    # came out a different coat colour and are left out.
    "punch2": [("uppercut_7", i) for i in range(0, 12, 2)] + [("upswing_3", i) for i in range(8)]
              + [("uprecover_2", i) for i in range(1, 10)],
    # Wan dropped the hair streak on the skipped frames.
    "dash": ("dash_2", [8, 9, 11, 13, 14, 17]),
    "hurt": ("recoil_1", range(9, 17)),
    "dead": ("death_1", range(9, 24)),
}


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png*"):
        old.unlink()
    for anim, spec in FRAMES.items():
        pairs = spec if isinstance(spec, list) else [(spec[0], i) for i in spec[1]]
        first = figure_bbox(cut_background(Image.open(WAN / pairs[0][0] / "f000.png")))
        scale = HEIGHT / (first[3] - first[1])
        centre = (first[0] + first[2]) / 2
        for k, (clip, i) in enumerate(pairs):
            frame = Image.open(WAN / clip / f"f{i:03d}.png")
            box = figure_bbox(cut_background(frame))
            sprite = to_sprite(frame.crop(box), round((box[3] - box[1]) * scale))
            x = ANCHOR[0] + round((box[0] - centre) * scale) - 1
            y = ANCHOR[1] - round((first[3] - box[1]) * scale)
            if x < 0 or y < 0 or x + sprite.width > CANVAS[0] or y + sprite.height > CANVAS[1]:
                raise ValueError(f"{anim} frame {i} does not fit the canvas at {x},{y} {sprite.size}")
            canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
            canvas.alpha_composite(sprite, (x, y))
            canvas.save(OUT / f"{anim}_{k}.png")
        print(anim, len(pairs))


if __name__ == "__main__":
    build()
