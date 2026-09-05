# GitHub Actions 职责划分

| 工作流 | 触发方式 | 职责 | 是否写入仓库 |
| --- | --- | --- | --- |
| `identity-check.yml` | PR 创建、重开、更新或转为可审查 | 检查最多 250 个提交的作者、提交者和身份 trailer；发现已知 AI 提交邮箱或超出可核验上限时留言并关闭 PR | 是，关闭并评论 PR |
| `quality-check.yml` | PR、`main` Push、手动 | Action 语法、GDScript 静态与架构测试、Konado.NET 编译、VS Code 扩展检查与打包、插件与文档资源完整性 | 否 |
| `export-check.yml` | 相关项目文件的 PR/Push、手动 | 调用可复用构建，验证 Windows、Linux、Web、Android 导出 | 否 |
| `project-export.yml` | 仅 `workflow_call` | 统一四个平台的 Godot 4.7.1 构建与产物上传 | 否 |
| `docs-build.yml` | 文档 PR、`workflow_call` | 构建 VitePress 并上传站点产物 | 否 |
| `docs-deploy.yml` | 文档 `main` Push、手动 | 调用文档构建、更新案例并部署 `docs` 分支 | 是，写入 `main` 和 `docs` |
| `release.yml` | 创建 `v*` 标签、手动 | 构建发布产物和插件包；仅创建版本标签时使用 `CHANGELOG.md` 对应版本章节创建 GitHub Release | 仅标签发布 |
| `update-showcase.yml` | 文档部署调用、手动 | 刷新 README 的 Made by Konado 内容 | 是，写入 `main` |

## 设计约束

- PR 构建和质量检查使用只读权限；身份策略仅授予读取提交元数据、评论和关闭 PR 所需的最小权限。
- 身份策略使用 `pull_request_target` 读取 GitHub API 元数据，不检出或执行 PR 分支代码。
- 构建逻辑集中在 `project-export.yml`，CI 与正式发布共用，避免平台配置漂移。
- 文档部署在案例刷新成功后进行；PR 只触发文档构建工作流。
- 正式发布只接受新建 `v*` 标签；手动运行只生成可下载构建产物。
- 正式发布要求 `CHANGELOG.md` 存在与标签版本一致的二级标题，并将该标题至下一二级标题前的内容作为 Release 描述。
- 会提交或推送内容的维护任务单独成工作流，并使用最小的写权限。
- 文档部署使用带租约的强制更新，不先删除远程分支。
- GitHub Actions 使用的辅助脚本和检查配置统一放在 `.github/scripts/`。
