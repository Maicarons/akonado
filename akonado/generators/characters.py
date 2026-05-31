"""Character sprite generator.

Reads manifests/characters.json, generates character art via ImageProvider,
then removes backgrounds to produce transparent PNG sprites.
"""

from __future__ import annotations

import json

from ..config import MANIFESTS_DIR, CHARACTERS_DIR
from ..providers.base import ImageProvider


def generate_characters(image: ImageProvider, *, skip_existing: bool = True) -> None:
    """Generate all character sprites.

    Args:
        image: Image generation provider (e.g. ComfyUIImageProvider).
        skip_existing: Skip files that already exist on disk.
    """
    manifest_path = MANIFESTS_DIR / "characters.json"
    if not manifest_path.exists():
        print("[characters] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("characters", {}))
    for char_id, char_cfg in items.items():
        base_prompt = char_cfg["base_prompt"]
        seed = char_cfg.get("seed")

        for expr_name, expr_prompt in char_cfg["expressions"].items():
            out_dir = CHARACTERS_DIR / char_id
            out_path = out_dir / f"{expr_name}.png"

            if skip_existing and out_path.exists():
                print(f"  [skip] {char_id}/{expr_name}.png")
                continue

            full_prompt = f"{base_prompt}, {expr_prompt}"
            print(f"[character] {char_id}/{expr_name}")

            # Generate raw image
            tmp_path = out_dir / f"{expr_name}_raw.png"
            image.generate(
                prompt=full_prompt,
                width=char_cfg.get("size", [768, 1024])[0],
                height=char_cfg.get("size", [768, 1024])[1],
                save_path=tmp_path,
                seed=seed,
            )

            # Remove background
            if tmp_path.exists():
                image.remove_background(tmp_path, out_path)
                tmp_path.unlink(missing_ok=True)

    print("[characters] done")
