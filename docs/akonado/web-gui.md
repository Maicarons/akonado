# Web GUI

Akonado 内置基于 Flask 的 Web GUI，提供可视化管理界面。

## 启动

```bash
python -m akonado web
```

在浏览器打开 http://127.0.0.1:5000 。

## 功能

### Dashboard（仪表盘）
- 资产生成统计（角色数、背景数等）
- Provider 状态指示器
- 快速操作按钮
- Skill 运行器（带输入/输出）

### Manifests（资产清单）
- 查看和编辑所有 JSON manifests
- JSON 格式化工具
- 直接保存到磁盘

### Skills（技能）
- 浏览可用 skills
- 编辑 skill 模板
- 使用自定义输入测试 skill

## 配置

在 `.env` 中设置：

```env
WEB_HOST=127.0.0.1
WEB_PORT=5000
WEB_DEBUG=false
```

或通过 CLI：

```bash
python -m akonado web --host 0.0.0.0 --port 8080 --debug
```
