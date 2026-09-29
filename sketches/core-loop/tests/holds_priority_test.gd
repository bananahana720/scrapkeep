extends SceneTree

const Holds := preload("res://src/combat/holds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# Holds' binding line and bracket must not tie with any threat_grammar draw layer
# (they once shared LIVE_PRIORITY, 41, and sorted arbitrarily), and a hostile P1 line
# reads on top: at or above the hot line layer.

var _failures := 0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	# Every int constant named *PRIORITY on the threat grammar, found by reflection so a
	# new layer is covered without editing this test.
	var used := {}
	var script: Script = load("res://src/combat/threat_grammar.gd")
	var constants: Dictionary = script.get_script_constant_map()
	for key in constants:
		if String(key).ends_with("PRIORITY"):
			used[key] = int(constants[key])
	_check("found layers", used.has("PRIORITY") and used.has("LIVE_PRIORITY") and used.has("LINE_UNDER_PRIORITY") and used.has("LINE_PRIORITY"),
		"threat priorities %s" % [used])
	var mine: int = Holds.DRAW_PRIORITY
	var ties := used.keys().filter(func(k): return used[k] == mine)
	_check("no tie", ties.is_empty(), "holds draws at %d; ties with %s" % [mine, ties])
	_check("on top", mine > Threat.LINE_PRIORITY, "holds %d above the hot P1 line layer %d" % [mine, Threat.LINE_PRIORITY])
	var holds := Holds.new()
	var ctx := _Ctx.new()
	ctx.events = GameEvents.new()
	holds.setup(ctx)
	var actual := [holds._lines.material_override.render_priority, holds._bracket_material.render_priority]
	_check("materials use it", actual == [mine, mine], "line and bracket materials draw at %s" % [actual])
	holds.free()
	ctx.events.free()
	print("holds_priority_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


class _Ctx:
	extends RefCounted
	var player = null
	var events = null
