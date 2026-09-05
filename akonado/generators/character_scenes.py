"""Character scene (.tscn) generator for Konado 2.8+.

Konado 2.8 characters use PackedScene (.tscn) files instead of
individual texture sub-resources. Each character gets a .tscn file
that references its expression textures.

The scene inherits from KonadoCharacterSceneBase and uses
TextureRect to display the appropriate expression.
"""

from __future__ import annotations

import json

from ..config import (
    AKONADO_CHARACTER_SCENE_SCRIPT,
    CHARACTERS_DIR,
    MANIFESTS_DIR,
)


def generate_character_scenes(*, skip_existing: bool = True) -> None:
    """Generate .tscn scene files for each character.

    Each character's expressions are bundled into a single .tscn file
    that maps status names to texture paths.
    """
    manifest_path = MANIFESTS_DIR / "characters.json"
    if not manifest_path.exists():
        print("[character_scenes] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("characters", {}))

    for char_id, char_cfg in items.items():
        out_dir = CHARACTERS_DIR / char_id
        out_path = out_dir / f"{char_id}.tscn"

        if skip_existing and out_path.exists():
            print(f"  [skip] {char_id}.tscn")
            continue

        expressions = char_cfg.get("expressions", {})
        available_exprs = {}
        for expr_name in expressions:
            img_path = out_dir / f"{expr_name}.png"
            if img_path.exists():
                available_exprs[expr_name] = f"res://assets/characters/{char_id}/{expr_name}.png"

        if not available_exprs:
            print(f"  [skip] {char_id}.tscn — no expression images found")
            continue

        # Build the .tscn file
        load_steps = 3 + len(available_exprs)  # scripts + textures + root
        lines = []
        lines.append(f"[gd_scene load_steps={load_steps} format=3]\n")

        # External resources
        lines.append(
            f'[ext_resource type="Script" path="{AKONADO_CHARACTER_SCENE_SCRIPT}" id="1"]\n'
        )

        # Texture references
        ext_id = 2
        tex_ids = {}
        for expr_name, tex_path in available_exprs.items():
            tex_ids[expr_name] = ext_id
            lines.append(f'[ext_resource type="Texture2D" path="{tex_path}" id="{ext_id}"]\n')
            ext_id += 1

        # Texture assignment in the node
        lines.append(f'\n[node name="{char_id}" type="Node2D"]')
        lines.append('script = ExtResource("1")')
        # expression_textures as dictionary
        tex_dict_items = []
        for expr_name in available_exprs:
            tex_dict_items.append(f'"{expr_name}" = ExtResource("{tex_ids[expr_name]}")')
        tex_dict = ",\n".join(tex_dict_items)
        lines.append(f"expression_textures = {{\n{tex_dict}\n}}")
        lines.append('\n[node name="TextureRect" type="TextureRect" parent="."]')
        lines.append("layout_mode = 1")
        lines.append("anchors_preset = 0")
        lines.append("offset_left = -384.0")
        lines.append("offset_top = -512.0")
        lines.append("offset_right = 384.0")
        lines.append("offset_bottom = 512.0")
        lines.append("scale = Vector2(0.5, 0.5)")
        lines.append("expand_mode = 1")
        lines.append("stretch_mode = 5")
        # Set default texture
        first_expr = next(iter(available_exprs))
        lines.append(f'texture = ExtResource("{tex_ids[first_expr]}")')

        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines), encoding="utf-8")
        print(f"  [saved] {out_path}")

    print("[character_scenes] done")
