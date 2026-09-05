---
title: 저장 시스템
order: 2
---

# 저장 시스템

기본 대화 템플릿에는 빠른 저장, 빠른 불러오기와 저장 슬롯 패널이 포함됩니다. 슬롯 `0`은 빠른 저장용이며, 기본 설정은 `0`부터 `19`까지 20개 슬롯을 제공합니다.

## 사용 방법

먼저 기본 대화 템플릿의 대화 관리자를 참조하세요.

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

### 게임 저장

```gdscript
# 지정 슬롯에 저장
dialogue_manager.save_game(1)  # 1번 슬롯에 저장
```

### 게임 불러오기

```gdscript
# 지정 슬롯에서 불러오기
dialogue_manager.load_game(1)  # 1번 슬롯에서 불러오기
```

### 저장 삭제

```gdscript
# 지정 슬롯의 저장 삭제
dialogue_manager.delete_save(1)  # 1번 슬롯 저장 삭제
```

### 저장 정보 가져오기

```gdscript
# 지정 슬롯의 저장 정보 가져오기
var save_info = dialogue_manager.get_save_info(1)
print("저장 시간: " + str(save_info.get("save_time", {})))

# 모든 저장 정보 가져오기
var all_save_infos = dialogue_manager.get_all_save_info()
for i in range(all_save_infos.size()):
    if all_save_infos[i].get("exists", false):
        print("저장 " + str(i) + " 존재")
```

## 저장 데이터 구조

Konado는 현재 명령, 임시 및 영구 변수, 대화 상자, 액터, 배경, 카메라, 오디오 등의 실행 상태를 하나의 원자적 실행 경계에서 저장합니다. 화면과 스토리 논리가 어긋나지 않도록 전체 상태를 한 단위로 저장하고 복원합니다.

불러올 때 파일 형식, 컴파일러 ABI, 스크립트 지문과 명령 식별자를 검증합니다. 변경된 스크립트로 정확히 복원할 수 없다면 잘못된 위치에서 계속하지 않고 불러오기에 실패합니다. `save_game()`, `load_game()`, `delete_save()`는 `bool`을 반환하므로 실패 결과를 처리해야 합니다.

## 저장 파일 형식

저장 파일은 `user://konado_saves/`에 `[슬롯ID].kns`로 저장됩니다. 형식 버전, 페이로드 길이와 SHA-256 무결성 다이제스트를 포함한 바이너리 형식입니다. 손상되거나 불완전한 쓰기는 감지하지만 암호화 또는 변조 방지 기능은 아닙니다.
