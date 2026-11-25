extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
var out := ""
var scene := ""
var only := ""
var bias := PackedFloat64Array()
var hdri := ""
var game
var cam: Camera3D
var failures := 0
var recs: Array = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--scene="): scene = a.trim_prefix("--scene=")
		elif a.begins_with("--only="): only = a.trim_prefix("--only=")
		elif a.begins_with("--sun-bias="): bias = PackedFloat64Array(Array(a.trim_prefix("--sun-bias=").split(",")).map(func(v): return float(v)))
		elif a.begins_with("--hdri="): hdri = a.trim_prefix("--hdri=")
	if DisplayServer.get_name() == "headless" or out == "" or scene == "":
		printerr("needs native display, --out, --scene"); quit(2); return
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n: await physics_frame

func _boot(warden: bool) -> void:
	seed(280928)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null: await physics_frame
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = warden
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	cam = Camera3D.new()
	cam.far = 1800.0
	cam.near = 0.05
	game.add_child(cam)

func _overrides() -> void:
	if bias.size() == 2:
		for sun: DirectionalLight3D in game.find_children("*", "DirectionalLight3D", true, false):
			if sun.shadow_enabled and sun.name != "SkyFill":
				sun.shadow_bias = bias[0]
				sun.shadow_normal_bias = bias[1]
	if hdri != "" and game.ctx.terrain.environment.sky != null:
		var image := Image.load_from_file(hdri)
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = ImageTexture.create_from_image(image)
		game.ctx.terrain.environment.sky.sky_material = panorama

func _snap(subject: String, shot: Array, ui := false) -> void:
	var id := subject + "__" + String(shot[0])
	if only != "" and not id.contains(only):
		return
	if not ui:
		_overrides()
	DirAccess.make_dir_recursive_absolute(out)
	var was_paused := paused
	if not ui:
		paused = true
		for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
		for l in root.find_children("*", "Label3D", true, false): l.visible = false
		cam.global_position = shot[1]
		cam.look_at(shot[2], Vector3.UP)
		cam.fov = shot[3]
		cam.current = true
	for i in 24: await RenderingServer.frame_post_draw
	var png := out.path_join(id + ".png")
	var image := root.get_texture().get_image()
	image.save_png(png)
	var rec := {"id": id, "eye": [shot[1].x, shot[1].y, shot[1].z], "target": [shot[2].x, shot[2].y, shot[2].z], "fov": shot[3], "sha256": FileAccess.get_sha256(png), "dead": _dead(image)}
	if rec.dead != "":
		failures += 1
	recs.append(rec)
	paused = was_paused
	print("snap ", id, " ", rec.dead)

func _dead(image: Image) -> String:
	var small := image.duplicate() as Image
	small.resize(192, 108, Image.INTERPOLATE_BILINEAR)
	var black := 0
	var bins := {}
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			if c.get_luminance() < 0.04:
				black += 1
			var key := "%d,%d,%d" % [int(c.r * 16.0), int(c.g * 16.0), int(c.b * 16.0)]
			bins[key] = bins.get(key, 0) + 1
	var total := float(small.get_width() * small.get_height())
	if black / total > 0.8:
		return "dead:black"
	if bins.values().max() / total > 0.6:
		return "dead:flat"
	return ""

func _gh(x: float, z: float) -> float:
	return game.ctx.terrain.height(x, z)

func _enter(stage: int) -> void:
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await _frames(40)
	game.player.body().freeze = true

