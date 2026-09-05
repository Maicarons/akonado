---
title: API 사용
order: 2
---

# Konado .NET API

Konado.NET은 기본 플러그인의 강력한 형식 C# 어댑터입니다. `Konado`와 `Konado.NET`을 활성화한 뒤 `KonadoApi` 자동 로드에서 런타임 서비스에 접근합니다.

## 빠른 시작

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

`DialogueManagerApi.IsReady`는 유효한 `KonadoDialogueManager`가 연결되었는지 나타냅니다. 관리자가 여러 개라면 `BindDialogueManager(node)`로 명시적으로 선택하세요.

## DialogueManagerApi

재생 제어에는 `SetShot`, `InitDialogue()`, `InitDialogue(Callable callback)`, `StartDialogue`, `StopDialogue`, `StartAutoplay`, `EmitWaitSignal`이 있습니다. `GetDialogueVariable`은 대화 변수를 읽고 `ReloadLocalizedScript`는 현재 스토리를 지정한 언어로 다시 불러옵니다. 리소스 속성은 `CharacterList`, `BackgroundList`, `BgmList`, `VoiceList`, `SoundEffectList`, `VariableStore`입니다.

`ShotStart`, `ShotEnd`, `DialogueLineStart`, `DialogueLineEnd`, `CustomSignal`, `RuntimeFailed`, `RuntimeFailureReported`는 표준 C# 이벤트입니다. `RuntimeFailureReported`는 안정적인 오류 코드, 작업, 리소스, 소스 경로와 줄, 명령 ID, 프로그램 위치를 제공합니다. 저장은 `SaveGame`, `LoadGame`, `DeleteSave`, `GetSaveInfo`, `GetAllSaveInfo`를 사용하고, 이력과 체크포인트는 `CanRollback`, `Rollback`, `GetExecutionHistory`, `ClearExecutionHistory`, `CreateCheckpoint`, `RestoreCheckpoint`를 사용합니다.

## StoryLocalizationApi

언어 전환, UI 번역, 사용 가능한 언어 목록은 Godot의 `TranslationServer`를 직접 사용합니다. `KonadoApi.StoryLocalizationApi`의 연결 상태는 `IsReady`와 `Source`로 확인하고 필요하면 `Bind(Node? source = null)`로 다시 연결할 수 있습니다. KonadoScript 전용 `ResolveScriptPath`와 `LoadLocalizedScript`를 제공하며 `warnOnFallback`으로 스토리 언어 파일이 없을 때의 폴백 보고를 제어할 수 있습니다.

## 컴파일 및 런타임 데이터

- `KonadoScriptCompiler`는 파일 또는 단일 명령을 컴파일합니다. `CompileLine(line, lineNumber, path = "")`의 소스 경로는 생략할 수 있습니다.
- `KonadoShot`은 `SourcePath`, `ShotId`, `Program`, `DependentCharacters`, `InstructionCount`, `EntryPc`, `ProgramFingerprint`를 제공합니다.
- `KonadoProgram`은 유효성, 명령 수, 진입점, 지문, 안정 키 또는 프로그램 위치 기반 명령 조회를 제공합니다.
- `KonadoInstruction`은 opcode, 안정 키, 소스 줄, 제어 흐름 위치를 가진 읽기 전용 뷰입니다.

일반 게임 코드는 컴파일 결과를 수정하지 말고 `DialogueManagerApi`로 샷을 재생해야 합니다.
