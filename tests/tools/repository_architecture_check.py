#!/usr/bin/env python3
"""Validate repository layout rules that are easy to regress during refactors."""

from __future__ import annotations

from pathlib import Path
import json
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
ADDONS = ROOT / "addons"
CORE = ADDONS / "konado"
KONADO_SCRIPT_SKILL = ROOT / "skills" / "konado-script"

ADDON_DIRECTORIES = {
    "konado",
    "konado_achievement",
    "konado_dotnet",
    "konado_settings",
    "konado_web_tool",
}

CORE_DIRECTORIES = {
    "assets",
    "editor",
    "export",
    "language",
    "localization",
    "runtime",
    "templates",
}
OBSOLETE_ADDON_DIRECTORIES = {
    "konadotnet",
    "konado_webtool",
}
OBSOLETE_CORE_DIRECTORIES = {
    "audioeffect",
    "cam",
    "fonts",
    "i18n",
    "ks",
    "logger",
    "scripts",
    "shader",
    "template",
    "typewriter",
}
LEGACY_RESOURCE_PATH_ALLOWLIST = {
    Path("addons/konado/konado_editor_plugin.gd"): {"i18n"},
    Path("tests/editor/test_project_migration.gd"): {"i18n"},
}
BACKUP_SUFFIXES = {".bak", ".orig", ".rej", ".tmp", "~"}
SOURCE_SUFFIXES = {".cs", ".gd", ".gdshader", ".json", ".ts", ".yml", ".yaml"}
RESOURCE_PATH_PATTERN = re.compile(r'res://addons/konado/([^"\s)]+)')
TEXT_RESOURCE_REFERENCE_PATTERN = re.compile(
    r'^\[ext_resource\b[^\]]*\bpath="(res://[^"]+)"', re.MULTILINE
)
SNAKE_CASE_PATH = re.compile(r"^[a-z0-9_]+$")
RESOURCE_FILE_NAME = re.compile(
    r"^[a-z0-9_]+(?:\.(?:en|ja|ko|zh_Hans|zh_Hant))?"
    r"\.(?:cfg|gd|gdshader|gif|jpg|json|ks|mp3|otf|png|svg|tres|tscn|ttf|txt|wav)"
    r"(?:\.import)?$"
)
RESOURCE_FILE_SUFFIXES = {
    ".cfg",
    ".gd",
    ".gdshader",
    ".gif",
    ".import",
    ".jpg",
    ".json",
    ".ks",
    ".mp3",
    ".otf",
    ".png",
    ".svg",
    ".tres",
    ".tscn",
    ".ttf",
    ".txt",
    ".wav",
}
CLASS_NAME_PATTERN = re.compile(r"^class_name\s+([A-Za-z][A-Za-z0-9]*)", re.MULTILINE)
CSHARP_CLASS_NAME_PATTERN = re.compile(
    r"^public\s+(?:(?:abstract|sealed|static)\s+)?(?:partial\s+)?class\s+"
    r"([A-Za-z][A-Za-z0-9]*)",
    re.MULTILINE,
)
SCENE_NODE_NAME_PATTERN = re.compile(r'^\[node name="([^"]+)"', re.MULTILINE)
SCENE_NODE_NAME = re.compile(r"^[A-Z][A-Za-z0-9]*$")
TYPESCRIPT_FILE_NAME = re.compile(
    r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.test)?\.(?:mjs|ts)$"
)
GENERIC_SCENE_NODE_NAMES = {
    "CanvasLayer",
    "ColorRect",
    "Control",
    "HBoxContainer",
    "Node",
    "Panel",
    "TextureRect",
    "VBoxContainer",
}
IGNORED_DIRECTORY_NAMES = {
    ".git",
    ".godot",
    "__pycache__",
    "node_modules",
    "bin",
    "dist",
}
FORBIDDEN_ROOT_ARTIFACTS = {"extension_api.json"}
INTERNAL_GDSCRIPT_TYPES = {
    Path("addons/konado/editor/script_editor/konado_script_link_overlay.gd"),
    Path("addons/konado/konado_editor_plugin.gd"),
    Path("addons/konado/runtime/camera/konado_camera_controller.gd"),
    Path("addons/konado/runtime/dialogue/konado_choice_controller.gd"),
    Path("addons/konado/runtime/integrations/konado_settings_adapter.gd"),
    Path("addons/konado/runtime/stage/background/konado_background_transition_layer.gd"),
    Path("addons/konado/runtime/ui/dialogue_box/konado_voice_progress_display.gd"),
    Path("addons/konado/runtime/ui/save/konado_save_panel.gd"),
}
EXPORT_PLUGIN = CORE / "export" / "konado_script_export_plugin.gd"
KONADO_EXPORT_CREDENTIALS_PATH = (
    'const EXPORT_CREDENTIALS_PATH := '
    '"res://.godot/konado_export_credentials.cfg"'
)
PLUGIN_VERSION_PATTERN = re.compile(r'^version="([^"]+)"$', re.MULTILINE)
LEGACY_SKILL_IDENTIFIER_PATTERN = re.compile(r"\bKND_[A-Za-z0-9_]+\b")


