@tool
extends SyntaxHighlighter
class_name KND_KsHighlighter

## KS语法高亮

@export var highlight_rules := [
	# 根命令（shot_id/background/actor等）
	{
		"regex": "\\b(shot_id|background|actor|play|stop|choice|branch|jump|start|end)\\b",
		"color": Color(0.85, 0.6, 1.0) # 紫罗兰色
	},
	# actor子命令（show/exit/change/move）
	{
		"regex": "\\bactor\\s+(show|exit|change|move)\\b",
		"color": Color(0.95, 0.7, 0.8)  # 樱花粉色
	},
	# play子命令（bgm/sound）
	{
		"regex": "\\bplay\\s+(bgm|sound)\\b",
		"color": Color(0.7, 0.85, 0.95)  # 天蓝色
	},
	# 背景特效
	{
		"regex": "\\bbackground\\s+\\w+\\s+(none|erase|blinds|wave|fade|vortex|windmill|cyberglitch|blink)\\b",
		"color": Color(0.7, 0.95, 0.8)  # 薄荷绿
	},
	# 字符串
	{
		"regex": "\".+?\"",
		"color": Color(0.405, 0.842, 0.512, 1.0) 
	},
	# 坐标关键字（x/y/scale）
	{
		"regex": "\\b(x|y|scale)\\b",
		"color": Color(0.75, 0.75, 0.75)  # 稍暗的灰色
	},
	# 流控制语句
	{
		"regex": "\\b(if|else|endif)\\b",
		"color": Color(1.0, 0.725, 0.314, 1.0)
	},
	# 注释
	{
		"regex": "#.*",
		"color": Color(0.5, 0.5, 0.5, 0.8)
	},
]


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var highlight_data = {}
	# 获取绑定的 CodeEdit 文本
	var text_edit = get_text_edit()
	if not text_edit:
		return highlight_data
	
	# 获取当前行文本
	var line_text = text_edit.get_line(line)
	if line_text.is_empty():
		return highlight_data
	
	# 遍历所有高亮规则（仅保留有效规则，无空正则）
	for rule in highlight_rules:
		var regex = RegEx.new()
		# 编译正则（提前校验，避免无效正则）
		var compile_error = regex.compile(rule.regex)
		if compile_error != OK:
			print("正则编译错误: ", compile_error, " 规则: ", rule.regex)
			continue
		
		# 单次搜索（避免重复编译正则，优化性能）
		var match_result = regex.search_all(line_text)
		if not match_result:
			continue
		
		# 遍历所有匹配结果（改用search_all，更高效）
		for match in match_result:
			var start_col = match.get_start()
			var end_col = match.get_end()
			# 为匹配的每一列设置颜色（修复只设置起始列的问题）
			for col in range(start_col, end_col):
				highlight_data[col] = {"color": rule.color}
	
	# 排序并返回（保持原有逻辑）
	var sorted_cols = highlight_data.keys()
	sorted_cols.sort()
	
	var sorted_highlight = {}
	for col in sorted_cols:
		sorted_highlight[col] = highlight_data[col]
	
	return sorted_highlight

func _clear_highlighting_cache():
	pass

func _update_cache():
	pass
