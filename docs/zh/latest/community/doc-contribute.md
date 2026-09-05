---
title: 文档贡献
order: 4
---

# 文档贡献指南

## 在线编辑

点击页面底部的“在线编辑此页”可直接打开 GitHub 中对应的 Markdown 文件。修改并预览后提交更改，随后创建以 `main` 为目标分支的 Pull Request。

## 本地编辑

1. Fork 仓库并克隆到本地
2. 从最新的 `main` 创建工作分支
3. 修改 `docs` 目录中的 Markdown 文件
4. 在本地完成预览和生产构建检查
5. 推送工作分支并创建 Pull Request

请让提交邮箱与代码托管账户关联；不要使用自动化工具或 AI 服务的公共 `noreply` 作者邮箱。

## 本地验证

文档构建环境与 CI 保持一致：

- Node.js 24
- pnpm 11

在仓库根目录执行：

```shell
cd docs
corepack enable
corepack prepare pnpm@11 --activate
pnpm install --no-frozen-lockfile
pnpm docs:dev
```

开发服务器会输出本地预览地址，并在文件修改后自动刷新。提交前还应执行生产构建：

```shell
pnpm docs:build
```

如需让局域网中的其他设备访问预览，可执行：

```shell
pnpm docs:dev -- --host
```
