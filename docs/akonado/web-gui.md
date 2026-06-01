# Web GUI

Akonado 内置基于 Flask 的 Web GUI，提供浏览器端可视化管理界面。

## 启动

```bash
python -m akonado web
```

在浏览器打开 http://127.0.0.1:5000 。

### 配置

在 `.env` 中设置：

```env
WEB_HOST=127.0.0.1
WEB_PORT=5000
WEB_DEBUG=false
```

或通过 CLI 参数：

```bash
python -m akonado web --host 0.0.0.0 --port 8080 --debug
```

## 功能

### Dashboard（仪表盘）

- 资产生成统计：角色数、背景数、BGM 数、音效数、配音数、脚本数
- Provider 状态指示器（ComfyUI / LLM / TTS）
- 快速操作入口

### Manifests（资产清单）

- 查看所有 JSON manifests
- 内置 JSON 编辑器，支持格式化
- 直接保存修改到磁盘
- JSON 语法错误提示

### Skills（技能）

- 浏览所有可用 skills
- 查看/编辑 skill 模板（system_prompt、user_prompt_template）
- 使用自定义输入运行 skill
- 查看 LLM 输出结果

### 配置编辑

- 在线编辑 `.env` 配置文件
- 修改后立即生效（下次生成时）

## API 端点

Web GUI 提供以下 REST API，可供外部工具调用：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/providers` | GET | 检查所有 provider 状态 |
| `/api/stats` | GET | 获取资产统计信息 |
| `/api/generate` | POST | 触发资产生成 |
| `/api/skill/run` | POST | 运行 LLM skill |

### 生成 API

```bash
# 生成全部资产
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{"type": "all", "engine": "mimo", "force": false}'

# 生成特定类型
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{"type": "characters"}'
```

### Skill 运行 API

```bash
curl -X POST http://localhost:5000/api/skill/run \
  -H "Content-Type: application/json" \
  -d '{
    "name": "generate_script",
    "input": "一个关于猫的故事",
    "variables": {"num_chapters": "3"},
    "temperature": 0.7
  }'
```
