---
title: API 使用
order: 2
---

# Konado .NET API

Konado.NET は本体プラグインの型安全な C# アダプターです。`Konado` と `Konado.NET` を有効にし、`KonadoApi` 自動読み込みからランタイムサービスへアクセスします。

## クイックスタート

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

`DialogueManagerApi.IsReady` は有効な `KonadoDialogueManager` がバインド済みかを示します。複数のマネージャーがある場合は `BindDialogueManager(node)` で明示的に選択します。

## DialogueManagerApi

再生制御は `SetShot`、`InitDialogue()`、`InitDialogue(Callable callback)`、`StartDialogue`、`StopDialogue`、`StartAutoplay`、`EmitWaitSignal` です。`GetDialogueVariable` は会話変数を取得し、`ReloadLocalizedScript` は現在のストーリーを指定言語で再読み込みします。リソースプロパティは `CharacterList`、`BackgroundList`、`BgmList`、`VoiceList`、`SoundEffectList`、`VariableStore` です。

`ShotStart`、`ShotEnd`、`DialogueLineStart`、`DialogueLineEnd`、`CustomSignal`、`RuntimeFailed`、`RuntimeFailureReported` は標準 C# イベントです。`RuntimeFailureReported` は安定したエラーコード、操作、リソース、ソースパスと行、命令 ID、プログラム位置を提供します。セーブには `SaveGame`、`LoadGame`、`DeleteSave`、`GetSaveInfo`、`GetAllSaveInfo` を、履歴とチェックポイントには `CanRollback`、`Rollback`、`GetExecutionHistory`、`ClearExecutionHistory`、`CreateCheckpoint`、`RestoreCheckpoint` を使用します。

## StoryLocalizationApi

言語切り替え、UI 翻訳、利用可能な言語には Godot の `TranslationServer` を直接使用します。`KonadoApi.StoryLocalizationApi` のバインド状態は `IsReady` と `Source` で確認し、必要な場合は `Bind(Node? source = null)` で再バインドできます。KonadoScript 固有の `ResolveScriptPath` と `LoadLocalizedScript` を提供し、`warnOnFallback` でストーリー言語版がない場合のフォールバック報告を制御できます。

## コンパイルとランタイムデータ

- `KonadoScriptCompiler` はファイルまたは単一命令をコンパイルします。`CompileLine(line, lineNumber, path = "")` のソースパスは省略できます。
- `KonadoShot` は `SourcePath`、`ShotId`、`Program`、`DependentCharacters`、`InstructionCount`、`EntryPc`、`ProgramFingerprint` を公開します。
- `KonadoProgram` は有効性、命令数、入口、フィンガープリント、安定キーまたはプログラム位置による命令検索を提供します。
- `KonadoInstruction` はオペコード、安定キー、ソース行、制御フロー位置を持つ読み取り専用ビューです。

通常のゲームコードはコンパイル結果を変更せず、`DialogueManagerApi` からショットを再生してください。
