# 2026-10-09 VX-FX: the burst is GPUParticles3D from fx_library (gravity lives on the process material); the lens shader strings now live in lamp_motion.gdshader; the Underlight is gone (no light, no glow puff).
# smoke: solo (the presentation CPU budget is measured here)
extends SceneTree

# Real Dig cover breaks through world._on_slammed. Cosmetic copies fall at the hole;
# the original cover parks immediately, and all one-shots expire. Boot is unchanged.
# This measures the host's CPU work, not GPU rendering or human feel.
const Palette := preload("res://src/core/palette.gd")
const Scenery := preload("res://src/presentation/dig_scenery.gd")
const Fx := preload("res://src/presentation/dig_fx.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

class DigGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/dig_table_defs.gd")

class BallProbe extends RefCounted:
	var at := Vector3.ZERO
	func shown_position() -> Vector3:
		return at

var t := T.new("dig_fx_test")

func _initialize() -> void:
	_run.call_deferred()

func _game() -> DigGame:
	var game := DigGame.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	return game

func _enter(game: DigGame) -> void:
	game.flow.press_start()
	game.flow.choose_class(0)
	var frames := 0
	while not game.flow.in_stage() and frames < 120:
		frames += 1
		await physics_frame
	t.check("Dig entered", game.flow.in_stage())

func _run() -> void:
	var before := Preset.current
	Preset.apply("high")
	var alpha := preload("res://src/game.gd").new()
	alpha.test_mode = true
	alpha.table = "alpha"
	root.add_child(alpha)
	while alpha.flow == null:
		await physics_frame
	t.check("alpha boot leaves Dig terrain unbuilt", not alpha.ctx.terrain.is_built(3) and not alpha.ctx.terrain.is_built(4))
	t.check("alpha boot creates no Dig effects", alpha.find_children("DigFx", "", true, false).is_empty())
	alpha.free()
	var game := await _game()
	t.check("boot creates no Dig scenery or effects", game.find_children("DigScenery", "", true, false).is_empty()
		and game.find_children("DigFx", "", true, false).is_empty())
	await _enter(game)
	var terrain = game.ctx.terrain
	var stage_root: Node3D = terrain.geometry_root(1)
	var fx = stage_root.get_node("DigScenery/DigFx")
	t.check("entry builds effects and no physics bodies", fx.available
		and fx.find_children("*", "CollisionObject3D", true, false).is_empty())
	t.check("lamp batches share the motion shader", not fx.lamp_views.is_empty()
		and fx.lamp_views.all(func(v): return v.material_override.shader == fx._shader))
	t.check("lamp lens shader uses white paint and emission", fx._shader.code.contains("lens ? vec3(0.94, 0.97, 0.96)")
		and fx._shader.code.contains("EMISSION = lens ? vec3(1.0) * 0.12"))
	var plate: Dictionary = terrain.map().breach_plates[0]
	var id: String = plate["id"]
	var centre: Vector2 = plate["rect"].get_center()
	var at := Vector3(centre.x, 13, centre.y)
	var cover: Node3D = stage_root.get_node("BreachPlate_" + id)
	var home: Vector3 = cover.get_meta("home")
	var signal_count := [0]
	game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "breach_opened":
			signal_count[0] += 1)
	game.world._on_slammed(at, 20, 1)
	t.eq("real break sends existing fact once", signal_count[0], 1)
	t.eq("cover still parks at exact old location", cover.position, home + Vector3.DOWN * terrain.map().SWAP_PARK)
	t.check("cover hidden and floor open immediately", not cover.visible
		and is_equal_approx(terrain.height(centre.x, centre.y), plate["drop_to"]))
	t.eq("one rupture copy spawned", fx.ruptures.size(), 1)
	t.eq("one self-contained debris and dust burst spawned", fx.bursts.size(), 1)
	if fx.ruptures.size() != 1 or fx.bursts.size() != 1:
		game.free()
		quit(t.verdict())
		return
	var rupture: Dictionary = fx.ruptures[0]
	var ghost: Node3D = rupture["node"]
	var burst: Node3D = fx.bursts[0]["node"]
	t.eq("three real GLB wedges animate", rupture["wedges"].size(), 3)
	t.check("copy remains at hole after cover parked", ghost.global_position.y > 11.9)
	t.check("mint ends at break and tabs hide", ghost.get_children().all(func(v):
		var muted: bool = v.get_instance_shader_parameter("state_tint") == Palette.SLATE if v.get_meta("wedge", false) else v.material_override.get_shader_parameter("spent") == true
		return muted and (not String(v.name).begins_with("tab_") or not v.visible)))
	t.check("burst uses the fx table's gravity and lifetime grammar", (burst.get_node("Debris").process_material as ParticleProcessMaterial).gravity.y == -26.0
		and burst.get_node("Dust").lifetime == 0.5 and burst.get_node("Debris").amount == 10)
	fx.freeze_rupture(0.18)
	t.check("wedges translate down and out at mid-rupture", rupture["wedges"].all(func(w):
		return (w["node"].position.y < w["rest"].origin.y - 1.7
			and Vector2(w["node"].position.x, w["node"].position.z).length()
			> Vector2(w["rest"].origin.x, w["rest"].origin.z).length())))
	t.check("wedges pitch around their outside pivots", rupture["wedges"].all(func(w):
		return not w["node"].basis.is_equal_approx(w["rest"].basis)))
	t.check("capture freeze stops particle clocks", burst.get_children().all(func(p): return p.speed_scale == 0))
	game.world._on_slammed(at, 20, 1)
	t.eq("repeat slam creates no second effect", fx.ruptures.size(), 1)
	fx._frozen = false
	for p in burst.get_children():
		p.speed_scale = 1.0
	# Let real process callbacks expire both transient nodes.
	for i in 180:
		await physics_frame
	t.check("rupture and burst free themselves", not is_instance_valid(ghost) and not is_instance_valid(burst)
		and fx.ruptures.is_empty() and fx.bursts.is_empty())
	t.eq("cover ends at its unchanged parked position", cover.position, home + Vector3.DOWN * terrain.map().SWAP_PARK)
	# A nearby cut face emits grit; no nearby faces stop it. No gameplay player moves.
	var probe := BallProbe.new()
	probe.at = fx.to_global(fx.faces[0])
	var player = fx._player
	fx._player = probe
	fx._nearby_grit()
	t.check("grit emits only near a cut face", fx.grit.any(func(p): return p.emitting))
	probe.at = Vector3.ZERO
	fx._nearby_grit()
	t.check("no grit in the playfield centre", fx.grit.all(func(p): return not p.emitting))
	probe.at = fx.to_global(fx.faces[0])
	fx._nearby_grit()
	var clock: float = fx._clock
	fx._process(0.1)
	t.check("high advances lamp motion", fx.lamp_views.all(func(v): return v.get_instance_shader_parameter("fx_time") > clock))
	Preset.apply("low")
	t.check("low disables ambient grit and sway", not fx._ambient and fx.grit.all(func(p): return not p.emitting)
		and fx.lamp_views.all(func(v): return not v.get_instance_shader_parameter("motion_enabled")))
	t.check("lamp animation creates no ambient fill light", stage_root.find_children("LampLight*", "OmniLight3D", true, false).is_empty())
	game.events.stage_entered.emit(1, true)
	game.world._on_slammed(at, 20, 1)
	t.eq("retry restores break presentation", fx.ruptures.size(), 1)
	if fx.bursts.size() > 0:
		t.check("low reduces debris", is_equal_approx(fx.bursts[0]["node"].get_node("Debris").amount_ratio * 10.0, 4.0))
	Preset.apply("target")
	t.check("target restores ambient motion", fx._ambient
		and fx.lamp_views.all(func(v): return v.get_instance_shader_parameter("motion_enabled")))
	fx.clear()
	Preset.apply("high")
	# Every sample scans nearby faces with grit active: the expensive host path, not an idle shortcut.
	probe.at = fx.to_global(fx.faces[0])
	fx._on_world_fact("breach_opened", at)
	var ticking := SimClock.ticks
	SimClock.ticks = false
	var samples: Array[float] = []
	for batch in 20:
		var start := SimClock.msec()
		for i in 300:
			fx._grit_wait = 0
			for row in fx.ruptures + fx.bursts:
				row["age"] = 0.0
			fx._process(1.0 / 60.0)
		samples.append((SimClock.msec() - start) / 300.0)
	SimClock.ticks = ticking
	samples.sort()
	var mean := 0.0
	for sample in samples:
		mean += sample / 20.0
	print("DigFx CPU host: mean %.3f ms, p95 batch %.3f ms, max batch %.3f ms; GPU unmeasured" % [mean, samples[18], samples[19]])
	t.check("host CPU below 0.3 ms per call in every batch", samples[19] <= 0.3)
	fx._player = player
	fx._on_stage_entered(99, false)
	t.check("inactive stage stops all ambient work", not fx.active and not fx.is_processing()
		and fx.grit.all(func(p): return not p.emitting))
	# 2026-10-23 (w18 gate, run_tier): a freed park stage leaves a few nodes a frame, so its lamp
	# views can go before this node. Freeing the stage lets go of the run's signals at once, and a
	# later entry or content clear never reaches the freed views.
	game.ctx.terrain.stage_freed.emit(1)
	fx.lamp_views[0].free()
	fx.grit[0].free()
	t.check("freed stage unhooks from the run's signals", not game.events.stage_entered.is_connected(fx._on_stage_entered)
		and not game.events.world_fact.is_connected(fx._on_world_fact)
		and not game.events.stage_content_cleared.is_connected(fx._on_content_cleared)
		and not game.ctx.terrain.stage_freed.is_connected(fx._on_stage_freed))
	fx._deactivate()
	t.check("a sync after the views go skips the freed nodes", fx.lamp_views.all(is_instance_valid) and fx.grit.all(is_instance_valid))
	game.free()

	# Missing shader: real break retains the old instant swap, one warning for the host.
	var path := Fx.lamp_shader_path
	Fx.lamp_shader_path = "res://assets/materials/dig_mechanical/missing_fx_shader.gdshader"
	game = await _game()
	await _enter(game)
	Fx.lamp_shader_path = path
	stage_root = game.ctx.terrain.geometry_root(1)
	fx = stage_root.get_node("DigScenery/DigFx")
	game.world._on_slammed(at, 20, 1)
	fx._on_world_fact("breach_opened", at)
	t.check("missing shader retains instant swap and no FX", not fx.available and fx.ruptures.is_empty()
		and fx.bursts.is_empty() and fx.grit.is_empty() and not stage_root.get_node("BreachPlate_" + id).visible)
	t.eq("missing shader warns once", fx.warning_count, 1)
	game.free()

	# Malformed/missing mesh after skin import must not crash or create partial effects.
	game = await _game()
	await _enter(game)
	stage_root = game.ctx.terrain.geometry_root(1)
	fx = stage_root.get_node("DigScenery/DigFx")
	cover = stage_root.get_node("BreachPlate_" + id)
	cover.get_node("BreachSkin").get_children().filter(func(n): return n.get_meta("wedge", false))[0].mesh = null
	game.world._on_slammed(at, 20, 1)
	fx._on_world_fact("breach_opened", at)
	t.check("missing wedge retains instant swap", fx.ruptures.is_empty() and fx.bursts.is_empty() and not cover.visible)
	t.eq("missing wedge warns once", fx.warning_count, 1)
	game.free()
	Preset.apply(before)
	var builder := Scenery.new()
	t.check("missing material slot returns a safe fallback", builder._slot_material("") == null)
	builder._slot_material("")
	t.eq("missing material slot warns once", builder._warnings.size(), 1)
	quit(t.verdict())
