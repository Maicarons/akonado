"""Pipeline command: premise -> manifests -> assets -> .ks scripts."""

from __future__ import annotations

import argparse
import json as _json
from pathlib import Path

from ..config import (
    ASSETS_DIR,
    GODOT_DIR,
    MANIFESTS_DIR,
    STORY_DIR,
    ensure_dirs,
)
from ..providers import OpenAICompatibleLLM
from .helpers import load_json, run_skill, save_json


def cmd_pipeline(args: argparse.Namespace) -> None:
    """Full pipeline: premise -> script -> manifests -> assets -> .ks scripts."""
    ensure_dirs()
    llm = OpenAICompatibleLLM()
    if not llm.available():
        print("Error: LLM provider not available. Set LLM_API_KEY in .env")
        return

    premise = args.premise
    temperature = args.temperature or 0.7
    num_chapters = args.chapters
    scenes_per_chapter = args.scenes_per_chapter
    godot_dir = Path(args.godot_dir) if args.godot_dir else GODOT_DIR

    # ── Step 1: Generate script.json ──────────────────────────
    print("\n" + "=" * 50)
    print("  Step 1/10: Generating script from premise")
    print("=" * 50)
    script_result = run_skill(
        llm,
        "generate_script",
        {
            "input": premise,
            "num_chapters": str(num_chapters),
            "scenes_per_chapter": str(scenes_per_chapter),
        },
        temperature,
    )
    try:
        script_data = _json.loads(script_result, strict=False)
    except _json.JSONDecodeError:
        print("Error: Failed to parse script JSON from LLM output")
        print(script_result[:500])
        return
    save_json(MANIFESTS_DIR / "script.json", script_data)

    # ── Step 2: Generate character manifest ───────────────────
    print("\n" + "=" * 50)
    print("  Step 2/10: Generating character prompts")
    print("=" * 50)
    char_input = _json.dumps(script_data.get("characters", []), ensure_ascii=False, indent=2)
    char_result = run_skill(
        llm,
        "generate_character_prompts",
        {
            "input": char_input,
            "style": "anime visual novel style",
            "style_keywords": "clean lineart, soft cel shading",
        },
        temperature,
    )
    try:
        char_data = _json.loads(char_result, strict=False)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse character JSON, saving raw output")
        char_data = char_result
    save_json(
        MANIFESTS_DIR / "characters.json",
        char_data if isinstance(char_data, dict) else {"raw": char_data},
    )

    # ── Step 3: Generate background manifest ──────────────────
    print("\n" + "=" * 50)
    print("  Step 3/10: Generating background prompts")
    print("=" * 50)
    bg_input = _json.dumps(script_data.get("backgrounds", []), ensure_ascii=False, indent=2)
    bg_result = run_skill(
        llm,
        "generate_background_prompts",
        {"input": bg_input, "style": "anime style background, visual novel background"},
        temperature,
    )
    try:
        bg_data = _json.loads(bg_result, strict=False)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse background JSON, saving raw output")
        bg_data = bg_result
    save_json(
        MANIFESTS_DIR / "backgrounds.json",
        bg_data if isinstance(bg_data, dict) else {"raw": bg_data},
    )

    # ── Step 4: Generate CG manifest ─────────────────────────
    print("\n" + "=" * 50)
    print("  Step 4/10: Generating CG illustration prompts")
    print("=" * 50)
    cgs_input = _json.dumps(script_data.get("cgs", []), ensure_ascii=False, indent=2)
    char_input_for_cg = _json.dumps(script_data.get("characters", []), ensure_ascii=False, indent=2)
    cgs_result = run_skill(
        llm,
        "generate_cg_prompts",
        {
            "input": cgs_input,
            "characters": char_input_for_cg,
            "style": "anime visual novel CG illustration",
            "style_keywords": "illustration, detailed, high quality, visual novel CG, anime art",
        },
        temperature,
    )
    try:
        cgs_data = _json.loads(cgs_result, strict=False)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse CG JSON, saving raw output")
        cgs_data = cgs_result
    save_json(
        MANIFESTS_DIR / "cgs.json", cgs_data if isinstance(cgs_data, dict) else {"raw": cgs_data}
    )

    # ── Step 5: Generate audio manifests ──────────────────────
    print("\n" + "=" * 50)
    print("  Step 5/10: Generating audio prompts")
    print("=" * 50)
    audio_input_data = {
        "bgm": script_data.get("bgm", []),
        "se": script_data.get("se", []),
    }
    audio_input = _json.dumps(audio_input_data, ensure_ascii=False, indent=2)
    audio_result = run_skill(
        llm,
        "generate_audio_prompts",
        {"input": audio_input, "style": "visual novel game audio"},
        temperature,
    )
    try:
        audio_data = _json.loads(audio_result, strict=False)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse audio JSON, saving raw output")
        audio_data = {"raw": audio_result}
    if isinstance(audio_data, dict):
        if "bgm" in audio_data:
            save_json(MANIFESTS_DIR / "bgm.json", audio_data["bgm"])
        if "se" in audio_data:
            save_json(MANIFESTS_DIR / "se.json", audio_data["se"])
    else:
        save_json(MANIFESTS_DIR / "audio.json", audio_data)

    # ── Step 6: Generate voice config ─────────────────────────
    print("\n" + "=" * 50)
    print("  Step 6/10: Generating voice config")
    print("=" * 50)
    voice_input = _json.dumps(script_data.get("characters", []), ensure_ascii=False, indent=2)
    voice_result = run_skill(
        llm,
        "generate_voice_config",
        {
            "input": voice_input,
            "mimo_voices": "冰糖(女), 茉莉(女), 苏打(男), 白桦(男)",
            "qwen_speakers": (
                "Ethan(晨煦/男), Cherry(芊悦/女), Serena(苏瑶/女), "
                "Eldric Sage(沧明子/老者男), Vincent(田叔/沙哑男), Kai(凯/男), "
                "Moon(月白/男), Maia(四月/女), Ryan(甜茶/男), "
                "Chelsie(千雪/女), Nofish(不吃鱼/男)"
            ),
        },
        temperature,
    )
    try:
        voice_data = _json.loads(voice_result, strict=False)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse voice config JSON, saving raw output")
        voice_data = {"raw": voice_result}
    save_json(
        MANIFESTS_DIR / "voice_config.json",
        voice_data if isinstance(voice_data, dict) else {"raw": voice_data},
    )

    # ── Step 7: Generate UI manifest ──────────────────────────
    print("\n" + "=" * 50)
    print("  Step 7/10: Generating UI prompts")
    print("=" * 50)
    ui_input = _json.dumps(
        {
            "title": script_data.get("title", ""),
            "premise": premise,
            "characters": script_data.get("characters", []),
        },
        ensure_ascii=False,
        indent=2,
    )
    ui_result = run_skill(
        llm,
        "generate_ui_prompts",
        {"input": ui_input, "style": "anime visual novel style"},
        temperature,
    )
    try:
        ui_data = _json.loads(ui_result, strict=False)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse UI JSON, saving raw output")
        ui_data = {"raw": ui_result}
    save_json(MANIFESTS_DIR / "ui.json", ui_data if isinstance(ui_data, dict) else {"raw": ui_data})

    # ── Prompts-only mode: stop here ─────────────────────────
    if getattr(args, "prompts_only", False):
        print("\n" + "=" * 50)
        print("  Prompts-only mode: manifests generated!")
        print("=" * 50)
        print("  All manifests saved to:", MANIFESTS_DIR)
        print()
        print("  You can now:")
        print("    1. Edit manifests/*.json to customize prompts")
        print("    2. Edit manifests/script.json to adjust the story")
        print("    3. Run 'python -m akonado generate all' when ready")
        print("    4. Or generate specific types:")
        print("       python -m akonado generate characters")
        print("       python -m akonado generate backgrounds")
        print("       python -m akonado generate bgm")
        return

    # ── Step 8: Generate visual/audio assets ──
    scripts_only = getattr(args, "scripts_only", False)

    if not scripts_only:
        print("\n" + "=" * 50)
        print("  Step 8/10: Generating visual/audio assets")
        print("=" * 50)
        from ..generators import (
            generate_background_scenes,
            generate_backgrounds,
            generate_bgm,
            generate_cg_scenes,
            generate_cgs,
            generate_character_scenes,
            generate_characters,
            generate_se,
            generate_ui,
        )
        from ..providers import ComfyUIImageProvider, MiMoTTS

        skip = not args.force
        engine = getattr(args, "engine", "mimo") or "mimo"
        image = ComfyUIImageProvider()
        tts = (
            MiMoTTS()
            if engine == "mimo"
            else __import__("akonado.providers.tts_qwen", fromlist=["QwenTTS"]).QwenTTS()
        )

        for name, fn in [
            ("characters", lambda: generate_characters(image, skip_existing=skip)),
            ("backgrounds", lambda: generate_backgrounds(image, skip_existing=skip)),
            ("cgs", lambda: generate_cgs(image, skip_existing=skip)),
            ("bgm", lambda: generate_bgm(image, skip_existing=skip)),
            ("se", lambda: generate_se(image, skip_existing=skip)),
            ("ui", lambda: generate_ui(image, skip_existing=skip)),
        ]:
            print(f"\n--- {name} ---")
            try:
                fn()
            except Exception as e:
                print(f"  [error] {name}: {e}")

    # ── Step 9: Generate .ks scripts ──
    print("\n" + "=" * 50)
    print("  Step 9/10: Generating .ks scripts, voice & dialogue")
    print("=" * 50)
    chapters = script_data.get("chapters", [])

    char_manifest = load_json(MANIFESTS_DIR / "characters.json")
    bg_manifest = load_json(MANIFESTS_DIR / "backgrounds.json")
    cgs_manifest_path = MANIFESTS_DIR / "cgs.json"
    cgs_manifest = load_json(cgs_manifest_path) if cgs_manifest_path.exists() else {}
    bgm_manifest = load_json(MANIFESTS_DIR / "bgm.json")
    se_manifest = load_json(MANIFESTS_DIR / "se.json")

    char_ids = list(char_manifest.get("items", {}).keys())
    bg_ids = list(bg_manifest.get("items", {}).keys())
    cg_ids = list(cgs_manifest.get("items", {}).keys())
    bgm_ids = list(bgm_manifest.get("items", {}).keys())
    se_ids = list(se_manifest.get("items", {}).keys())

    char_info = []
    for cid in char_ids:
        cdata = char_manifest["items"][cid]
        char_info.append(
            {
                "id": cid,
                "name": cdata.get("name", cid),
                "expressions": list(cdata.get("expressions", {}).keys()),
            }
        )
    char_info_str = _json.dumps(char_info, ensure_ascii=False)

    print(f"  Characters: {char_ids}")
    print(f"  Backgrounds: {bg_ids}")
    print(f"  CGs: {cg_ids}")
    print(f"  BGM: {bgm_ids}")
    print(f"  SE: {se_ids}")

    for chapter in chapters:
        chapter_dir = STORY_DIR / chapter["id"]
        chapter_dir.mkdir(parents=True, exist_ok=True)
        for scene in chapter.get("scenes", []):
            scene_vars = {
                "scene_summary": scene.get("summary", ""),
                "characters": char_info_str,
                "backgrounds": _json.dumps(bg_ids, ensure_ascii=False),
                "cg_list": _json.dumps(cg_ids, ensure_ascii=False) if cg_ids else "（无可用CG）",
                "bgm_list": _json.dumps(bgm_ids, ensure_ascii=False),
                "context": chapter.get("summary", ""),
                "extra_instructions": f"""重要：必须使用以下ID，不要自行发明！
背景ID: {", ".join(bg_ids)}
CG ID: {", ".join(cg_ids) if cg_ids else "（无）"}
BGM ID: {", ".join(bgm_ids)}
SE ID: {", ".join(se_ids)}
角色ID: {", ".join(char_ids)}
角色表情: {
                    _json.dumps(
                        {
                            c: list(char_manifest["items"][c]["expressions"].keys())
                            for c in char_ids
                        },
                        ensure_ascii=False,
                    )
                }""",
            }
            ks_result = run_skill(llm, "generate_scene_script", scene_vars, temperature)
            ks_path = chapter_dir / f"{scene['id']}.ks"
            with open(ks_path, "w", encoding="utf-8") as f:
                f.write(ks_result)
            print(f"  [saved] {ks_path}")

    # ── Step 8b: Generate voice and dialogue ──
    if not scripts_only:
        print("\n--- voice ---")
        try:
            from ..generators import generate_voice_all

            generate_voice_all(tts, skip_existing=skip)
        except Exception as e:
            print(f"  [error] voice: {e}")

    print("\n--- dialogue ---")
    try:
        from ..generators import generate_dialogue

        generate_dialogue()
    except Exception as e:
        print(f"  [error] dialogue: {e}")

    # ── Step 10: Generate Konado 2.8+ scene files & .tres ──
    print("\n" + "=" * 50)
    print("  Step 10/10: Generating scene files & .tres resources")
    print("=" * 50)

    if not scripts_only:
        print("\n--- character scenes ---")
        try:
            from ..generators import generate_character_scenes

            generate_character_scenes(skip_existing=skip)
        except Exception as e:
            print(f"  [error] character_scenes: {e}")

        print("\n--- background scenes ---")
        try:
            from ..generators import generate_background_scenes

            generate_background_scenes(skip_existing=skip)
        except Exception as e:
            print(f"  [error] background_scenes: {e}")

        print("\n--- CG scenes ---")
        try:
            from ..generators import generate_cg_scenes

            generate_cg_scenes(skip_existing=skip)
        except Exception as e:
            print(f"  [error] cg_scenes: {e}")

    print("\n--- .tres resources ---")
    try:
        from ..generators import generate_all_tres

        generate_all_tres()
    except Exception as e:
        print(f"  [error] godot_resources: {e}")

    # ── Summary ──
    print("\n" + "=" * 50)
    print("  Pipeline complete!")
    print("=" * 50)
    print(f"  Premise: {premise[:60]}...")
    print(f"  Chapters: {len(chapters)}")
    total_scenes = sum(len(ch.get("scenes", [])) for ch in chapters)
    print(f"  Scenes: {total_scenes}")
    print(f"  Godot dir: {godot_dir}")
    print(f"  Assets: {ASSETS_DIR}")
    print(f"  Scripts: {STORY_DIR}")