func _run() -> void:
	match scene:
		"worlds": await _worlds()
		"pit": await _pit()
		"arenas": await _arenas()
		"title": await _title()
		"warden": await _warden()
		_:
			printerr("unknown scene ", scene); quit(2); return
	var doc := {"tool": "w12_light_capture.gd", "scene": scene, "preset": GraphicsPreset.current, "adapter": RenderingServer.get_video_adapter_name(), "frames": recs}
	var f := FileAccess.open(out.path_join("frames_%s.json" % scene), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	print("done failures=", failures, " preset=", GraphicsPreset.current)
	quit(failures)

func _worlds() -> void:
	await _boot(false)
	await _frames(60)
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	await _snap("wog_spillway", ["spawn_wide", b + Vector3(-40, 28, -50), b + Vector3(10, 0, 30), 65.0])
	await _snap("wog_spillway", ["benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0])
	await _enter(3)
	var items: Array = game.find_child("Scrap", true, false).get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	var q2: Vector3 = items[0].global_position
	await _snap("scr_dig", ["cluster", q2 + Vector3(0, 6, -10), q2 + Vector3(0, -0.5, 4), 55.0])
	await _snap("scr_dig", ["wide", q2 + Vector3(-18, 14, -26), q2 + Vector3(0, 0, 6), 62.0])
	game.player.body().freeze = false
	await _frames(30)
	game.player.body().freeze = true
	var lit: Array = game.find_children("Lamp*", "OmniLight3D", true, false).filter(func(l): return l.is_visible_in_tree())
	if not lit.is_empty():
		var ball: Vector3 = game.player.ball_position()
		lit.sort_custom(func(a, c): return a.global_position.distance_to(ball) < c.global_position.distance_to(ball))
		var at: Vector3 = lit[0].global_position
		var away := Vector3(ball.x - at.x, 0, ball.z - at.z).normalized()
		await _snap("scr_dig", ["lamp_pool", at + away * 26.0 + Vector3.UP * 2.0, at + away * 6.0 + Vector3.DOWN * 9.0, 62.0])
	else:
		print("no lit lamp pool")
		failures += 1
	await _enter(5)
	await _snap("hdr_sky", ["sky_loom", Vector3(0, 45, 60), Vector3(0, 10, -400), 70.0])

func _pit() -> void:
	await _boot(true)
	await _frames(20)
	game.flow.enter_stage(game.ctx.stages.last_of(2), Vector3.ZERO, false)
	await _frames(20)
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	var m = game.flow._boss_module()
	var wp: Vector3 = m.warden.global_position
	var c: Vector3 = m._center
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	print("warden ", wp, " ball ", b)
	await _snap("arw_pit", ["over_shoulder", b + Vector3(0, 6, 14), wp, 62.0])
	await _snap("arw_pit", ["rim_view", c + Vector3(0, 12, 66), c + Vector3(0, 6, 0), 60.0])
	await _snap("arw_pit", ["lamps_wall", c + Vector3(-30, 8, 20), c + Vector3(20, 6, -10), 65.0])

func _arenas() -> void:
	await _boot(false)
	await _frames(20)
	game.flow.enter_boss(Vector3(18, 0, 0))
	await _frames(60)
	game.player.body().freeze = true
	var c: Vector3 = game.boss.arena.global_position
	await _snap("arb_bowl", ["overview", c + Vector3(0, 70, 105), c, 60.0])
	await _snap("arb_bowl", ["floor_level", c + Vector3(34, 3.5, -34), c + Vector3(-12, 3, 14), 60.0])
	game.flow.enter_stage(game.ctx.stages.last_of(3), Vector3.ZERO, false)
	await _frames(20)
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	var m = game.flow._boss_module()
	var p: Vector3 = m.pad.global_position + Vector3(0, 1, 0)
	game.player.body().freeze = true
	await _snap("arm_crown", ["crown", p + Vector3(0, 18, 78), p + Vector3(0, 16, 0), 60.0])

func _title() -> void:
	seed(280928)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	await _frames(30)
	var d = game.presentation.get_node("TitleStage")
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != d._layer: n.visible = false
	await _snap("ttl_stage_only", ["t0", Vector3.ZERO, Vector3.ZERO, 55.0], true)

func _warden() -> void:
	await _boot(true)
	await _frames(90)
	game.player.body().freeze = true
	var w: Vector3 = game.flow.warden.global_position
	var b: Vector3 = game.player.ball_position()
	var away := Vector3(b.x - w.x, 0, b.z - w.z).normalized()
	var side := away.cross(Vector3.UP)
	var at := w + away * 7.0 + side * 2.0
	game.player.body().global_position = Vector3(at.x, _gh(at.x, at.z) + 1.2, at.z)
	await _frames(4)
	await _snap("wdn_stage1", ["three_q", at + away * 9.0 + side * 3.0 + Vector3.UP * 4.0, w + Vector3.UP * 2.0, 55.0])
