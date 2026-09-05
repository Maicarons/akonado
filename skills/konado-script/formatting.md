# 代码格式化

## 缩进

- **缩进单位**：遵循 Godot 编辑器当前的缩进设置；同一文件只使用一种缩进方式
- **需要缩进的场景**：
  - `branch <id>` 块内的所有语句至少缩进 1 级
  - `if` / `else` 和 `screentext` 块内语句必须缩进 1 级
- **不需要缩进的场景**：
  - 顶层命令（`background`、`actor`、`play`、`stop`、`choice`、`set` 等）不缩进
- **禁止**：同一脚本混用空格和 Tab 作为缩进单位

## 换行

- 每个语句独占一行，不允许在一行内写多个不同命令
- 每个 `choice` 选项独占一行；连续的 `choice` 行会组成同一个选项组
- `if`、`else:`、`endif` 各自独占一行
- `branch` 声明独占一行，块内语句每行一个
- 空行用于分隔不同逻辑段落，`branch` 之间建议用空行隔开

## 命名约定

| 元素 | 约定 | 示例 |
|------|------|------|
| 变量名 | `[a-zA-Z_][a-zA-Z0-9_]*`，区分大小写 | `%love`、`$score`、`%player_name` |
| branch 标签ID | 小写字母 + 下划线，语义化 | `gift_choice`、`chat_more` |
| 角色ID | 与项目资源一致，大小写敏感 | `Kona`、`alice` |
| 资源名 | 使用项目资源列表中登记的 ID | `morning_forest`、`main_theme` |
| 状态名 | 语义化英文或中文 | `正常`、`happy`、`angry` |
| 配音标签 | 小写字母 + 下划线 | `alice_intro_01` |

## 注释

- 使用 `#` 开头；既支持独占一行，也支持不破坏可读性的行尾注释
- 在 `branch` 块前建议添加注释说明该分支的用途

## 字符串

- 对话正文、选项文本、全屏文本和纯文本署名使用英文双引号 `"..."` 包裹
- 演员 ID 使用裸标识符，动态演员使用 `$name` 或 `%name`，不要给演员 ID 加引号
- 如需在字符串内使用双引号，使用 `\"` 转义
- 选项文本、角色对话文本、资源名引号均为英文半角

## 建议的文件结构

```ks
# ==== 文件头注释 ====
# 场景名：xxx
# 作者：xxx

# ==== 场景初始化 ====
play bgm main_theme
background morning_forest fade
actor show Kona 正常 at 2

# ==== 开场对话 ====
Kona "欢迎来到故事！" [speed=1.2]

# ==== 选项区 ====
choice "选项一" -> branch_a
choice "选项二" -> branch_b

# ==== 分支定义 ====
branch branch_a
	set %flag_a = 1
	Kona "你选择了选项一。"
	jump_branch common_end

branch branch_b
	set %flag_b = 1
	Kona "你选择了选项二。"
	jump_branch common_end

# ==== 共同结局 ====
branch common_end
	actor exit Kona
	background bg_end fade
	end
```
