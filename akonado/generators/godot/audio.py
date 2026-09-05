"""Audio .tres generators (BGM, SE, Voice) for Konado 2.8+."""

from __future__ import annotations

import json
from pathlib import Path

from ...config import (
    BGM_DIR,
    KONADO_BGM_LIST_SCRIPT,
    KONADO_BGM_SCRIPT,
    KONADO_SE_LIST_SCRIPT,
    KONADO_SE_SCRIPT,
    KONADO_VOICE_LIST_SCRIPT,
    KONADO_VOICE_SCRIPT,
    MANIFESTS_DIR,
    SE_DIR,
    VOICE_DIR,
)
from .helpers import ext_resource_audio, ext_resource_script, tres_header


def _generate_audio_tres(
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
    lines = [tres_header(script_class, load_steps)]

    lines.append(ext_resource_script(list_script, "ext_1"))
    lines.append(ext_resource_script(item_script, "ext_2"))

    ext_id = 3
    audio_ids = {}
    res_prefix_map = {
        "bgm": "res://assets/audio/bgm",
        "se": "res://assets/audio/se",
        "voice": "res://assets/audio/voice",
    }
    res_prefix = res_prefix_map.get(asset_dir.name, f"res://assets/{asset_dir.name}")

    for item_id, ext in audio_items:
        audio_ids[item_id] = ext_id
        lines.append(ext_resource_audio(f"{res_prefix}/{item_id}.{ext}", f"ext_{ext_id}"))
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
    _generate_audio_tres(
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
    _generate_audio_tres(
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
    _generate_audio_tres(
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
