extends RefCounted

const ACTIONS: Array[String] = ["cast", "move_left", "move_right"]


class InputFrame extends RefCounted:
	var held: Dictionary[String, bool] = {}
	var released: Dictionary[String, bool] = {}


var _held: Dictionary[String, bool] = {}
var _previous: Dictionary[String, bool] = {}


func _init() -> void:
	clear_held()


func press(action: String) -> void:
	_held[action] = true


func release(action: String) -> void:
	_held[action] = false


func frame() -> InputFrame:
	var result: InputFrame = InputFrame.new()
	for action: String in ACTIONS:
		result.held[action] = _held[action]
		result.released[action] = _previous[action] and not _held[action]
		_previous[action] = _held[action]
	return result


func clear_held() -> void:
	for action: String in ACTIONS:
		_held[action] = false
		_previous[action] = false


func any_held() -> bool:
	for action: String in ACTIONS:
		if _held[action] or _previous[action]:
			return true
	return false
