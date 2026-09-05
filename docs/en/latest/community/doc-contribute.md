---
title: Documentation contributions
order: 4
---

# Documentation contribution guide

## Edit online

Select **Edit this page** at the bottom of a documentation page to open its Markdown source on GitHub. Edit and preview the file, commit the change, and then open a pull request targeting `main`.

## Edit locally

1. Fork and clone the repository
2. Create a working branch from the latest `main`
3. Edit Markdown files under `docs`
4. Run both the local preview and production build checks
5. Push the working branch and open a pull request

Use a commit email associated with your hosting account. Do not use a public `noreply` author address belonging to an automation or AI service.

## Local validation

Use the same toolchain as CI:

- Node.js 24
- pnpm 11

From the repository root, run:

```shell
cd docs
corepack enable
corepack prepare pnpm@11 --activate
pnpm install --no-frozen-lockfile
pnpm docs:dev
```

The development server prints the preview URL and refreshes when files change. Before submitting, also run the production build:

```shell
pnpm docs:build
```

To expose the preview to other devices on your local network, run:

```shell
pnpm docs:dev -- --host
```
