"""Godot .tres resource generator for Konado 2.8+.

Generates Konado 2.8-compatible .tres files from manifests and generated assets:
- characters.tres (KonadoCharacterList)
- backgrounds.tres (KonadoBackgroundList)
- bgm.tres (KonadoBackgroundMusicList)
- se.tres (KonadoSoundEffectList)
- voice.tres (KonadoVoiceList)
"""

from __future__ import annotations

import json
from pathlib import Path

from ..config import (
    BACKGROUNDS_DIR,
    BGM_DIR,
    CGS_DIR,
    CHARACTERS_DIR,
    KONADO_BACKGROUND_LIST_SCRIPT,
    KONADO_BACKGROUND_SCRIPT,
    KONADO_BGM_LIST_SCRIPT,
    KONADO_BGM_SCRIPT,
    KONADO_CHARACTER_LIST_SCRIPT,
    KONADO_CHARACTER_SCRIPT,
    KONADO_SE_LIST_SCRIPT,
    KONADO_SE_SCRIPT,
    KONADO_VOICE_LIST_SCRIPT,
    KONADO_VOICE_SCRIPT,
    MANIFESTS_DIR,
    SE_DIR,
    VOICE_DIR,
)


def _tres_header(script_class: str, load_steps: int) -> str:
    """Generate .tres header."""
    return f'[gd_resource type="Resource" script_class="{script_class}" load_steps={load_steps} format=3]\n'


def _ext_resource_script(path: str, res_id: str) -> str:
    return f'[ext_resource type="Script" path="{path}" id="{res_id}"]\n'


def _ext_resource_texture(path: str, res_id: str) -> str:
    return f'[ext_resource type="Texture2D" path="{path}" id="{res_id}"]\n'


def _ext_resource_audio(path: str, res_id: str) -> str:
    return f'[ext_resource type="AudioStream" path="{path}" id="{res_id}"]\n'


def _ext_resource_scene(path: str, res_id: str) -> str:
    return f'[ext_resource type="PackedScene" path="{path}" id="{res_id}"]\n'


