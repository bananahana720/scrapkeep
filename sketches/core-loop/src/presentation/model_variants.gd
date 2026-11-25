class_name ModelVariants
extends RefCounted


const SUFFIX := "_tripo"
const FLAG := "--models=tripo"
const FLAG_ALL := "--models=tripo-all"
const REJECTED := {}

static var _on := -1
static var _rejected: Dictionary = REJECTED
static var _stamp := 0


static func reset_for_tests() -> void:
	_on = -1
	_rejected = REJECTED
	_stamp = 0


static func path(authored: String) -> String:
	if not enabled():
		return authored
	var alt := authored.get_basename() + SUFFIX + "." + authored.get_extension()
	return alt if accepted(alt) and ResourceLoader.exists(alt) else authored


static func only(tripo_path: String) -> String:
	return tripo_path if enabled() and accepted(tripo_path) and ResourceLoader.exists(tripo_path) else ""


static func accepted(tripo_path: String) -> bool:
	return _on == 2 or not _rejected.has(tripo_path)


static func enabled() -> bool:
	if _on < 0:
		var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
		_on = 2 if FLAG_ALL in args else (1 if FLAG in args else 0)
	return _on >= 1


static func stamp() -> int:
	return _stamp


static func set_enabled(on: bool, all := false) -> void:
	_on = (2 if all else 1) if on else 0
	_stamp += 1


static func set_rejected(rejected: Dictionary = REJECTED) -> void:
	_rejected = rejected
	_stamp += 1
