extends Node

## 是否启用 Web 开发者工具快捷键放行
@export var developer_shortcuts_enabled: bool = true

## 是否允许在正式导出包中放行开发者快捷键
@export var allow_in_release: bool = false

## F12：打开开发者工具
@export var enable_f12: bool = true
## F5：刷新页面
@export var enable_f5: bool = true
## F11：全屏切换
@export var enable_f11: bool = true
## Ctrl+Shift+I (Win/Linux) / Cmd+Opt+I (Mac)：打开元素面板
@export var enable_ctrl_shift_i: bool = true
## Ctrl+Shift+J (Win/Linux) / Cmd+Opt+J (Mac)：打开控制台
@export var enable_ctrl_shift_j: bool = true
## Ctrl+Shift+C (Win/Linux) / Cmd+Shift+C (Mac)：检查元素模式
@export var enable_ctrl_shift_c: bool = true
## Ctrl+U (Win/Linux) / Cmd+U (Mac)：查看页面源码
@export var enable_ctrl_u: bool = true
## Ctrl+R (Win/Linux) / Cmd+R (Mac)：刷新页面
@export var enable_ctrl_r: bool = true


func _ready() -> void:
	refresh_shortcuts()


func _exit_tree() -> void:
	_remove_web_shortcut_handler()


## 根据当前配置重新安装或移除浏览器快捷键处理器。
func refresh_shortcuts() -> void:
	if not OS.has_feature("web"):
		return
	if developer_shortcuts_enabled and (OS.has_feature("debug") or allow_in_release):
		_inject_web_shortcut_handler()
	else:
		_remove_web_shortcut_handler()


func _inject_web_shortcut_handler() -> void:
	var injected: Variant = (
		JavaScriptBridge
		. eval(
			(
				"""
		(function() {
			if (window.__konadoDevtoolHandler) {
				document.removeEventListener('keydown', window.__konadoDevtoolHandler, true);
			}

			// 根据当前配置动态构建快捷键列表
			var shortcuts = [];
	"""
				+ _build_shortcuts_js_array()
				+ """
			var isMac = /Mac|iPhone|iPad|iPod/.test(navigator.platform);

			window.__konadoDevtoolHandler = function(e) {
				for (var i = 0; i < shortcuts.length; i++) {
					var s = shortcuts[i];
					var keyMatch = String(e.key).toUpperCase() === s.key;
					if (!keyMatch) continue;

					var primaryPressed = isMac ? e.metaKey : e.ctrlKey;
					var secondaryPressed = isMac ? e.ctrlKey : e.metaKey;
					var shiftRequired = isMac && s.macAlt ? false : Boolean(s.shift);
					var altRequired = isMac && s.macAlt ? true : Boolean(s.alt);
					var ctrlMatch = primaryPressed === Boolean(s.ctrl) && !secondaryPressed;
					var shiftMatch = e.shiftKey === shiftRequired;
					var altMatch = e.altKey === altRequired;

					if (ctrlMatch && shiftMatch && altMatch) {
						e.stopImmediatePropagation();
						return;
					}
				}
			};
			document.addEventListener('keydown', window.__konadoDevtoolHandler, true);
			return true;
		})();
	"""
			)
		)
	)
	if injected != true:
		push_warning("KonadoWebTool: 无法安装浏览器快捷键处理器")


func _remove_web_shortcut_handler() -> void:
	if not OS.has_feature("web"):
		return
	(
		JavaScriptBridge
		. eval(
			"""
		(function() {
			if (!window.__konadoDevtoolHandler) return true;
			document.removeEventListener('keydown', window.__konadoDevtoolHandler, true);
			delete window.__konadoDevtoolHandler;
			return true;
		})();
	"""
		)
	)


func _build_shortcuts_js_array() -> String:
	var items: Array[String] = []

	if enable_f12:
		items.append("{ key: 'F12' }")
	if enable_f5:
		items.append("{ key: 'F5' }")
	if enable_f11:
		items.append("{ key: 'F11' }")
	if enable_ctrl_shift_i:
		items.append("{ key: 'I', ctrl: true, shift: true, macAlt: true }")
	if enable_ctrl_shift_j:
		items.append("{ key: 'J', ctrl: true, shift: true, macAlt: true }")
	if enable_ctrl_shift_c:
		items.append("{ key: 'C', ctrl: true, shift: true }")
	if enable_ctrl_u:
		items.append("{ key: 'U', ctrl: true }")
	if enable_ctrl_r:
		items.append("{ key: 'R', ctrl: true }")

	if items.is_empty():
		return "// No shortcuts enabled"
	return "shortcuts = [" + ", ".join(items) + "];"
