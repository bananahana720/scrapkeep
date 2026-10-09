extends SceneTree
# Wave 12 capture port of the w7 driver (P-ADDON). Boots the real Game on table alpha, renders the
# P-GROUND cameras with eyes and targets identical to w7_capture.gd, and writes
# <out>/<camera>.png + frames.json. --ground=addon hides the native ground view (its collider stays)
# and shows the Terrain3D region plus the Proton Scatter layer from terrain3d_bridge.gd.
#   godot --path sketches/core-loop --script res://tools/w12_capture.gd -- --out=<dir> [--ground=addon|native] [--far]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Bridge := preload("res://src/world/terrain3d_bridge.gd")
var out := ""
var ground := "addon"
var far := false
var game
var cam: Camera3D
var failures := 0
var recs: Array = []
var probe: Node3D
var scatter: Node3D

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--ground="): ground = a.trim_prefix("--ground=")
		elif a == "--far": far = true
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs native display and --out"); quit(2); return
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n: await physics_frame

func _boot() -> void:
	seed(280928)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null: await physics_frame
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	cam = Camera3D.new()
	cam.far = 1800.0
	cam.near = 0.05
	game.add_child(cam)
	await _frames(60)

func _enter(stage: int) -> void:
	if stage != game.ctx.terrain.stage:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(40)
	game.player.body().freeze = true
	if probe != null:
		probe.queue_free()
		probe = null
	if ground != "addon":
		return
	var holder: Node3D = game.ctx.terrain.geometry_root(stage)
	var view := Bridge.native_ground_view(holder)
	if view != null: view.visible = false
	else:
		failures += 1; printerr("no native ground view on stage ", stage)
	var t0 := Time.get_ticks_msec()
	probe = Bridge.build_terrain(game, game.ctx.terrain.map_for(stage))
	print("terrain3d stage ", stage, " built ", probe != null, " in ", Time.get_ticks_msec() - t0, " ms")
	if probe == null: failures += 1
	scatter = Bridge.build_scatter(holder, Bridge.LAYERS[0], 0.0)
	if scatter == null:
		failures += 1; return
	for i in 600:
		await process_frame
		if scatter.output_root != null and scatter.output_root.get_child_count() > 0: break
	var n := 0
	if scatter.transforms != null: n = scatter.transforms.size()
	print("scatter stage ", stage, " instances ", n, " after ", Time.get_ticks_msec() - t0, " ms")
	if n == 0: failures += 1

# shots: Array of [camera id, eye, target, fov]
func _snap(shots: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	paused = true
	for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
	for l in root.find_children("*", "Label3D", true, false): l.visible = false
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = s[3]
		cam.current = true
		for i in 12: await RenderingServer.frame_post_draw
		var png := out.path_join(s[0] + ".png")
		root.get_texture().get_image().save_png(png)
		recs.append({"id": s[0], "eye": [s[1].x, s[1].y, s[1].z], "target": [s[2].x, s[2].y, s[2].z], "fov": s[3], "sha256": FileAccess.get_sha256(png)})
		print("snap ", s[0])
	paused = false

func _gh(x: float, z: float) -> float:
	return game.ctx.terrain.height(x, z)

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree(): continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _run() -> void:
	await _boot()
	await _enter(1)
	var b: Vector3 = game.player.ball_position()
	await _snap([
		["wog_spillway__spawn_wide", b + Vector3(-40, 28, -50), b + Vector3(10, 0, 30), 65.0],
		["wog_spillway__benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0]])
	var offers: Array = []
	for slot in game.ctx.terrain.map().gate_slots:
		var sa: Vector2 = slot["at"]
		offers.append({"at": Vector3(sa.x, _gh(sa.x, sa.y), sa.y), "facing": slot["facing"], "width": 8.0})
	var docked: bool = game.world.bay.dock(offers, Callable(game.ctx.terrain, "height"), null)
	await _frames(40)
	var box := _aabb(game.world.bay)
	var bc := box.get_center()
	var r := maxf(box.size.x, box.size.z) * 0.8 + 6.0
	print("bay docked ", docked, " aabb ", box)
	await _snap([["cv2_camp_bay__three_q", bc + Vector3(r * 0.7, r * 0.45, -r * 0.7), bc, 60.0]])
	if far and probe != null:
		var imgs := Bridge.sample_images(game.ctx.terrain.map_for(1))
		probe.data.import_images([imgs[0], null, imgs[1]], Vector3(1024, 0, -256), 0.0, 1.0)
		await _frames(10)
		print("far regions ", probe.data.get_region_locations())
		await _snap([["far_region_tiles", Vector3(640, 420, 520), Vector3(640, 0, 0), 60.0]])
	await _enter(3)
	var sc = game.find_child("Scrap", true, false)
	var items: Array = sc.get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	if items.is_empty():
		failures += 1; printerr("no dig scrap")
	else:
		var q2: Vector3 = items[0].global_position
		await _snap([["scr_dig__close", q2 + Vector3(2.4, 1.6, -3), q2, 45.0], ["scr_dig__cluster", q2 + Vector3(0, 6, -10), q2 + Vector3(0, -0.5, 4), 55.0]])
	await _enter(5)
	await _snap([["hdr_island_bridge__island_bridge", Vector3(0, 40, 150), Vector3(0, 26, 100), 60.0]])
	var doc := {"tool": "w12_capture.gd", "ground": ground, "adapter": RenderingServer.get_video_adapter_name(), "frames": recs}
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	print("done failures=", failures)
	quit(failures)
