extends RefCounted

const PATH := "res://data/challenge/monster_heft.json"
static var _doc = null


static func threshold_for_stage(stage: int) -> float:
	return _number("wardens", str(stage))


static func waking_threshold() -> float:
	return _number("waking")


static func mind_threshold() -> float:
	return _number("mind")


static func _number(key: String, sub := "") -> float:
	if _doc == null:
		_doc = {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if parsed is Dictionary:
			_doc = parsed
	var value = _doc.get(key)
	if sub != "":
		value = value.get(sub) if value is Dictionary else null
	return float(value) if value is float or value is int else INF
