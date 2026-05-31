"""ComfyUI image/audio generation provider.

Wraps the ComfyUI REST API for image generation, background removal, and audio synthesis.
Configure via environment variable: COMFYUI_URL (default: http://127.0.0.1:8188)
"""

from __future__ import annotations

import io
import json
import time

import requests
from pathlib import Path
from PIL import Image

from ..config import (
    COMFYUI_URL,
    IMAGE_WORKFLOW,
    REMOVE_BG_WORKFLOW,
    AUDIO_WORKFLOW,
)
from .base import ImageProvider


class ComfyUIImageProvider(ImageProvider):
    """Image generation via ComfyUI workflows."""

    def __init__(self, base_url: str | None = None):
        self._base_url = (base_url or COMFYUI_URL).rstrip("/")

    def available(self) -> bool:
        try:
            resp = requests.get(f"{self._base_url}/system_stats", timeout=3)
            return resp.status_code == 200
        except requests.ConnectionError:
            return False

    # ── Low-level API ──────────────────────────────────────────

    def _queue_prompt(self, workflow: dict) -> str:
        resp = requests.post(
            f"{self._base_url}/prompt", json={"prompt": workflow}
        )
        resp.raise_for_status()
        return resp.json()["prompt_id"]

    def _wait_for_prompt(self, prompt_id: str, timeout: int = 600) -> dict:
        start = time.time()
        while time.time() - start < timeout:
            resp = requests.get(f"{self._base_url}/history/{prompt_id}")
            if resp.status_code == 200:
                data = resp.json()
                if prompt_id in data:
                    return data[prompt_id]
            time.sleep(2)
        raise TimeoutError(f"ComfyUI prompt {prompt_id} timed out after {timeout}s")

    def _download_image(self, filename: str, subfolder: str = "", img_type: str = "output") -> bytes:
        url = f"{self._base_url}/view?filename={filename}&subfolder={subfolder}&type={img_type}"
        resp = requests.get(url)
        resp.raise_for_status()
        return resp.content

    def _download_audio(self, filename: str, subfolder: str = "") -> bytes:
        url = f"{self._base_url}/view?filename={filename}&subfolder={subfolder}&type=output"
        resp = requests.get(url)
        resp.raise_for_status()
        return resp.content

    def _save_bytes(self, data: bytes, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)

    # ── Image generation ───────────────────────────────────────

    def generate(
        self,
        prompt: str,
        width: int,
        height: int,
        save_path: Path,
        *,
        seed: int | None = None,
    ) -> None:
        if not IMAGE_WORKFLOW.exists():
            raise FileNotFoundError(
                f"Image workflow not found: {IMAGE_WORKFLOW}\n"
                "Place your ComfyUI workflow JSON in the comfyui/ folder."
            )

        with open(IMAGE_WORKFLOW, encoding="utf-8") as f:
            workflow = json.load(f)

        # Use placeholder substitution in workflow
        self._inject_workflow_params(workflow, prompt=prompt, width=width, height=height, seed=seed)

        prompt_id = self._queue_prompt(workflow)
        print(f"  queued: {prompt_id}")
        result = self._wait_for_prompt(prompt_id)

        for node_output in result.get("outputs", {}).values():
            if "images" in node_output:
                for img in node_output["images"]:
                    content = self._download_image(img["filename"], img.get("subfolder", ""))
                    self._save_bytes(content, save_path)
                    print(f"  saved: {save_path}")
                    return

        print("  warning: no image output found")

    def _inject_workflow_params(self, workflow: dict, **kwargs) -> None:
        """Inject parameters into workflow nodes using placeholder markers.

        Workflow JSON files should use {{prompt}}, {{width}}, {{height}}, {{seed}}
        placeholders in node input values.
        """
        for node_id, node in workflow.items():
            inputs = node.get("inputs", {})
            for key, value in inputs.items():
                if isinstance(value, str):
                    if "{{prompt}}" in value:
                        inputs[key] = value.replace("{{prompt}}", kwargs.get("prompt", ""))
                    elif value == "{{width}}":
                        inputs[key] = kwargs.get("width", 1024)
                    elif value == "{{height}}":
                        inputs[key] = kwargs.get("height", 1024)
                    elif value == "{{seed}}":
                        inputs[key] = kwargs.get("seed", -1)

    # ── Background removal ─────────────────────────────────────

    def remove_background(self, input_path: Path, output_path: Path) -> None:
        if not REMOVE_BG_WORKFLOW.exists():
            print(f"  warning: remove_bg workflow not found: {REMOVE_BG_WORKFLOW}")
            return

        with open(REMOVE_BG_WORKFLOW, encoding="utf-8") as f:
            workflow = json.load(f)

        # Upload source image
        with open(input_path, "rb") as f:
            files = {"image": (input_path.name, f, "image/png")}
            resp = requests.post(f"{self._base_url}/upload/image", files=files)
            resp.raise_for_status()
            uploaded_name = resp.json()["name"]

        # Inject uploaded filename into workflow
        for node_id, node in workflow.items():
            inputs = node.get("inputs", {})
            for key, value in inputs.items():
                if isinstance(value, str) and value == "{{image}}":
                    inputs[key] = uploaded_name

        prompt_id = self._queue_prompt(workflow)
        print(f"  queued: {prompt_id}")
        result = self._wait_for_prompt(prompt_id)

        composited_bytes = None
        mask_bytes = None

        for node_id, node_output in result.get("outputs", {}).items():
            if "images" not in node_output:
                continue
            for img in node_output["images"]:
                content = self._download_image(
                    img["filename"], img.get("subfolder", ""), img.get("type", "output")
                )
                # Try to identify composite vs mask by node type
                if composited_bytes is None:
                    composited_bytes = content
                else:
                    mask_bytes = content

        if composited_bytes and mask_bytes:
            base_img = Image.open(io.BytesIO(composited_bytes)).convert("RGB")
            mask_img = Image.open(io.BytesIO(mask_bytes)).convert("L")
            rgba_img = base_img.copy()
            rgba_img.putalpha(mask_img)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            rgba_img.save(str(output_path), "PNG")
            print(f"  saved (transparent): {output_path}")
            return

        if composited_bytes:
            self._save_bytes(composited_bytes, output_path)
            print(f"  saved: {output_path}")
            return

        print("  warning: no background removal result found")

    # ── Audio generation ───────────────────────────────────────

    def generate_audio(
        self,
        prompt: str,
        duration: float,
        save_path: Path,
        *,
        category: str = "Music",
    ) -> None:
        if not AUDIO_WORKFLOW.exists():
            raise FileNotFoundError(
                f"Audio workflow not found: {AUDIO_WORKFLOW}\n"
                "Place your ComfyUI audio workflow JSON in the comfyui/ folder."
            )

        with open(AUDIO_WORKFLOW, encoding="utf-8") as f:
            workflow = json.load(f)

        # Inject parameters
        for node_id, node in workflow.items():
            inputs = node.get("inputs", {})
            for key, value in inputs.items():
                if isinstance(value, str):
                    if "{{prompt}}" in value:
                        inputs[key] = value.replace("{{prompt}}", prompt)
                    elif value == "{{duration}}":
                        inputs[key] = duration
                    elif value == "{{category}}":
                        inputs[key] = category

        prompt_id = self._queue_prompt(workflow)
        print(f"  queued: {prompt_id}")
        result = self._wait_for_prompt(prompt_id, timeout=600)

        for node_output in result.get("outputs", {}).values():
            if "audio" in node_output:
                for audio in node_output["audio"]:
                    content = self._download_audio(audio["filename"], audio.get("subfolder", ""))
                    self._save_bytes(content, save_path)
                    print(f"  saved: {save_path}")
                    return

        print("  warning: no audio output found")
