"""Wan 2.2 I2V 14B (GGUF Q4 + lightx2v 4-step) turns one key frame into a short clip; frames become sprite frames.

A video model keeps neighbouring frames consistent, which separate image edits never did.
Usage: python wan_anim.py <name> <seed> "<motion prompt>" [start_image] [frames]
"""

import json
import sys
import time
import urllib.parse
import uuid
from pathlib import Path

from comfy import _get, _post, upload_image

ROOT = Path(__file__).resolve().parents[2]
NEGATIVE = ("camera movement, camera pan, zoom, cut, blurry, motion blur, extra limbs, extra legs, deformed hands, "
            "turning around, facing away, text, watermark, background objects, shadow")


def build(prompt: str, seed: int, image: str, width: int, height: int, length: int) -> dict:
    g = {
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "type": "wan"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "wan_2.1_vae.safetensors"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": NEGATIVE}},
        "img": {"class_type": "LoadImage", "inputs": {"image": image}},
        "i2v": {"class_type": "WanImageToVideo", "inputs": {
            "positive": ["pos", 0], "negative": ["neg", 0], "vae": ["vae", 0], "start_image": ["img", 0],
            "width": width, "height": height, "length": length, "batch_size": 1}},
    }
    # The two experts split the schedule: high-noise lays out the motion, low-noise fills in detail.
    for part, lo, hi, add_noise, leftover, src in (("high", 0, 2, "enable", "enable", ["i2v", 2]),
                                                   ("low", 2, 4, "disable", "disable", ["s_high", 0])):
        cap = part.capitalize()
        g[f"unet_{part}"] = {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": f"Wan2.2-I2V-A14B-{cap}Noise-Q4_K_M.gguf"}}
        g[f"lora_{part}"] = {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": [f"unet_{part}", 0], "strength_model": 1.0,
            "lora_name": f"wan2.2_i2v_lightx2v_4steps_lora_v1_{part}_noise.safetensors"}}
        g[f"shift_{part}"] = {"class_type": "ModelSamplingSD3", "inputs": {"model": [f"lora_{part}", 0], "shift": 5.0}}
        g[f"s_{part}"] = {"class_type": "KSamplerAdvanced", "inputs": {
            "model": [f"shift_{part}", 0], "positive": ["i2v", 0], "negative": ["i2v", 1], "latent_image": src,
            "add_noise": add_noise, "noise_seed": seed, "steps": 4, "cfg": 1.0, "sampler_name": "euler",
            "scheduler": "simple", "start_at_step": lo, "end_at_step": hi, "return_with_leftover_noise": leftover}}
    g["decode"] = {"class_type": "VAEDecode", "inputs": {"samples": ["s_low", 0], "vae": ["vae", 0]}}
    g["save"] = {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "razlom/wan"}}
    return g


def between(name: str, seed: int, prompt: str, start: Path, end: Path, length: int = 17,
            width: int = 480, height: int = 640) -> list[Path]:
    """Animates from `start` to `end`. Pinning both poses stops Wan from drifting into a different move,
    which it kept doing for the uppercut when given only a start frame and text."""
    graph = build(prompt, seed, upload_image(start), width, height, length)
    graph["end_img"] = {"class_type": "LoadImage", "inputs": {"image": upload_image(end)}}
    graph["i2v"] = {"class_type": "WanFirstLastFrameToVideo", "inputs": {
        "positive": ["pos", 0], "negative": ["neg", 0], "vae": ["vae", 0], "start_image": ["img", 0],
        "end_image": ["end_img", 0], "width": width, "height": height, "length": length, "batch_size": 1}}
    graph["neg"]["inputs"]["text"] = NEGATIVE + ", flash, explosion, light burst, lightning, sparks, glow effects"
    return run_frames(graph, ROOT / "art/hero/wan" / f"{name}_{seed}")


def run_frames(graph: dict, out_dir: Path, timeout: float = 3600.0) -> list[Path]:
    resp = _post("/prompt", json.dumps({"prompt": graph, "client_id": uuid.uuid4().hex}).encode(), "application/json")
    if resp.get("node_errors"):
        raise RuntimeError(json.dumps(resp["node_errors"], ensure_ascii=False))
    pid = resp["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        entry = json.loads(_get(f"/history/{pid}")).get(pid)
        if entry:
            if entry.get("status", {}).get("status_str") == "error":
                raise RuntimeError(json.dumps(entry["status"], ensure_ascii=False)[:2000])
            out_dir.mkdir(parents=True, exist_ok=True)
            paths = []
            for node in entry["outputs"].values():
                for i, img in enumerate(node.get("images", [])):
                    q = urllib.parse.urlencode({k: img[k] for k in ("filename", "subfolder", "type")})
                    p = out_dir / f"f{i:03d}.png"
                    p.write_bytes(_get(f"/view?{q}"))
                    paths.append(p)
            return paths
        time.sleep(2.0)
    raise TimeoutError(pid)


def animate(name: str, seed: int, prompt: str, start: Path, length: int = 33,
            width: int = 480, height: int = 640) -> list[Path]:
    graph = build(prompt, seed, upload_image(start), width, height, length)
    return run_frames(graph, ROOT / "art/hero/wan" / f"{name}_{seed}")


if __name__ == "__main__":
    name, seed, prompt = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    start = Path(sys.argv[4]) if len(sys.argv) > 4 else ROOT / "art/hero/ronin_ref.png"
    length = int(sys.argv[5]) if len(sys.argv) > 5 else 33
    t = time.time()
    frames = animate(name, seed, prompt, start, length)
    print(f"{len(frames)} frames in {time.time() - t:.0f}s -> {frames[0].parent}")
