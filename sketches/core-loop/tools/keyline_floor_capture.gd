extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const SIZE := Vector2i(1280, 720)
const RING := 7.0
const EDGE_STEP_MIN := 20.0
const MIN_RAYS := 6
const CONTROL_DARK := Color(0.25, 0.25, 0.25)
const CONTROL_LIGHT := Color(0.75, 0.75, 0.75)
const CONTROL_TOLERANCE := 0.3
const MIN_CONTROLS := 4
var out := ""
var gate := false
var red := []
var report := {}
var _ground
var planted := []
var controls_ok := 0
var game
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--gate":
			gate = true
	var project := ProjectSettings.globalize_path("res://")
	if out.is_empty() or out.is_relative_path() or out.simplify_path().path_join("").begins_with(project):
		push_error("keyline_floor_capture: pass --out=<absolute dir outside %s>" % project)
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


static func lstar(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var y: float = 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
	return 116.0 * (pow(y, 1.0 / 3.0) if y > 0.008856 else (7.787 * y + 16.0 / 116.0)) - 16.0


func _px(img: Image, p: Vector3) -> Color:
	if cam.is_position_behind(p):
		return Color(-1, -1, -1)
	var s := cam.unproject_position(p)
	if s.x < 1 or s.y < 1 or s.x >= SIZE.x - 1 or s.y >= SIZE.y - 1:
		return Color(-1, -1, -1)
	return img.get_pixel(int(s.x), int(s.y))


func _run() -> void:
	seed(171022)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	for i in 600:
		if game.flow != null:
			break
		await physics_frame
	if game.flow == null:
		push_error("keyline_floor_capture: the game never built its flow")
		quit(2)
		return
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	DirAccess.make_dir_recursive_absolute(out)
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(40)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(40)
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	game.player.body().freeze = true
	var arena = game.flow._boss_module().get("arena")
	_ground = arena.ground_query()
	var centre: Vector3 = arena.global_position
	var env: Environment = game.ctx.terrain.environment
	var game_cam: Camera3D = root.get_camera_3d()
	var reach: float = game_cam.global_position.distance_to(game.player.ball_position()) if game_cam != null else 11.0
	print("BOWL ambient %s energy %.2f camera reach %.1f" % [env.ambient_light_color.to_html(false), env.ambient_light_energy, reach])
	cam = Camera3D.new()
	cam.far = 1800.0
	game.add_child(cam)
	var hidden: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.visible)
	for n in hidden:
		n.visible = false
	report = {"tool": "keyline_floor_capture.gd", "adapter": RenderingServer.get_video_adapter_name(),
		"look": WorldLook.arena_look("brindle").get("time", ""), "camera_reach": reach, "edge_step_min": EDGE_STEP_MIN, "spots": []}
	var spots := [Vector2(0, 0), Vector2(22, 0), Vector2(0, 30), Vector2(-38, 0), Vector2(0, -44), Vector2(30, 30)]
	for k in spots.size():
		var at := centre + Vector3(spots[k].x, 0, spots[k].y)
		at.y = _ground.height(at.x, at.z)
		var ring = Telegraph.ring(game, _ground, Threat.Type.INSTANT, at, RING, 4.0)
		ring.set_progress(0.5)
		var dark_at := _plant(at + Vector3(-2.0, 0, -0.7), CONTROL_DARK)
		var light_at := _plant(at + Vector3(-2.0, 0, 0.7), CONTROL_LIGHT)
		cam.global_position = at + Vector3(0.0, reach, 0.01)
		cam.look_at(at, Vector3.FORWARD)
		cam.fov = 85.0
		cam.current = true
		for i in 10:
			await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("keyline-%d.png" % k))
		var steps := []
		var keylines := []
		var strokes := []
		for a in 16:
			var u := Vector3(cos(TAU * (a + 0.5) / 16.0), 0, sin(TAU * (a + 0.5) / 16.0))
			var stroke := _band(img, at, u, RING - 0.3, RING - 0.05, Telegraph.LIFT, true)
			var keyline := _band(img, at, u, RING + 0.05, RING + Threat.UNDERLAY - 0.05, Telegraph.LIFT, false)
			var beyond := _band(img, at, u, RING + Threat.UNDERLAY + 0.15, RING + Threat.UNDERLAY + 0.55, 0.02, false)
			if stroke.is_empty() or keyline.size() < 3 or beyond.size() < 5:
				continue
			var floor_l := _median(beyond)
			var key_l := _median(keyline)
			var stroke_l: float = stroke.max()
			keylines.append(key_l)
			strokes.append(stroke_l)
			steps.append({"ray": a, "floor": floor_l, "keyline": key_l, "stroke": stroke_l,
				"step": maxf(floor_l - key_l, absf(stroke_l - floor_l))})
		var dark_c := _px(img, dark_at)
		var light_c := _px(img, light_at)
		var control := lstar(light_c) - lstar(dark_c) if dark_c.r >= 0.0 and light_c.r >= 0.0 else -1.0
		var control_dl := lstar(CONTROL_LIGHT) - lstar(CONTROL_DARK)
		var control_ok := absf(control - control_dl) <= control_dl * CONTROL_TOLERANCE
		if control_ok:
			controls_ok += 1
		var key_med := _median(keylines) if not keylines.is_empty() else -1.0
		var weakest := 999.0
		for row in steps:
			weakest = minf(weakest, row.step)
		var row := {"spot": [spots[k].x, spots[k].y], "rays": steps.size(), "weakest_step": weakest,
			"floor_median": _median(steps.map(func(r): return r.floor)) if not steps.is_empty() else -1.0,
			"keyline_median": key_med, "stroke_median": _median(strokes) if not strokes.is_empty() else -1.0,
			"control_dl": control, "control_ok": control_ok, "per_ray": steps}
		report.spots.append(row)
		print("SPOT %d %s rays %d floor %.1f keyline %.1f stroke %.1f weakest step %.1f control dL* %.1f" % [k, str(spots[k]),
			steps.size(), row.floor_median, key_med, row.stroke_median, weakest, control])
		if steps.size() < MIN_RAYS:
			red.append("spot %d counted %d rays" % [k, steps.size()])
		elif weakest < EDGE_STEP_MIN:
			red.append("spot %d weakest edge step %.1f" % [k, weakest])
		ring.queue_free()
		for n in planted:
			n.queue_free()
		planted.clear()
		await _frames(2)
	if controls_ok < MIN_CONTROLS:
		red.append("the planted control read in %d of %d spots" % [controls_ok, spots.size()])
	report["red"] = red
	var f := FileAccess.open(out.path_join("keyline_floor.json"), FileAccess.WRITE)
	if f == null:
		push_error("keyline_floor_capture: cannot write %s" % out)
		quit(2)
		return
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	for line in red:
		print("RED ", line)
	print("CAPTURE DONE adapter %s" % report.adapter)
	quit(1 if gate and not red.is_empty() else 0)


func _band(img: Image, at: Vector3, u: Vector3, r0: float, r1: float, lift: float, hazard: bool) -> Array:
	var result := []
	var r := r0
	while r <= r1 + 0.001:
		var p := at + u * r
		p.y = _ground.height(p.x, p.z) + lift
		var c := _px(img, p)
		if c.r >= 0.0 and (not hazard or (c.r - c.g > 0.25 and c.r > 0.75)):
			result.append(lstar(c))
		r += 0.025
	return result


func _plant(where: Vector3, colour: Color) -> Vector3:
	var plate := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	plate.mesh = mesh
	plate.material_override = Palette.unshaded(colour)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(plate)
	where.y = _ground.height(where.x, where.z) + 0.25
	plate.global_position = where
	planted.append(plate)
	return where


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
