import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from comfy import txt2img

STYLE = ("full body game character concept art, side view facing right, standing in a fighting stance, "
         "anime style, clean bold outlines, flat cel shading, limited palette of dark navy, neon magenta #FF3D81 "
         "and electric cyan #34E5FF accents, plain flat light gray background, no text, single character, centered")

HEROES = {
    "a_street_girl": "young woman street brawler, short white bob hair, oversized black techwear jacket, "
                     "glowing cyan energy gauntlets on both fists, magenta scarf, combat boots",
    "b_rift_ronin": "young man with spiky black hair and a magenta streak, long dark coat, "
                    "one arm covered in glowing cyan rift cracks, fingerless gloves, sneakers",
    "c_courier": "teen delivery courier girl, cyan hoodie with hood down, twin ponytails, "
                 "heavy magenta mechanical arm brace, shorts over leggings, chunky sneakers",
    "d_ex_cop": "tall muscular man, ex riot police, cracked dark armor vest, magenta visor pushed up, "
                "short cyan mohawk, taped knuckles, cargo pants",
}

out = Path(__file__).resolve().parents[2] / "art" / "concepts"
for name, desc in HEROES.items():
    for seed in (11, 23):
        p = txt2img(f"{desc}, {STYLE}", seed, out / f"{name}_{seed}.png", width=768, height=1024)
        print(p, flush=True)
