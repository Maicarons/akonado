"""ComfyUI provider — extensible workflow-based image/audio generation.

Supports auto-discovery of workflow JSON files from the comfyui/ directory.
Workflows are classified by filename prefix:
  - image_*   → image generation
  - audio_*   → audio generation
  - utility_*_remove_background → background removal

Parameter injection is convention-based: workflows use placeholder nodes
(PrimitiveStringMultiline, PrimitiveFloat, etc.) that the provider locates
and replaces automatically.
"""

from __future__ import annotations

import io
import json
import random
import time
from pathlib import Path

import requests
from PIL import Image

from ..config import COMFYUI_URL, COMFYUI_DIR
from .base import ImageProvider

# Fixed workflow filenames — the pipeline expects these exact names
WORKFLOW_IMAGE = "image_generation.json"
WORKFLOW_AUDIO = "audio_generation.json"
WORKFLOW_SFX = "sfx_generation.json"
WORKFLOW_REMOVE_BG = "remove_background.json"
WORKFLOW_LOGO = "logo.json"
WORKFLOW_TITLE_BG = "title_bg.json"


# ── Workflow Template ────────────────────────────────────────────


class WorkflowTemplate:
    """Wraps a ComfyUI workflow JSON with parameter injection logic.

    Workflows declare parameters via placeholder markers in node inputs:
    - String placeholders: ``{prompt}``, ``{{prompt}}``, ``USER_INPUT``
    - Numeric placeholders: ``{width}``, ``{height}``, ``{duration}``, ``{seed}``

    The template scans all node inputs for these markers and replaces them
    when ``inject()`` is called.
    """

    # Known placeholder patterns → logical parameter names
    _PLACEHOLDER_MAP: dict[str, str] = {
        "{prompt}": "prompt",
        "{{prompt}}": "prompt",
        "{width}": "width",
        "{{width}}": "width",
        "{height}": "height",
        "{{height}}": "height",
        "{seed}": "seed",
        "{{seed}}": "seed",
        "{duration}": "duration",
        "{{duration}}": "duration",
        "{category}": "category",
        "{{category}}": "category",
        "{input_image}": "input_image",
        "{{input_image}}": "input_image",
        "USER_INPUT": "prompt",
        "AUDIO_LENGTH": "duration",
    }

    def __init__(self, workflow: dict, path: Path | None = None):
        self._workflow = workflow
        self._path = path

    @classmethod
    def load(cls, path: Path) -> WorkflowTemplate:
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f), path)

    @property
    def workflow(self) -> dict:
        return self._workflow

    def inject(self, **kwargs) -> dict:
        """Return a copy of the workflow with parameters injected.

        Handles two injection patterns:
        1. PrimitiveStringMultiline nodes: directly set value from kwargs
        2. StringReplace chains: leave template intact, update source nodes

        KSampler nodes always get randomized seeds (unless seed is provided).
        """
        wf = json.loads(json.dumps(self._workflow))  # deep copy

        # --- 1. Update PrimitiveStringMultiline nodes ---
        for node_id, node in wf.items():
            if node.get("class_type") != "PrimitiveStringMultiline":
                continue
            inputs = node.get("inputs", {})
            title = node.get("_meta", {}).get("title", "").lower()
            val = inputs.get("value", "")
            if not isinstance(val, str):
                continue

            # Match parameter by title keywords
            if "prompt" in title and "prompt" in kwargs:
                inputs["value"] = str(kwargs["prompt"])
            elif "width" in title and "width" in kwargs:
                inputs["value"] = str(kwargs["width"])
            elif "height" in title and "height" in kwargs:
                inputs["value"] = str(kwargs["height"])
            elif "seed" in title and "seed" in kwargs:
                inputs["value"] = str(kwargs["seed"])
            else:
                # Fallback: replace placeholders in value
                for placeholder, param_name in self._PLACEHOLDER_MAP.items():
                    if placeholder in val and param_name in kwargs:
                        inputs["value"] = val.replace(
                            placeholder, str(kwargs[param_name])
                        )
                        break

        # --- 2. Update PrimitiveFloat nodes (e.g. audio duration) ---
        for node_id, node in wf.items():
            if node.get("class_type") != "PrimitiveFloat":
                continue
            inputs = node.get("inputs", {})
            title = node.get("_meta", {}).get("title", "").lower()
            if "duration" in kwargs and ("duration" in title or "audio" in title or "length" in title):
                inputs["value"] = float(kwargs["duration"])

        # --- 3. Update width/height in EmptyLatentImage nodes ---
        latent_types = {"EmptyLatentImage", "EmptyFlux2LatentImage", "EmptySD3LatentImage"}
        for node_id, node in wf.items():
            if node.get("class_type") not in latent_types:
                continue
            inputs = node.get("inputs", {})
            if "width" in kwargs:
                inputs["width"] = int(kwargs["width"])
            if "height" in kwargs:
                inputs["height"] = int(kwargs["height"])

        # --- 3b. Update LoadImage nodes (for background removal workflows) ---
        for node_id, node in wf.items():
            if node.get("class_type") != "LoadImage":
                continue
            inputs = node.get("inputs", {})
            img_val = inputs.get("image", "")
            if not isinstance(img_val, str):
                continue
            # Direct replacement when image kwarg is provided
            if "image" in kwargs:
                inputs["image"] = str(kwargs["image"])
            # Placeholder replacement: {input_image} / {{input_image}}
            elif "{input_image}" in img_val or "{{input_image}}" in img_val:
                if "input_image" in kwargs:
                    inputs["image"] = str(kwargs["input_image"])

        # --- 4. Randomize seeds for sampler nodes ---
        seed_override = kwargs.get("seed")
        sampler_types = {"KSampler", "KSamplerAdvanced", "SamplerCustom"}
        for node_id, node in wf.items():
            if node.get("class_type") in sampler_types:
                inputs = node.get("inputs", {})
                if seed_override is not None:
                    inputs["seed"] = int(seed_override)
                else:
                    inputs["seed"] = random.randint(0, 2**53 - 1)

        return wf

    def find_output_images(self, result: dict) -> list[dict]:
        """Extract image output info from ComfyUI history result."""
        images = []
        for node_output in result.get("outputs", {}).values():
            if "images" in node_output:
                images.extend(node_output["images"])
        return images

    def find_output_audio(self, result: dict) -> list[dict]:
        """Extract audio output info from ComfyUI history result."""
        audio = []
        for node_output in result.get("outputs", {}).values():
            if "audio" in node_output:
                audio.extend(node_output["audio"])
        return audio


