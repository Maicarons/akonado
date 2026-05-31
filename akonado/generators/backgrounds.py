"""Background image generator.

Reads manifests/backgrounds.json, generates 1920x1080 background images.
"""

from __future__ import annotations

import json

from ..config import MANIFESTS_DIR, BACKGROUNDS_DIR
from ..providers.base import ImageProvider


def generate_backgrounds(image: ImageProvider, *, skip_existing: bool = True) -> None:
    """Generate all background images.

    Args:
        image: Image generation provider.
        skip_existing: Skip files that already exist on disk.
    """
    manifest_path = MANIFESTS_DIR / "backgrounds.json"
    if not manifest_path.exists():
        print("[backgrounds] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    width, height = data.get("size", [1920, 1080])
    items = data.get("items", data.get("backgrounds", {}))

    for bg_id, bg_prompt in items.items():
        out_path = BACKGROUNDS_DIR / f"{bg_id}.png"

        if skip_existing and out_path.exists():
            print(f"  [skip] {bg_id}.png")
            continue

        print(f"[background] {bg_id}")
        image.generate(
            prompt=bg_prompt,
            width=width,
            height=height,
            save_path=out_path,
        )

    print("[backgrounds] done")
