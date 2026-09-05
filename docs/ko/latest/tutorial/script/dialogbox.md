---
title: 대화 상자 표시와 숨기기
order: 5
---

# 대화 상자 표시와 숨기기

이 명령은 대화 상자의 표시 상태를 제어하고 페이드가 끝난 뒤 다음 문장을 실행합니다.

## 문법

```text
showtextbox [duration]
hidetextbox [duration]
```

`duration`은 초 단위의 선택적 값이며 음수일 수 없습니다. 생략하거나 `0.0`을 사용하면 표시 상태가 즉시 바뀝니다.

`hidetextbox`는 숨기기가 끝난 뒤 현재 화자 이름과 대화문을 지워, 다음에 대화 상자를 표시할 때 이전 문장이 잠깐 나타나지 않도록 합니다.

## 예제

```text
# 1초 동안 대화 상자를 표시
showtextbox 1.0

# 0.5초 동안 대화 상자를 숨김
hidetextbox 0.5

# 표시 상태를 즉시 변경
showtextbox 0.0
hidetextbox 0.0
```