# ── ComfyUI REST Client ─────────────────────────────────────────


class ComfyUIClient(ImageProvider):
    """Image/audio generation via a local ComfyUI instance.

    Auto-discovers workflow JSON files from the comfyui/ directory.
    Falls back to manual workflow specification if auto-discovery finds nothing.
    """

    name = "comfyui"

    def __init__(self, base_url: str | None = None, comfyui_dir: Path | None = None):
        self._base_url = (base_url or COMFYUI_URL).rstrip("/")
        self._comfyui_dir = comfyui_dir or COMFYUI_DIR
        self._workflows: dict[str, WorkflowTemplate] = {}
        self._discover_workflows()

    # ── Workflow Discovery ──────────────────────────────────────

    def _discover_workflows(self) -> None:
        """Scan comfyui/ for workflow JSON files.

        Fixed filenames (used directly by the pipeline):
          - image_generation.json → image generation
          - audio_generation.json → audio generation (music/BGM)
          - sfx_generation.json → sound effects generation
          - remove_background.json → background removal
          - logo.json → logo generation
          - title_bg.json → title background generation

        Also discovers additional workflows by prefix classification.
        """
        if not self._comfyui_dir.exists():
            return

        for path in sorted(self._comfyui_dir.glob("*.json")):
            stem = path.stem.lower()
            try:
                tpl = WorkflowTemplate.load(path)
            except (json.JSONDecodeError, OSError) as e:
                print(f"  [warn] Skipping workflow {path.name}: {e}")
                continue

            # Register by fixed name
            if path.name == WORKFLOW_IMAGE:
                self._workflows["image:default"] = tpl
            elif path.name == WORKFLOW_AUDIO:
                self._workflows["audio:default"] = tpl
            elif path.name == WORKFLOW_SFX:
                self._workflows["audio:sfx"] = tpl
            elif path.name == WORKFLOW_REMOVE_BG:
                self._workflows["utility:remove_bg"] = tpl
            elif path.name == WORKFLOW_LOGO:
                self._workflows["image:logo"] = tpl
            elif path.name == WORKFLOW_TITLE_BG:
                self._workflows["image:title_bg"] = tpl
            else:
                # Classify additional workflows by prefix
                if stem.startswith("image_"):
                    name = stem.removeprefix("image_")
                    self._workflows.setdefault(f"image:{name}", tpl)
                elif stem.startswith("audio_"):
                    name = stem.removeprefix("audio_")
                    self._workflows.setdefault(f"audio:{name}", tpl)
                elif "_remove_background" in stem:
                    self._workflows.setdefault("utility:remove_bg", tpl)

    @staticmethod
    def _detect_workflow_type(tpl: WorkflowTemplate) -> str | None:
        """Detect workflow type by examining output node class_types."""
        wf = tpl.workflow
        has_image_output = False
        has_audio_output = False
        for node in wf.values():
            cls = node.get("class_type", "")
            if cls in ("SaveImage", "PreviewImage"):
                has_image_output = True
            elif cls in ("SaveAudioMP3", "SaveAudio", "PreviewAudio"):
                has_audio_output = True
        if has_audio_output:
            return "audio"
        if has_image_output:
            return "image"
        return None

    def list_workflows(self) -> list[str]:
        """Return names of all discovered workflows."""
        return sorted(self._workflows.keys())

    def get_workflow(self, name: str) -> WorkflowTemplate | None:
        """Get a workflow template by name (e.g. 'image:ernie_image_turbo')."""
        return self._workflows.get(name)

    def _find_first(self, prefix: str) -> WorkflowTemplate | None:
        """Find the first workflow matching a prefix."""
        for name, tpl in self._workflows.items():
            if name.startswith(prefix):
                return tpl
        return None

    # ── ComfyUI REST API ────────────────────────────────────────

    def available(self) -> bool:
        try:
            resp = requests.get(f"{self._base_url}/system_stats", timeout=3)
            return resp.status_code == 200
        except requests.ConnectionError:
            return False

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

    def _download_file(self, filename: str, subfolder: str = "", file_type: str = "output") -> bytes:
        url = f"{self._base_url}/view?filename={filename}&subfolder={subfolder}&type={file_type}"
        resp = requests.get(url)
        resp.raise_for_status()
        return resp.content

    def _upload_image(self, path: Path) -> str:
        with open(path, "rb") as f:
            files = {"image": (path.name, f, "image/png")}
            resp = requests.post(f"{self._base_url}/upload/image", files=files)
        resp.raise_for_status()
        return resp.json()["name"]

    def _save_bytes(self, data: bytes, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)

    # ── ImageProvider Interface ─────────────────────────────────

    def generate(
        self,
        prompt: str,
        width: int,
        height: int,
        save_path: Path,
        *,
        seed: int | None = None,
    ) -> None:
        tpl = self._workflows.get("image:default")
        if tpl is None:
            raise FileNotFoundError(
                f"No image workflow found in comfyui/.\n"
                f"Add a workflow JSON file named {WORKFLOW_IMAGE}"
            )

        kwargs = {"prompt": prompt, "width": width, "height": height}
        if seed is not None:
            kwargs["seed"] = seed
        wf = tpl.inject(**kwargs)

        prompt_id = self._queue_prompt(wf)
        print(f"  queued: {prompt_id}")
        result = self._wait_for_prompt(prompt_id)

        for img in tpl.find_output_images(result):
            content = self._download_file(img["filename"], img.get("subfolder", ""))
            self._save_bytes(content, save_path)
            print(f"  saved: {save_path}")
            return

        print("  warning: no image output found")

    def remove_background(self, input_path: Path, output_path: Path) -> None:
        tpl = self._workflows.get("utility:remove_bg")
        if tpl is None:
            print(f"  warning: no remove_background workflow found in comfyui/")
            print(f"  Expected: {WORKFLOW_REMOVE_BG}")
            return

        uploaded_name = self._upload_image(input_path)
        wf = tpl.inject(image=uploaded_name)

        prompt_id = self._queue_prompt(wf)
        print(f"  queued: {prompt_id}")
        result = self._wait_for_prompt(prompt_id)

        # Filter to only output-type images (skip temp/preview)
        all_images = tpl.find_output_images(result)
        images = [img for img in all_images if img.get("type") == "output"]

        if not images:
            # Fallback: try all images
            images = all_images

        if len(images) >= 2:
            # First output = composite with alpha, second = mask
            composite_data = self._download_file(
                images[0]["filename"], images[0].get("subfolder", ""), images[0].get("type", "output")
            )
            mask_data = self._download_file(
                images[1]["filename"], images[1].get("subfolder", ""), images[1].get("type", "output")
            )
            base_img = Image.open(io.BytesIO(composite_data)).convert("RGB")
            mask_img = Image.open(io.BytesIO(mask_data)).convert("L")
            rgba_img = base_img.copy()
            rgba_img.putalpha(mask_img)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            rgba_img.save(str(output_path), "PNG")
            print(f"  saved (transparent): {output_path}")
            return

        if images:
            content = self._download_file(
                images[0]["filename"], images[0].get("subfolder", ""), images[0].get("type", "output")
            )
            self._save_bytes(content, output_path)
            print(f"  saved: {output_path}")
            return

        print("  warning: no background removal result found")

    def generate_audio(
        self,
        prompt: str,
        duration: float,
        save_path: Path,
        *,
        category: str = "Music",
        use_sfx: bool = False,
    ) -> None:
        """Generate audio (BGM or SFX).

        Args:
            prompt: Text description of the audio.
            duration: Duration in seconds.
            save_path: Output file path.
            category: Audio category (Music, SFX, etc.).
            use_sfx: If True, use the SFX workflow instead of the default audio workflow.
        """
        if use_sfx:
            tpl = self._workflows.get("audio:sfx")
            if tpl is None:
                raise FileNotFoundError(
                    f"No SFX workflow found in comfyui/.\n"
                    f"Add a workflow JSON file named {WORKFLOW_SFX}"
                )
        else:
            tpl = self._workflows.get("audio:default")
            if tpl is None:
                raise FileNotFoundError(
                    f"No audio workflow found in comfyui/.\n"
                    f"Add a workflow JSON file named {WORKFLOW_AUDIO}"
                )

        wf = tpl.inject(prompt=prompt, duration=duration, category=category)

        prompt_id = self._queue_prompt(wf)
        print(f"  queued: {prompt_id}")
        result = self._wait_for_prompt(prompt_id, timeout=600)

        for audio in tpl.find_output_audio(result):
            content = self._download_file(audio["filename"], audio.get("subfolder", ""))
            self._save_bytes(content, save_path)
            print(f"  saved: {save_path}")
            return

        print("  warning: no audio output found")
