# 资产清单（Manifests）

Manifests 是定义要生成哪些资产的 JSON 文件。

## 清单类型

### characters.json
定义角色精灵图的外观和表情。

```json
{
  "type": "characters",
  "items": {
    "character_id": {
      "name": "角色名",
      "seed": 12345,
      "size": [768, 1024],
      "base_prompt": "英文外观描述...",
      "expressions": {
        "normal": "平静表情...",
        "happy": "开心微笑..."
      }
    }
  }
}
```

### backgrounds.json
定义背景图片。

```json
{
  "type": "backgrounds",
  "size": [1920, 1080],
  "items": {
    "bg_id": "英文场景描述..."
  }
}
```

### bgm.json
定义背景音乐。

```json
{
  "type": "bgm",
  "format": "mp3",
  "duration": 150,
  "items": {
    "bgm_id": "英文音乐描述..."
  }
}
```

### se.json
定义音效。

```json
{
  "type": "se",
  "format": "mp3",
  "items": {
    "se_id": {
      "prompt": "英文音效描述...",
      "duration": 3
    }
  }
}
```

### voice_config.json
定义角色 TTS 语音配置。

```json
{
  "description": "角色语音配置",
  "characters": {
    "角色名": {
      "profile": "角色性格...",
      "instruct_mimo": "",
      "instruct_qwen": "用温暖的语气说",
      "voices": {
        "mimo": "音色名",
        "qwen": "说话人名"
      },
      "gender": "male"
    }
  },
  "emotion_rules": [...],
  "emotion_directions": {...},
  "punctuation_boost": {...}
}
```

### ui.json
定义 UI 资产（logo、标题画面等）。

```json
{
  "type": "ui",
  "items": {
    "item_id": {
      "prompt": "英文描述...",
      "size": [512, 512],
      "output": "filename.png"
    }
  }
}
```

### dialogue.json
从 .ks 脚本自动提取，不要手动编辑。
