extends SceneTree
# The post grade's contract (Grading lane, wave 18). The grade probe (tools/grade_probe.gd) measures
# what each look does to the meaning colours on the render bench; this test pins what holds
# without a display:
#   WG-1 the probe covers every stage at its time of day, every arena row and the camp.
#   WG-2 its gaps are DefenceBars' CIE76, HAZARD against AMBER, BRASS and every Bible ground,
#        and its floor is beacon_colour_test's 20.
#   WG-3 telegraphs never bloom: threat_grammar paints unshaded colours at most 1.0, so every
#        preset with glow keeps its HDR threshold above 1.0 (VISUAL-LANGUAGE checklist item 14).
#   WG-4 reduce flashes (DECISIONS section 10) leaves the grade alone: turning it on and off
#        changes no tonemap, adjustment or glow field on the run's environment.
const Game := preload("res://src/game.gd")
const Probe := preload("res://tools/grade_probe.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const T := preload("res://tests/support/t.gd")
const GRADE_KEYS := ["tonemap_mode", "tonemap_exposure", "tonemap_white", "tonemap_agx_white", "tonemap_agx_contrast",
	"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
	"adjustment_color_correction", "glow_enabled", "glow_intensity", "glow_strength", "glow_bloom",
	"glow_hdr_threshold", "glow_blend_mode"]

var _t := T.new("world_grade_test")
var _game
var _step := 0


func _initialize() -> void:
	_contract()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _contract() -> void:
	var ids := Probe.looks(Game.TABLES[Game.LAUNCH_TABLE]).map(func(entry): return entry.id)
	for stage in range(1, Game.TABLES[Game.LAUNCH_TABLE].COUNT + 1):
		_t.check("WG-1 stage %d is probed at its time" % stage, ids.has("stage%d-%s" % [stage, WorldLook.time_id(stage)]), str(ids))
	for arena in WorldLook.ARENAS:
		_t.check("WG-1 arena %s is probed" % arena, ids.has("arena-" + arena), str(ids))
	_t.check("WG-1 the camp is probed", ids.has("camp"), str(ids))
	var raw: Dictionary = Probe._raw()
	_t.near("WG-2 hazard~amber is CIE76", raw["hazard~amber"], DefenceBars.cie76(Palette.HAZARD, Palette.AMBER))
	_t.near("WG-2 hazard~brass is CIE76", raw["hazard~brass"], DefenceBars.cie76(Palette.HAZARD, Palette.BRASS))
	for ground in Probe.GROUND:
		_t.check("WG-2 hazard is gated against " + ground, raw.has("hazard~" + ground) and Probe.gated("hazard~" + ground), ground)
	_t.check("WG-2 arc is reported, not gated", raw.has("arc~sand") and not Probe.gated("arc~sand"), "arc")
	_t.near("WG-2 the floor is beacon_colour_test's", Probe.GAP, 20.0)
	for id in Probe.MEANING:
		_t.check("WG-2 the ungraded palette clears the floor: hazard~" + id, id == "hazard" or id == "arc" or id == "slate" or raw["hazard~" + id] >= Probe.GAP, str(raw))

	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	GraphicsPreset.bind(env, sun, root)
	for id in Probe.MEANING:
		var c: Color = Probe.MEANING[id]
		_t.check("WG-3 %s is an LDR fill" % id, maxf(c.r, maxf(c.g, c.b)) <= 1.0, c.to_html(false))
	for preset in GraphicsPreset.PRESETS:
		GraphicsPreset.apply(preset)
		_t.check("WG-3 %s: glow threshold sits above unshaded telegraphs" % preset,
			not env.glow_enabled or env.glow_hdr_threshold > 1.0, "threshold %.2f" % env.glow_hdr_threshold)
	GraphicsPreset.apply("high")
	sun.free()


func _grade(env: Environment) -> Dictionary:
	var values := {}
	for key in GRADE_KEYS:
		values[key] = env.get(key)
	return values


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_step += 1
	if _step == 1:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _step == 6:
		var env: Environment = _game.ctx.terrain.environment
		_game.set_reduce_flashes(false)
		var before := _grade(env)
		_game.set_reduce_flashes(true)
		var on := _grade(env)
		_game.set_reduce_flashes(false)
		var after := _grade(env)
		for key in GRADE_KEYS:
			_t.check("WG-4 reduce flashes leaves %s alone" % key, before[key] == on[key] and on[key] == after[key], "%s / %s / %s" % [before[key], on[key], after[key]])
		_game.set_reduce_flashes(false)
		quit(_t.verdict())
	return false
