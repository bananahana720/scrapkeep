extends SceneTree
# The post grade's contract (Grading lane, wave 18). The grade probe (tools/grade_probe.gd) measures
# what each look does to the meaning colours on the render bench; this test pins what holds
# without a display:
#   WG-1 the probe covers every launch-table stage at its time of day, each world's arena and the camp.
#   WG-2 its gaps are DefenceBars' CIE76 at threat_grammar's alphas: edge pairs on the keyline band
#        (beacon_colour_test's pairs plus HAZARD against AMBER and BRASS) gated at that test's 20,
#        the hostile fill of the live telegraph look over the Bible grounds reported.
#   WG-3 threat_grammar's marks never bloom: they are unshaded and at most bright() of their tone,
#        so every preset with glow keeps its HDR threshold above 1.0 and no bloom term
#        (VISUAL-LANGUAGE checklist item 14, for threat_grammar marks only; emissive wind-up bodies
#        are not covered here).
#   WG-4 reduce flashes (DECISIONS section 10) leaves the grade alone: turning it on and off
#        changes no tonemap, adjustment or glow field on the run's environment.
#   WG-5 WorldGrade.BASE is what graphics_preset.gd writes: after bind and apply("high") every BASE key
#        equals the bound environment's value, so the menus' grade cannot drift from the run's.
#   WG-6 the class preview and the customize bench take AgX at BASE's contrast through WorldGrade.menu.
const Game := preload("res://src/game.gd")
const Probe := preload("res://tools/grade_probe.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WorldGrade := preload("res://src/presentation/world_grade.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const ThreatGrammar := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")
const GRADE_KEYS := ["tonemap_mode", "tonemap_exposure", "tonemap_white", "tonemap_agx_white", "tonemap_agx_contrast",
	"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
	"adjustment_color_correction", "glow_enabled", "glow_intensity", "glow_strength", "glow_bloom",
	"glow_hdr_threshold", "glow_hdr_scale", "glow_hdr_luminance_cap", "glow_blend_mode", "glow_mix", "glow_normalized",
	"glow_map", "glow_map_strength", "glow_levels/1", "glow_levels/2", "glow_levels/3", "glow_levels/4", "glow_levels/5",
	"glow_levels/6", "glow_levels/7"]

var _t := T.new("world_grade_test")
var _game
var _step := 0


func _initialize() -> void:
	_contract()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _contract() -> void:
	var stages = Game.TABLES[Game.LAUNCH_TABLE]
	var ids := Probe.places(stages).map(func(entry): return entry.id)
	for stage in range(1, stages.COUNT + 1):
		_t.check("WG-1 stage %d is probed at its time" % stage, ids.has("stage%d-%s" % [stage, WorldLook.time_id(stage)]), str(ids))
		var world: int = stages.world_of(stage)
		_t.check("WG-1 world %d's arena is probed" % world, ids.has("arena-w%d" % world), str(ids))
	_t.check("WG-1 the camp is probed", ids.has("camp"), str(ids))
	var raw: Dictionary = Probe.raw()
	# The painter's own alphas: the keyline band over sandstone, an edge over the band, and a hostile
	# fill under the live telegraph look (haze by default: HAZARD at FILL_ALPHA * HAZE_FILL).
	var fill_alpha := ThreatGrammar.FILL_ALPHA * (ThreatGrammar.HAZE_FILL if ThreatGrammar.haze() else 1.0)
	_t.near("WG-2 the probe's fill is the painter's hostile fill", Probe.fill().a, fill_alpha)
	var keyline := Palette.SANDSTONE.lerp(Palette.CHARCOAL, ThreatGrammar.UNDERLAY_ALPHA)
	var edge := func(c: Color) -> Color: return keyline.lerp(c, ThreatGrammar.EDGE_ALPHA)
	_t.near("WG-2 an edge pair is CIE76 at EDGE_ALPHA on the band", raw["edge:hazard~amber"], DefenceBars.cie76(edge.call(Palette.HAZARD), edge.call(Palette.AMBER)))
	_t.near("WG-2 a fill pair is CIE76 at the fill's alpha over its ground", raw["fill:hazard~sandstone"],
		DefenceBars.cie76(Palette.SANDSTONE.lerp(Palette.HAZARD, fill_alpha), Palette.SANDSTONE))
	for pair in Probe.PAIRS:
		var id := "edge:%s~%s" % pair
		_t.check("WG-2 %s is gated" % id, raw.has(id) and Probe.gated(id), str(raw.keys()))
		_t.check("WG-2 the authored palette clears the floor on " + id, raw[id] >= Probe.GAP, "%.1f" % raw[id])
	for ground in Probe.GROUND:
		_t.check("WG-2 the fill over %s is reported, not gated" % ground, raw.has("fill:hazard~" + ground) and not Probe.gated("fill:hazard~" + ground), ground)
	_t.near("WG-2 the floor is beacon_colour_test's", Probe.GAP, 20.0)

	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	GraphicsPreset.bind(env, sun, root)
	for tone in [Palette.HAZARD, Palette.AMBER]:
		var lit: Color = ThreatGrammar.bright(tone)
		_t.check("WG-3 threat_grammar's brightest %s stays LDR" % tone.to_html(false), maxf(lit.r, maxf(lit.g, lit.b)) <= 1.0, lit.to_html(false))
	for preset in GraphicsPreset.PRESETS:
		GraphicsPreset.apply(preset)
		_t.check("WG-3 %s: no bloom term lifts LDR marks" % preset, not env.glow_enabled or env.glow_bloom == 0.0, "bloom %.2f" % env.glow_bloom)
		_t.check("WG-3 %s: glow threshold sits above threat_grammar's unshaded marks" % preset,
			not env.glow_enabled or env.glow_hdr_threshold > 1.0, "threshold %.2f" % env.glow_hdr_threshold)
	GraphicsPreset.apply("high")
	for key in WorldGrade.BASE:
		var want = WorldGrade.BASE[key]
		# Environment stores floats at single precision.
		_t.check("WG-5 BASE %s matches the run's preset" % key, absf(env.get(key) - want) < 0.0001 if want is float else env.get(key) == want, "%s vs %s" % [env.get(key), want])
	sun.free()
	var preview := ClassPreview.new(ClassDef.all()[0])
	var page := Customize.new()
	var menus := {"class preview": preview._camera.environment, "customize bench": page._viewport.get_child(0).environment}
	for stage in menus:
		var menu: Environment = menus[stage]
		_t.check("WG-6 %s tonemaps with AgX" % stage, menu.tonemap_mode == Environment.TONE_MAPPER_AGX, str(menu.tonemap_mode))
		_t.near("WG-6 %s contrast is BASE's" % stage, menu.tonemap_agx_contrast, WorldGrade.BASE.tonemap_agx_contrast)
		_t.near("WG-6 %s saturation is the run's" % stage, menu.adjustment_saturation, WorldLook.ROWS[1].saturation)
	preview.free()
	page.free()


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
		for key in GRADE_KEYS:
			_t.check("WG-4 %s is an Environment field" % key, key in env, key)
		var before := _grade(env)
		_game.set_reduce_flashes(true)
		var on := _grade(env)
		_game.set_reduce_flashes(false)
		var after := _grade(env)
		for key in GRADE_KEYS:
			_t.check("WG-4 reduce flashes leaves %s alone" % key, before[key] == on[key] and on[key] == after[key], "%s / %s / %s" % [before[key], on[key], after[key]])
		quit(_t.verdict())
	return false
