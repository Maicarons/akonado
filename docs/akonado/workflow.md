# 工作流程指南

Akonado 支持多种灵活的工作流程，适应不同的创作需求。

## 两阶段工作流（推荐）

两阶段工作流让你先生成剧本和素材 prompt，手动调整后再生成实际素材。

### 阶段一：生成剧本和 Prompt

```bash
python -m akonado pipeline "一个关于奶茶店的故事" --prompts-only
```

这只会执行 LLM 生成步骤，产出所有 manifest 文件：

| 输出文件 | 内容 |
|----------|------|
| `manifests/script.json` | 剧本结构（章节、场景、角色） |
| `manifests/characters.json` | 角色立绘 prompt + 表情定义 |
| `manifests/backgrounds.json` | 背景图 prompt |
| `manifests/cgs.json` | CG 插画 prompt |
| `manifests/bgm.json` | 背景音乐 prompt |
| `manifests/se.json` | 音效 prompt |
| `manifests/voice_config.json` | TTS 配音配置 |
| `manifests/ui.json` | UI 资产 prompt |

此时不会生成任何图片、音频或 .ks 脚本。

### 手动编辑

你可以自由修改任何 manifest 文件：

- **调整角色外观**：编辑 `characters.json` 中的 `base_prompt` 和 `expressions`
- **更换背景描述**：编辑 `backgrounds.json` 中的场景 prompt
- **修改剧本结构**：编辑 `script.json` 中的章节和场景
- **调整 BGM/音效**：编辑 `bgm.json` / `se.json` 中的音乐描述
- **更换配音音色**：编辑 `voice_config.json` 中的音色配置

也可以在 Web GUI 中可视化编辑：

```bash
python -m akonado web
```

### 阶段二：生成实际素材

编辑完成后，生成全部素材：

```bash
python -m akonado generate all
```

或分步生成（方便调试）：

```bash
python -m akonado generate characters   # 先生成角色
python -m akonado generate backgrounds  # 再生成背景
python -m akonado generate bgm          # 生成 BGM
python -m akonado generate se           # 生成音效
python -m akonado generate ui           # 生成 UI
python -m akonado generate voice        # 生成配音
python -m akonado generate dialogue     # 提取台词
```

---

## 选择性重新生成

### 重新生成特定类型

随时可以重新生成某一种素材，已有的文件默认会被跳过：

```bash
python -m akonado generate characters    # 只重新生成角色
python -m akonado generate backgrounds   # 只重新生成背景
python -m akonado generate voice         # 只重新生成配音
```

### 强制重新生成

使用 `--force` 覆盖已有文件：

```bash
python -m akonado generate characters --force    # 强制重新生成所有角色
python -m akonado generate all --force            # 强制重新生成全部
```

### 检查并补全缺失素材

如果删除了某些素材文件，或部分生成失败，可以用 `--check-missing` 自动检测并补全：

```bash
python -m akonado generate all --check-missing
```

这会：

1. 扫描所有 manifest 文件
2. 对比磁盘上实际存在的文件
3. 报告缺失的素材清单
4. 自动重新生成缺失的部分

也可以针对特定类型检查：

```bash
python -m akonado generate characters --check-missing
python -m akonado generate voice --check-missing
```

示例输出：

```
Missing assets found:
  [characters] 3 missing:
    - girl/happy.png
    - girl/sad.png
    - boy/normal.png

  [bgm] 1 missing:
    - rain_night_mood.mp3

Total: 4 missing assets

Regenerating missing assets...
```

---

## 清理素材

```bash
python -m akonado clean characters    # 删除角色素材
python -m akonado clean backgrounds   # 删除背景素材
python -m akonado clean all           # 删除全部素材
python -m akonado clean all --deep    # 删除全部素材 + manifests + .ks 脚本
```

---

## 典型工作流程

### 快速原型（一键到底）

```bash
python -m akonado pipeline "一个关于奶茶店的故事"
```

### 精细控制（两阶段）

```bash
# 1. 生成 prompt
python -m akonado pipeline "故事概要" --prompts-only

# 2. 编辑 manifests/*.json

# 3. 生成素材
python -m akonado generate all

# 4. 在 Godot 中测试
scripts\Windows\godot.cmd
```

### 迭代优化

```bash
# 对角色不满意？只重新生成角色
python -m akonado clean characters
python -m akonado generate characters

# 配音有问题？只重新生成配音
python -m akonado generate voice --force

# 删除了几个文件？自动补全
python -m akonado generate all --check-missing
```
