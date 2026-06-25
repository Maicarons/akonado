extends Resource
class_name KND_CharacterStatusAlias

## 角色状态别名条目。
## 用资源条目承载两个字符串，是为了让 Inspector 比 Dictionary 更好编辑。

## 剧本里使用的状态名，例如“正常”。
@export var status_name: String = ""

## 角色场景内部实际使用的状态、动画、表情或视频名，例如“default”。
@export var resolved_status_name: String = ""
