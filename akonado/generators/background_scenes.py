"""Background scene (.tscn) generator for Konado 2.8+.

Konado 2.8 backgrounds use PackedScene (.tscn) files instead of
direct texture references. Each background image gets a .tscn scene
that wraps it in a KonadoBackgroundSceneBase.
"""

from __future__ import annotations

import json

from ..config import (
    BACKGROUNDS_DIR,
    CGS_DIR,
    KONADO_BACKGROUND_SCENE_BASE,
    MANIFESTS_DIR,
)


def generate_background_scenes(*, skip_existing: bool = True, cg_mode: bool = False) -> None:
    """Generate .tscn scene files for backgrounds.

    Args:
        skip_existing: Skip files that already exist.
        cg_mode: If True, generate from cgs.json instead of backgrounds.json.
    """
    manifest_name = "cgs" if cg_mode else "backgrounds"
    manifest_path = MANIFESTS_DIR / f"{manifest_name}.json"
    if not manifest_path.exists():
        print(f"[{manifest_name}_scenes] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get(manifest_name, {}))
    out_dir = CGS_DIR if cg_mode else BACKGROUNDS_DIR

    for item_id in items:
        out_path = out_dir / f"{item_id}.tscn"

        if skip_existing and out_path.exists():
            print(f"  [skip] {item_id}.tscn")
            continue

        # Find the image file
        img_path = None
        for ext in ["png", "jpg", "jpeg", "webp"]:
            candidate = out_dir / f"{item_id}.{ext}"
            if candidate.exists():
                img_path = candidate
                break

        if img_path is None:
            print(f"  [skip] {item_id}.tscn — no image found")
            continue

        img_ext = img_path.suffix
        res_prefix = "cgs" if cg_mode else "backgrounds"
        res_path = f"res://assets/{res_prefix}/{item_id}{img_ext}"

        lines = [
            "[gd_scene load_steps=2 format=3]\n",
            f'[ext_resource type="Script" path="{KONADO_BACKGROUND_SCENE_BASE}" id="1"]\n',
            f'[ext_resource type="Texture2D" path="{res_path}" id="2"]\n',
            f'\n[node name="{item_id}" type="Control"]',
            "layout_mode = 3",
            "anchors_preset = 15",
            "anchor_right = 1.0",
            "anchor_bottom = 1.0",
            "grow_horizontal = 2",
            "grow_vertical = 2",
            "mouse_filter = 2",
            'script = ExtResource("1")',
            '\n[node name="TextureRect" type="TextureRect" parent="."]',
            "layout_mode = 1",
            "anchors_preset = 15",
            "anchor_right = 1.0",
            "anchor_bottom = 1.0",
            "grow_horizontal = 2",
            "grow_vertical = 2",
            "mouse_filter = 2",
            'texture = ExtResource("2")',
            "expand_mode = 1",
            "stretch_mode = 6",
        ]

        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines), encoding="utf-8")
        print(f"  [saved] {out_path}")

    print(f"[{manifest_name}_scenes] done")


def generate_cg_scenes(*, skip_existing: bool = True) -> None:
    """Generate .tscn scene files for CG illustrations."""
    generate_background_scenes(skip_existing=skip_existing, cg_mode=True)
