extends SceneTree

const T := preload("res://tests/support/t.gd")

# tools/model_render_check.gd shoots with a window (scripts/gate/display-run.mjs), so no headless test runs a shoot.
# This loads and compiles it, so a parse error fails the fast lane instead of the models-render receipt, and runs its
# judge on made-up stats: a generated model that was not loaded is a miss named by kind, never judged as present.

var _t := T.new("model_render_check_parse_test")


func _initialize() -> void:
	var script := load("res://tools/model_render_check.gd") as GDScript
	_t.check("model_render_check.gd loads as a script", script != null)
	_t.check("model_render_check.gd compiles", script != null and script.can_instantiate())
	if script == null or not script.can_instantiate():
		quit(_t.verdict())
		return
	_t.check("it pins the six enemy kinds", (script.get_script_constant_map().get("KINDS", []) as Array).size() == 6)
	var view := {"pixels": 5000, "brightness": 0.4, "near_black": 0.01}
	var dark := {"pixels": 5000, "brightness": 0.1, "near_black": 0.5}
	var authored := {"models": "authored", "kinds": {"hooker": [view, view], "lobber": [view, view], "swatter": [view, view]}}
	var tripo := {"models": "tripo-all", "kinds": {"hooker": [view, view], "lobber": [view, dark], "swatter": [view, view]}, "files": {
		"hooker": {"authored": "res://h.glb", "path": "res://h_tripo.glb", "loaded": true},
		"lobber": {"authored": "res://l.glb", "path": "res://l_tripo.glb", "loaded": true},
		"swatter": {"authored": "res://s.glb", "path": "res://s.glb", "loaded": true}}}
	var verdict: Dictionary = script.judge(authored, tripo)
	_t.check("judge: a bright generated model passes, a dark one fails", verdict.judged == 2 and verdict.failed == ["lobber"], str(verdict))
	_t.check("judge: a kind that loaded its authored file is missing, not judged", verdict.missing == ["swatter"], str(verdict))
	tripo.files.swatter = {"authored": "res://s.glb", "path": "res://s_tripo.glb", "loaded": false}
	_t.check("judge: a generated file that did not load is missing", (script.judge(authored, tripo) as Dictionary).missing == ["swatter"])
	tripo.files.erase("hooker")
	_t.check("judge: a kind with no file record is missing", (script.judge(authored, tripo) as Dictionary).missing == ["hooker", "swatter"])
	_t.check("judge: two authored shoots are refused", not String((script.judge(authored, authored) as Dictionary).error).is_empty())
	quit(_t.verdict())