def generate_characters_tres() -> None:
    """Generate characters.tres referencing character .tscn scene files.

    Konado 2.8: KonadoCharacterList -> characters: Array[KonadoCharacter]
      KonadoCharacter.character_id: String
      KonadoCharacter.character_scene: PackedScene (the .tscn file)
    """
    manifest_path = MANIFESTS_DIR / "characters.json"
    if not manifest_path.exists():
        print("[characters.tres] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("characters", {}))

    # Collect characters that have a scene file
    characters = []
    for char_id, char_cfg in items.items():
        scene_path = CHARACTERS_DIR / char_id / f"{char_id}.tscn"
        if scene_path.exists():
            characters.append(char_id)

    if not characters:
        print("[characters.tres] no character scene files found, skipping")
        return

    # load_steps: scripts + scenes + sub_resources + root
    load_steps = 2 + len(characters) + len(characters) + 1
    lines = [_tres_header("KonadoCharacterList", load_steps)]

    # External resources
    lines.append(_ext_resource_script(KONADO_CHARACTER_SCRIPT, "ext_1"))
    lines.append(_ext_resource_script(KONADO_CHARACTER_LIST_SCRIPT, "ext_2"))

    ext_id = 3
    scene_ids = {}
    for char_id in characters:
        scene_ids[char_id] = ext_id
        lines.append(
            _ext_resource_scene(
                f"res://assets/characters/{char_id}/{char_id}.tscn", f"ext_{ext_id}"
            )
        )
        ext_id += 1

    # Sub-resources for characters
    res_id = 1
    char_res_ids = {}
    for char_id in characters:
        char_res_ids[char_id] = res_id
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append('script = ExtResource("ext_1")')
        lines.append(f'character_id = "{char_id}"')
        lines.append(f'character_scene = ExtResource("ext_{scene_ids[char_id]}")')
        res_id += 1

    # Root resource
    char_refs = ", ".join(f'SubResource("res_{char_res_ids[c]}")' for c in characters)
    lines.append("\n[resource]")
    lines.append('script = ExtResource("ext_2")')
    lines.append(f'characters = Array[ExtResource("ext_1")]([{char_refs}])')

    out_path = CHARACTERS_DIR / "characters.tres"
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [saved] {out_path}")


def generate_backgrounds_tres() -> None:
    """Generate backgrounds.tres referencing background .tscn scene files.

    Konado 2.8: KonadoBackgroundList -> background_list: Array[KonadoBackground]
      KonadoBackground.background_name: String
      KonadoBackground.background_scene: PackedScene (the .tscn file)
    """
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
    lines = [_tres_header("KonadoBackgroundList", load_steps)]

    lines.append(_ext_resource_script(KONADO_BACKGROUND_SCRIPT, "ext_1"))
    lines.append(_ext_resource_script(KONADO_BACKGROUND_LIST_SCRIPT, "ext_2"))

    ext_id = 3
    scene_ids = {}
    for bg_id in backgrounds:
        scene_ids[bg_id] = ext_id
        # Check if it's a CG (in cgs/) or regular background
        bg_dir = "cgs" if (CGS_DIR / f"{bg_id}.tscn").exists() else "backgrounds"
        lines.append(_ext_resource_scene(f"res://assets/{bg_dir}/{bg_id}.tscn", f"ext_{ext_id}"))
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


def generate_audio_tres(
    manifest_name: str,
    asset_dir: Path,
    script_class: str,
    list_script: str,
    item_script: str,
    list_field: str,
    name_field: str,
    audio_field: str,
    out_name: str,
) -> None:
    """Generate an audio .tres file (BGM, SE, or voice)."""
    manifest_path = MANIFESTS_DIR / f"{manifest_name}.json"
    if not manifest_path.exists():
        print(f"[{out_name}] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    if manifest_name == "voice":
        items_data = data.get("lines", [])
        item_ids = [item["id"] for item in items_data if "id" in item]
    else:
        items_data = data.get("items", {})
        item_ids = list(items_data.keys())

    audio_items = []
    for item_id in item_ids:
        for ext in ["mp3", "ogg", "wav"]:
            audio_path = asset_dir / f"{item_id}.{ext}"
            if audio_path.exists():
                audio_items.append((item_id, ext))
                break

    if not audio_items:
        print(f"[{out_name}] no audio assets found, skipping")
        return

    load_steps = 2 + len(audio_items) + len(audio_items) + 1
    lines = [_tres_header(script_class, load_steps)]

    lines.append(_ext_resource_script(list_script, "ext_1"))
    lines.append(_ext_resource_script(item_script, "ext_2"))

    ext_id = 3
    audio_ids = {}
    if asset_dir.name == "bgm":
        res_prefix = "res://assets/audio/bgm"
    elif asset_dir.name == "se":
        res_prefix = "res://assets/audio/se"
    elif asset_dir.name == "voice":
        res_prefix = "res://assets/audio/voice"
    else:
        res_prefix = f"res://assets/{asset_dir.name}"

    for item_id, ext in audio_items:
        audio_ids[item_id] = ext_id
        lines.append(_ext_resource_audio(f"{res_prefix}/{item_id}.{ext}", f"ext_{ext_id}"))
        ext_id += 1

    res_id = 1
    item_res_ids = {}
    for item_id, ext in audio_items:
        item_res_ids[item_id] = res_id
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append('script = ExtResource("ext_2")')
        lines.append(f'{name_field} = "{item_id}"')
        lines.append(f'{audio_field} = ExtResource("ext_{audio_ids[item_id]}")')
        res_id += 1

    item_refs = ", ".join(f'SubResource("res_{item_res_ids[i]}")' for i, _ in audio_items)
    lines.append("\n[resource]")
    lines.append('script = ExtResource("ext_1")')
    lines.append(f'{list_field} = Array[ExtResource("ext_2")]([{item_refs}])')

    out_path = asset_dir / out_name
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [saved] {out_path}")


def generate_bgm_tres() -> None:
    """Generate bgm.tres for Konado 2.8."""
    generate_audio_tres(
        manifest_name="bgm",
        asset_dir=BGM_DIR,
        script_class="KonadoBackgroundMusicList",
        list_script=KONADO_BGM_LIST_SCRIPT,
        item_script=KONADO_BGM_SCRIPT,
        list_field="background_music_tracks",
        name_field="background_music_name",
        audio_field="stream",
        out_name="bgm.tres",
    )


def generate_se_tres() -> None:
    """Generate se.tres for Konado 2.8."""
    generate_audio_tres(
        manifest_name="se",
        asset_dir=SE_DIR,
        script_class="KonadoSoundEffectList",
        list_script=KONADO_SE_LIST_SCRIPT,
        item_script=KONADO_SE_SCRIPT,
        list_field="sound_effects",
        name_field="sound_effect_name",
        audio_field="stream",
        out_name="se.tres",
    )


def generate_voice_tres() -> None:
    """Generate voice.tres for Konado 2.8."""
    generate_audio_tres(
        manifest_name="voice",
        asset_dir=VOICE_DIR,
        script_class="KonadoVoiceList",
        list_script=KONADO_VOICE_LIST_SCRIPT,
        item_script=KONADO_VOICE_SCRIPT,
        list_field="voices",
        name_field="voice_name",
        audio_field="stream",
        out_name="voice.tres",
    )


def generate_all_tres() -> None:
    """Generate all .tres resource files."""
    print("[godot_resources] Generating .tres files...")
    generate_characters_tres()
    generate_backgrounds_tres()
    generate_bgm_tres()
    generate_se_tres()
    generate_voice_tres()
    print("[godot_resources] done")
