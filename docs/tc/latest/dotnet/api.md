---
title: 使用 API
order: 2
---

# Konado .NET API

Konado.NET 是主插件的強型別 C# 介面。啟用 `Konado` 與 `Konado.NET` 後，透過 `KonadoApi` 自動載入入口存取執行階段服務。

## 快速開始

```csharp
using Konado.Runtime.Api;
using Konado.Runtime.Resources;

var dialogue = KonadoApi.DialogueManagerApi;
var shot = new KonadoScriptCompiler().CompileFile("res://story/intro.ks");
if (dialogue is not null && shot is not null)
{
    dialogue.SetShot(shot);
    dialogue.InitDialogue();
    dialogue.StartDialogue();
}
```

`DialogueManagerApi.IsReady` 表示是否已綁定有效的 `KonadoDialogueManager`。多管理器場景可用 `BindDialogueManager(node)` 明確指定。

## DialogueManagerApi

播放控制包括 `SetShot`、`InitDialogue()`、`InitDialogue(Callable callback)`、`StartDialogue`、`StopDialogue`、`StartAutoplay` 與 `EmitWaitSignal`。`GetDialogueVariable` 可讀取對話變數，`ReloadLocalizedScript` 可依指定語言重新載入目前劇情。資源屬性包括 `CharacterList`、`BackgroundList`、`BgmList`、`VoiceList`、`SoundEffectList` 與 `VariableStore`。

`ShotStart`、`ShotEnd`、`DialogueLineStart`、`DialogueLineEnd`、`CustomSignal`、`RuntimeFailed` 與 `RuntimeFailureReported` 是標準 C# 事件。`RuntimeFailureReported` 提供穩定錯誤碼、具體操作、資源、原始碼路徑與行號、指令 ID 及程式位置。存檔使用 `SaveGame`、`LoadGame`、`DeleteSave`、`GetSaveInfo` 與 `GetAllSaveInfo`；回滾與檢查點使用 `CanRollback`、`Rollback`、`GetExecutionHistory`、`ClearExecutionHistory`、`CreateCheckpoint` 與 `RestoreCheckpoint`。

## StoryLocalizationApi

語言切換、UI 翻譯與可用語言直接使用 Godot 的 `TranslationServer`。`KonadoApi.StoryLocalizationApi` 可透過 `IsReady` 與 `Source` 檢查綁定狀態，必要時呼叫 `Bind(Node? source = null)` 重新綁定。它提供 KonadoScript 專用的 `ResolveScriptPath` 與 `LoadLocalizedScript`；`warnOnFallback` 可控制缺少劇情語言版本時是否報告回退。

## 編譯與執行資料

- `KonadoScriptCompiler` 編譯檔案或單一指令；`CompileLine(line, lineNumber, path = "")` 的來源路徑可省略。
- `KonadoShot` 提供 `SourcePath`、`ShotId`、`Program`、`DependentCharacters`、`InstructionCount`、`EntryPc` 與 `ProgramFingerprint`。
- `KonadoProgram` 提供程式有效性、指令數、入口、指紋，以及依穩定鍵或程式位置查找指令的介面。
- `KonadoInstruction` 是單一指令的唯讀檢視，包含操作碼、穩定鍵、原始碼行與控制流程位置。

一般遊戲邏輯應透過 `DialogueManagerApi` 播放鏡頭，不應修改編譯結果。