def report(errors: list[str], message: str) -> None:
    errors.append(message)


def exists_with_exact_case(path: Path) -> bool:
    """Reject paths that only resolve through a case-insensitive filesystem."""
    return path.parent.is_dir() and path.name in {entry.name for entry in path.parent.iterdir()}


def resource_exists_with_exact_case(resource_path: str) -> bool:
    """Resolve a Godot resource path without accepting case-only mismatches."""
    if not resource_path.startswith("res://"):
        return False
    current = ROOT
    for component in Path(resource_path.removeprefix("res://")).parts:
        if not current.is_dir() or component not in {
            entry.name for entry in current.iterdir()
        }:
            return False
        current /= component
    return current.is_file()


def check_layout(errors: list[str]) -> None:
    actual_addon_dirs = {item.name for item in ADDONS.iterdir() if item.is_dir()}
    unexpected_addons = actual_addon_dirs - ADDON_DIRECTORIES
    missing_addons = ADDON_DIRECTORIES - actual_addon_dirs
    if unexpected_addons:
        report(errors, f"unexpected add-on directories: {', '.join(sorted(unexpected_addons))}")
    if missing_addons:
        report(errors, f"missing add-on directories: {', '.join(sorted(missing_addons))}")

    actual_core_dirs = {item.name for item in CORE.iterdir() if item.is_dir()}
    unexpected = actual_core_dirs - CORE_DIRECTORIES
    missing = CORE_DIRECTORIES - actual_core_dirs
    if unexpected:
        report(errors, f"unexpected core directories: {', '.join(sorted(unexpected))}")
    if missing:
        report(errors, f"missing core directories: {', '.join(sorted(missing))}")

    for directory in sorted(OBSOLETE_ADDON_DIRECTORIES):
        if (ADDONS / directory).exists():
            report(errors, f"obsolete add-on directory exists: addons/{directory}")
    for directory in sorted(OBSOLETE_CORE_DIRECTORIES):
        if (CORE / directory).exists():
            report(errors, f"obsolete core directory exists: addons/konado/{directory}")


def check_files(errors: list[str]) -> None:
    for file_path in ROOT.rglob("*"):
        if not file_path.is_file() or any(
            part in IGNORED_DIRECTORY_NAMES for part in file_path.relative_to(ROOT).parts
        ):
            continue
        relative = file_path.relative_to(ROOT)
        if file_path.name.endswith("~") or file_path.suffix in BACKUP_SUFFIXES:
            report(errors, f"backup or temporary file in repository: {relative}")
        if file_path.suffix in SOURCE_SUFFIXES and file_path.stat().st_size == 0:
            report(errors, f"empty source file: {relative}")
        if file_path.suffix == ".uid":
            source = file_path.with_suffix("")
            if not exists_with_exact_case(source):
                report(errors, f"orphan UID sidecar: {relative}")

    for artifact in sorted(FORBIDDEN_ROOT_ARTIFACTS):
        if (ROOT / artifact).exists():
            report(errors, f"generated root artifact exists: {artifact}")


