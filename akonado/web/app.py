"""akonado web application.

Provides a browser-based GUI for:
- Viewing and editing manifests
- Triggering asset generation
- Monitoring generation progress
- Managing skills and prompts
"""

from __future__ import annotations

import json
from pathlib import Path

from flask import Flask, render_template, request, jsonify, redirect, url_for

from ..config import (
    AKONADO_ROOT, MANIFESTS_DIR, SKILLS_DIR, CHARACTERS_DIR,
    BACKGROUNDS_DIR, BGM_DIR, SE_DIR, VOICE_DIR, UI_DIR,
    STORY_DIR, ensure_dirs,
)


def create_app() -> Flask:
    app = Flask(
        __name__,
        template_folder=str(Path(__file__).parent / "templates"),
        static_folder=str(Path(__file__).parent / "static"),
    )

    # ── Dashboard ──────────────────────────────────────────────

    @app.route("/")
    def index():
        manifests = _list_manifests()
        skills = _list_skills()
        stats = _get_stats()
        return render_template("index.html", manifests=manifests, skills=skills, stats=stats)

    # ── Manifests ──────────────────────────────────────────────

    @app.route("/manifests")
    def manifests_page():
        manifests = _list_manifests()
        return render_template("manifests.html", manifests=manifests)

    @app.route("/manifests/<name>", methods=["GET", "POST"])
    def manifest_detail(name):
        path = MANIFESTS_DIR / f"{name}.json"
        if request.method == "POST":
            try:
                data = json.loads(request.form["content"])
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                return redirect(url_for("manifest_detail", name=name))
            except json.JSONDecodeError as e:
                return render_template("manifest_detail.html", name=name,
                                       content=request.form["content"], error=str(e))

        if not path.exists():
            return render_template("manifest_detail.html", name=name,
                                   content="{}", error=None)
        with open(path, encoding="utf-8") as f:
            content = f.read()
        return render_template("manifest_detail.html", name=name,
                               content=content, error=None)

    # ── Skills ─────────────────────────────────────────────────

    @app.route("/skills")
    def skills_page():
        skills = _list_skills()
        return render_template("skills.html", skills=skills)

    @app.route("/skills/<name>", methods=["GET", "POST"])
    def skill_detail(name):
        path = SKILLS_DIR / f"{name}.json"
        if request.method == "POST":
            try:
                data = json.loads(request.form["content"])
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                return redirect(url_for("skill_detail", name=name))
            except json.JSONDecodeError as e:
                return render_template("skill_detail.html", name=name,
                                       content=request.form["content"], error=str(e))

        if not path.exists():
            return "Skill not found", 404
        with open(path, encoding="utf-8") as f:
            content = f.read()
        return render_template("skill_detail.html", name=name, content=content, error=None)

    # ── Generation API ─────────────────────────────────────────

    @app.route("/api/generate", methods=["POST"])
    def api_generate():
        data = request.json
        asset_type = data.get("type", "all")
        engine = data.get("engine", "mimo")
        force = data.get("force", False)

        ensure_dirs()

        from ..providers import ComfyUIImageProvider, MiMoTTS, QwenTTS
        from ..generators import (
            generate_characters, generate_backgrounds, generate_bgm,
            generate_se, generate_voice_all, generate_ui, generate_dialogue,
        )

        image = ComfyUIImageProvider()
        tts = QwenTTS() if engine == "qwen" else MiMoTTS()

        generators = {
            "characters": lambda: generate_characters(image, skip_existing=not force),
            "backgrounds": lambda: generate_backgrounds(image, skip_existing=not force),
            "bgm": lambda: generate_bgm(image, skip_existing=not force),
            "se": lambda: generate_se(image, skip_existing=not force),
            "voice": lambda: generate_voice_all(tts, skip_existing=not force),
            "ui": lambda: generate_ui(image, skip_existing=not force),
            "dialogue": lambda: generate_dialogue(),
        }

        if asset_type == "all":
            results = {}
            for name, fn in generators.items():
                try:
                    fn()
                    results[name] = "ok"
                except Exception as e:
                    results[name] = f"error: {e}"
            return jsonify({"status": "done", "results": results})
        elif asset_type in generators:
            try:
                generators[asset_type]()
                return jsonify({"status": "ok"})
            except Exception as e:
                return jsonify({"status": "error", "message": str(e)}), 500
        else:
            return jsonify({"status": "error", "message": f"Unknown type: {asset_type}"}), 400

    # ── Provider check API ─────────────────────────────────────

    @app.route("/api/providers")
    def api_providers():
        from ..providers import ComfyUIImageProvider, MiMoTTS, QwenTTS, OpenAICompatibleLLM

        providers = {
            "comfyui": ComfyUIImageProvider().available(),
            "llm": OpenAICompatibleLLM().available(),
            "mimo_tts": MiMoTTS().available(),
            "qwen_tts": QwenTTS().available(),
        }
        return jsonify(providers)

    # ── Skill run API ──────────────────────────────────────────

    @app.route("/api/skill/run", methods=["POST"])
    def api_skill_run():
        data = request.json
        name = data.get("name")
        input_text = data.get("input", "")
        variables = data.get("variables", {})
        temperature = data.get("temperature", 0.7)

        from ..skills import load_skill, render_user_prompt
        from ..providers import OpenAICompatibleLLM

        try:
            skill = load_skill(name)
        except FileNotFoundError as e:
            return jsonify({"status": "error", "message": str(e)}), 404

        llm = OpenAICompatibleLLM()
        if not llm.available():
            return jsonify({"status": "error", "message": "LLM not configured"}), 503

        variables["input"] = input_text
        system = skill["system_prompt"]
        user = render_user_prompt(skill, **variables)

        try:
            result = llm.generate(system, user, temperature=temperature)
            output_format = skill.get("output_format", "text")
            if output_format == "json":
                try:
                    result = json.loads(result)
                except json.JSONDecodeError:
                    pass
            return jsonify({"status": "ok", "result": result})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500

    # ── Stats API ──────────────────────────────────────────────

    @app.route("/api/stats")
    def api_stats():
        return jsonify(_get_stats())

    return app


def _list_manifests() -> list[dict]:
    """List all manifest files."""
    manifests = []
    if MANIFESTS_DIR.exists():
        for path in sorted(MANIFESTS_DIR.glob("*.json")):
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            manifests.append({
                "name": path.stem,
                "type": data.get("type", "unknown"),
                "path": str(path),
            })
    return manifests


def _list_skills() -> list[dict]:
    """List all skill files."""
    skills = []
    if SKILLS_DIR.exists():
        for path in sorted(SKILLS_DIR.glob("*.json")):
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            skills.append({
                "name": data.get("name", path.stem),
                "description": data.get("description", ""),
            })
    return skills


def _get_stats() -> dict:
    """Get asset generation statistics."""
    def count_files(d: Path) -> int:
        return len(list(d.iterdir())) if d.exists() else 0

    def count_dirs(d: Path) -> int:
        return len([x for x in d.iterdir() if x.is_dir()]) if d.exists() else 0

    return {
        "characters": count_dirs(CHARACTERS_DIR),
        "backgrounds": count_files(BACKGROUNDS_DIR),
        "bgm": count_files(BGM_DIR),
        "se": count_files(SE_DIR),
        "voice": count_files(VOICE_DIR),
        "ui": count_files(UI_DIR),
        "stories": len(list(STORY_DIR.rglob("*.ks"))) if STORY_DIR.exists() else 0,
    }
