extends SceneTree
# 2026-10-09 re-pin (VX-LIGHT): the Dig has its own world look row (world_look.gd ROWS[2], a dark
# dome), entered on the Dig stage before the pit, so leaving the pit restores the Dig's light,
# not stage 1's (measured: background, ambient, energy and saturation differ from stage 1).

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Palette := preload("res://src/core/palette.gd")
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
			_t.check("DK rim pool reaches floor without shadows", light.light_energy >= 1.399 and light.omni_range >= 30.0 and not light.shadow_enabled)
		for child in top.get_children():
			if child is MeshInstance3D:
				var mat := child.material_override as ShaderMaterial
				var seam = mat.get_shader_parameter("seam_width") if mat != null else null
				_t.check("DK floor panel seams are at least 0.10m", seam is float and seam >= 0.10)
				_t.check("DK floor uses sandstone", mat != null and mat.get_shader_parameter("base_color") == Palette.SANDSTONE)
		for preset in ["low", "high", "target"]:
			Preset.apply(preset)
			_t.check("DK pit lift survives " + preset, is_equal_approx(game.ctx.terrain.environment.ambient_light_energy, 0.16) and bounce.light_energy >= 3.0)
		mod._dropping = 1
		mod._drop_left = 0.0
		await physics_frame
		await process_frame
		_t.check("DK dropped floor removes its rim lights", pools.is_empty() or not is_instance_valid(pools[0]))
		if key != null:
			_t.near("DK key follows core after drop", key.global_position.distance_to(mod.warden.family_point_at() + Vector3(10, 18, 12)), 0.0, 0.01)
	mod.exit_arena()
	Preset.apply("high")
	Probe.check_lighting(_t, "DK exit restores world lighting", game, before)
	game.free()
	quit(_t.verdict())
