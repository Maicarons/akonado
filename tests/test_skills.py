"""Tests for akonado.skills — skill loading and prompt rendering."""

import json
from pathlib import Path

import pytest

from akonado.skills import list_skills, load_skill, render_user_prompt


# ── list_skills ──────────────────────────────────────────────


class TestListSkills:
    def test_returns_list(self):
        skills = list_skills()
        assert isinstance(skills, list)

    def test_skills_have_required_fields(self):
        skills = list_skills()
        for s in skills:
            assert "name" in s
            assert "description" in s

    def test_generate_script_exists(self):
        skills = list_skills()
        names = [s["name"] for s in skills]
        assert "generate_script" in names

    def test_generate_character_prompts_exists(self):
        skills = list_skills()
        names = [s["name"] for s in skills]
        assert "generate_character_prompts" in names


# ── load_skill ───────────────────────────────────────────────


class TestLoadSkill:
    def test_load_generate_script(self):
        skill = load_skill("generate_script")
        assert "name" in skill
        assert "system_prompt" in skill
        assert "user_prompt_template" in skill
        assert skill["name"] == "generate_script"

    def test_load_nonexistent_skill(self):
        with pytest.raises(FileNotFoundError):
            load_skill("nonexistent_skill_xyz")

    def test_all_skills_loadable(self):
        skills = list_skills()
        for s in skills:
            skill = load_skill(s["name"])
            assert "system_prompt" in skill
            assert "user_prompt_template" in skill


# ── render_user_prompt ───────────────────────────────────────


class TestRenderUserPrompt:
    def test_replaces_input(self):
        skill = {
            "user_prompt_template": "请根据以下概要生成：{input}",
        }
        result = render_user_prompt(skill, input="一个关于猫的故事")
        assert "一个关于猫的故事" in result
        assert "{input}" not in result

    def test_replaces_multiple_vars(self):
        skill = {
            "user_prompt_template": "输入：{input}\n风格：{style}\n关键词：{style_keywords}",
        }
        result = render_user_prompt(
            skill,
            input="test",
            style="anime",
            style_keywords="cel shading",
        )
        assert "test" in result
        assert "anime" in result
        assert "cel shading" in result

    def test_missing_var_keeps_placeholder(self):
        skill = {
            "user_prompt_template": "输入：{input}\n可选：{optional_var}",
        }
        result = render_user_prompt(skill, input="test")
        assert "test" in result
        assert "{optional_var}" in result

    def test_extra_vars_ignored(self):
        skill = {
            "user_prompt_template": "输入：{input}",
        }
        result = render_user_prompt(skill, input="test", extra="ignored")
        assert result == "输入：test"

    def test_generate_script_template(self):
        """Real generate_script skill should render correctly."""
        skill = load_skill("generate_script")
        result = render_user_prompt(
            skill,
            input="战争与和平的故事",
            num_chapters="4",
            scenes_per_chapter="3",
        )
        assert "战争与和平的故事" in result
        assert "4" in result
        assert "3" in result
