"""Godot .tres resource generator.

Generates Konado-compatible .tres files from manifests and generated assets:
- characters.tres (KND_CharacterList)
- backgrounds.tres (KND_BackgroundList)
- bgm.tres (KND_BgmList)
- se.tres (KND_SoundEffectList)
- voice.tres (DialogVoiceList)
"""

from __future__ import annotations

import json
from pathlib import Path

from ..config import (
    MANIFESTS_DIR,
    CHARACTERS_DIR,
    BACKGROUNDS_DIR,
    CGS_DIR,
    BGM_DIR,
    SE_DIR,
    VOICE_DIR,
)


def _tres_header(script_class: str, load_steps: int) -> str:
    """Generate .tres header."""
    return f'[gd_resource type="Resource" script_class="{script_class}" load_steps={load_steps} format=3]\n'


def _ext_resource_script(path: str, res_id: str) -> str:
    """Generate ext_resource for a script."""
    return f'[ext_resource type="Script" path="{path}" id="{res_id}"]\n'


def _ext_resource_texture(path: str, res_id: str) -> str:
    """Generate ext_resource for a texture."""
    return f'[ext_resource type="Texture2D" path="{path}" id="{res_id}"]\n'


def _ext_resource_audio(path: str, res_id: str) -> str:
    """Generate ext_resource for an audio stream."""
    return f'[ext_resource type="AudioStream" path="{path}" id="{res_id}"]\n'


def generate_characters_tres() -> None:
    """Generate characters.tres from character assets."""
    manifest_path = MANIFESTS_DIR / "characters.json"
    if not manifest_path.exists():
        print("[characters.tres] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("characters", {}))

    # Collect all characters and their expressions
    characters = []
    for char_id, char_cfg in items.items():
        expressions = char_cfg.get("expressions", {})
        # Only include expressions that have generated files
        available_states = []
        for expr_name in expressions:
            img_path = CHARACTERS_DIR / char_id / f"{expr_name}.png"
            if img_path.exists():
                available_states.append(expr_name)
        if available_states:
            characters.append((char_id, available_states))

    if not characters:
        print("[characters.tres] no character assets found, skipping")
        return

    # Calculate load_steps: scripts + textures + sub_resources + root
    total_textures = sum(len(states) for _, states in characters)
    total_sub_resources = total_textures + len(characters)  # states + characters
    load_steps = 3 + total_textures + total_sub_resources + 1  # 3 scripts + textures + subs + root

    lines = [_tres_header("KND_CharacterList", load_steps)]

    # External resources
    lines.append(_ext_resource_script(
        "res://addons/konado/scripts/character/knd_character_list.gd", "ext_1"
    ))
    lines.append(_ext_resource_script(
        "res://addons/konado/scripts/character/knd_character.gd", "ext_2"
    ))
    lines.append(_ext_resource_script(
        "res://addons/konado/scripts/character/knd_character_status.gd", "ext_3"
    ))

    ext_id = 4
    texture_ids = {}  # (char_id, expr_name) -> ext_id
    for char_id, states in characters:
        for expr_name in states:
            texture_ids[(char_id, expr_name)] = ext_id
            lines.append(_ext_resource_texture(
                f"res://assets/characters/{char_id}/{expr_name}.png", f"ext_{ext_id}"
            ))
            ext_id += 1

    # Sub-resources for character states
    res_id = 1
    state_ids = {}  # (char_id, expr_name) -> res_id
    for char_id, states in characters:
        for expr_name in states:
            state_ids[(char_id, expr_name)] = res_id
            lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
            lines.append(f'script = ExtResource("ext_3")')
            lines.append(f'status_name = "{expr_name}"')
            lines.append(f'status_texture = ExtResource("ext_{texture_ids[(char_id, expr_name)]}")')
            res_id += 1

    # Sub-resources for characters
    char_ids = {}  # char_id -> res_id
    for char_id, states in characters:
        char_ids[char_id] = res_id
        state_refs = ", ".join(f'SubResource("res_{state_ids[(char_id, s)]}")' for s in states)
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append(f'script = ExtResource("ext_2")')
        lines.append(f'chara_name = "{char_id}"')
        lines.append(f'chara_status = Array[ExtResource("ext_3")]([{state_refs}])')
        res_id += 1

    # Root resource
    char_refs = ", ".join(f'SubResource("res_{char_ids[c]}")' for c, _ in characters)
    lines.append(f'\n[resource]')
    lines.append(f'script = ExtResource("ext_1")')
    lines.append(f'characters = Array[ExtResource("ext_2")]([{char_refs}])')

    out_path = CHARACTERS_DIR / "characters.tres"
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [saved] {out_path}")


def generate_backgrounds_tres() -> None:
    """Generate backgrounds.tres from background and CG assets.

    CGs are registered alongside regular backgrounds so they can be used
    with the ``background`` command in .ks scripts.
    """
    manifest_path = MANIFESTS_DIR / "backgrounds.json"
    if not manifest_path.exists():
        print("[backgrounds.tres] manifest not found, skipping")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data.get("backgrounds", {}))

    # Collect backgrounds: (id, res_path) pairs
    backgrounds: list[tuple[str, str]] = []
    for bg_id in items:
        img_path = BACKGROUNDS_DIR / f"{bg_id}.png"
        if img_path.exists():
            backgrounds.append((bg_id, f"res://assets/backgrounds/{bg_id}.png"))

    # Also include CGs as backgrounds (they can be used with the background command)
    cgs_manifest_path = MANIFESTS_DIR / "cgs.json"
    if cgs_manifest_path.exists():
        with open(cgs_manifest_path, encoding="utf-8") as f:
            cgs_data = json.load(f)
        for cg_id, cg_cfg in cgs_data.get("items", {}).items():
            img_path = CGS_DIR / f"{cg_id}.png"
            if img_path.exists():
                backgrounds.append((cg_id, f"res://assets/cgs/{cg_id}.png"))

    if not backgrounds:
        print("[backgrounds.tres] no background assets found, skipping")
        return

    # Calculate load_steps
    load_steps = 2 + len(backgrounds) + len(backgrounds) + 1  # scripts + textures + subs + root

    lines = [_tres_header("KND_BackgroundList", load_steps)]

    # External resources
    lines.append(_ext_resource_script(
        "res://addons/konado/scripts/background/knd_background_list.gd", "ext_1"
    ))
    lines.append(_ext_resource_script(
        "res://addons/konado/scripts/background/knd_background.gd", "ext_2"
    ))

    ext_id = 3
    texture_ids = {}
    for bg_id, res_path in backgrounds:
        texture_ids[bg_id] = ext_id
        lines.append(_ext_resource_texture(res_path, f"ext_{ext_id}"))
        ext_id += 1

    # Sub-resources
    res_id = 1
    bg_ids = {}
    for bg_id, _ in backgrounds:
        bg_ids[bg_id] = res_id
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append(f'script = ExtResource("ext_2")')
        lines.append(f'background_name = "{bg_id}"')
        lines.append(f'background_image = ExtResource("ext_{texture_ids[bg_id]}")')
        res_id += 1

    # Root resource
    bg_refs = ", ".join(f'SubResource("res_{bg_ids[b]}")' for b, _ in backgrounds)
    lines.append(f'\n[resource]')
    lines.append(f'script = ExtResource("ext_1")')
    lines.append(f'background_list = Array[ExtResource("ext_2")]([{bg_refs}])')

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

    # Handle different manifest structures
    if manifest_name == "voice":
        # Voice manifest has "lines" array with "id" field
        items_data = data.get("lines", [])
        item_ids = [item["id"] for item in items_data if "id" in item]
    else:
        # Other manifests have "items" dict
        items_data = data.get("items", {})
        item_ids = list(items_data.keys())

    # Find available audio files
    audio_items = []
    for item_id in item_ids:
        # Check for various audio formats
        for ext in ["mp3", "ogg", "wav"]:
            audio_path = asset_dir / f"{item_id}.{ext}"
            if audio_path.exists():
                audio_items.append((item_id, ext))
                break

    if not audio_items:
        print(f"[{out_name}] no audio assets found, skipping")
        return

    # Calculate load_steps
    load_steps = 2 + len(audio_items) + len(audio_items) + 1

    lines = [_tres_header(script_class, load_steps)]

    # External resources
    lines.append(_ext_resource_script(list_script, "ext_1"))
    lines.append(_ext_resource_script(item_script, "ext_2"))

    ext_id = 3
    audio_ids = {}
    # Determine the res:// path based on asset_dir
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
        lines.append(_ext_resource_audio(
            f"{res_prefix}/{item_id}.{ext}", f"ext_{ext_id}"
        ))
        ext_id += 1

    # Sub-resources
    res_id = 1
    item_res_ids = {}
    for item_id, ext in audio_items:
        item_res_ids[item_id] = res_id
        lines.append(f'\n[sub_resource type="Resource" id="res_{res_id}"]')
        lines.append(f'script = ExtResource("ext_2")')
        lines.append(f'{name_field} = "{item_id}"')
        lines.append(f'{audio_field} = ExtResource("ext_{audio_ids[item_id]}")')
        res_id += 1

    # Root resource
    item_refs = ", ".join(f'SubResource("res_{item_res_ids[i]}")' for i, _ in audio_items)
    lines.append(f'\n[resource]')
    lines.append(f'script = ExtResource("ext_1")')
    lines.append(f'{list_field} = Array[ExtResource("ext_2")]([{item_refs}])')

    out_path = asset_dir / out_name
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [saved] {out_path}")


