"""UI asset generator.

Reads manifests/ui.json, generates logo/title/app icon images.
"""

from __future__ import annotations

import json

from ..config import MANIFESTS_DIR, UI_DIR
from ..providers.base import ImageProvider


def generate_ui(image: ImageProvider, *, skip_existing: bool = True) -> None:
    """Generate all UI assets.

    Args:
        image: Image generation provider.
        skip_existing: Skip files that already exist on disk.
    """
    manifest_path = MANIFESTS_DIR / "ui.json"
    if not manifest_path.exists():
        print("[ui] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    for item_id, item_cfg in data["items"].items():
        out_path = UI_DIR / item_cfg["output"]

        if skip_existing and out_path.exists():
            print(f"  [skip] {item_id}")
            continue

        print(f"[ui] {item_id}")
        image.generate(
            prompt=item_cfg["prompt"],
            width=item_cfg["size"][0],
            height=item_cfg["size"][1],
            save_path=out_path,
        )

    print("[ui] done")
