"""Tests for akonado.config — configuration and path setup."""

from pathlib import Path

import pytest

from akonado.config import (
    AKONADO_ROOT,
    PROJECT_ROOT,
    ASSETS_DIR,
    CHARACTERS_DIR,
    BACKGROUNDS_DIR,
    AUDIO_DIR,
    BGM_DIR,
    SE_DIR,
    VOICE_DIR,
    STORY_DIR,
    MANIFESTS_DIR,
    SKILLS_DIR,
    COMFYUI_DIR,
    GODOT_DIR,
    ensure_dirs,
)


# ── Path Constants ───────────────────────────────────────────


class TestPaths:
    def test_akonado_root_is_directory(self):
        assert AKONADO_ROOT.is_dir()

    def test_project_root_is_parent_of_akonado(self):
        assert AKONADO_ROOT.parent == PROJECT_ROOT

    def test_assets_dir_under_project_root(self):
        assert ASSETS_DIR.parent == PROJECT_ROOT

    def test_manifests_dir_under_akonado(self):
        assert MANIFESTS_DIR.parent == AKONADO_ROOT

    def test_skills_dir_under_akonado(self):
        assert SKILLS_DIR.parent == AKONADO_ROOT

    def test_comfyui_dir_under_akonado(self):
        assert COMFYUI_DIR.parent == AKONADO_ROOT

    def test_godot_dir_is_absolute(self):
        assert GODOT_DIR.is_absolute()

    def test_audio_subdirectories(self):
        assert BGM_DIR.parent == AUDIO_DIR
        assert SE_DIR.parent == AUDIO_DIR
        assert VOICE_DIR.parent == AUDIO_DIR


# ── ensure_dirs ──────────────────────────────────────────────


class TestEnsureDirs:
    def test_creates_directories(self, tmp_path, monkeypatch):
        """ensure_dirs should create all required directories."""
        import akonado.config as config

        # Patch all directories to tmp_path
        dirs = [
            "CHARACTERS_DIR", "BACKGROUNDS_DIR", "BGM_DIR", "SE_DIR",
            "VOICEdir", "UI_DIR", "STORY_DIR", "RESOURCES_DIR",
            "OUTPUT_DIR", "COMFYUI_DIR",
        ]
        for attr in dirs:
            if hasattr(config, attr):
                monkeypatch.setattr(config, attr, tmp_path / attr.lower())

        ensure_dirs()

        for attr in dirs:
            if hasattr(config, attr):
                d = getattr(config, attr)
                assert d.exists(), f"{attr} not created: {d}"

    def test_idempotent(self):
        """Calling ensure_dirs twice should not raise."""
        ensure_dirs()
        ensure_dirs()