def generate_bgm_tres() -> None:
    """Generate bgm.tres."""
    generate_audio_tres(
        manifest_name="bgm",
        asset_dir=BGM_DIR,
        script_class="KND_BgmList",
        list_script="res://addons/konado/scripts/audio/bgm/knd_bgm_list.gd",
        item_script="res://addons/konado/scripts/audio/bgm/knd_bgm.gd",
        list_field="bgms",
        name_field="bgm_name",
        audio_field="bgm",
        out_name="bgm.tres",
    )


def generate_se_tres() -> None:
    """Generate se.tres."""
    generate_audio_tres(
        manifest_name="se",
        asset_dir=SE_DIR,
        script_class="KND_SoundEffectList",
        list_script="res://addons/konado/scripts/audio/soundeffect/knd_soundeffect_list.gd",
        item_script="res://addons/konado/scripts/audio/soundeffect/knd_soundeffect.gd",
        list_field="soundeffects",
        name_field="se_name",
        audio_field="se",
        out_name="se.tres",
    )


def generate_voice_tres() -> None:
    """Generate voice.tres."""
    generate_audio_tres(
        manifest_name="voice",
        asset_dir=VOICE_DIR,
        script_class="DialogVoiceList",
        list_script="res://addons/konado/scripts/audio/voice/knd_voice_list.gd",
        item_script="res://addons/konado/scripts/audio/voice/knd_voice.gd",
        list_field="voices",
        name_field="voice_name",
        audio_field="voice",
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
