"""Minimal client for a local ComfyUI on 127.0.0.1:8188: upload an image, queue a graph, fetch the result."""

import json
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

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
            if entry.get("status", {}).get("completed"):
                return out_path
        time.sleep(1.0)
    raise TimeoutError(pid)
