"""Character list .tres generator for Konado 2.8+."""

from __future__ import annotations

import json

from ...config import (
    CHARACTERS_DIR,
    KONADO_CHARACTER_LIST_SCRIPT,
    KONADO_CHARACTER_SCRIPT,
    MANIFESTS_DIR,
)
from .helpers import (
    ext_resource_scene,
    ext_resource_script,
    tres_header,
)


def generate_characters_tres() -> None:
    """Generate characters.tres referencing character .tscn scene files."""
    manifest_path = MANIFESTS_DIR / "characters.json"
    if not manifest_path.exists():
        print("[characters.tres] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("characters", {}))
    characters = []
    for char_id, char_cfg in items.items():
        scene_path = CHARACTERS_DIR / char_id / f"{char_id}.tscn"
        if scene_path.exists():
            characters.append(char_id)

    if not characters:
        print("[characters.tres] no character scene files found, skipping")
        return

    load_steps = 2 + len(characters) + len(characters) + 1
    lines = [tres_header("KonadoCharacterList", load_steps)]

    lines.append(ext_resource_script(KONADO_CHARACTER_SCRIPT, "ext_1"))
    lines.append(ext_resource_script(KONADO_CHARACTER_LIST_SCRIPT, "ext_2"))

    ext_id = 3
    scene_ids = {}
    for char_id in characters:
        scene_ids[char_id] = ext_id
        lines.append(
            ext_resource_scene(f"res://assets/characters/{char_id}/{char_id}.tscn", f"ext_{ext_id}")
        )
        ext_id += 1

    res_id = 1
    char_res_ids = {}
    for char_id in characters:
        char_res_ids[char_id] = res_id
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append('script = ExtResource("ext_1")')
        lines.append(f'character_id = "{char_id}"')
        lines.append(f'character_scene = ExtResource("ext_{scene_ids[char_id]}")')
        res_id += 1

    char_refs = ", ".join(f'SubResource("res_{char_res_ids[c]}")' for c in characters)
    lines.append("\n[resource]")
    lines.append('script = ExtResource("ext_2")')
    lines.append(f'characters = Array[ExtResource("ext_1")]([{char_refs}])')

    out_path = CHARACTERS_DIR / "characters.tres"
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [saved] {out_path}")
