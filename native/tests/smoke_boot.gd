extends SceneTree

const MARKER: String = "SCRAPKEEP_SMOKE"


func _init() -> void:
	print("%s %s typed" % [MARKER, version_token()])
	quit(0)


func version_token() -> String:
	var info: Dictionary = Engine.get_version_info()
	var major: int = info["major"]
	var minor: int = info["minor"]
	var patch: int = info["patch"]
	var status: String = info["status"]
	var build: String = info["build"]
	var full_hash: String = info["hash"]
	return "%d.%d.%d.%s.%s.%s" % [major, minor, patch, status, build, full_hash.substr(0, 9)]
