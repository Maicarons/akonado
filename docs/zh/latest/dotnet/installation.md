---
title: 安装
order: 1
---

# 安装

## 基础依赖

1. 安装 Konado 插件（必须）
2. 支持 C# 的 Godot .NET 4.7.1 或更高版本
3. 项目需要使用 Godot .NET 编辑器打开，普通 Godot 编辑器无法编译和加载 C# 插件脚本。

## 安装步骤

1. 将 konado_dotnet 插件解压缩到 Godot 项目的 `addons` 目录下
2. 确认 `addons/konado` 主插件也在项目中
3. 在 Godot 编辑器中，进入 `项目 -> 项目设置 -> 插件`，先启用 `Konado`
4. 构建 C# 项目，确保 MSBuild 没有报错
5. 再启用 `Konado.NET` 插件
6. 重新打开项目，让自动加载节点和 C# 脚本状态刷新

## 首次启用时的常见报错

首次启用 Konado.NET 时，如果项目还没有完成 C# 构建，可能出现类似错误：

```text
Unable to load addon script from path: 'res://addons/konado_dotnet/editor/KonadoDotNetPlugin.cs'.
```

这通常不是 Konado 主插件问题。请先在 Godot .NET 编辑器中构建项目，再重新打开项目并启用插件。

## 启用顺序

Konado.NET 依赖 Konado 主插件。推荐顺序是：

1. 启用 `Konado`
2. 构建 C# 项目
3. 启用 `Konado.NET`

如果先启用了 Konado.NET，插件会检查主插件状态；主插件未启用时，Konado.NET 不会继续注册 API 自动加载节点。

## 场景要求

使用 `DialogueManagerApi` 时，场景树中需要包含满足完整公开 API 契约的
`KonadoDialogueManager` 节点。Konado.NET 会在节点进入场景树时自动绑定，不依赖节点名称。

如果场景中存在多个对话管理器，请在 C# 中手动绑定：

```csharp
using Godot;

var manager = GetNode<Node>("UI/KonadoDialogueManager");
Konado.Runtime.Api.KonadoApi.DialogueManagerApi?.BindDialogueManager(manager);
```