def check_resource_naming(errors: list[str]) -> None:
    for root in (ADDONS, ROOT / "sample", ROOT / "tests", ROOT / "assets" / "kona_portrait"):
        for item in root.rglob("*"):
            relative = item.relative_to(ROOT)
            if item.is_dir():
                if not SNAKE_CASE_PATH.fullmatch(item.name):
                    report(errors, f"non-snake-case resource directory: {relative}")
                continue
            if item.suffix in RESOURCE_FILE_SUFFIXES and not RESOURCE_FILE_NAME.fullmatch(item.name):
                report(errors, f"non-snake-case resource file: {relative}")


def class_name_to_file_stem(class_name: str) -> str:
    separated_acronyms = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", class_name)
    separated_words = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", separated_acronyms)
    return separated_words.lower()


def check_gdscript_class_names(errors: list[str]) -> None:
    for file_path in ADDONS.rglob("*.gd"):
        source = file_path.read_text(encoding="utf-8")
        match = CLASS_NAME_PATTERN.search(source)
        if not match:
            continue
        expected_stem = class_name_to_file_stem(match.group(1))
        if file_path.stem != expected_stem:
            report(
                errors,
                f"GDScript class/file mismatch: {file_path.relative_to(ROOT)} "
                f"declares {match.group(1)} (expected {expected_stem}.gd)",
            )


def check_internal_gdscript_types(errors: list[str]) -> None:
    for relative_path in sorted(INTERNAL_GDSCRIPT_TYPES):
        file_path = ROOT / relative_path
        if not file_path.is_file():
            report(errors, f"missing internal GDScript type: {relative_path}")
            continue
        if CLASS_NAME_PATTERN.search(file_path.read_text(encoding="utf-8")):
            report(
                errors,
                f"internal GDScript type leaks into the global class list: {relative_path}",
            )


def check_csharp_class_names(errors: list[str]) -> None:
    for root in (ADDONS, ROOT / "sample", ROOT / "tests"):
        for file_path in root.rglob("*.cs"):
            source = file_path.read_text(encoding="utf-8")
            match = CSHARP_CLASS_NAME_PATTERN.search(source)
            if match and file_path.stem != match.group(1):
                report(
                    errors,
                    f"C# class/file mismatch: {file_path.relative_to(ROOT)} "
                    f"declares {match.group(1)}",
                )


def check_typescript_file_names(errors: list[str]) -> None:
    extension_root = ROOT / "plugins" / "vscode"
    for relative_root in ("src", "test", "scripts"):
        for file_path in (extension_root / relative_root).rglob("*"):
            if file_path.is_file() and file_path.suffix in {".mjs", ".ts"}:
                if not TYPESCRIPT_FILE_NAME.fullmatch(file_path.name):
                    report(
                        errors,
                        f"non-kebab-case TypeScript file: {file_path.relative_to(ROOT)}",
                    )


def check_scene_node_names(errors: list[str]) -> None:
    for file_path in ADDONS.rglob("*.tscn"):
        source = file_path.read_text(encoding="utf-8")
        for node_name in SCENE_NODE_NAME_PATTERN.findall(source):
            if (
                not SCENE_NODE_NAME.fullmatch(node_name)
                or node_name in GENERIC_SCENE_NODE_NAMES
            ):
                report(
                    errors,
                    f"non-descriptive scene node name in {file_path.relative_to(ROOT)}: "
                    f"{node_name}",
                )


def check_dependency_direction(errors: list[str]) -> None:
    runtime_root = CORE / "runtime"
    for file_path in runtime_root.rglob("*.gd"):
        source = file_path.read_text(encoding="utf-8")
        if "res://addons/konado/editor/" in source:
            report(
                errors,
                f"runtime code depends on editor code: {file_path.relative_to(ROOT)}",
            )


