---
title: 文件貢獻
order: 4
---

# 文件貢獻指南

## 線上編輯

點擊頁面底部的「線上編輯此頁」，即可在 GitHub 開啟對應的 Markdown 檔案。修改並預覽後提交變更，再建立以 `main` 為目標分支的 Pull Request。

## 本機編輯

1. Fork 儲存庫並複製到本機
2. 從最新的 `main` 建立工作分支
3. 修改 `docs` 目錄中的 Markdown 檔案
4. 在本機完成預覽與正式建置檢查
5. 推送工作分支並建立 Pull Request

請讓提交信箱與程式碼託管帳戶關聯；不要使用自動化工具或 AI 服務的公共 `noreply` 作者信箱。

## 本機驗證

文件建置環境與 CI 保持一致：

- Node.js 24
- pnpm 11

在儲存庫根目錄執行：

```shell
cd docs
corepack enable
corepack prepare pnpm@11 --activate
pnpm install --no-frozen-lockfile
pnpm docs:dev
```

開發伺服器會輸出本機預覽網址，並在檔案修改後自動重新整理。提交前還應執行正式建置：

```shell
pnpm docs:build
```

若要讓區域網路中的其他裝置存取預覽，可執行：

```shell
pnpm docs:dev -- --host
```
