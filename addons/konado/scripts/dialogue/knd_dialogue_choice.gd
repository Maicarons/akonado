extends KND_Data
class_name KND_DialogueChoice

## 选项文本内容
@export var choice_text: String
## 选项跳转的下一个节点ID
@export var next_id: String = ""

func serialize_to_dict() -> Dictionary:
	return {
		"choice_text": choice_text,
		"next_id": next_id
	}

func deserialize_from_dict(dict: Dictionary) -> bool:
	if "choice_text" in dict:
		choice_text = dict["choice_text"]
	if "next_id" in dict:
		next_id = dict["next_id"]
	return true
