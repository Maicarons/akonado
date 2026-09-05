# Konado

Konado 官方 Visual Studio Code 扩展，为 `.ks` 剧本提供完整的 KonadoScript
编辑体验。

## 功能

- 根据上下文补全命令、命名参数、角色、状态、动作、背景、音频、镜头、分支、变量和剧本路径
- 实时语法诊断与 Godot 项目资源诊断
- 为常见错误提供最多三条按可信度排序的快速修复
- 悬浮文档和命令签名
- 跳转到分支、剧本、角色、资源和项目符号的定义
- 查找引用，安全重命名分支、变量和信号
- 文档符号、工作区符号、语义高亮、折叠和同名符号高亮
- 不修改对话、字符串和注释内容的确定性格式化
- 点击 `res://...ks` 路径打开目标剧本
- 直接切换当前剧本已有的多语言版本
- 检查工作区内的全部 KonadoScript

扩展会直接读取 Godot 文本格式的 `.tres` 与 `.tscn` 资源建立索引，不会运行项目
脚本。请打开包含 `project.godot` 的项目目录，以启用项目级补全、诊断和跳转。

## 开发

需要 Node.js 20 或更高版本、pnpm 10，以及 Visual Studio Code 1.96 或更高版本。

```bash
pnpm install
pnpm check
pnpm package:vsix
```

安装依赖后，可在 Visual Studio Code 中按 `F5` 启动扩展开发宿主。

## 发布标识

- Marketplace 扩展 ID：`GodotHub.Konado`
- 展示名：`Konado`
- 包名：`Konado`
- 发布账号邮箱：`app@godothub.com`

`com.godothub.konado` 是反向域名风格标识，不符合 VS Code Marketplace 使用
`<publisher>.<name>` 组成扩展 ID 的约定，因此不作为 `name` 使用。

运行 `pnpm package:vsix` 完成检查并生成 `dist/konado.vsix`，然后在 Visual
Studio Marketplace 发布者管理页面手动上传该文件。

## 许可证

MIT 许可证。
