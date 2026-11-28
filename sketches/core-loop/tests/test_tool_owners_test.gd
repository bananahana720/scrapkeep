extends SceneTree

const Combat := preload("res://src/combat/combat.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const BossDouble := preload("res://tests/doubles/boss_spawner_double.gd")
const SpineDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const T := preload("res://tests/support/t.gd")

const PUSH_OWNER := "res://tests/support/push.gd"
const ALLOWED_PRESS_HELPERS: Array[String] = []

var _t := T.new("test_tool_owners_test")


func _initialize() -> void:
	_check_spawner_double_owners()
	_check_push_owners()
	quit(_t.verdict())


func _check_spawner_double_owners() -> void:
	for path in [
		"res://tests/doubles/boss_spawner_double.gd",
		"res://tests/doubles/spine_spawner_double.gd",
	]:
		var text := FileAccess.get_file_as_string(path)
		var dupes: Array[String] = []
		for token in [
			"const STRIKE_DAMAGE",
			"const CHIP",
			"const CRUISE_TIER",
			"func punch_of(",
			"func integrity_of(",
			"func would_crush(",
		]:
			if text.contains(token):
				dupes.append(token)
		_t.eq("%s inherits shared strike math from spawner_double_base" % path, dupes, [])
	_t.eq("BossDouble.STRIKE_DAMAGE matches Combat.STRIKE_DAMAGE", BossDouble.STRIKE_DAMAGE, Combat.STRIKE_DAMAGE)
	_t.eq("SpineDouble.STRIKE_DAMAGE matches Combat.STRIKE_DAMAGE", SpineDouble.STRIKE_DAMAGE, Combat.STRIKE_DAMAGE)
	_t.eq("BossDouble.CONTACT_KINDS matches Combat.CONTACT_KINDS", BossDouble.CONTACT_KINDS, Combat.CONTACT_KINDS)
	_t.near("BossDouble.CHIP matches Combat.CHIP", BossDouble.CHIP, Combat.CHIP)
	_t.near("SpineDouble.CHIP matches Combat.CHIP", SpineDouble.CHIP, Combat.CHIP)
	_t.eq("BossDouble.CRUISE_TIER matches SpeedTier.CRUISE", BossDouble.CRUISE_TIER, SpeedTier.CRUISE)
	_t.eq("SpineDouble.CRUISE_TIER matches SpeedTier.CRUISE", SpineDouble.CRUISE_TIER, SpeedTier.CRUISE)


func _check_push_owners() -> void:
	var old_path := "res://tests/" + "workshop/push.gd"
	var stale_refs: Array[String] = []
	var press_helpers: Array[String] = []
	var scripts := _scripts("res://tests/")
	scripts.append_array(_scripts("res://tools/"))
	scripts.sort()
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		if text.contains(old_path):
			stale_refs.append(path)
		if path != PUSH_OWNER and _has_key_push_press(text):
			press_helpers.append(path)
	_t.eq("no script references old workshop push path", stale_refs, [])
	var unexpected: Array[String] = []
	for path in press_helpers:
		if not path in ALLOWED_PRESS_HELPERS:
			unexpected.append(path)
	var stale_allowed: Array[String] = []
	for path in ALLOWED_PRESS_HELPERS:
		if not path in press_helpers:
			stale_allowed.append(path)
	_t.eq("no unlisted _press helper builds InputEventKey.new() with push_input", unexpected, [])
	_t.eq("allowed _press helper list has no stale entries", stale_allowed, [])


static func _has_key_push_press(text: String) -> bool:
	var lines := text.split("\n")
	var in_press := false
	var has_key := false
	var has_push := false
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("static func ") or stripped.begins_with("class "):
			if in_press and has_key and has_push:
				return true
			in_press = stripped.begins_with("func _press(") or stripped.begins_with("static func _press(")
			has_key = false
			has_push = false
		if in_press:
			if line.contains("InputEventKey.new()"):
				has_key = true
			if line.contains("push_input"):
				has_push = true
	return in_press and has_key and has_push


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + sub + "/"))
	return out
