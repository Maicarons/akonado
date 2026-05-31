"""BGM generator.

Reads manifests/bgm.json, generates background music via ImageProvider.generate_audio().
"""

from __future__ import annotations

import json

from ..config import MANIFESTS_DIR, BGM_DIR
from ..providers.base import ImageProvider


def generate_bgm(image: ImageProvider, *, skip_existing: bool = True) -> None:
    """Generate all background music tracks.

    Args:
        image: Image generation provider (uses generate_audio method).
        skip_existing: Skip files that already exist on disk.
    """
    manifest_path = MANIFESTS_DIR / "bgm.json"
    if not manifest_path.exists():
        print("[bgm] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    fmt = data.get("format", "mp3")
    default_duration = data.get("duration", 150)

    for bgm_id, bgm_prompt in data["items"].items():
        out_path = BGM_DIR / f"{bgm_id}.{fmt}"

        if skip_existing and out_path.exists():
            print(f"  [skip] {bgm_id}.{fmt}")
            continue

        print(f"[bgm] {bgm_id}")
        image.generate_audio(
            prompt=bgm_prompt,
            duration=default_duration,
            save_path=out_path,
            category="Music",
        )

    print("[bgm] done")
