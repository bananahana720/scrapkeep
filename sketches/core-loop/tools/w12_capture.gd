extends SceneTree
# Wave 12 light probe capture (port of the wave 7 driver's six environment cameras; eyes and
# targets unchanged so frames compare with w11/captures). Native window only.
#   godot --path sketches/core-loop --script res://tools/w12_capture.gd -- --out=<dir> --scene=worlds|pit [--preset=<name>]
# Writes <out>/<camera>.png (camera = subject__shot) and frames.json. On entry to each stage or
# arena it names the world's air through GraphicsPreset.enter_world, as the stage flow would.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
var out := ""
var scene := ""
var game
var cam: Camera3D
var failures := 0
var recs: Array = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--scene="): scene = a.trim_prefix("--scene=")
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

func _air(owner: Node, world_name: String) -> void:
	GraphicsPreset.enter_world(owner, game.ctx.terrain.environment, world_name)

func _snap(subject: String, shot: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var was_paused := paused
	paused = true
	for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
	for l in root.find_children("*", "Label3D", true, false): l.visible = false
	cam.global_position = shot[1]
	cam.look_at(shot[2], Vector3.UP)
	cam.fov = shot[3]
	cam.current = true
	for i in 24: await RenderingServer.frame_post_draw
	var id := subject + "__" + String(shot[0])
	var png := out.path_join(id + ".png")
	root.get_texture().get_image().save_png(png)
	recs.append({"id": id, "eye": [shot[1].x, shot[1].y, shot[1].z], "target": [shot[2].x, shot[2].y, shot[2].z], "fov": shot[3], "sha256": FileAccess.get_sha256(png)})
	paused = was_paused
	print("snap ", id)

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

func _enter(stage: int, world_name: String) -> void:
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await _frames(40)
	_air(game.ctx.terrain.geometry_root(stage), world_name)
	game.player.body().freeze = true

func _run() -> void:
	match scene:
		"worlds": await _worlds()
		"pit": await _pit()
		_:
			printerr("unknown scene ", scene); quit(2); return
	var doc := {"tool": "w12_capture.gd", "scene": scene, "preset": GraphicsPreset.current, "adapter": RenderingServer.get_video_adapter_name(), "frames": recs}
	var f := FileAccess.open(out.path_join("frames_%s.json" % scene), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	print("done failures=", failures, " preset=", GraphicsPreset.current)
	quit(failures)

func _worlds() -> void:
	await _boot(false)
	await _frames(60)
	_air(game.ctx.terrain.geometry_root(1), "spillway")
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	# w7 _workshop
	await _snap("wog_spillway", ["spawn_wide", b + Vector3(-40, 28, -50), b + Vector3(10, 0, 30), 65.0])
	await _snap("wog_spillway", ["benches", Vector3(10, 44, 56), Vector3(24, 28, 22), 65.0])
	# w7 _props camp bay
	await _enter(1, "spillway")
	var offers: Array = []
	for slot in game.ctx.terrain.map().gate_slots:
		var sa: Vector2 = slot["at"]
		offers.append({"at": Vector3(sa.x, _gh(sa.x, sa.y), sa.y), "facing": slot["facing"], "width": 8.0})
	var docked: bool = game.world.bay.dock(offers, Callable(game.ctx.terrain, "height"), null)
	print("bay docked ", docked)
	# w11 also found no gate offers on stage 1 (w11 cv2_camp_bay frames.json "docked": false); frame kept as is.
	await _frames(40)
	var box := _aabb(game.world.bay)
	var bc := box.get_center()
	var r := maxf(box.size.x, box.size.z) * 0.8 + 6.0
	await _snap("cv2_camp_bay", ["three_q", bc + Vector3(r * 0.7, r * 0.45, -r * 0.7), bc, 60.0])
	# w7 _scrap, Dig half
	await _enter(3, "dig")
	var items: Array = game.find_child("Scrap", true, false).get_children().filter(func(n): return n is MeshInstance3D and n.visible)
	var q2: Vector3 = items[0].global_position
	await _snap("scr_dig", ["cluster", q2 + Vector3(0, 6, -10), q2 + Vector3(0, -0.5, 4), 55.0])
	# w7 _hd_redo sky camera
	await _enter(5, "highdraft")
	await _snap("hdr_sky", ["sky_loom", Vector3(0, 45, 60), Vector3(0, 10, -400), 70.0])

# w7 _arw2: the Waking pit entered from the last Spillway stage with the Warden forced.
func _pit() -> void:
	await _boot(true)
	await _frames(20)
	game.flow.enter_stage(game.ctx.stages.last_of(2), Vector3.ZERO, false)
	await _frames(20)
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	var m = game.flow._boss_module()
	_air(m if m is Node else game, "waking")
	var wp: Vector3 = m.warden.global_position
	game.player.body().freeze = true
	var b: Vector3 = game.player.ball_position()
	print("warden ", wp, " ball ", b)
	await _snap("arw_pit_b", ["over_shoulder", b + Vector3(0, 6, 14), wp, 62.0])
