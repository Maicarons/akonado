# GitHub 辅助脚本与配置

此目录保存 GitHub Actions 使用的检查、构建和案例更新脚本；工作流本身位于相邻的 `workflows/` 目录。

## 职责

- `generate-konado-case.mjs`：生成文档部署后用于更新案例展示的数据。
- `requirements.txt`：固定 Python 检查工具版本，保证本地与 CI 结果一致。
- `Konado.CI.csproj`：编译 Konado.NET 包装层及 C# 示例，并启用 Nullable、推荐分析器和警告即错误，不改变主项目类型。
- `../../gdlintrc`：定义项目采用的类型、枚举和成员排列约定。
- `check_doc_resource_paths.py`：验证各语言 `latest` 文档中的 `res://addons/` 静态路径。
- `check_dotnet_docs.py`：验证多语言 Konado.NET API 覆盖范围及 C# 示例所需命名空间。
- `tests/editor/test_konado_script_documentation_examples.gd`：验证文档只保留 `2.4` LTS 与
  `latest`，并编译检查 `latest` 中可执行的 KonadoScript 示例。
- `check_plugin_configs.py`：验证所有 `plugin.cfg` 引用的入口脚本和图标真实存在。
- `check_plugin_resource_boundaries.py`：验证 Konado 核心插件没有引用其目录之外的资源。
- `../../tests/tools/repository_architecture_check.py`：验证插件目录白名单、资源命名、类型与文件名、依赖方向、孤立 UID、外部资源引用及过时路径。
- `run_godot_test.py`：运行 Godot 脚本测试，并阻止“引擎输出脚本错误但退出码仍为 0”的假通过；默认 120 秒超时，需要验证实际像素输出时可通过 `--rendering` 启用兼容渲染器；性能测试使用规模增长比守护编译与取指复杂度，避免用不同 CI 机器间不稳定的绝对耗时作为失败条件。
- `run_dotnet_runtime_tests.sh`：在隔离的临时项目中编译并运行 Konado.NET 与 GDScript 的跨语言运行时测试。

## 本地运行

```bash
python3 -m pip install -r .github/scripts/requirements.txt
gdlint addons sample tests
gdformat --check addons sample tests
python3 .github/scripts/check_doc_resource_paths.py \
  docs/zh/latest docs/en/latest docs/ja/latest docs/ko/latest docs/tc/latest
python3 .github/scripts/check_dotnet_docs.py \
  docs/zh/latest docs/en/latest docs/ja/latest docs/ko/latest docs/tc/latest
python3 .github/scripts/check_plugin_configs.py
python3 .github/scripts/run_godot_test.py tests/localization/test_localization.gd
python3 .github/scripts/check_plugin_resource_boundaries.py \
  "res://addons/konado/" "./addons/konado/"
dotnet build .github/scripts/Konado.CI.csproj --configuration Release --warnaserror
dotnet build .github/scripts/Konado.CI.csproj --configuration Debug --warnaserror
dotnet format .github/scripts/Konado.CI.csproj --verify-no-changes --no-restore
bash .github/scripts/run_dotnet_runtime_tests.sh
```

GDScript 静态检查采用零基线策略，任何 lint 问题都会直接导致 CI 失败。
