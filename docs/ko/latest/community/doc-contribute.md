---
title: 문서 기여
order: 4
---

# 문서 기여 안내

## 온라인 편집

문서 페이지 아래의 **이 페이지 편집**을 선택하면 GitHub의 Markdown 원본이 열립니다. 파일을 수정하고 미리 본 뒤 커밋하고, `main`을 대상으로 Pull Request를 만드세요.

## 로컬 편집

1. 저장소를 Fork하고 로컬로 복제합니다
2. 최신 `main`에서 작업 브랜치를 만듭니다
3. `docs` 아래의 Markdown 파일을 편집합니다
4. 로컬 미리 보기와 프로덕션 빌드를 모두 확인합니다
5. 작업 브랜치를 push하고 Pull Request를 만듭니다

커밋 이메일은 코드 호스팅 계정과 연결된 주소를 사용하세요. 자동화 도구나 AI 서비스의 공개 `noreply` 작성자 주소는 사용하지 마세요.

## 로컬 검증

CI와 같은 도구 체인을 사용합니다.

- Node.js 24
- pnpm 11

저장소 루트에서 다음을 실행합니다.

```shell
cd docs
corepack enable
corepack prepare pnpm@11 --activate
pnpm install --no-frozen-lockfile
pnpm docs:dev
```

개발 서버는 미리 보기 주소를 출력하고 파일이 바뀌면 자동으로 갱신합니다. 제출하기 전에는 프로덕션 빌드도 실행하세요.

```shell
pnpm docs:build
```

같은 로컬 네트워크의 다른 기기에서 미리 보려면 다음을 실행합니다.

```shell
pnpm docs:dev -- --host
```
