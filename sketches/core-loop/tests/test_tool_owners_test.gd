extends SceneTree

const Combat := preload("res://src/combat/combat.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const BossDouble := preload("res://tests/doubles/boss_spawner_double.gd")
const SpineDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

const ROOTS: Array[String] = ["res://tests", "res://tools"]
const PUSH_OWNER := "res://tests/support/push.gd"
const KEY_LOOP := "for\\s+\\w+\\s+in\\s+\\[\\s*(?:true\\s*,\\s*false|false\\s*,\\s*true)\\s*\\]"
const ALLOWED_KEY_LOOP_HELPERS: Array[String] = []
const ALLOWED_SINGLE_EDGE_KEY_PUSHES: Array[String] = [
	"res://tests/death_summary_loop_test.gd:_key",
	"res://tests/flourish_test.gd:_live",
	"res://tests/run_tier_test.gd:_card",
	"res://tests/run_tier_test.gd:_continue_replay",
	"res://tests/ui_settings_pages_test.gd:_run",
	"res://tests/ui_skill_bar_test.gd:_key",
	"res://tests/world23_flourishes_test.gd:_skip_and_nonblocking",
]
const ALLOWED_SCREENS_BODY_REACHINS: Array[String] = [
	"res://tests/death_summary_loop_test.gd",
	"res://tests/old_works_screens_hand_test.gd",
	"res://tests/pol_ui_title_readability_test.gd",
	"res://tests/ui_class_card_level_test.gd",
]
const ALLOWED_POSTURE_VALUE_READS: Array[String] = [
	"res://tests/park_reactor_phase_quarters_test.gd",
]

var _t := T.new("test_tool_owners_test")


func _initialize() -> void:
	_check_spawner_double_owners()
	_check_push_owners()
	_check_public_read_seams()
	quit(_t.verdict())


func _check_spawner_double_owners() -> void:
	for path in [
		"res://tests/doubles/boss_spawner_double.gd",
		"res://tests/doubles/spine_spawner_double.gd",
	]:
		var text := SourceScan.text(_t, path)
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
	var stale_refs := SourceScan.matching(_t, ROOTS, "res://tests/" + "workshop/push\\.gd")
	var loop_helpers: Array[String] = []
	var single_edge_helpers: Array[String] = []
	var key_files := SourceScan.matching(_t, ROOTS, "InputEventKey" + "\\.new\\(\\)")
	for path in key_files:
		if path == PUSH_OWNER:
			continue
		var text := SourceScan.text(_t, path)
		if text.is_empty():
			continue
		for block in _key_push_blocks(_t, text):
			var entry := "%s:%s" % [path, block["name"]]
			if block["loop"]:
				loop_helpers.append(entry)
			else:
				single_edge_helpers.append(entry)
	_t.eq("no script references old workshop push path", stale_refs, [])
	_check_allowlist("no unlisted press-and-release loop helper builds InputEventKey with push_input",
		loop_helpers, ALLOWED_KEY_LOOP_HELPERS)
	_check_allowlist("no unlisted single-edge helper builds InputEventKey with push_input",
		single_edge_helpers, ALLOWED_SINGLE_EDGE_KEY_PUSHES)


func _check_public_read_seams() -> void:
	var body_files := SourceScan.matching(_t, ROOTS, "(?m)^[^#\\n]*screens" + "\\._body")
	var posture_files := SourceScan.matching(_t, ROOTS, "(?m)^[^#\\n]*\\._pos" + "ture\\.posture\\b(?!\\s*[-+*/]?=(?!=))")
	_check_allowlist("no unlisted file reaches into screens body control", body_files, ALLOWED_SCREENS_BODY_REACHINS)
	_check_allowlist("no unlisted file reads posture value through private posture field", posture_files, ALLOWED_POSTURE_VALUE_READS)


func _check_allowlist(label: String, found: Array[String], allowed: Array[String]) -> void:
	var unexpected: Array[String] = []
	for entry in found:
		if not entry in allowed:
			unexpected.append(entry)
	var stale: Array[String] = []
	for entry in allowed:
		if not entry in found:
			stale.append(entry)
	_t.eq(label, unexpected, [])
	_t.eq("%s (no stale allowlist entries)" % label, stale, [])


static func _key_push_blocks(t, text: String) -> Array[Dictionary]:
	var key_ctor := "InputEventKey" + ".new()"
	var push_call := "push_" + "input"
	var out: Array[Dictionary] = []
	var func_name := ""
	var has_key := false
	var has_push := false
	var has_loop := false
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("static func ") or stripped.begins_with("class "):
			if func_name != "" and has_key and has_push:
				out.append({"name": func_name, "loop": has_loop})
			func_name = _extract_func_name(stripped)
			has_key = false
			has_push = false
			has_loop = false
		if func_name != "":
			if line.contains(key_ctor):
				has_key = true
			if line.contains(push_call):
				has_push = true
			if line.contains("for") and line.contains("[") and not SourceScan.search(t, line, KEY_LOOP).is_empty():
				has_loop = true
	if func_name != "" and has_key and has_push:
		out.append({"name": func_name, "loop": has_loop})
	return out


static func _extract_func_name(stripped: String) -> String:
	var rest := ""
	if stripped.begins_with("static func "):
		rest = stripped.substr(12)
	elif stripped.begins_with("func "):
		rest = stripped.substr(5)
	else:
		return ""
	var paren := rest.find("(")
	return rest.substr(0, paren).strip_edges() if paren > 0 else ""
