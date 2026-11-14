extends "res://tests/work_machines_test.gd"

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

# Receipts for the looping workers (work_machines.gd, BACKLOG W1-93): for each machine in a park, a
# still and a clip from where a pilot sees it: a pilot line point 60 to 140 m out, nearest 90 m, whose
# sight of the machine is clear over the baked ground and the scatter props (the test's own judge;
# props have no colliders, so a physics ray misses them). Needs a rendered display (on a GPU-less box, xvfb):
#
#   $GODOT_BIN --fixed-fps 15 --path sketches/core-loop --script res://tools/work_machines_capture.gd \
#     -- --out=<absolute dir> [--park=park_dam] [--id=<row id>] [--seconds=20] [--near=1]
#
# --near=1 adds a second clip from the nearest line point with a clear sight, the closest a pilot
# gets a whole view. Writes
# <out>/<park>_<id>[_near]/{still.png, frame_####.png, works_<park>_<id>.mp4}.

const FPS := 15.0
const SIZE := Vector2i(1280, 720)
const CAM_EYE_M := 7.0
const SETTLE_S := 2.0

var _out := ""
var _park := "park_dam"
var _id := ""
var _seconds := 20.0
var _near := false
var _game
var _cam: Camera3D
var _fails := 0
var _heights: PackedFloat32Array


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if DisplayServer.get_name() == "headless" or not settings.has("out"):
		printerr("work_machines_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	_park = settings.get("park", "park_dam")
	_id = settings.get("id", "")
	_seconds = maxf(float(settings.get("seconds", "20")), 2.0)
	_near = settings.get("near", "0") == "1"
	if not ParkSchema.MAP_STAGE.has(_park):
		printerr("work_machines_capture: unknown park ", _park)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _main() -> void:
	seed(93)
	GraphicsPreset.apply("high")
	_game = Game.new()
	_game.name = "Game"
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await process_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	for i in 60:
		await process_frame
	var stage: int = ParkSchema.MAP_STAGE[_park]
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	var works = null
	for i in 900:
		await process_frame
		works = _game.presentation.work_machines
		if _game.ctx.terrain.is_ready(stage) and works != null and not works.machines.is_empty() and works.map_id == _park and _game.flow.in_play():
			break
	if works == null or works.machines.is_empty() or works.map_id != _park:
		printerr("work_machines_capture: no machines built for %s" % _park)
		quit(1)
		return
	_cam = Camera3D.new()
	_cam.far = 1800.0
	_cam.near = 0.1
	_cam.fov = 55.0
	_game.add_child(_cam)
	_cam.make_current()
	_game.player.set_frozen(true)
	_game.presentation.hide_ui()
	var lines := _ride_lines()
	var map := ParkMap.new("res://src/world/park/%s.json" % _park)
	_heights = ParkTerrain._read_zstd(ParkTerrain.bake_dir(_park) + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	_scatter = _scatter_of(_park, map, _heights)
	for m in works.machines:
		if not _id.is_empty() and m.row.id != _id:
			continue
		await _shoot(m, "%s_%s" % [_park, m.row.id], _vantage(m, lines, 60.0, 140.0, 90.0))
		if _near:
			await _shoot(m, "%s_%s_near" % [_park, m.row.id], _vantage(m, lines, 0.0, 140.0, 0.0))
	quit(_fails)


func _gh(x: float, z: float) -> float:
	return _game.ctx.terrain.height(x, z)


func _ride_lines() -> Array:
	var director = _game.world.get("events") if _game.get("world") != null else null
	if director != null and director.get("_park_pilot_lines") != null and not director._park_pilot_lines.is_empty():
		return director._park_pilot_lines
	printerr("work_machines_capture: no pilot lines; shooting from the drop-in")
	return []


# The point of a pilot line between near_m and far_m from the machine, closest to want_m, whose sight of
# the machine is clear; the nearest line point when none is.
func _vantage(m: Dictionary, lines: Array, near_m: float, far_m: float, want_m: float) -> Vector2:
	var at: Vector2 = m.row.at
	var target := Vector3(at.x, Terrain._grid_height(_heights, at.x, at.y) + MID_M, at.y)
	var props := _scatter.filter(func(prop): return Vector2(prop.pos.x, prop.pos.z).distance_to(at) < far_m + 10.0)
	var best := Vector2.INF
	var best_score := INF
	for points in lines:
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var n := maxi(1, int(a.distance_to(b) / 5.0))
			for k in n:
				var q := a.lerp(b, float(k) / n)
				var d := q.distance_to(at)
				if d < near_m or d > far_m or absf(d - want_m) >= best_score:
					continue
				var eye := Vector3(q.x, Terrain._grid_height(_heights, q.x, q.y) + CAM_EYE_M, q.y)
				if _sight_clear(eye, target, _heights, props):
					best_score = absf(d - want_m)
					best = q
	if best != Vector2.INF:
		return best
	printerr("work_machines_capture: no clear vantage for %s" % m.row.id)
	return _nearest(at, lines)


func _nearest(at: Vector2, lines: Array) -> Vector2:
	var best := at + Vector2(0.0, 80.0)
	var best_d := INF
	for points in lines:
		for i in points.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1])
			if at.distance_to(q) < best_d:
				best_d = at.distance_to(q)
				best = q
	return best


func _shoot(m: Dictionary, tag: String, eye2: Vector2) -> void:
	var dir_out := _out.path_join(tag)
	DirAccess.make_dir_recursive_absolute(dir_out)
	for f in DirAccess.get_files_at(dir_out):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(dir_out.path_join(f))
	var base: Vector3 = m.root.global_position
	var eye := Vector3(eye2.x, _gh(eye2.x, eye2.y) + CAM_EYE_M, eye2.y)
	var ball := Vector3(eye2.x, _gh(eye2.x, eye2.y) + 1.2, eye2.y)
	_game.player.body().global_position = ball
	_game.player.body().linear_velocity = Vector3.ZERO
	_cam.global_position = eye
	_cam.look_at(base + Vector3(0.0, 12.0, 0.0), Vector3.UP)
	for i in int(SETTLE_S * FPS):
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_viewport().get_texture().get_image().save_png(dir_out.path_join("still.png"))
	var frames := int(_seconds * FPS)
	for i in frames:
		await RenderingServer.frame_post_draw
		get_root().get_viewport().get_texture().get_image().save_png(dir_out.path_join("frame_%04d.png" % i))
		await process_frame
	var mp4 := dir_out.path_join("works_%s.mp4" % tag)
	var log := []
	var rc := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "15", "-i", dir_out.path_join("frame_%04d.png"),
		"-pix_fmt", "yuv420p", "-vf", "scale=1280:-2", mp4], log, true)
	print("WORKS_CAPTURE %s eye=%s base=%s dist=%.0f m frames=%d mp4_rc=%d" % [tag, eye, base, Vector2(eye.x, eye.z).distance_to(Vector2(base.x, base.z)), frames, rc])
	if rc != 0:
		_fails += 1
