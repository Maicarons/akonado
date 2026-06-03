"""CG (Computer Graphics) illustration generator.

Reads manifests/cgs.json, generates high-quality 1920x1080 CG illustrations.
CGs are full-scene illustrations combining characters, backgrounds, and atmosphere
into a single polished image — unlike regular backgrounds which exclude characters.
"""

from __future__ import annotations

import json

from ..config import MANIFESTS_DIR, CGS_DIR
from ..providers.base import ImageProvider


def generate_cgs(image: ImageProvider, *, skip_existing: bool = True) -> None:
    """Generate all CG illustrations.

    Args:
        image: Image generation provider.
        skip_existing: Skip files that already exist on disk.
    """
    manifest_path = MANIFESTS_DIR / "cgs.json"
    if not manifest_path.exists():
        print("[cgs] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    width, height = data.get("size", [1920, 1080])
    items = data.get("items", {})

    for cg_id, cg_cfg in items.items():
        out_path = CGS_DIR / f"{cg_id}.png"

        if skip_existing and out_path.exists():
            print(f"  [skip] {cg_id}.png")
            continue

        # CG items can be either a string (prompt only) or a dict (with metadata)
        if isinstance(cg_cfg, str):
            prompt = cg_cfg
        else:
            prompt = cg_cfg["prompt"]

        print(f"[cg] {cg_id}")
        image.generate(
            prompt=prompt,
            width=width,
            height=height,
            save_path=out_path,
        )

    print("[cgs] done")
