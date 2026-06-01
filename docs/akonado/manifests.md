# 资产清单（Manifests）

Manifests 是定义要生成哪些资产的 JSON 文件，位于 `akonado/manifests/`。Pipeline 自动生成，也可手动编辑。

## 清单类型总览

| Manifest | 生成方式 | 用途 |
|----------|---------|------|
| `script.json` | LLM 生成 | 剧本结构（章节、场景、角色定义） |
| `characters.json` | LLM 生成 | 角色立绘 prompt 和表情定义 |
| `backgrounds.json` | LLM 生成 | 背景图 prompt |
| `bgm.json` | LLM 生成 | 背景音乐 prompt |
| `se.json` | LLM 生成 | 音效 prompt |
| `voice_config.json` | LLM 生成 | TTS 语音配置 |
| `dialogue.json` | 自动提取 | 从 .ks 脚本提取的台词数据 |

## characters.json

定义角色精灵图的外观和表情。

```json
{
  "type": "characters",
  "items": {
    "girl": {
      "name": "少女",
      "seed": 12345,
      "size": [768, 1024],
      "base_prompt": "1girl, anime style, long black hair, school uniform...",
      "expressions": {
        "normal": "calm expression, gentle smile",
        "happy": "bright smile, sparkling eyes",
        "sad": "teary eyes, slight frown",
        "angry": "furrowed brows, clenched teeth"
      }
    }
  }
}
```

| 字段 | 说明 |
|------|------|
| `name` | 角色显示名 |
| `seed` | ComfyUI 种子（固定外观，省略则每次随机） |
| `size` | 图像尺寸 `[width, height]`，默认 `[768, 1024]` |
| `base_prompt` | 基础外观描述（英文） |
| `expressions` | 表情变体，key 为表情名，value 为表情描述 |

生成后每个角色产出一个子目录：`assets/characters/<character_id>/`，包含各表情的透明背景 PNG。

## backgrounds.json

定义背景图片。

```json
{
  "type": "backgrounds",
  "size": [1920, 1080],
  "items": {
    "train_station_night": "anime style background, train station at night, rainy...",
    "park_afternoon": "anime style background, sunny park, green trees..."
  }
}
```

| 字段 | 说明 |
|------|------|
| `size` | 图像尺寸，默认 `[1920, 1080]` |
| `items` | key 为背景 ID，value 为英文场景描述 |

## bgm.json

定义背景音乐。

```json
{
  "type": "bgm",
  "format": "mp3",
  "duration": 150,
  "items": {
    "rain_night_mood": "Gentle piano melody with soft rain sounds...",
    "happy_reunion": "Joyful orchestral piece with violin and piano..."
  }
}
```

| 字段 | 说明 |
|------|------|
| `format` | 音频格式，默认 `mp3` |
| `duration` | 默认时长（秒），默认 `150` |
| `items` | key 为 BGM ID，value 为英文音乐描述 |

## se.json

定义音效。

```json
{
  "type": "se",
  "format": "mp3",
  "items": {
    "rain_sound": {
      "prompt": "Continuous rain sound, gentle pitter-patter...",
      "duration": 10
    },
    "door_close": {
      "prompt": "Sound of a heavy wooden door closing firmly...",
      "duration": 2
    }
  }
}
```

| 字段 | 说明 |
|------|------|
| `items.<id>.prompt` | 英文音效描述 |
| `items.<id>.duration` | 时长（秒） |

## voice_config.json

定义角色 TTS 语音配置。详见 [TTS 配音搭建指南](tts-setup.md#配音配置voice_configjson)。

```json
{
  "characters": {
    "girl": {
      "profile": "你是少女，声音温柔清澈。",
      "voices": {
        "mimo": "zh-CN-XiaoyiNeural",
        "qwen": "female-1"
      },
      "instruct_qwen": "温柔的年轻女性声音"
    }
  },
  "emotion_rules": [
    {"label": "开心", "keywords": ["哈哈", "太好了"]},
    {"label": "悲伤", "keywords": ["对不起", "难过"]}
  ],
  "emotion_directions": {
    "平静": "用自然平和的语气说这句台词。",
    "开心": "用愉快、轻快的语气说这句台词。",
    "悲伤": "用低沉、略带哽咽的语气说这句台词。"
  }
}
```

## dialogue.json

从 .ks 脚本自动提取，不要手动编辑。

```json
{
  "type": "dialogue",
  "characters": ["girl", "returnee"],
  "lines": [
    {
      "file": "story/chapter01/chapter01_01.ks",
      "chapter": "chapter01",
      "line_no": 14,
      "character": "girl",
      "text": "嗯……他说今天会回来的。",
      "voiced": true
    }
  ]
}
```

## 管理命令

```bash
# 查看 manifest 内容
python -m akonado list              # 列出所有
python -m akonado list characters   # 查看角色清单

# 清理生成的文件
python -m akonado clean characters
python -m akonado clean all

# 在 Web GUI 中编辑
python -m akonado web
```
