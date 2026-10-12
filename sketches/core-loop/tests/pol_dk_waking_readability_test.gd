extends SceneTree
# 2026-10-11 re-pin (W13-LIGHTS): dropped-floor rim lights return to the session-lived pool
# and stay dark across preset changes. Freeing them was the Forward+ exit/reentry crash path.
# 2026-10-09 re-pin (SWAP-FIX): the plate is pale zinc (ArenaWakingDress.FLOOR_PLATE_COLOR), not slate, because slate is
# the "not yet" state colour (palette.gd:25) and, at half sandstone's luminance, took arw_pit/down_shaft to 0.90 and
# arw_pit_b/pit_edge to 0.85 near-black (dead). The check now asks for a cool, non-state tone at least sandstone in every
# channel: #c4c9cb (red under sandstone's) left arw_pit lamps_wall 0.5513 and side_stack 0.6903 over base 0.5494 and 0.6900.
# 2026-10-09 re-pin (VX-SWAP): the pit floor plate is cool slate (Palette.SLATE), not sandstone, because the sandstone
# plate read amber-brown under the rim pools (LIGHT-FIX follow-up); weathered petrol was tried and took arw_pit_b
# over_shoulder to 0.81 near-black (dead), so the lighter cool tone stands.
# 2026-10-09 re-pin (LIGHT-FIX): the rim pool energy floor falls from 1.4 to 1.0 because the pit's amber
# floor accent swamped the cool walls at 2.2 (blind read, arw_pit_b over_shoulder); LIGHTS.rim_pool.energy is now 1.0.
# 2026-10-09 re-pin (VX-LIGHT): the Dig has its own world look row (world_look.gd ROWS[2], a dark
# dome), entered on the Dig stage before the pit, so leaving the pit restores the Dig's light,
# not stage 1's (measured: background, ambient, energy and saturation differ from stage 1).

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Palette := preload("res://src/core/palette.gd")
const Dress := preload("res://src/presentation/arena_waking_dress.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("pol_dk_waking_readability_test")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = await Probe.boot(self)
	game.flow.enter_stage(game.ctx.stages.last_of(2), Vector3.ZERO, false)
	var before := Probe.lighting(game)
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var dress = mod._arena_dress
	if _t.check("DK pit dressing attached", dress != null):
		_t.check("DK pit preserves dark ambient", is_equal_approx(game.ctx.terrain.environment.ambient_light_energy, 0.16))
		var bounce := dress.get_node("ReactorBounce") as OmniLight3D
		_t.check("DK core bounce reaches 3.0", bounce.light_energy >= 3.0)
		var key := dress.get_node_or_null("CoreKey") as SpotLight3D
		_t.check("DK warm core key exists", key != null and key.light_energy >= 2.5)
		var top: StaticBody3D = mod._floor_bodies[1]
		var pools := top.find_children("RimPool*", "OmniLight3D", true, false)
		_t.eq("DK top floor has four rim pools", pools.size(), 4)
		for light: OmniLight3D in pools:
			_t.check("DK rim pool reaches floor without shadows", light.light_energy >= 0.999 and light.omni_range >= 30.0 and not light.shadow_enabled)
		for child in top.get_children():
			if child is MeshInstance3D:
				var mat := child.material_override as ShaderMaterial
				var seam = mat.get_shader_parameter("seam_width") if mat != null else null
				_t.check("DK floor panel seams are at least 0.10m", seam is float and seam >= 0.10)
				_t.check("DK floor uses the dress's plate colour", mat != null and mat.get_shader_parameter("base_color") == Dress.FLOOR_PLATE_COLOR)
		var plate: Color = Dress.FLOOR_PLATE_COLOR
		_t.check("DK plate is cool (blue at or above red)", plate.b >= plate.r)
		_t.check("DK plate is no state colour", not [Palette.SLATE, Palette.ARC, Palette.AMBER, Palette.HAZARD].has(plate))
		# Per channel, because the harness counts a pixel near-black only when all three channels are under 24
		# (look_harness.gd frame_metrics): under the amber pools a plate with less red than sandstone goes black first.
		_t.check("DK plate is at least sandstone in every channel", plate.r >= Palette.SANDSTONE.r and plate.g >= Palette.SANDSTONE.g and plate.b >= Palette.SANDSTONE.b)
		for preset in ["low", "high", "target"]:
			Preset.apply(preset)
			_t.check("DK pit lift survives " + preset, is_equal_approx(game.ctx.terrain.environment.ambient_light_energy, 0.16) and bounce.light_energy >= 3.0)
		mod._dropping = 1
		mod._drop_left = 0.0
		await physics_frame
		await process_frame
		for light in pools:
			if _t.check("DK dropped floor preserves its rim light", is_instance_valid(light)):
				_t.check("DK dropped floor darkens its rim light", is_zero_approx(light.light_energy) and not light.visible)
		Preset.apply("low")
		for light in pools:
			if is_instance_valid(light):
				_t.check("DK preset change keeps dropped rim light dark", is_zero_approx(light.light_energy) and not light.visible)
		if key != null:
			_t.near("DK key follows core after drop", key.global_position.distance_to(mod.warden.family_point_at() + Vector3(10, 18, 12)), 0.0, 0.01)
	mod.exit_arena()
	Preset.apply("high")
	Probe.check_lighting(_t, "DK exit restores world lighting", game, before)
	game.free()
	quit(_t.verdict())
