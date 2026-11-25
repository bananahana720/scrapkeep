extends RefCounted

const HOLD := 4.0

var _key := ""
var _held := 0.0
var _reported := {}


func listen(key: String, delta: float) -> String:
	if key != _key:
		_key = key
		_held = 0.0
	if key == "" or _reported.has(key):
		return ""
	_held += delta
	if _held < HOLD:
		return ""
	_reported[key] = true
	return key


func knows(id: String) -> void:
	_reported[id] = true


func heard(id: String) -> bool:
	return _reported.has(id)
