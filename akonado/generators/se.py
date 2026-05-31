"""Sound effects generator.

Reads manifests/se.json, generates sound effects via ImageProvider.generate_audio().
"""

from __future__ import annotations

import json

from ..config import MANIFESTS_DIR, SE_DIR
from ..providers.base import ImageProvider


def generate_se(image: ImageProvider, *, skip_existing: bool = True) -> None:
    """Generate all sound effects.

    Args:
        image: Image generation provider (uses generate_audio method).
        skip_existing: Skip files that already exist on disk.
    """
    manifest_path = MANIFESTS_DIR / "se.json"
    if not manifest_path.exists():
        print("[se] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    fmt = data.get("format", "mp3")

    for se_id, se_cfg in data["items"].items():
        out_path = SE_DIR / f"{se_id}.{fmt}"

        if skip_existing and out_path.exists():
            print(f"  [skip] {se_id}.{fmt}")
            continue

        print(f"[se] {se_id}")
        image.generate_audio(
            prompt=se_cfg["prompt"],
            duration=se_cfg.get("duration", 3),
            save_path=out_path,
            category="Sound Effects",
        )

    print("[se] done")
