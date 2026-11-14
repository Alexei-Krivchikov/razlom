"""Minimal client for a local ComfyUI running Z-Image-Turbo.

Usage as a library: txt2img(prompt, seed, out_path, ...).
Expects ComfyUI on 127.0.0.1:8188 with z_image_turbo_bf16, qwen_3_4b, ae and
(optionally) Z-Image-Turbo-Fun-Controlnet-Union installed.
"""

import json
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from PIL import Image

SERVER = "http://127.0.0.1:8188"


def _post(path: str, data: bytes, content_type: str) -> dict:
    req = urllib.request.Request(SERVER + path, data=data, headers={"Content-Type": content_type})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def _get(path: str) -> bytes:
    with urllib.request.urlopen(SERVER + path) as r:
        return r.read()


def upload_image(path: Path) -> str:
    boundary = uuid.uuid4().hex
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: image/png\r\n\r\n"
    ).encode() + path.read_bytes() + (
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{boundary}--\r\n"
    ).encode()
    return _post("/upload/image", body, f"multipart/form-data; boundary={boundary}")["name"]


def build_txt2img(prompt: str, seed: int, width: int, height: int, steps: int,
                  control_image: str | None, control_strength: float, lora: str | None) -> dict:
    g = {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "fp8_e4m3fn"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["unet", 0], "shift": 3.0}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "neg": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["pos", 0]}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "sample": {"class_type": "KSampler", "inputs": {
            "model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0],
            "seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "razlom/gen"}},
    }
    model_out = ["shift", 0]
    if lora:
        g["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": model_out, "lora_name": lora, "strength_model": 1.0}}
        model_out = ["lora", 0]
    if control_image:
        g["cn_patch"] = {"class_type": "ModelPatchLoader", "inputs": {"name": "Z-Image-Turbo-Fun-Controlnet-Union.safetensors"}}
        g["cn_img"] = {"class_type": "LoadImage", "inputs": {"image": control_image}}
        g["cn"] = {"class_type": "ZImageFunControlnet", "inputs": {
            "model": model_out, "model_patch": ["cn_patch", 0], "vae": ["vae", 0],
            "strength": control_strength, "image": ["cn_img", 0]}}
        model_out = ["cn", 0]
    g["sample"]["inputs"]["model"] = model_out
    return g


def run(graph: dict, out_path: Path, timeout: float = 600.0) -> Path:
    client_id = uuid.uuid4().hex
    resp = _post("/prompt", json.dumps({"prompt": graph, "client_id": client_id}).encode(), "application/json")
    if resp.get("node_errors"):
        raise RuntimeError(json.dumps(resp["node_errors"], ensure_ascii=False))
    pid = resp["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        hist = json.loads(_get(f"/history/{pid}"))
        if pid in hist:
            entry = hist[pid]
            if entry.get("status", {}).get("status_str") == "error":
                raise RuntimeError(json.dumps(entry["status"], ensure_ascii=False)[:2000])
            for node in entry["outputs"].values():
                for img in node.get("images", []):
                    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
                    out_path.parent.mkdir(parents=True, exist_ok=True)
                    out_path.write_bytes(_get(f"/view?{q}"))
                    return out_path
        time.sleep(1.0)
    raise TimeoutError(pid)


def img2img(prompt: str, seed: int, source: Path, out_path: Path, denoise: float = 0.4, steps: int = 9,
            lora: str | None = None) -> Path:
    """Redraws an existing image; low denoise keeps pose and composition, higher lets the prompt change more."""
    with Image.open(source) as im:
        width, height = im.size
    graph = build_txt2img(prompt, seed, width, height, steps, None, 0.0, lora)
    graph["src"] = {"class_type": "LoadImage", "inputs": {"image": upload_image(source)}}
    graph["latent"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
    graph["sample"]["inputs"]["denoise"] = denoise
    return run(graph, out_path)


def repose(prompt: str, seed: int, reference: Path, control: Path, out_path: Path,
           denoise: float = 0.75, control_strength: float = 0.9, steps: int = 9) -> Path:
    """Redraws the reference itself into the pose of a skeleton: colours and costume come from the
    image, not from the prompt, which Z-Image alone cannot hold."""
    graph = build_txt2img(prompt, seed, 768, 1024, steps, upload_image(control), control_strength, None)
    graph["src"] = {"class_type": "LoadImage", "inputs": {"image": upload_image(reference)}}
    graph["latent"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
    graph["sample"]["inputs"]["denoise"] = denoise
    return run(graph, out_path)


def beside_reference(prompt: str, seed: int, reference: Path, control: Path, out_path: Path,
                     control_strength: float = 0.8, steps: int = 9) -> Path:
    """Puts the reference on the left half and inpaints the right half under a pose skeleton.

    Seeing the reference in the same picture keeps the outfit and colours far more stable than prompt alone.
    The returned file is the right half only.
    """
    ref = Image.open(reference).convert("RGB")
    w, h = ref.size
    canvas = Image.new("RGB", (w * 2, h), ref.getpixel((4, 4)))
    canvas.paste(ref, (0, 0))
    mask = Image.new("RGB", (w * 2, h), (0, 0, 0))
    mask.paste((255, 255, 255), (w, 0, w * 2, h))
    ctrl = Image.new("RGB", (w * 2, h), (0, 0, 0))
    ctrl.paste(Image.open(control).convert("RGB").resize((w, h)), (w, 0))

    tmp = out_path.parent / "_tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    for name, im in (("canvas", canvas), ("mask", mask), ("ctrl", ctrl)):
        im.save(tmp / f"{name}.png")

    graph = build_txt2img(prompt, seed, w * 2, h, steps, upload_image(tmp / "ctrl.png"), control_strength, None)
    graph["src"] = {"class_type": "LoadImage", "inputs": {"image": upload_image(tmp / "canvas.png")}}
    graph["mask_img"] = {"class_type": "LoadImage", "inputs": {"image": upload_image(tmp / "mask.png")}}
    graph["mask"] = {"class_type": "ImageToMask", "inputs": {"image": ["mask_img", 0], "channel": "red"}}
    graph["cn"]["inputs"]["inpaint_image"] = ["src", 0]
    graph["cn"]["inputs"]["mask"] = ["mask", 0]
    graph["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
    graph["latent"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}}
    full = out_path.with_name(out_path.stem + "_full.png")
    run(graph, full)
    Image.open(full).crop((w, 0, w * 2, h)).save(out_path)
    return out_path


def txt2img(prompt: str, seed: int, out_path: Path, width: int = 1024, height: int = 1024, steps: int = 9,
            control_image: Path | None = None, control_strength: float = 0.8, lora: str | None = None) -> Path:
    uploaded = upload_image(control_image) if control_image else None
    graph = build_txt2img(prompt, seed, width, height, steps, uploaded, control_strength, lora)
    return run(graph, out_path)
