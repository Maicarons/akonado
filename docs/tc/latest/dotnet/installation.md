---
title: 安裝
order: 1
---

# 安裝

## 基礎依賴

1. 安裝 Konado 插件（必須）
2. Godot .NET 4.7.1 或更高版本
3. 專案需要使用 Godot .NET 編輯器開啟，普通 Godot 編輯器無法編譯與載入 C# 插件腳本。

## 安裝步驟

1. 將 konado_dotnet 插件解壓縮到 Godot 專案的 `addons` 目錄下
2. 確認 `addons/konado` 主插件也在專案中
3. 在 Godot 編輯器中，進入 `專案 -> 專案設定 -> 插件`，先啟用 `Konado`
4. 建構 C# 專案，確保 MSBuild 沒有錯誤
5. 再啟用 `Konado.NET` 插件
6. 重新開啟專案，讓自動載入節點與 C# 腳本狀態刷新

## 首次啟用時的常見錯誤

若專案尚未完成 C# 建構，首次啟用可能出現：

```text
Unable to load addon script from path: 'res://addons/konado_dotnet/editor/KonadoDotNetPlugin.cs'.
```

請先使用 Godot .NET 編輯器建構專案，再重新開啟專案並啟用插件。

## 啟用順序

Konado.NET 依賴 Konado 主插件。建議依照以下順序啟用：

1. 啟用 `Konado`
2. 建構 C# 專案
3. 啟用 `Konado.NET`

若先啟用 Konado.NET，插件會檢查主插件狀態；主插件未啟用時，不會註冊 API 自動載入節點。

## 場景要求

使用 `DialogueManagerApi` 時，場景樹中需要包含符合完整公開 API 契約的
`KonadoDialogueManager` 節點。節點進入場景樹時會自動綁定，不依賴節點名稱。

若有多個對話管理器，請手動綁定：

```csharp
using Godot;

var manager = GetNode<Node>("UI/KonadoDialogueManager");
Konado.Runtime.Api.KonadoApi.DialogueManagerApi?.BindDialogueManager(manager);
```
