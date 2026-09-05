"""Background list .tres generator for Konado 2.8+."""

from __future__ import annotations

import json

from ...config import (
    BACKGROUNDS_DIR,
    CGS_DIR,
    KONADO_BACKGROUND_LIST_SCRIPT,
    KONADO_BACKGROUND_SCRIPT,
    MANIFESTS_DIR,
)
from .helpers import (
    ext_resource_scene,
    ext_resource_script,
    tres_header,
)


def generate_backgrounds_tres() -> None:
    """Generate backgrounds.tres referencing background .tscn scene files."""
    manifest_path = MANIFESTS_DIR / "backgrounds.json"
    if not manifest_path.exists():
        print("[backgrounds.tres] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("backgrounds", {}))

    backgrounds = []
    for bg_id in items:
        scene_path = BACKGROUNDS_DIR / f"{bg_id}.tscn"
        if scene_path.exists():
            backgrounds.append(bg_id)

    # Also include CGs as backgrounds
    cgs_manifest_path = MANIFESTS_DIR / "cgs.json"
    if cgs_manifest_path.exists():
        with open(cgs_manifest_path, encoding="utf-8") as f:
            cgs_data = json.load(f)
        for cg_id, cg_cfg in cgs_data.get("items", {}).items():
            scene_path = CGS_DIR / f"{cg_id}.tscn"
            if scene_path.exists():
                backgrounds.append(cg_id)

    if not backgrounds:
        print("[backgrounds.tres] no background scene files found, skipping")
        return

    load_steps = 2 + len(backgrounds) + len(backgrounds) + 1
    lines = [tres_header("KonadoBackgroundList", load_steps)]

    lines.append(ext_resource_script(KONADO_BACKGROUND_SCRIPT, "ext_1"))
    lines.append(ext_resource_script(KONADO_BACKGROUND_LIST_SCRIPT, "ext_2"))

    ext_id = 3
    scene_ids = {}
    for bg_id in backgrounds:
        scene_ids[bg_id] = ext_id
        bg_dir = "cgs" if (CGS_DIR / f"{bg_id}.tscn").exists() else "backgrounds"
        lines.append(ext_resource_scene(f"res://assets/{bg_dir}/{bg_id}.tscn", f"ext_{ext_id}"))
        ext_id += 1

    res_id = 1
    bg_res_ids = {}
    for bg_id in backgrounds:
        bg_res_ids[bg_id] = res_id
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append('script = ExtResource("ext_1")')
        lines.append(f'background_name = "{bg_id}"')
        lines.append(f'background_scene = ExtResource("ext_{scene_ids[bg_id]}")')
        res_id += 1

    bg_refs = ", ".join(f'SubResource("res_{bg_res_ids[b]}")' for b in backgrounds)
    lines.append("\n[resource]")
    lines.append('script = ExtResource("ext_2")')
    lines.append(f'background_list = Array[ExtResource("ext_1")]([{bg_refs}])')

    out_path = BACKGROUNDS_DIR / "backgrounds.tres"
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [saved] {out_path}")
