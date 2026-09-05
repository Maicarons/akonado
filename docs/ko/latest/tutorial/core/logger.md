---
title: Logger
order: 4
---

# 로거 KonadoLogger

## 머리말

KonadoLogger는 Godot Logger 구현을 기반으로 한 로그 모듈입니다. 로그 레벨, 로그 형식, 로그 출력, 로그 파일 등의 기능을 지원하며 Konado 실행 중의 로그 정보를 기록하는 데 사용됩니다.

## 로그 경로

로그 파일의 논리 경로는 `user://konado_log.log`입니다. 실제 디렉터리는 현재 운영 체제와 프로젝트 이름에 따라 Godot가 결정하며 `OS.get_user_data_dir()`로 확인할 수 있습니다. `LOG_FILE_PATH`는 기본 상수이므로 경로를 변경하려면 사용자 지정 플러그인 버전에서 이 상수를 관리해야 합니다.

## 화면 오버레이 로그

오류가 발생하면 대화 장면은 화면 위에 로그 창을 덮어 표시하여 오류 정보를 보여 주고 게임 실행을 중단합니다. 일반 경고는 계속 로그 파일에 기록되지만 런타임 오류로 표시되거나 게임을 중단하지는 않습니다. 오류 오버레이를 끄려면 `KonadoDialogueManager`의 `enable_overlay_log` 속성을 `false`로 설정하세요.

## 로그 콜백

`KonadoLogger` 인스턴스는 `error_caught(msg)`와 `message_caught(message, error)` 신호를 보냅니다. `KonadoDialogueManager`는 씬 트리에 들어갈 때 내부 로거를 만들어 Godot에 등록하고 `error_caught`로 화면 오버레이를 구동합니다. 로거는 전역 자동 로드 객체가 아닙니다. 별도의 `KonadoLogger`를 만드는 사용자 지정 연동은 `OS.add_logger()`로 등록하고 해제 전에 `OS.remove_logger()`를 호출하여 중복 기록이나 유효하지 않은 인스턴스가 남지 않게 해야 합니다.

## 런타임 실패

원자 명령 실행이 실패하면 `KonadoDialogueManager`는 최종 오류 한 건만 기록하고 `runtime_failure_reported(failure)` 신호를 보냅니다. `failure`에는 안정적인 오류 코드, 작업, 관련 리소스, 근본 원인, 소스 경로와 줄, 명령 ID, opcode, 프로그램 위치가 포함되어 오류 보고나 사용자 지정 디버깅 UI에 사용할 수 있습니다. 간단한 인터페이스인 `runtime_failed(message, instruction_id, source_line)`도 계속 제공됩니다.
