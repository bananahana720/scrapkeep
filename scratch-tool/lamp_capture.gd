extends SceneTree
# SCRATCH ONLY (PC lane job AE, 13 Nov 2026), not for any game branch.
# PR 966 crew lamps: per kind, one colour still at rest and one mid-wind-up from a chase-height camera
# 12 m out (play size), plus close shots. The tree is paused; the lamp field runs always.
#   <godot> --path sketches/core-loop --script res://tools/lamp_capture.gd -- --out=/abs/dir [--kinds=a,b] [--close=hooker]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const SIZE := Vector2i(1920, 1080)
const WIND := 0.75

var game
var out := ""
var kinds: Array = ["mag_trapper", "hooker", "jolt_layer", "catch_trap", "plated_brute", "ramp_flipper",
	"bola_thrower", "netcaster", "deflector", "gyro_jammer", "swatter", "winch_drone"]
var close: Array = ["hooker"]
var records := []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
		elif arg.begins_with("--close="):
			close = Array(arg.trim_prefix("--close=").split(","))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _shot(path: String) -> void:
	for f in 8:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _set_wind(enemy, share: float) -> void:
	if "phase" in enemy and "warn_seconds" in enemy:
		if share <= 0.0:
			enemy.phase = 0
			enemy._t = 0.0
		else:
			enemy.phase = 1
			enemy._t = enemy.warn_seconds * share
		enemy._pose()
	var eye = enemy.get("_eye")
	if eye != null:
		eye.watch(10.0, share)


func _run() -> void:
	seed(280928)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 60:
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	var cam := Camera3D.new()
	game.add_child(cam)
	var terrain = game.ctx.terrain
	var base: Vector3 = terrain.drop_point(-65.0, -130.0, 0.0)
	var toward := Vector3(0, 0, -1)
	for i in kinds.size():
		var kind: String = kinds[i]
		var at: Vector3 = terrain.drop_point(base.x + i * 14.0, base.z, 1.2)
		var enemy = game.ctx.spawner.spawn_enemy(kind, at)
		game.player.reset_to(terrain.drop_point(at.x + toward.x * 12.0, at.z + toward.z * 12.0, 1.0))
		for f in 60:
			await physics_frame
		paused = true
		var feet: Vector3 = enemy.global_position
		var low := feet + toward * 12.0
		var eye_at := Vector3(low.x, terrain.height(low.x, low.z) + 3.5, low.z)
		var near_at := feet + toward * 3.0 + Vector3.UP * 1.4
		var has_eye: bool = enemy.get("_eye") != null
		for share in [0.0, WIND]:
			_set_wind(enemy, share)
			var tag := "rest" if share == 0.0 else "windup"
			cam.fov = 70.0
			cam.look_at_from_position(eye_at, feet + Vector3.UP * 0.8)
			cam.current = true
			await _shot(out.path_join("%s-%s.png" % [kind, tag]))
			var energy: float = enemy._eye.energy() if has_eye else -1.0
			records.append({"kind": kind, "shot": tag, "camera_m": 12, "lamp": has_eye, "energy": snappedf(energy, 0.01)})
			if kind in close:
				cam.fov = 40.0
				cam.look_at_from_position(near_at, feet + Vector3.UP * 1.0)
				cam.current = true
				await _shot(out.path_join("%s-%s-close.png" % [kind, tag]))
				records.append({"kind": kind, "shot": tag + "-close", "camera_m": 3, "lamp": has_eye, "energy": snappedf(energy, 0.01)})
		enemy.queue_free()
		paused = false
		await process_frame
	var file := FileAccess.open(out.path_join("lamps.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"wind_share": WIND, "frames": records}, "\t"))
	quit()
