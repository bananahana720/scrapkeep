extends SceneTree
# Wave 12 ground capture driver, ported from the wave 11 w7_capture.gd (evidence only). Boots the
# real Game on table alpha, renders the w7 cameras for the ground probe with unchanged eyes and
# targets, and puts the ball (frozen) beside each target as the scale reference.
# Writes <out>/<subject>/<cam>.png + frames.json. Native window only.
#   godot --path sketches/core-loop --script res://tools/w12_capture.gd -- --out=<dir>
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
var out := ""
var class_index := 1
var game
var cam: Camera3D
var failures := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--class="): class_index = int(a.trim_prefix("--class="))
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


# The ball sits on the ground at (x, z), frozen, as the scale reference.
func _ball_at(x: float, z: float, y := NAN) -> void:
	game.player.body().freeze = false
	game.player.reset_to(Vector3(x, _gh(x, z) + 1.0 if is_nan(y) else y, z))
	# The teleport lands on the next physics tick, so the ball freezes after it.
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
	var doc := {"tool": "w12_capture.gd", "subject": subject, "class": class_index, "mode": "lit", "adapter": RenderingServer.get_video_adapter_name(), "extra": extra, "frames": recs}
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
	await _camp_bay()
	await _dig()
	await _dig_deep()
	await _highdraft()
	print("done failures=", failures)
	quit(failures)


# w7 _workshop: wog_spillway spawn_wide and benches (the ball stays on its spawn pad).
func _spillway() -> void:
	var b: Vector3 = game.player.ball_position()
	await _snap("wog_spillway", [
		["spawn_wide", b + Vector3(-40, 28, -50), b + Vector3(10, 0, 30), 65.0]])
	await _ball_at(22.0, 28.0)
	await _frames(2)
	await _snap("wog_spillway_benches", [
		["benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0]])


# w7 _props, camp bay three_q: the bay docked at the stage's gate slots.
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
	# Deviation from w7: with no visible bay mesh the w7 framing points at the origin under the
	# map, so the camera falls back to the first gate slot with the w7 radius rule on an 8 m box.
	if box.size == Vector3.ZERO and not offers.is_empty():
		bc = offers[0]["at"] + Vector3(0, 2, 0)
		r = 8.0 * 0.8 + 6.0
	await _ball_at(bc.x + r * 0.3, bc.z - r * 0.3)
	await _frames(2)
	await _snap("cv2_camp_bay", [["three_q", bc + Vector3(r * 0.7, r * 0.45, -r * 0.7), bc, 60.0]], {"docked": docked})


# w7 _scrap, scr_dig close and cluster on stage 3 (Dig: the upper bench).
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
	await _snap("scr_dig", [["close", q2 + Vector3(2.4, 1.6, -3), q2, 45.0], ["cluster", q2 + Vector3(0, 6, -10), q2 + Vector3(0, -0.5, 4), 55.0]], {"scrap_count": items.size()})


# Extra (not a w7 camera): the Dig deep floor on stage 4, near its spawn pad.
func _dig_deep() -> void:
	await _stage(4)
	var s: Vector3 = game.ctx.terrain.spawn_point(4)
	await _ball_at(s.x + 4.0, s.z + 8.0)
	await _frames(2)
	await _snap("dig_deep_floor", [["floor", s + Vector3(-6, 9, -12), s + Vector3(4, 0, 10), 60.0]])


# w7 _hd_redo, hdr_island_bridge island_bridge on stage 5.
func _highdraft() -> void:
	await _stage(5)
	await _ball_at(0.0, 104.0, 27.0)
	await _frames(2)
	await _snap("hdr_island_bridge", [["island_bridge", Vector3(0, 40, 150), Vector3(0, 26, 100), 60.0]])
