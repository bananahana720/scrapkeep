extends SceneTree

# World 1 day-cycle rows (world 1 unit 12): every world 1 scene the sitting walks through (title,
# camp, dam, flume, Brindle's Slag Bowl) has a complete light row, the daylit ones carry a time of
# day and a sky grade, and the run's scenes walk the day forward: dawn dam, morning flume, noon bowl.
# Then the real fight entry: the bowl's arena row (noon's sun, its own gold) covers the flume's look on the arena slot and
# leaves with the arena. Evidence limit: headless values; the look is judged from rendered stills
# (tools/day_arc_capture.gd) and frame times on the 4080.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Palette := preload("res://src/core/palette.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

const LIGHT_KEYS := ["ambient", "energy", "sun_color", "sun_energy", "sun_rotation", "fill", "fill_color"]
const EXPECTED_CHECKS := 20
var _t := T.new("world1_day_rows_test")
var game


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_rows()
	await _fight()
	_t.eq("every check ran", _t.checks, EXPECTED_CHECKS)
	quit(_t.verdict())


func _complete(look: Dictionary) -> bool:
	return LIGHT_KEYS.all(func(key): return look.has(key))


func _rows() -> void:
	var dam := StageDefs.first_of(1)
	var flume := StageDefs.last_of(1)
	var scenes := {
		"camp": WorldLook.CAMP,
		"dam": WorldLook.stage_look(dam, 1, String(StageDefs.of(dam).get("map", ""))),
		"flume": WorldLook.stage_look(flume, 1, String(StageDefs.of(flume).get("map", ""))),
		"bowl": WorldLook.arena_look("brindle"),
	}
	_t.check("the title has its own complete row", LIGHT_KEYS.all(func(key): return key == "fill_color" or WorldLook.TITLE.has(key))
		and WorldLook.TITLE.fill_color is Color)
	for id in scenes:
		var look: Dictionary = scenes[id]
		_t.check(id + " has a complete light row", _complete(look), str(look.keys()))
		_t.check(id + " names a time of day and grades its sky", WorldLook.TIME_ORDER.has(look.get("time", ""))
			and look.get("sky") == "hdri" and not WorldLook.grade(look).is_empty() and not WorldLook.sky_rows(look).is_empty(), str(look.get("time")))
	_t.eq("the dam is dawn", scenes.dam.time, "dawn")
	_t.eq("the flume is morning", scenes.flume.time, "morning")
	_t.eq("the Slag Bowl is noon", scenes.bowl.time, "noon")
	var order := ["dam", "flume", "bowl"].map(func(id): return WorldLook.TIME_ORDER.find(scenes[id].time))
	_t.check("the run walks the day forward", order[0] < order[1] and order[1] < order[2], str(order))
	_t.check("the bowl's sun is the noon sun, higher than the flume's", scenes.bowl.sun_rotation == WorldLook.TIME_ROWS.noon.sun_rotation
		and -scenes.bowl.sun_rotation.x > -scenes.flume.sun_rotation.x)
	# The bowl's gold rides in its arena row; noon itself is world 2's open pit (parked, ruling at) and keeps its light.
	var pit := WorldLook.stage_look(3, 2, "park_pit")
	var noon: Dictionary = WorldLook.TIME_ROWS.noon
	_t.check("the park pit keeps the noon row's light", ["sun_color", "ambient", "fog_tint", "grade"].all(func(key): return pit[key] == noon[key])
		and noon.ambient == Color("dbe6ec") and noon.grade.horizon == Color("ffffff"), str(pit.ambient))
	_t.check("the camp's grade is warm at the horizon", (scenes.camp.grade.horizon as Color).r > (scenes.camp.grade.horizon as Color).b)


# The real fight entry through the spine's seam, and the arena's exit.
func _fight() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	await physics_frame
	var env: Environment = game.ctx.terrain.environment
	var material := Palette.hdri_sky().sky_material as ShaderMaterial
	var before_ambient := env.ambient_light_color
	var before_horizon = material.get_shader_parameter("horizon_tint")
	Harness.enter(game, Vector3(18, 0, 0))
	await physics_frame
	var bowl := WorldLook.arena_look("brindle")
	_t.check("the bowl enters", game.boss.arena != null)
	_t.check("the bowl's ambient is its arena row's", env.ambient_light_color.is_equal_approx(bowl.ambient)
		and is_equal_approx(env.ambient_light_energy, bowl.energy), str(env.ambient_light_color))
	_t.eq("the bowl's sky horizon is its arena row's", material.get_shader_parameter("horizon_tint"), bowl.grade.horizon)
	game.boss.exit_arena()
	await physics_frame
	_t.check("leaving the bowl restores the look it covered", env.ambient_light_color.is_equal_approx(before_ambient)
		and material.get_shader_parameter("horizon_tint") == before_horizon, str(env.ambient_light_color))
	game.free()