def check_export_credentials(errors: list[str]) -> None:
    if not EXPORT_PLUGIN.is_file():
        report(errors, "missing KonadoScript export plugin")
        return
    source = EXPORT_PLUGIN.read_text(encoding="utf-8")
    if KONADO_EXPORT_CREDENTIALS_PATH not in source:
        report(
            errors,
            "KonadoScript export keys must use the dedicated "
            ".godot/konado_export_credentials.cfg file",
        )
    if '"res://.godot/export_credentials.cfg"' in source:
        report(errors, "KonadoScript export keys leak into Godot's shared credentials file")


def check_resource_paths(errors: list[str]) -> None:
    roots = [ADDONS, ROOT / "sample", ROOT / "tests"]
    for scan_root in roots:
        for file_path in scan_root.rglob("*"):
            if not file_path.is_file() or file_path.suffix not in SOURCE_SUFFIXES | {".tscn", ".tres", ".cfg"}:
                continue
            source = file_path.read_text(encoding="utf-8", errors="replace")
            for match in RESOURCE_PATH_PATTERN.finditer(source):
                first_component = match.group(1).split("/", 1)[0]
                relative_path = file_path.relative_to(ROOT)
                allowed_legacy_paths = LEGACY_RESOURCE_PATH_ALLOWLIST.get(
                    relative_path, set()
                )
                if (
                    first_component in OBSOLETE_CORE_DIRECTORIES
                    and first_component not in allowed_legacy_paths
                ):
                    report(
                        errors,
                        f"obsolete core resource path in {file_path.relative_to(ROOT)}: "
                        f"addons/konado/{first_component}",
                    )

    for scan_root in roots:
        for file_path in (*scan_root.rglob("*.tscn"), *scan_root.rglob("*.tres")):
            source = file_path.read_text(encoding="utf-8", errors="replace")
            for resource_path in TEXT_RESOURCE_REFERENCE_PATTERN.findall(source):
                if not resource_exists_with_exact_case(resource_path):
                    report(
                        errors,
                        f"missing or case-mismatched external resource in "
                        f"{file_path.relative_to(ROOT)}: {resource_path}",
                    )


def check_konado_script_skill(errors: list[str]) -> None:
    manifest_path = KONADO_SCRIPT_SKILL / "plugin.json"
    plugin_config_path = CORE / "plugin.cfg"
    if not manifest_path.is_file():
        report(errors, "missing KonadoScript skill manifest")
        return
    if not plugin_config_path.is_file():
        report(errors, "missing Konado core plugin configuration")
        return

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version_match = PLUGIN_VERSION_PATTERN.search(
        plugin_config_path.read_text(encoding="utf-8")
    )
    core_version = "" if version_match is None else version_match.group(1)
    skill_version = str(manifest.get("version", ""))
    if not core_version or skill_version != core_version:
        report(
            errors,
            "KonadoScript skill version must match the core plugin: "
            f"skill={skill_version or '<missing>'}, core={core_version or '<missing>'}",
        )

    for file_path in KONADO_SCRIPT_SKILL.rglob("*"):
        if not file_path.is_file() or file_path.suffix not in {".json", ".ks", ".md"}:
            continue
        source = file_path.read_text(encoding="utf-8")
        match = LEGACY_SKILL_IDENTIFIER_PATTERN.search(source)
        if match:
            report(
                errors,
                f"legacy public identifier in {file_path.relative_to(ROOT)}: "
                f"{match.group(0)}",
            )


def main() -> int:
    errors: list[str] = []
    check_layout(errors)
    check_files(errors)
    check_resource_naming(errors)
    check_gdscript_class_names(errors)
    check_internal_gdscript_types(errors)
    check_csharp_class_names(errors)
    check_typescript_file_names(errors)
    check_scene_node_names(errors)
    check_dependency_direction(errors)
    check_export_credentials(errors)
    check_resource_paths(errors)
    check_konado_script_skill(errors)
    if errors:
        print("Repository architecture check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Repository architecture check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
