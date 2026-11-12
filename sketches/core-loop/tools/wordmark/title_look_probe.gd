extends SceneTree
# Taste-page probe for W1-47 (removed when the chosen look is built). Run under xvfb with --rendering-driver opengl3 (or a
# real display on the PC):  --script res://tools/wordmark/title_look_probe.gd -- --look=base|a|b|c --out=<abs dir>
#   --wm=<abs path to sketches/core-loop/tools/wordmark/candidates>. Prints TITLE_LOOK <look> prims=<code primitives>.
# Taste probe for W1-47: --look=base|a|b|c --out=<dir> --wm=<dir of wordmark svgs> [--size=1280x720]
const Game := preload("res://src/game.gd")
const CODE := ["ServiceDeck", "CanalLip", "WaterChannel", "LanternLens", "LanternPost", "Ball", "BallGyro"]
var _game
var _out := ""
var _look := "base"
var _wm := ""
var _size := Vector2i(1280, 720)
var _frame := 0
var _times: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		match kv[0]:
			"out": _out = kv[1]
			"look": _look = kv[1]
			"wm": _wm = kv[1]
			"size": _size = Vector2i(int(kv[1].split("x")[0]), int(kv[1].split("x")[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(_size)
	root.size = _size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)

func _process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frame += 1
	if _frame == 30:
		var s = _game.get_node("Screens")
		s.prologue_enabled = false
		s._on_flow_changed("title")
	elif _frame == 50:
		_apply()
	if _frame > 50 and _look != "base":
		var v: ColorRect = _game.get_node("Screens")._veil
		v.color = Color(0.09, 0.105, 0.1, 0.82)
		v.anchor_top = 0.285
		v.anchor_bottom = 0.5
	if _frame > 120 and _frame <= 240:
		_times.append(delta * 1000.0)
	elif _frame == 241:
		_save()
	return false

func _ts():
	return _game.find_child("TitleStage", true, false)

func _apply() -> void:
	var ts = _ts()
	if _look == "base":
		return
	for n in ts.stage.get_children():
		var nm := String(n.name)
		if nm in CODE or nm.begins_with("DeckPlate") or nm.begins_with("PumpPipe") or nm.begins_with("PipeBrace"):
			n.queue_free()
	var env: Environment = ts._environment
	match _look:
		"a":
			env.background_color = Color("3a2a2e")
			ts._sun.light_color = Color("ffb27a")
			_put(ts, "res://assets/models/barge.glb", Vector3(0, -1.95, 0.3), 0.0, Vector3(1.0, 1.0, 0.62))
			_put(ts, "res://assets/models/bosses/boss_brindle.glb", Vector3(1.5, 4.5, -16.0), deg_to_rad(155), Vector3.ONE * 1.25)
			_put(ts, "res://assets/models/camp/camp_barrel.glb", Vector3(-5.6, 0.0, 1.2), 0.3)
			_put(ts, "res://assets/models/gauge_dial_stand.glb", Vector3(6.4, 0.0, 0.4), -0.4)
			_wordmark(s_screens(), "poster")
		"b":
			env.background_color = Color("1d2a33")
			ts._sun.light_color = Color("cfdcff")
			ts._sun.light_energy = 0.6
			_put(ts, "res://assets/models/camp/camp_plaza.glb", Vector3(0, -0.18, 30.0), 0.0)
			_put(ts, "res://assets/models/camp/camp_fire_pit.glb", Vector3(0.0, 0.0, 2.6), 0.0, Vector3.ONE * 0.6)
			_put(ts, "res://assets/models/camp/camp_tarp.glb", Vector3(-1.0, 0.0, -3.6), 0.2)
			_put(ts, "res://assets/models/camp/camp_lockers.glb", Vector3(-6.0, 0.0, -6.5), 0.15, Vector3.ONE * 0.6)
			_put(ts, "res://assets/models/camp/camp_crate_stack.glb", Vector3(7.0, 0.0, -1.5), -0.5)
			_put(ts, "res://assets/models/camp/camp_bench.glb", Vector3(2.0, 0.0, 3.4), -0.2)
			var fire := OmniLight3D.new()
			fire.light_color = Color("ff9a4a")
			fire.light_energy = 3.0
			fire.omni_range = 7.0
			fire.position = Vector3(0, 1.0, 2.6)
			ts.stage.add_child(fire)
			_wordmark(s_screens(), "plate")
		"c":
			env.background_color = Color("243b43")
			_put(ts, "res://assets/models/barge.glb", Vector3(0, -1.95, 0.3), 0.0, Vector3(1.0, 1.0, 0.62))
			_put(ts, "res://assets/models/lantern_beacon_frame.glb", Vector3(-6.3, 0.0, -1.0), 0.3, Vector3.ONE * 0.28)
			_put(ts, "res://assets/models/lantern_beacon_lens.glb", Vector3(-6.3, 0.0, -1.0), 0.3, Vector3.ONE * 0.28)
			_put(ts, "res://assets/models/gauge_dial_stand.glb", Vector3(-6.0, 0.0, 1.2), 0.5)
			_put(ts, "res://assets/models/camp/camp_tool_rack.glb", Vector3(6.6, 0.0, -2.0), -0.4)
			_put(ts, "res://assets/models/camp/camp_barrel.glb", Vector3(-6.4, 0.0, -2.6), 0.0)
			_put(ts, "res://assets/models/camp/camp_crate_stack.glb", Vector3(7.2, 0.0, 1.0), -0.6)
			_wordmark(s_screens(), "splash")

func s_screens():
	return _game.get_node("Screens")

func _put(ts, path: String, at: Vector3, yaw: float, scale := Vector3.ONE) -> void:
	var n: Node3D = load(path).instantiate()
	n.position = at
	n.rotation.y = yaw
	n.scale = scale
	ts.stage.add_child(n)
	ts.intro._dress(n, path)

func _wordmark(s, look: String) -> void:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(_wm.path_join("wordmark_%s.svg" % look)), 1.0)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 250 if look == "splash" else 210)
	var t: Label = s._title
	t.get_parent().add_child(rect)
	t.get_parent().move_child(rect, t.get_index())
	t.visible = false
	t.text = ""

func _save() -> void:
	await RenderingServer.frame_post_draw
	var ts = _ts()
	var prims := []
	for m in ts.stage.find_children("*", "MeshInstance3D", true, false):
		if m.visible and m.mesh is PrimitiveMesh:
			prims.append(String(m.name))
	_times.sort()
	var med: float = _times[_times.size() / 2]
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("title-%s.png" % _look))
	print("TITLE_LOOK %s prims=%d median_ms=%.2f %s" % [_look, prims.size(), med, ",".join(prims)])
	quit(0)
