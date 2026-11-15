"""Qwen-Image-Edit 2511 (GGUF Q4 + Lightning 4-step) through the local ComfyUI.

Unlike Z-Image it sees the reference itself, so costume and colours survive a pose change.
"""

import sys
from pathlib import Path

from comfy import run, upload_image

ROOT = Path(__file__).resolve().parents[2]


def build(prompt: str, seed: int, image: str, pose: str | None = None, megapixels: float = 0.8, steps: int = 4) -> dict:
    g = {
        "unet": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": "qwen-image-edit-2511-Q4_K_M.gguf"}},
        "lora": {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": ["unet", 0], "lora_name": "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
            "strength_model": 1.0}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["lora", 0], "shift": 3.0}},
        "norm": {"class_type": "CFGNorm", "inputs": {"model": ["shift", 0], "strength": 1.0}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors", "type": "qwen_image"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "src": {"class_type": "LoadImage", "inputs": {"image": image}},
        "scaled": {"class_type": "ImageScaleToTotalPixels", "inputs": {
            "image": ["src", 0], "upscale_method": "lanczos", "megapixels": megapixels, "resolution_steps": 16}},
        "pos": {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {
            "clip": ["clip", 0], "prompt": prompt, "vae": ["vae", 0], "image1": ["scaled", 0]}},
        "neg": {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {
            "clip": ["clip", 0], "prompt": "", "vae": ["vae", 0], "image1": ["scaled", 0]}},
        "latent": {"class_type": "VAEEncode", "inputs": {"pixels": ["scaled", 0], "vae": ["vae", 0]}},
        "sample": {"class_type": "KSampler", "inputs": {
            "model": ["norm", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0],
            "seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "razlom/qwen"}},
    }
    if pose:
        g["pose"] = {"class_type": "LoadImage", "inputs": {"image": pose}}
        for k in ("pos", "neg"):
            g[k]["inputs"]["image2"] = ["pose", 0]
    return g


def edit(prompt: str, seed: int, reference: Path, out_path: Path, pose: Path | None = None) -> Path:
    """`pose` is an OpenPose skeleton passed as picture 2; the prompt should refer to it as such."""
    graph = build(prompt, seed, upload_image(reference), upload_image(pose) if pose else None)
    return run(graph, out_path, timeout=1800)


if __name__ == "__main__":
    prompt = sys.argv[1]
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    out = ROOT / "art/hero/qwen" / (sys.argv[3] if len(sys.argv) > 3 else f"test_{seed}.png")
    print(edit(prompt, seed, ROOT / "art/hero/ronin_ref.png", out))
