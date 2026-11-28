extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AppShell := preload("res://src/core/app_shell.gd")
var out := ""
var class_index := 1
var game
var cam: Camera3D
var failures := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--class="): class_index = int(a.trim_prefix("--class="))
	if AppShell.headless() or out == "":
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
	game.flow.choose_class(class_index)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	cam = Camera3D.new()
	cam.far = 1800.0
	cam.near = 0.05
	game.add_child(cam)
	await _frames(60)


func _stage(n: int) -> void:
	game.flow.enter_stage(n, Vector3.ZERO, false)
	await _frames(40)
	game.player.body().freeze = true


func _gh(x: float, z: float) -> float:
	return game.ctx.terrain.height(x, z)


func _ball_at(x: float, z: float, y := NAN) -> void:
	game.player.body().freeze = false
	game.player.reset_to(Vector3(x, _gh(x, z) + 1.0 if is_nan(y) else y, z))
	await _frames(3)
	game.player.body().freeze = true


func _snap(subject: String, shots: Array, extra := {}) -> void:
	var dir := out.path_join(subject)
	DirAccess.make_dir_recursive_absolute(dir)
	paused = true
	for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
	for l in root.find_children("*", "Label3D", true, false): l.visible = false
	var recs: Array = []
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = s[3]
		cam.current = true
		for i in 12: await RenderingServer.frame_post_draw
		var png := dir.path_join(s[0] + ".png")
		root.get_texture().get_image().save_png(png)
		recs.append({"id": s[0], "eye": [s[1].x, s[1].y, s[1].z], "target": [s[2].x, s[2].y, s[2].z], "fov": s[3], "file": s[0] + ".png", "sha256": FileAccess.get_sha256(png)})
	extra["ball"] = [game.player.ball_position().x, game.player.ball_position().y, game.player.ball_position().z]
	var doc := {"tool": "w12_ground_capture.gd", "subject": subject, "class": class_index, "mode": "lit", "adapter": RenderingServer.get_video_adapter_name(), "extra": extra, "frames": recs}
	var f := FileAccess.open(dir.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	paused = false
	print("snap ", subject, " ", recs.size())


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
	game.player.body().freeze = true
	await _spillway()
	await _scrap_variants()
	await _cache()
	await _dig()
	await _dig_deep()
	await _highdraft()
	print("done failures=", failures)
	quit(failures)


func _spillway() -> void:
	var b: Vector3 = game.player.ball_position()
	await _snap("wog_spillway", [
		["spawn_wide", b + Vector3(-40, 28, -50), b + Vector3(10, 0, 30), 65.0]])
	await _ball_at(22.0, 28.0)
	await _frames(2)
	await _snap("wog_spillway_benches", [
		["benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0]])


func _camp_bay() -> void:
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
	if box.size == Vector3.ZERO and not offers.is_empty():
		bc = offers[0]["at"] + Vector3(0, 2, 0)
		r = 8.0 * 0.8 + 6.0
	await _ball_at(bc.x + r * 0.3, bc.z - r * 0.3)
	await _frames(2)
	await _snap("cv2_camp_bay", [["three_q", bc + Vector3(r * 0.7, r * 0.45, -r * 0.7), bc, 60.0]], {"docked": docked})


func _dig() -> void:
	await _stage(3)
	var sc = game.find_child("Scrap", true, false)
	var items: Array = sc.get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	if items.is_empty():
		failures += 1
		printerr("no scrap on stage 3")
		return
	var q2: Vector3 = items[0].global_position
	await _ball_at(q2.x + 2.0, q2.z + 3.0)
	await _frames(2)
	var rest: Array = []
	for k in mini(items.size(), 8):
		var at: Vector3 = items[k].global_position
		rest.append(snappedf(at.y - _gh(at.x, at.z), 0.001))
	await _snap("scr_dig", [["close", q2 + Vector3(2.4, 1.6, -3), q2, 45.0], ["cluster", q2 + Vector3(0, 6, -10), q2 + Vector3(0, -0.5, 4), 55.0]], {"scrap_count": items.size(), "scrap_rest_above_collider": rest})


func _dig_deep() -> void:
	await _stage(4)
	var s: Vector3 = game.ctx.terrain.spawn_point(4)
	await _ball_at(s.x + 4.0, s.z + 8.0)
	await _frames(2)
	await _snap("dig_deep_floor", [["floor", s + Vector3(-6, 9, -12), s + Vector3(4, 0, 10), 60.0]])


func _highdraft() -> void:
	await _stage(5)
	await _ball_at(0.0, 104.0, 27.0)
	await _frames(2)
	await _snap("hdr_island_bridge", [["island_bridge", Vector3(0, 40, 150), Vector3(0, 26, 100), 60.0]])
	var sc: Node3D = game.ctx.terrain.geometry_root(5).get_node("HighdraftScenery")
	var props: Node3D = sc.get_node("Props")
	var shots: Array = []
	for pname in ["prop_crate", "prop_spool", "prop_lamp_body", "prop_bearing", "prop_clamp", "prop_pot"]:
		var mm := props.get_node_or_null(pname) as MultiMeshInstance3D
		if mm == null or mm.multimesh.instance_count == 0: continue
		var p: Vector3 = (mm.global_transform * mm.multimesh.get_instance_transform(0)).origin
		shots.append([pname, p + Vector3(5, 3.5, 6), p + Vector3(0, 0.8, 0), 55.0])
	await _ball_at(0.0, -10.0, 12.0)
	await _snap("hdr_props", shots)
	await _snap("hdr_net", [["net_deck", Vector3(0, 45, -20), Vector3(0, 10, -10), 60.0], ["return_ramps", Vector3(-14, 30, -35), Vector3(-8, 15, -70), 60.0], ["net_low", Vector3(0, 14, 30), Vector3(0, 8, -30), 65.0]])


func _scrap_variants() -> void:
	await _stage(1)
	var sc = game.find_child("Scrap", true, false)
	var vs := {}
	for it in sc.get_children():
		if it is MeshInstance3D and it.visible:
			vs[str(it.get_meta("scrap_variant", "?"))] = it
	var vshots: Array = []
	for k in vs:
		var q: Vector3 = vs[k].global_position
		vshots.append(["v_" + k, q + Vector3(2.2, 1.4, -2.6), q, 45.0])
	if vshots.is_empty():
		failures += 1
		return
	var first: Vector3 = vs[vs.keys()[0]].global_position
	await _ball_at(first.x + 2.0, first.z + 3.0)
	await _snap("scr_variants", vshots, {"variants": vs.keys()})


func _cache() -> void:
	await _stage(1)
	var b: Vector3 = game.player.ball_position()
	var Cache := preload("res://src/world/cracked_cache.gd")
	var d = Cache.new()
	game.add_child(d)
	var x: float = b.x + 10
	var z: float = b.z + 40
	d.global_position = Vector3(x, _gh(x, z), z)
	d.setup(game.ctx, game.world.interact, {"id": "w12_cache"})
	await _frames(30)
	d.fire()
	await _frames(60)
	var c: Vector3 = d.global_position + Vector3(0, 1.4, 0)
	await _ball_at(c.x - 3.0, c.z - 3.0)
	await _snap("gpd_cache_fired", [["three_q", c + Vector3(7, 3, -6), c, 50.0]])
