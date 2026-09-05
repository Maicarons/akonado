---
title: ドキュメントへの貢献
order: 4
---

# ドキュメント貢献ガイド

## オンライン編集

ページ下部の「このページを編集」を選択すると、GitHub 上の Markdown ソースが開きます。編集内容をプレビューしてコミットし、`main` を対象とする Pull Request を作成してください。

## ローカル編集

1. リポジトリを Fork してローカルへクローンする
2. 最新の `main` から作業ブランチを作成する
3. `docs` 配下の Markdown ファイルを編集する
4. ローカルプレビューと本番ビルドを確認する
5. 作業ブランチを push して Pull Request を作成する

コミットメールはホスティングアカウントに関連付けられたものを使用してください。自動化ツールや AI サービスの公開 `noreply` 作者アドレスは使用しないでください。

## ローカル検証

CI と同じツールチェーンを使用します。

- Node.js 24
- pnpm 11

リポジトリのルートで次を実行します。

```shell
cd docs
corepack enable
corepack prepare pnpm@11 --activate
pnpm install --no-frozen-lockfile
pnpm docs:dev
```

開発サーバーにプレビュー URL が表示され、ファイル変更時に自動更新されます。提出前には本番ビルドも実行してください。

```shell
pnpm docs:build
```

同じ LAN 上の別端末からプレビューする場合は、次を実行します。

```shell
pnpm docs:dev -- --host
```
