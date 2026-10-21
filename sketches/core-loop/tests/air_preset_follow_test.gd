extends SceneTree

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("air_preset_follow_test")

# L4: the world's volumetric air follows the preset's air flag when the preset changes inside a
# stage, the same as on stage entry (HIGH has air, LOW has none).


func _initialize() -> void:
	call_deferred("_run")


func _air(env: Environment, label: String, on: bool, density: float) -> void:
	_t.check(label + " volumetric fog " + ("on" if on else "off"), env.volumetric_fog_enabled == on,
		"enabled=%s" % env.volumetric_fog_enabled)
	if on:
		_t.check(label + " air density is the row's", is_equal_approx(env.volumetric_fog_density, density),
			"density=%s" % env.volumetric_fog_density)


func _run() -> void:
	var game = await Probe.boot(self)
	if not _t.check("game booted", game.flow != null):
		game.free()
		quit(_t.verdict())
		return
	var env: Environment = game.ctx.terrain.environment
	Preset.apply("high")
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await physics_frame
	var density: float = WorldLook.ROWS[1].air.volumetric_fog_density
	_air(env, "stage 1 on high", true, density)
	Preset.apply("low")
	_air(env, "stage 1 high to low", false, density)
	Preset.apply("high")
	_air(env, "stage 1 low to high", true, density)
	Preset.apply("low")
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	_air(env, "stage 2 entered on low", false, density)
	Preset.apply("high")
	var dig: float = WorldLook.row(game.ctx.stages.world_of(2)).air.get("volumetric_fog_density", 0.0)
	_air(env, "stage 2 low to high", true, dig)
	Harness.enter_world(game, 3)
	await physics_frame
	var mod = Harness.module(game, 3)
	if _t.check("Mind arena dressing attached", "_arena_dress" in mod and mod._arena_dress != null):
		_air(env, "Mind arena on high", false, 0.0)
		Preset.apply("low")
		_air(env, "Mind arena high to low", false, 0.0)
		Preset.apply("high")
		_air(env, "Mind arena low to high", false, 0.0)
		mod.exit_arena()
	Preset.apply("high")
	game.free()
	quit(_t.verdict())
