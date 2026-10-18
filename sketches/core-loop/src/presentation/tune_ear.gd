extends RefCounted

# Hears which jukebox record is playing. A tune counts once its key has held for HOLD
# seconds, so a track that only flickers through a transition (a summary between a death
# and the title, a stage passed through in a launch) is not found. listen returns the id
# on the frame it is found and "" otherwise; each id is reported once per ear.

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


# A tune the profile already holds: the ear stays quiet about it.
func knows(id: String) -> void:
	_reported[id] = true


func heard(id: String) -> bool:
	return _reported.has(id)
