# smoke: solo timeout=180s
extends "res://tools/look_harness.gd"

# Exercise the actual capture group through its last step before drawing a frame.
const T := preload("res://tests/support/t.gd")
var _t := T.new("look_stations_test")
var _captures := 0
var _plant_alpha := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_t.check("station files load", Subjects.station_errors.is_empty(), str(Subjects.station_errors))
	for route in ["west_wash_run", "canal_run", "incline_line"]:
		_t.check("dam station %s is available" % route, Subjects.in_group("staged").has(route))

	var fixture := "user://station-plant"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	var file := FileAccess.open(fixture.path_join("duplicate.json"), FileAccess.WRITE)
	file.store_string('{"arb_bowl": {}}')
	file.close()
	var errors := Subjects.merge_stations(fixture, Subjects.SUBJECTS.duplicate())
	_t.check("duplicate built-in subject is refused", errors.size() == 1 and str(errors[0]).contains("duplicates subject arb_bowl"), str(errors))

	requested = ["west_wash_run", "incline_line"]
	await _staged()
	_t.eq("both independent stations reached capture", _captures, 2)
	_t.eq("both stations passed", failures, 0)
	_plant_alpha = true
	requested = ["west_wash_run"]
	await _staged()
	_t.eq("the same station on alpha fails before capture", failures, 1)
	_t.eq("the alpha frame cannot enter the proof", _captures, 2)
	game.free()
	quit(_t.verdict())


func _boot(warden := false, table := "alpha") -> void:
	await super._boot(warden, "alpha" if _plant_alpha else table)


func _shoot(subject: String, extra := {}) -> void:
	_captures += 1
	var row: Dictionary = Subjects.SUBJECTS[subject]
	_t.eq("capture reports the active park table", extra.table, "park")
	_t.eq("park definitions actually built the game", game.ctx.stages, Game.TABLES.park)
	_t.eq("physics tick matches the row", ticks, int(row.tick))
	var p: Vector3 = row.point
	p.y += game.ctx.terrain.height(p.x, p.z)
	var nearest := INF
	for actor in get_nodes_in_group("enemy"):
		if actor.get("kind") == "chaser":
			nearest = minf(nearest, actor.global_position.distance_to(p))
	_t.check("a real chaser stands within 0.5 m of the station", nearest <= 0.5, "%.3f m" % nearest)
	var b: Vector3 = row.ball_position
	b.y += game.ctx.terrain.height(b.x, b.z)
	var placed := _place_ball(subject, "rider", p, p)
	_t.check("the camera preserves the staged ball position", b.distance_to(placed.at) < 0.01)
	_t.check("the ball has the station velocity", game.player.body().linear_velocity.is_equal_approx(row.ball_velocity))
