extends SceneTree
# SCRATCH ONLY (PC lane job Z, 13 Nov 2026), not for any game branch.
# Crews standing on a measured 15 to 25 degree slope of the stage 1 park, for PR 954's slope tilt.
# Finds slope spots near the stage 1 launch by finite differences of terrain.height(), stands each
# kind there, lets it settle under ctx.calm, then shoots one frame from the game's own camera (ball
# 10 m behind the crew) and one close side view. slopes.json records the measured slope at the feet.
#   <godot> --path sketches/core-loop --script res://tools/slope_capture.gd -- --out=/abs/dir [--kinds=a,b]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const SIZE := Vector2i(1920, 1080)
const SLOPE_MIN := 15.0
const SLOPE_MAX := 25.0
const SPOTS_PER_KIND := 2

var game
var out := ""
var kinds: Array = ["mag_trapper", "jolt_layer"]
var records := []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _slope_deg(terrain, x: float, z: float) -> float:
	var dx: float = (terrain.height(x + 1.0, z) - terrain.height(x - 1.0, z)) / 2.0
	var dz: float = (terrain.height(x, z + 1.0) - terrain.height(x, z - 1.0)) / 2.0
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))


# Spots whose slope stays inside the band over a 2 m patch, nearest the launch first, 25 m apart.
func _find_spots(terrain, base: Vector3) -> Array:
	var found := []
	for r in range(12, 260, 4):
		for k in 64:
			var a := TAU * k / 64.0
			var x := base.x + cos(a) * r
			var z := base.z + sin(a) * r
			var ok := true
			for o in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var s := _slope_deg(terrain, x + o.x, z + o.y)
				if s < SLOPE_MIN or s > SLOPE_MAX:
					ok = false
					break
			if not ok:
				continue
			var far := true
			for f in found:
				if Vector2(f.x, f.z).distance_to(Vector2(x, z)) < 25.0:
					far = false
			if far:
				found.append(Vector3(x, terrain.height(x, z), z))
			if found.size() >= SPOTS_PER_KIND:
				return found
	return found


func _shot(path: String) -> void:
	for f in 8:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


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
	var terrain = game.ctx.terrain
	var base: Vector3 = terrain.drop_point(-65.0, -130.0, 0.0)
	var spots := _find_spots(terrain, base)
	var game_cam: Camera3D = root.get_viewport().get_camera_3d()
	var side := Camera3D.new()
	game.add_child(side)
	side.fov = 40.0
	for kind in kinds:
		for n in spots.size():
			var spot: Vector3 = spots[n]
			var at: Vector3 = terrain.drop_point(spot.x, spot.z, 1.2)
			var enemy = game.ctx.spawner.spawn_enemy(kind, at)
			# Downhill side of the spot, so the ball looks up the slope at the crew.
			var dx: float = terrain.height(spot.x + 1.0, spot.z) - terrain.height(spot.x - 1.0, spot.z)
			var dz: float = terrain.height(spot.x, spot.z + 1.0) - terrain.height(spot.x, spot.z - 1.0)
			var down := -Vector3(dx, 0, dz).normalized()
			if down.length() < 0.5:
				down = Vector3(0, 0, 1)
			game.player.reset_to(terrain.drop_point(spot.x + down.x * 10.0, spot.z + down.z * 10.0, 1.0))
			for i in 45:
				await physics_frame
			paused = true
			var feet: Vector3 = enemy.global_position
			var slope := _slope_deg(terrain, feet.x, feet.z)
			var gap: float = feet.y - terrain.height(feet.x, feet.z)
			var stem := "%s-%d" % [kind, n + 1]
			# Chase-camera framing: behind and above the ball, looking up the slope at the crew.
			var low := feet + down * 12.0
			var eye := Vector3(low.x, terrain.height(low.x, low.z) + 3.5, low.z)
			side.fov = 70.0
			side.look_at_from_position(eye, feet + Vector3.UP * 0.5)
			side.current = true
			await _shot(out.path_join(stem + "-game.png"))
			# Side view across the slope, low and back, framed on the feet.
			var centre := feet + Vector3.UP * 0.3
			var across := down.cross(Vector3.UP).normalized()
			side.fov = 40.0
			side.look_at_from_position(centre + across * 8.0 + Vector3.UP * 0.4, centre)
			side.current = true
			await _shot(out.path_join(stem + "-side.png"))
			records.append({"kind": kind, "spot": n + 1, "feet": [feet.x, feet.y, feet.z],
				"slope_deg": snappedf(slope, 0.1), "feet_above_ground_m": snappedf(gap, 0.01)})
			enemy.queue_free()
			paused = false
			await process_frame
	var file := FileAccess.open(out.path_join("slopes.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"band_deg": [SLOPE_MIN, SLOPE_MAX], "spots_found": spots.size(),
		"head": "be7abb45", "frames": records}, "\t"))
	quit()
