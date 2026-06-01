# Skills

Skills are JSON-based LLM prompt templates for guiding LLMs to generate visual novel content. Every LLM call in the pipeline corresponds to a skill.

## Structure

```json
{
  "name": "skill_name",
  "description": "What this skill does",
  "system_prompt": "System prompt for the LLM...",
  "user_prompt_template": "User prompt with {placeholder} variables",
  "output_format": "json|text"
}
```

| Field | Description |
|-------|-------------|
| `name` | Skill name, used with CLI `--name` parameter |
| `description` | Skill description, shown in `skill list` |
| `system_prompt` | System prompt defining LLM role and output specifications |
| `user_prompt_template` | User prompt template; `{variable}` is replaced with actual values |
| `output_format` | Output format: `json` (auto-parsed) or `text` (raw output) |

## Built-in Skills

| Skill | Purpose | Output | Pipeline Step |
|-------|---------|--------|--------------|
| `generate_script` | Generate complete script from a premise | JSON | Step 1 |
| `generate_character_prompts` | Generate sprite prompts from character definitions | JSON | Step 2 |
| `generate_background_prompts` | Generate background prompts from scene list | JSON | Step 3 |
| `generate_audio_prompts` | Generate BGM/SFX prompts from requirements | JSON | Step 4 |
| `generate_voice_config` | Generate TTS voice config from character list | JSON | Step 5 |
| `generate_scene_script` | Generate .ks scripts from scene summaries | text | Step 7a |

### generate_script

Generates a complete script structure from a one-sentence summary, including chapters, scenes, characters, backgrounds, BGM, and SE definitions.

Template variables:
- `{input}` -- Story summary
- `{num_chapters}` -- Number of chapters
- `{scenes_per_chapter}` -- Scenes per chapter
- `{extra_instructions}` -- Extra instructions (optional)

### generate_scene_script

Generates executable Konado .ks format scripts from scene summaries.

Template variables:
- `{scene_summary}` -- Scene summary
- `{characters}` -- Character info for the scene
- `{backgrounds}` -- Available background list
- `{bgm_list}` -- Available BGM list
- `{context}` -- Previous story context
- `{extra_instructions}` -- Extra instructions

Generated .ks scripts follow Konado syntax and use `end` as the ending command (not `divider`).

## Usage

### CLI

```bash
# List all skills
python -m akonado skill list

# Run a skill
python -m akonado skill run -n generate_script -i "a story about a tea shop"

# Save output to file
python -m akonado skill run -n generate_script -i "summary" -o output.json

# Pass extra variables
python -m akonado skill run -n generate_character_prompts -i "characters" --var style=anime

# Adjust temperature
python -m akonado skill run -n generate_script -i "summary" -t 0.8
```

### Web GUI

Go to the Skills page, select a skill, enter content, and click Run. See [Web GUI docs](web-gui.md) for details.

## Creating Custom Skills

Create a new JSON file in `akonado/skills/`:

```json
{
  "name": "my_skill",
  "description": "My custom skill",
  "system_prompt": "You are a professional...\n\nOutput specifications:\n- Spec 1\n- Spec 2",
  "user_prompt_template": "Generate based on the following info:\n\n{input}\n\nStyle: {style}",
  "output_format": "json"
}
```

Template variables use `{variable_name}` syntax, filled via `--var key=value` parameters or the Web GUI. Unprovided variables retain their original placeholders.
