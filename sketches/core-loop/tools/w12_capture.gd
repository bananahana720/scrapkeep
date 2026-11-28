extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AppShell := preload("res://src/core/app_shell.gd")
var out := ""
var scene := ""
var class_index := 1
var seam := false
var game
var cam: Camera3D
var failures := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
		elif a == "--seam":
			seam = true
		elif a.begins_with("--class="):
			class_index = int(a.trim_prefix("--class="))
	if AppShell.headless() or out == "" or scene == "":
		printerr("needs native display, --out, --scene")
		quit(2)
		return
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _boot(warden: bool) -> void:
	seed(280928)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = warden
	game.flow.press_start()
	game.flow.choose_class(class_index)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	cam = Camera3D.new()
	cam.far = 1800.0
	cam.near = 0.05
	game.add_child(cam)


func _snap(subject: String, shots: Array, extra := {}, ui := false) -> void:
	var dir := out.path_join(subject)
	DirAccess.make_dir_recursive_absolute(dir)
	var was_paused := paused
	if not ui:
		paused = true
		for n in root.find_children("*", "CanvasLayer", true, false):
			n.visible = false
		for l in root.find_children("*", "Label3D", true, false):
			l.visible = false
	var recs: Array = []
	for s in shots:
		if not ui:
			cam.global_position = s[1]
			cam.look_at(s[2], Vector3.UP)
			cam.fov = s[3]
			cam.current = true
		for i in 12:
			await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var png := dir.path_join(s[0] + ".png")
		img.save_png(png)
		recs.append({"id": s[0], "eye": [s[1].x, s[1].y, s[1].z], "target": [s[2].x, s[2].y, s[2].z], "fov": s[3], "file": s[0] + ".png", "sha256": FileAccess.get_sha256(png)})
	var doc := {"tool": "w12_capture.gd", "scene": scene, "subject": subject, "class": class_index, "mode": "lit", "adapter": RenderingServer.get_video_adapter_name(), "extra": extra, "frames": recs}
	var f := FileAccess.open(dir.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	if not ui:
		paused = was_paused
	print("snap ", subject, " ", recs.size())


func _gh(x: float, z: float) -> float:
	return game.ctx.terrain.height(x, z)


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _boot_play(stage := 1, warden := false) -> void:
	await _boot(warden)
	await _frames(60)
	if stage != 1:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(40)


func _run() -> void:
	match scene:
		"wog":
			await _wog()
		"cache":
			await _cache()
		"pylon":
			await _pylon()
		"bay":
			await _bay()
		"dig":
			await _dig()
		"hdr":
			await _hdr()
		"ending":
			await _ending()
		_:
			printerr("unknown scene ", scene)
			quit(2)
			return
	print("done failures=", failures)
	quit(failures)


func _route_mesas() -> void:
	var Palette := preload("res://src/core/palette.gd")
	var strata := Palette.look_texture("sandstone-strata")
	var routed: Array[String] = []
	for view in root.find_children("*", "MeshInstance3D", true, false):
		var mat := (view as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null and mat.albedo_texture == strata:
			(view as MeshInstance3D).material_override = Palette.rock_material()
			routed.append(String(view.name))
	print("seam routed ", routed)
	for view in root.find_children("*", "MeshInstance3D", true, false):
		var m := (view as MeshInstance3D).material_override
		if m != null and (view as MeshInstance3D).get_aabb().size.length() > 60.0:
			print("big ", view.name, " ", m.get_class(), " ", (m as ShaderMaterial).shader.resource_path if m is ShaderMaterial else "", " ", (view as MeshInstance3D).get_aabb().size)


func _wog() -> void:
	await _boot_play(1)
	if seam:
		_route_mesas()
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	await _snap("wog_spillway", [["spawn_wide", b + Vector3(-40, 28, -50), b + Vector3(10, 0, 30), 65.0], ["benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0]], {"ball": [b.x, b.y, b.z]})


func _cache() -> void:
	await _boot_play(2)
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	var Cache := preload("res://src/world/cracked_cache.gd")
	var Bet := preload("res://src/world/bet_crate.gd")
	var Altar := preload("res://src/world/ambush_altar.gd")
	var made := {}
	var i := 0
	for row in [["cache", Cache], ["bet", Bet], ["altar", Altar]]:
		var d = row[1].new()
		game.add_child(d)
		var x: float = b.x - 14 + i * 14
		var z: float = b.z + 26
		d.global_position = Vector3(x, _gh(x, z), z)
		d.setup(game.ctx, game.world.interact, {"id": "w7_" + row[0]})
		made[row[0]] = d
		i += 1
	await _frames(30)
	var c: Vector3 = (made["cache"] as Node3D).global_position + Vector3(0, 1.4, 0)
	await _snap("gpd_cache", [["three_q", c + Vector3(7, 3, -6), c, 50.0]], {"pos": [c.x, c.y, c.z], "stage": 2})


func _pylon() -> void:
	await _boot_play(1)
	game.player.body().freeze = true
	var st1 = game.ctx.terrain.geometry_root(1)
	var walls := []
	for body in st1.find_children("*", "StaticBody3D", true, false):
		for m in body.get_children():
			if m is MeshInstance3D and m.mesh is BoxMesh and absf(m.mesh.size.z - 1.6) < 0.01 and m.mesh.size.y >= 4.0:
				walls.append(body)
	print("spillway walls ", walls.size())
	if walls.is_empty():
		failures += 1
		return
	var w: Node3D = walls[0]
	var wc: Vector3 = w.global_position + Vector3(0, 3, 0)
	await _snap("gpw_pylon_spillway", [["face", wc + w.global_basis * Vector3(0, 1, -14), wc, 55.0], ["three_q", wc + w.global_basis * Vector3(10, 3, -11), wc, 55.0]], {"walls": walls.size()})


func _bay() -> void:
	await _boot_play(1)
	game.player.body().freeze = true
	var offers: Array = []
	for slot in game.ctx.terrain.map().gate_slots:
		var sa: Vector2 = slot["at"]
		offers.append({"at": Vector3(sa.x, _gh(sa.x, sa.y), sa.y), "facing": slot["facing"], "width": 8.0})
	var docked: bool = game.world.bay.dock(offers, Callable(game.ctx.terrain, "height"), null)
	print("bay docked ", docked)
	await _frames(40)
	var box := _aabb(game.world.bay)
	var bc := box.get_center()
	var r := maxf(box.size.x, box.size.z) * 0.8 + 6.0
	await _snap("cv2_camp_bay", [["three_q", bc + Vector3(r * 0.7, r * 0.45, -r * 0.7), bc, 60.0]], {"docked": docked, "aabb": [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]})


func _dig() -> void:
	await _boot_play(3)
	game.player.body().freeze = true
	var sc = game.find_child("Scrap", true, false)
	var items: Array = sc.get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	var q2: Vector3 = items[0].global_position
	await _snap("scr_dig", [["cluster", q2 + Vector3(0, 6, -10), q2 + Vector3(0, -0.5, 4), 55.0], ["close", q2 + Vector3(2.4, 1.6, -3), q2, 45.0]], {"scrap_count": items.size()})


func _hdr() -> void:
	await _boot_play(5)
	game.player.body().freeze = true
	await _snap("hdr_island_bridge", [["island_bridge", Vector3(0, 40, 150), Vector3(0, 26, 100), 60.0]])


func _ending() -> void:
	var StageDefs := preload("res://src/core/stage_defs.gd")
	seed(280928)
	game = Game.new()
	game.test_mode = true
	game.table = "default"
	var folder := "user://ending-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	game.run_store_path = folder.path_join("run.json")
	root.add_child(game)
	await _frames(5)
	game.bot_driven = false
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(3)
	for world in StageDefs.worlds():
		game.flow.enter_stage(StageDefs.first_of(world), Vector3.ZERO, false)
	game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	await _frames(3)
	game.flow._set_state(game.flow.BOSS)
	game.events.boss_defeated.emit()
	game.flow.physics_step(game.flow.VICTORY_SECONDS + 0.01)
	var seq = game.screens.ending_sequence
	if not (is_instance_valid(seq) and seq.active):
		printerr("ending did not start")
		failures += 1
		return
	seq.set_process(false)
	seq.advance(1.0 - seq.elapsed)
	await RenderingServer.frame_post_draw
	await _snap("end_spillway_establish", [["frame", Vector3.ZERO, Vector3.ZERO, 55.0]], {"elapsed": seq.elapsed, "phase": seq.phase, "world": seq.world_index}, true)
	seq.skip()
