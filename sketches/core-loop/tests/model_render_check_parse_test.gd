extends SceneTree

const T := preload("res://tests/support/t.gd")

# tools/model_render_check.gd shoots with a window (scripts/gate/display-run.mjs), so no headless test runs it. This
# loads and compiles it, so a parse error fails the fast lane instead of the models-render receipt.

var _t := T.new("model_render_check_parse_test")


func _initialize() -> void:
	var script := load("res://tools/model_render_check.gd") as GDScript
	_t.check("model_render_check.gd loads as a script", script != null)
	_t.check("model_render_check.gd compiles", script != null and script.can_instantiate())
	_t.check("it pins the six enemy kinds", script != null and (script.get_script_constant_map().get("KINDS", []) as Array).size() == 6)
	quit(_t.verdict())
