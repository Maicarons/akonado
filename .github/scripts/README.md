# GitHub 辅助脚本

此目录保存 GitHub Actions 使用的辅助脚本。

## 工作流

- `workflows/python-ci.yml` — Python 代码质量检查（ruff lint + format check）
- `workflows/release.yml` — 推送 tag 时自动构建 Python 包并发布 GitHub Release