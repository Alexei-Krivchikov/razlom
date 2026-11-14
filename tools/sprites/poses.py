"""OpenPose skeletons for the hero, side view facing right, on a 768x1024 canvas.

Joint order is OpenPose COCO-18. "l_*" is the near side (the hero's left faces the camera when facing right).
"""

from pathlib import Path

from PIL import Image, ImageDraw

W, H = 768, 1024

ORDER = ["nose", "neck", "r_sh", "r_el", "r_wr", "l_sh", "l_el", "l_wr", "r_hip", "r_kn", "r_an",
         "l_hip", "l_kn", "l_an", "r_eye", "l_eye", "r_ear", "l_ear"]
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13),
         (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0),
          (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255),
          (170, 0, 255), (255, 0, 255), (255, 0, 170), (255, 0, 85)]


def _head(nx: float, ny: float) -> dict:
    return {"nose": (nx, ny), "r_eye": (nx + 6, ny - 12), "l_eye": (nx - 4, ny - 12),
            "r_ear": (nx - 30, ny - 6), "l_ear": (nx - 34, ny - 8)}


POSES: dict[str, dict] = {
    "stance": {**_head(430, 200), "neck": (395, 285),
               "r_sh": (365, 300), "r_el": (360, 400), "r_wr": (425, 345),
               "l_sh": (420, 300), "l_el": (470, 390), "l_wr": (505, 320),
               "r_hip": (370, 530), "r_kn": (305, 690), "r_an": (250, 890),
               "l_hip": (410, 530), "l_kn": (475, 700), "l_an": (510, 890)},
    "jab": {**_head(450, 205), "neck": (410, 290),
            "r_sh": (380, 305), "r_el": (385, 405), "r_wr": (445, 350),
            "l_sh": (440, 300), "l_el": (540, 300), "l_wr": (650, 295),
            "r_hip": (375, 535), "r_kn": (300, 695), "r_an": (240, 890),
            "l_hip": (415, 535), "l_kn": (490, 700), "l_an": (530, 890)},
    "cross": {**_head(465, 210), "neck": (425, 295),
              "r_sh": (445, 300), "r_el": (545, 300), "r_wr": (660, 290),
              "l_sh": (400, 305), "l_el": (420, 400), "l_wr": (470, 345),
              "r_hip": (385, 540), "r_kn": (330, 700), "r_an": (300, 890),
              "l_hip": (420, 540), "l_kn": (500, 690), "l_an": (540, 890)},
    "heavy": {**_head(480, 240), "neck": (440, 320),
              "r_sh": (460, 325), "r_el": (560, 280), "r_wr": (640, 200),
              "l_sh": (415, 330), "l_el": (380, 420), "l_wr": (430, 470),
              "r_hip": (390, 555), "r_kn": (300, 700), "r_an": (220, 890),
              "l_hip": (425, 555), "l_kn": (520, 690), "l_an": (580, 890)},
    "walk_a": {**_head(425, 195), "neck": (395, 280),
               "r_sh": (370, 295), "r_el": (365, 395), "r_wr": (420, 345),
               "l_sh": (415, 295), "l_el": (460, 385), "l_wr": (500, 320),
               "r_hip": (380, 525), "r_kn": (440, 690), "r_an": (470, 890),
               "l_hip": (400, 525), "l_kn": (350, 700), "l_an": (290, 885)},
    "walk_b": {**_head(425, 190), "neck": (395, 275),
               "r_sh": (370, 290), "r_el": (365, 390), "r_wr": (420, 340),
               "l_sh": (415, 290), "l_el": (460, 380), "l_wr": (500, 315),
               "r_hip": (385, 520), "r_kn": (400, 700), "r_an": (370, 890),
               "l_hip": (400, 520), "l_kn": (420, 700), "l_an": (400, 880)},
    "dash": {**_head(520, 290), "neck": (470, 360),
             "r_sh": (445, 365), "r_el": (380, 420), "r_wr": (320, 470),
             "l_sh": (490, 370), "l_el": (560, 420), "l_wr": (600, 380),
             "r_hip": (370, 560), "r_kn": (250, 640), "r_an": (130, 760),
             "l_hip": (395, 560), "l_kn": (500, 680), "l_an": (480, 890)},
    "hurt": {**_head(360, 220), "neck": (360, 300),
             "r_sh": (335, 310), "r_el": (280, 380), "r_wr": (250, 300),
             "l_sh": (385, 310), "l_el": (440, 380), "l_wr": (480, 330),
             "r_hip": (385, 540), "r_kn": (330, 700), "r_an": (300, 890),
             "l_hip": (420, 540), "l_kn": (470, 700), "l_an": (520, 890)},
}


def draw(pose: dict, size=(W, H), offset=(0, 0)) -> Image.Image:
    img = Image.new("RGB", size, (0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(pose[k][0] + offset[0], pose[k][1] + offset[1]) for k in ORDER]
    for i, (a, b) in enumerate(LIMBS):
        c = tuple(int(v * 0.6) for v in COLORS[i])
        d.line([pts[a], pts[b]], fill=c, width=14)
    for i, p in enumerate(pts):
        d.ellipse([p[0] - 7, p[1] - 7, p[0] + 7, p[1] + 7], fill=COLORS[i])
    return img


if __name__ == "__main__":
    out = Path(__file__).resolve().parents[2] / "art" / "poses"
    out.mkdir(parents=True, exist_ok=True)
    for name, pose in POSES.items():
        draw(pose).save(out / f"{name}.png")
