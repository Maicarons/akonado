# 技能系统（Skills）

Skills 是基于 JSON 的 LLM prompt 模板，用于引导 LLM 生成视觉小说内容。Pipeline 中的每个 LLM 调用都对应一个 skill。

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

| 字段 | 说明 |
|------|------|
| `name` | 技能名称，用于 CLI `--name` 参数 |
| `description` | 技能描述，显示在 `skill list` 中 |
| `system_prompt` | 系统提示词，定义 LLM 角色和输出规范 |
| `user_prompt_template` | 用户提示模板，`{variable}` 会被替换为实际值 |
| `output_format` | 输出格式：`json`（自动解析）或 `text`（原样输出） |

## 内置 Skills

| Skill | 用途 | 输出 | Pipeline 步骤 |
|-------|------|------|--------------|
| `generate_script` | 从一句话生成完整剧本 | JSON | Step 1 |
| `generate_character_prompts` | 根据角色定义生成立绘 prompt | JSON | Step 2 |
| `generate_background_prompts` | 根据场景列表生成背景图 prompt | JSON | Step 3 |
| `generate_audio_prompts` | 根据需求生成 BGM/音效 prompt | JSON | Step 4 |
| `generate_voice_config` | 根据角色列表生成 TTS 语音配置 | JSON | Step 5 |
| `generate_scene_script` | 根据场景概要生成 .ks 脚本 | text | Step 7a |

### generate_script

从一句话概要生成完整剧本结构，包括章节、场景、角色、背景、BGM、SE 定义。

模板变量：
- `{input}` — 故事概要
- `{num_chapters}` — 章节数
- `{scenes_per_chapter}` — 每章场景数
- `{extra_instructions}` — 额外指令（可选）

### generate_scene_script

根据场景概要生成 Konado .ks 格式的可执行脚本。

模板变量：
- `{scene_summary}` — 场景概要
- `{characters}` — 出场角色信息
- `{backgrounds}` — 可用背景列表
- `{bgm_list}` — 可用 BGM 列表
- `{context}` — 前置剧情上下文
- `{extra_instructions}` — 额外指令

生成的 .ks 脚本遵循 Konado 2.4 语法，支持以下特性：

- **变量系统**：持久变量（`%`）和临时变量（`$`），用于追踪角色关系和故事状态
- **条件分支**：`if/else/endif` 语法，支持动态对话和多结局
- **变量插值**：在对话中直接显示变量值，如 `"好感度：%love"`
- **信号系统**：`signal` 指令，用于触发外部游戏逻辑

脚本使用 `end` 结尾（不是 `divider`）。

## 使用方式

### CLI

```bash
# 列出所有 skills
python -m akonado skill list

# 运行 skill
python -m akonado skill run -n generate_script -i "一个关于奶茶店的故事"

# 保存输出到文件
python -m akonado skill run -n generate_script -i "概要" -o output.json

# 传递额外变量
python -m akonado skill run -n generate_character_prompts -i "角色" --var style=anime

# 调整温度参数
python -m akonado skill run -n generate_script -i "概要" -t 0.8
```

### Web GUI

进入 Skills 页面，选择 skill，输入内容，点击运行。详见 [Web GUI 文档](web-gui.md)。

## 创建自定义 Skill

在 `akonado/skills/` 中创建新的 JSON 文件：

```json
{
  "name": "my_skill",
  "description": "我的自定义 skill",
  "system_prompt": "你是一个专业的...\n\n输出规范：\n- 规范1\n- 规范2",
  "user_prompt_template": "请根据以下信息生成：\n\n{input}\n\n风格：{style}",
  "output_format": "json"
}
```

模板变量使用 `{variable_name}` 语法，通过 `--var key=value` 参数或 Web GUI 填充。未提供的变量会保留原始占位符。
