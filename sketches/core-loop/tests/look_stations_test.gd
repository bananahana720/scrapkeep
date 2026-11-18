# smoke: solo timeout=180s
extends "res://tools/look_harness.gd"

# Inspect the actual capture group at its requested tick immediately after the spawn.
# The 0.5 m bound checks authored placement at capture, before the chaser moves.
const T := preload("res://tests/support/t.gd")
var _t := T.new("look_stations_test")
var _captures := 0
var _plant_alpha := false
var _ordinary_flume := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_t.eq("Mac embedded children select the backend before startup", child_display_args("macOS", "Embedded"),
		["--embedded", "--debug", "--skip-breakpoints", "--ignore-error-breaks", "--audio-driver", "Dummy", "--display-driver", "embedded"])
	_t.eq("a regular Mac child keeps its parent display", child_display_args("macOS", "macOS"), ["--display-driver", "macos"])
	_t.eq("a Linux child keeps its parent display", child_display_args("Linux", "X11"), ["--display-driver", "x11"])
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
	var scratch := DirAccess.open(fixture)
	_t.eq("duplicate fixture removed", scratch.remove("duplicate.json"), OK)
	_t.eq("fixture directory removed", DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture)), OK)

	requested = ["west_wash_run", "incline_line"]
	await _staged()
	_t.eq("both independent stations reached capture", _captures, 2)
	_t.eq("both stations passed", failures, 0)
	_plant_alpha = true
	requested = ["west_wash_run"]
	await _staged()
	_t.eq("the same station on alpha fails before capture", failures, 1)
	_t.eq("the alpha frame cannot enter the proof", _captures, 2)
	_plant_alpha = false
	var early: Dictionary = Subjects.SUBJECTS["west_wash_run"].duplicate(true)
	early.stage = 2
	early.tick = 0
	Subjects.SUBJECTS["too_early"] = early
	requested = ["too_early"]
	await _staged()
	_t.eq("a tick before the stage was ready fails", failures, 2)
	_t.eq("a late frame cannot stand in for tick zero", _captures, 2)
	Subjects.SUBJECTS.erase("too_early")

	requested = ["bowl_mast"]
	_ordinary_flume = true
	await _staged()
	_t.eq("ordinary flume at the old coordinates fails", failures, 3)
	_t.eq("ordinary flume cannot supply a mast frame", _captures, 2)
	_ordinary_flume = false
	await _staged()
	_t.eq("Brindle mast reaches capture", _captures, 3)
	_t.eq("the physical mast passes", failures, 3)
	game.free()
	quit(_t.verdict())


func _boot(warden := false, table := "alpha") -> void:
	await super._boot(warden, "alpha" if _plant_alpha else table)


func _enter_station_bowl() -> void:
	if _ordinary_flume:
		var row: Dictionary = Subjects.SUBJECTS.bowl_mast
		game.player.reset_to(row.ball_position, row.ball_velocity)
	else:
		super._enter_station_bowl()


func _shoot(subject: String, extra := {}) -> void:
	_captures += 1
	var row: Dictionary = Subjects.SUBJECTS[subject]
	_t.eq("capture reports the active park table", extra.table, "park")
	_t.eq("park definitions actually built the game", game.ctx.stages, Game.TABLES.park)
	_t.eq("physics tick matches the row", ticks, int(row.tick))
	if subject == "bowl_mast":
		_t.check("Brindle boss is active", game.flow.in_arena and game.flow.state == game.flow.BOSS)
		var arena: Node3D = game.ctx.boss.arena
		_t.check("measured mast body supplied the hit", extra.mast.collider.ends_with("/SlagBowl/Bowl"))
		_t.eq("the mast cylinder supplied the hit", extra.mast.shape_type, "CylinderShape3D")
		_t.check("mast has the measured angle", absf(extra.mast.angle_deg - 225.0) < 0.01)
		var entry := arena.global_position + Vector3(-22.6264, 1.5, -11.3137)
		var target := arena.global_position + Vector3(-19.091883, 9.0, -19.091883)
		var eye := entry - Vector3(1, 0, -1).normalized() * 6.0 + Vector3.UP * 3.0
		_t.check("ball is at the measured entry", game.player.ball_position().distance_to(entry) < 0.01)
		_t.check("ball has the measured velocity", game.player.body().linear_velocity.distance_to(Vector3(9.899495, 0, -9.899495)) < 0.001)
		_t.check("camera anchor matches the measured target", target.distance_to(_anchors.station.point) < 0.01)
		_t.check("numerical camera matches the probe", eye.distance_to(_anchors.mast_eye.point) < 0.01)
		var hit: Array = extra.mast.hit
		_t.check("ray hit matches the measured bite", Vector3(hit[0], hit[1], hit[2]).distance_to(arena.global_position + Vector3(-19.6351, 8.6857, -18.2523)) < 0.05)
		return
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
