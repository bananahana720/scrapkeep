extends SceneTree
# SCRATCH ONLY (PC lane job BF, 14 Nov 2026): never for the repo's tests or a game branch.
# PR 917 stills on the dam: (1) cogs and dropped panels on the ground at the play camera's distance;
# (2) a cable drum seen from 80 m and 100 m, once at the play camera's field of view and once through a
# narrow lens, so the far meshes (lod1/lod2) can be checked for faces drawn inside out.
#   gamescope ... -- <godot> --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 \
#     --script res://tools/bf_stills.gd -- --out=<abs dir>
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SIZE := Vector2i(1920, 1080)

var out := ""
var game

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _save(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("STILL ", name)

func _hide_ui() -> void:
	if game.get("presentation") != null:
		game.presentation.hide_ui()
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false

# World positions of the cable drums: from the per-kind MultiMesh batches (name starts with the kind), the hero
# views (kind_N_Lk) and the merged far view's member lists (dress_member_kinds / dress_member_pos).
func _drums() -> Array:
	var found := []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var name := String(n.name).to_lower()
		if n is MultiMeshInstance3D and name.begins_with("cable_drum") and (n as MultiMeshInstance3D).multimesh != null:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				found.append((n as Node3D).global_transform * mm.get_instance_transform(i).origin)
		elif n is MeshInstance3D and name.begins_with("cable_drum"):
			found.append((n as Node3D).global_position)
		elif n.has_meta("dress_member_kinds") and n.has_meta("dress_member_pos"):
			var kinds: Array = n.get_meta("dress_member_kinds")
			var pos: Array = n.get_meta("dress_member_pos")
			for i in mini(kinds.size(), pos.size()):
				if String(kinds[i]).begins_with("cable_drum"):
					var p = pos[i]
					found.append((n as Node3D).global_transform * (p if p is Vector3 else Vector3(p[0], p[1], p[2])))
	var unique := []
	for p in found:
		if not unique.any(func(q): return (q as Vector3).distance_to(p) < 1.0):
			unique.append(p)
	return unique

func _run() -> void:
	seed(1)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	for i in 600:
		await process_frame
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 200:
			break
	game.ctx.calm = true
	_hide_ui()
	# (1) Cogs and panels ahead of the ball, at the play camera's own distance.
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var ball: Vector3 = game.player.ball_position()
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var scrap = game.ctx.build.scrap
	var ground := func(p: Vector3) -> Vector3: return Vector3(p.x, game.ctx.terrain.height(p.x, p.z), p.z)
	scrap.drop_cogs(ground.call(ball + fwd * 7.0 - side * 2.5), 6)
	scrap.drop_panel(ground.call(ball + fwd * 9.0 + side * 2.5), "fin_plate")
	var Panels = load("res://src/build/panels.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var drawn: String = Panels.draw(rng, game.run.class_id())
	scrap.drop_panel(ground.call(ball + fwd * 12.0 - side * 1.0), drawn)
	print("STILL panels fin_plate and ", drawn, " ball ", ball)
	# Hold the ball where it stood and the magnet off, so the drops stay on the ground where they landed.
	var hold: Vector3 = game.ctx.terrain.drop_point(ball.x, ball.z, 1.0)
	for i in 120:
		scrap.magnet_scale = 0.0
		game.player.reset_to(hold, Vector3.ZERO)
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	print("STILL cogs on the ground ", scrap.count() if scrap.has_method("count") else -1)
	scrap.magnet_scale = 0.0
	await _save("pickups-play")
	# A lower camera behind the ball, a little closer, for the colour of the cog and the plate.
	var low := Camera3D.new()
	low.fov = 50.0
	root.add_child(low)
	low.global_position = ball - fwd * 2.0 + Vector3.UP * 2.2
	low.look_at(ball + fwd * 9.0, Vector3.UP)
	low.make_current()
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(low)
	await _save("pickups-near")
	# (2) Cable drums from 80 m and 100 m.
	var drums := _drums()
	print("STILL drums found ", drums.size())
	if drums.is_empty():
		quit(0)
		return
	# --bf-cameras: aim from BF's ball spot at BF's two drums, so the shots match BF's cameras exactly.
	if OS.get_cmdline_user_args().has("--bf-cameras"):
		ball = Vector3(-129.8724, 139.6478, -617.4695)
		var fixed: Array = []
		for want in [Vector2(-133.0, -568.0), Vector2(-62.0, -612.0)]:
			for d in drums:
				if Vector2((d as Vector3).x, (d as Vector3).z).distance_to(want) < 0.5:
					fixed.append(d)
					break
		print("STILL bf-cameras drums matched ", fixed.size())
		drums = fixed
	else:
		drums.sort_custom(func(a, b): return (a as Vector3).distance_to(ball) < (b as Vector3).distance_to(ball))
	var shots := 0
	for d in drums:
		if shots >= 2:
			break
		var at: Vector3 = d
		var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
		if away.length() < 1.0:
			away = Vector3.BACK
		away = away.normalized()
		var tag := "drum%d" % shots
		print("STILL ", tag, " at ", at, " ", snappedf(at.distance_to(ball), 0.1), " m from the ball")
		for dist in [80.0, 100.0]:
			var from: Vector3 = at + away * float(dist)
			from.y = game.ctx.terrain.height(from.x, from.z) + 4.0
			var c := Camera3D.new()
			root.add_child(c)
			c.global_position = from
			c.look_at(at + Vector3.UP * 1.0, Vector3.UP)
			c.make_current()
			for t in root.find_children("*", "Terrain3D", true, false):
				t.set_camera(c)
			c.fov = 70.0
			for i in 30:
				await process_frame
			await _save("%s-%dm-play" % [tag, int(dist)])
			c.fov = 6.0
			await _save("%s-%dm-zoom" % [tag, int(dist)])
			c.queue_free()
		shots += 1
	quit(0)
