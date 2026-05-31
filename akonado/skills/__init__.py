"""akonado skills — LLM prompt template system.

Skills are JSON-based prompt templates that guide LLMs to generate
visual novel content (scripts, character prompts, backgrounds, etc.).

All skill templates live in this directory as .json files.
"""

from __future__ import annotations

import json
from pathlib import Path

SKILLS_DIR = Path(__file__).resolve().parent


def list_skills() -> list[dict[str, str]]:
    """List all available skills.

    Returns:
        List of dicts with 'name' and 'description' keys.
    """
    skills = []
    for path in sorted(SKILLS_DIR.glob("*.json")):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        skills.append({
            "name": data.get("name", path.stem),
            "description": data.get("description", ""),
        })
    return skills


def load_skill(name: str) -> dict:
    """Load a skill template by name.

    Args:
        name: Skill name (matches the 'name' field in the JSON, or filename stem).

    Returns:
        Full skill dict with system_prompt, user_prompt_template, etc.

    Raises:
        FileNotFoundError: If the skill is not found.
    """
    path = SKILLS_DIR / f"{name}.json"
    if path.exists():
        with open(path, encoding="utf-8") as f:
            return json.load(f)

    for path in SKILLS_DIR.glob("*.json"):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if data.get("name") == name:
            return data

    available = [p.stem for p in SKILLS_DIR.glob("*.json")]
    raise FileNotFoundError(f"Skill '{name}' not found. Available: {', '.join(available)}")


def render_user_prompt(skill: dict, **kwargs) -> str:
    """Render the user prompt template with provided variables.

    Args:
        skill: Skill dict loaded via load_skill().
        **kwargs: Template variables.

    Returns:
        Rendered user prompt string.
    """
    template = skill.get("user_prompt_template", "")
    for key, value in kwargs.items():
        placeholder = "{" + key + "}"
        if placeholder in template:
            template = template.replace(placeholder, str(value))
    return template
