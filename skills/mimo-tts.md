# MiMo V2.5 TTS - 语音合成 API 参考

## 概述

Xiaomi MiMo V2.5 TTS 系列语音合成 API，支持预置音色、音色设计、音色复刻三种模式。

- **API Base**: `https://api.xiaomimimo.com/v1`
- **兼容**: OpenAI SDK (`openai.OpenAI`)
- **计费**: 限时免费

## 模型列表

| Model ID | 功能 | 音色来源 |
|----------|------|----------|
| `mimo-v2.5-tts` | 预置精品音色 | 内置音色列表 |
| `mimo-v2.5-tts-voicedesign` | 文本描述定制音色 | user message 中的描述 |
| `mimo-v2.5-tts-voiceclone` | 音频样本复刻音色 | base64 音频样本 |

## 预置音色 (mimo-v2.5-tts)

| 音色名 | Voice ID | 语言 | 性别 |
|--------|----------|------|------|
| 冰糖 | `冰糖` | 中文 | 女性 |
| 茉莉 | `茉莉` | 中文 | 女性 |
| 苏打 | `苏打` | 中文 | 男性 |
| 白桦 | `白桦` | 中文 | 男性 |
| Mia | `Mia` | 英文 | 女性 |
| Chloe | `Chloe` | 英文 | 女性 |
| Milo | `Milo` | 英文 | 男性 |
| Dean | `Dean` | 英文 | 男性 |

## 消息格式

- **user message**: 风格指令（自然语言描述语音风格、情绪、语速等）可选
- **assistant message**: 待合成的目标文本（必填）
- **audio.voice**: 音色 ID 或音色描述（voicedesign 模式）

## 风格控制

### 自然语言控制 (user message)

直接用自然语言描述想要的语音风格，支持导演模式：

```
角色: 24岁的奶茶店女店长，性格干练务实、温暖有担当。
场景: 正在安慰失落的弟弟，语气温柔但坚定。
指导: 语速偏快，语气利落但不失温柔，像一个操心店铺的姐姐。
```

### 音频标签控制 (assistant message)

在目标文本中嵌入标签：

- 基础情绪: 开心/悲伤/愤怒/恐惧/惊讶/兴奋/委屈/平静/冷漠
- 复合情绪: 怅然/欣慰/无奈/愧疚/释然/嫉妒/厌倦/忐忑/动情
- 整体语调: 温柔/高冷/活泼/严肃/慵懒/俏皮/深沉/干练/凌厉
- 音色定位: 磁性/醇厚/清亮/空灵/稚嫩/苍老/甜美/沙哑/醇雅
- 细粒度: [吸气]/[叹气]/[沉默片刻]/[苦笑]/[轻笑]/[抽泣]

示例: `(温柔)你好，欢迎光临。` 或 `(无奈)[叹气]算了，就这样吧。`

## Python 调用示例

```python
import base64
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_API_KEY",
    base_url="https://api.xiaomimimo.com/v1"
)

# 预置音色
completion = client.chat.completions.create(
    model="mimo-v2.5-tts",
    messages=[
        {"role": "user", "content": "用温柔的语调，语速适中"},
        {"role": "assistant", "content": "你好，欢迎光临林记奶茶。"}
    ],
    audio={"format": "wav", "voice": "冰糖"}
)

# 音色设计
completion = client.chat.completions.create(
    model="mimo-v2.5-tts-voicedesign",
    messages=[
        {"role": "user", "content": "24岁年轻女性，干练温暖，语速偏快"},
        {"role": "assistant", "content": "你好，欢迎光临林记奶茶。"}
    ],
    audio={"format": "wav"}
)

# 解码保存
message = completion.choices[0].message
audio_bytes = base64.b64decode(message.audio.data)
with open("output.wav", "wb") as f:
    f.write(audio_bytes)
```

## 注意事项

- 目标文本必须在 assistant 角色消息中
- user 消息为风格指令，不会出现在合成语音中
- 流式输出格式建议用 pcm16，采样率 24kHz
- voicedesign 模式下 user 消息为必填
