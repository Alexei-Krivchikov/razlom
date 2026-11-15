"""Renders every hero animation as a Wan clip from the stance key frame; frames are picked by hand afterwards."""

import sys

from wan_anim import ROOT, animate

START = ROOT / "art/hero/ronin_ref.png"
STYLE = (" Side view, he faces right the whole time and stays in the centre of the frame. "
         "The camera is completely static, no zoom, no pan. Plain flat light grey background. Flat anime style.")

CLIPS = {
    "idle": (33, "The man stands in a fighting stance with fists raised, breathing calmly, a slight bounce on his knees, "
                 "he does not step anywhere."),
    "combo": (49, "The man throws a fast three-punch combo: a straight jab with the glowing cracked fist, then a hook "
                  "with the other fist, then a powerful rising uppercut with the glowing cracked fist, "
                  "then returns to his fighting stance."),
    "dash": (33, "The man bursts into a low, fast forward dash, body leaning forward, coat flying behind him, "
                 "then stops and returns to his fighting stance."),
    # Anything mentioning a hit or punch made Wan animate him attacking instead of being struck.
    "recoil": (33, "The man's head jerks backwards as if struck by an invisible force, his upper body bends back, "
                   "he staggers one step backwards with arms thrown out, then straightens up into his fighting stance."),
    "uppercut": (33, "First he crouches down low, bending his knees deeply and dropping his shoulders, the cracked fist "
                     "pulled down by his hip and glowing brighter and brighter. Then he explodes upward and drives the "
                     "fist straight up in a rising uppercut, the fist finishing high above his head, while a huge burst "
                     "of bright cyan lightning and energy erupts from the fist. Then he settles back into his "
                     "fighting stance."),
    "death": (33, "The man is hit hard, falls backwards onto the ground and lies still on his back."),
}
SEEDS = (1, 2)
# Clips that needed more tries: their seeds continue past the first pair.
EXTRA_SEEDS = {"uppercut": (7, 8, 9, 10, 11, 12)}

if __name__ == "__main__":
    for name in sys.argv[1:] or list(CLIPS):
        length, motion = CLIPS[name]
        for seed in EXTRA_SEEDS.get(name, SEEDS):
            if (ROOT / "art/hero/wan" / f"{name}_{seed}").exists():
                continue
            animate(name, seed, motion + STYLE, START, length)
            print(name, seed, flush=True)
