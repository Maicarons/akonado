# 技能（Skills）

Skills 是基于 JSON 的 prompt 模板，用于引导 LLM 生成视觉小说内容。

## 结构

```json
{
  "name": "skill_name",
  "description": "这个 skill 做什么",
  "system_prompt": "给 LLM 的系统提示...",
  "user_prompt_template": "带 {placeholder} 变量的用户提示",
  "output_format": "json|text"
}
```

## 内置 Skills

| Skill | 说明 |
|-------|------|
| `generate_script` | 从一句话生成完整剧本 + 角色 + 场景 |
| `generate_character_prompts` | 根据角色定义生成立绘 prompt |
| `generate_background_prompts` | 根据场景列表生成背景图 prompt |
| `generate_audio_prompts` | 根据需求生成 BGM/音效 prompt |
| `generate_scene_script` | 根据场景概要生成 .ks 脚本 |
| `generate_voice_config` | 根据角色列表生成 TTS 语音配置 |

## 使用方式

### CLI
```bash
# 列出所有 skills
python -m akonado skill list

# 运行 skill
python -m akonado skill run -n generate_script -i "你的故事概要"

# 保存输出到文件
python -m akonado skill run -n generate_script -i "概要" -o output.json

# 传递额外变量
python -m akonado skill run -n generate_character_prompts -i "角色" --var style=anime
```

### Web GUI
进入 Skills 页面，选择 skill，输入内容，点击运行。

## 创建自定义 Skill

在 `akonado/skills/` 中创建新的 JSON 文件：

```json
{
  "name": "my_skill",
  "description": "我的自定义 skill",
  "system_prompt": "你是一个...",
  "user_prompt_template": "请做这个：{input}\n使用：{extra_var}",
  "output_format": "json"
}
```

模板变量使用 `{variable_name}` 语法，通过 `--var` 参数或 Web GUI 填充。
