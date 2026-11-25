extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const PENDING_PROGRESS := 0.95
const RING_RADIUS := 3.0
const PLACES := [
	{"id": "stage2-morning", "stage": 2, "ahead": 24.0, "side": 5.0, "ground_ahead": 7.0, "ground_side": 0.0},
	{"id": "arena-w3", "boss": true, "ahead": 8.0, "side": 4.0, "ground_ahead": 0.0, "ground_side": 8.0, "dark_ahead": 8.0, "dark_side": 4.0, "dark_dir": Vector2(0.0, -1.0)},
]
const BAND_HALF := 0.5
const GROUND_OUT := 1.2
const GROUND_HALF := 0.4
const KEYLINE_GAP := 0.05
const INNER := 0.4
const GAP_HALF := 0.5
const SETTLE_FRAMES := 40
const SIZE := Vector2i(1280, 720)


class FloorAt:
	var y := 0.0

	func height(_x: float, _z: float) -> float:
		return y


var out := ""
var game
var recs: Array = []
var scorches: Array = []
var alphas: Array = []
var swept := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scorch="):
			scorches = _floats(a.trim_prefix("--scorch="))
		elif a.begins_with("--live-alpha="):
			alphas = _floats(a.trim_prefix("--live-alpha="))
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	swept = not scorches.is_empty() or not alphas.is_empty()
	if scorches.is_empty():
		scorches = [Threat.LIVE_SCORCH]
	if alphas.is_empty():
		alphas = [Threat.LIVE_SCORCH_ALPHA]
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


static func _floats(text: String) -> Array:
	var result := []
	for part in text.split(",", false):
		result.append(float(part))
	return result


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	seed(171022)
	game = Game.new()
	game.test_mode = true
	game.table = Game.LAUNCH_TABLE
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	DirAccess.make_dir_recursive_absolute(out)
	for place in PLACES:
		if place.has("stage"):
			game.flow.enter_stage(place.stage, Vector3.ZERO, false)
			await _frames(40)
		else:
			game.flow.enter_stage(game.ctx.stages.COUNT, Vector3.ZERO, false)
			await _frames(40)
			game.flow.enter_boss(Vector3.ZERO)
			await _frames(90)
		await _pose(place)
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("haze-pose.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "haze_pose_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"adapter": RenderingServer.get_video_adapter_name(), "haze": Threat.haze(), "HAZE_FILL": Threat.HAZE_FILL,
		"LIVE_SCORCH": Threat.LIVE_SCORCH, "LIVE_SCORCH_ALPHA": Threat.LIVE_SCORCH_ALPHA, "swept": swept, "pending_progress": PENDING_PROGRESS, "viewport": root.get_visible_rect().size, "places": recs}, "\t"))
	f.close()
	quit(0)


func _pose(place: Dictionary) -> void:
	var id: String = place["id"]
	game.player.body().freeze = true
	var cam: Camera3D = game.camera.cam
	cam.current = true
	var ball: Vector3 = game.player.ball_position()
	var fwd: Vector3 = ball - cam.global_position
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var ahead: float = place["ahead"]
	var side: float = place["side"]
	var pending := _ring(ball + fwd * ahead - right * side, ball.y)
	var live := _ring(ball + fwd * ahead + right * side, ball.y)
	var dark: Node3D = null
	if place.has("dark_ahead"):
		dark = _ring(ball + fwd * float(place["dark_ahead"]) + right * float(place["dark_side"]), ball.y)
		dark.set_progress(1.0)
	pending.set_progress(PENDING_PROGRESS)
	live.set_progress(1.0)
	await _frames(SETTLE_FRAMES)
	paused = true
	var shown: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.visible)
	for n in shown:
		n.visible = false
	for s in scorches:
		for a in alphas:
			if swept:
				var tint := Color(Palette.HAZARD.lerp(Palette.CHARCOAL, s), a)
				live.painter().tint("fill", tint)
				if dark != null:
					dark.painter().tint("fill", tint)
			if dark != null:
				pending.visible = true
				live.visible = true
				dark.visible = false
			for i in 12:
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var tag := id if not swept else "%s-s%.2f-a%.2f" % [id, s, a]
			image.save_png(out.path_join("haze-pose-%s.png" % tag))
			var rec := {"place": id, "scorch": s, "live_alpha": a, "image": [image.get_width(), image.get_height()], "camera_to_ball": cam.global_position.distance_to(ball)}
			rec["pending"] = _ring_box(image, cam, pending.center, right)
			rec["live"] = _ring_box(image, cam, live.center, right)
			var mid: Vector3 = (pending.center + live.center) * 0.5
			rec["ground"] = _box(image, cam, mid + fwd * float(place["ground_ahead"]) + right * float(place["ground_side"]), right, GAP_HALF)
			rec["step"] = float(rec["pending"]["mean_l"]) - float(rec["live"]["mean_l"])
			if dark != null:
				pending.visible = false
				live.visible = false
				dark.visible = true
				for i in 12:
					await RenderingServer.frame_post_draw
				image = root.get_texture().get_image()
				image.save_png(out.path_join("haze-pose-%s-dark.png" % tag))
				var dir2: Vector2 = place["dark_dir"]
				var dir3 := (fwd * dir2.x + right * dir2.y).normalized()
				var rim: Vector3 = dark.center + dir3 * RING_RADIUS
				var band := _box(image, cam, rim, right, BAND_HALF)
				var ground := _box(image, cam, rim + dir3 * GROUND_OUT, right, GROUND_HALF)
				var kl_len: float = Threat.UNDERLAY - 2.0 * KEYLINE_GAP
				var keyline := _box(image, cam, rim + dir3 * (KEYLINE_GAP + kl_len * 0.5), right, kl_len * 0.5)
				var ew := Threat.edge_width({"r_out": RING_RADIUS})
				var edge := _box(image, cam, rim - dir3 * (ew * 0.5), right, ew * 0.5)
				var gl := float(ground["mean_l"])
				var kl := float(keyline["mean_l"])
				var el := float(edge["mean_l"])
				rec["dark"] = {"band": band, "ground": ground, "keyline": keyline, "edge": edge, "edge_l": el, "keyline_l": kl, "ground_l": gl,
					"edge_separation": absf(el - gl), "keyline_separation": absf(kl - gl)}
			recs.append(rec)
			print("pose ", tag, " ", rec)
	for n in shown:
		n.visible = true
	paused = false
	pending.free()
	live.free()
	if dark != null:
		dark.free()
	game.player.body().freeze = false


func _ring(at: Vector3, from_y: float) -> Node3D:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y + 20.0, at.z), Vector3(at.x, from_y - 40.0, at.z))
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	var floor_at := FloorAt.new()
	floor_at.y = float(hit["position"].y) if not hit.is_empty() else from_y
	return Telegraph.ring(game, floor_at, Threat.Type.INSTANT, at, RING_RADIUS, 0.0)


func _ring_box(image: Image, cam: Camera3D, centre: Vector3, right: Vector3) -> Dictionary:
	return _box(image, cam, centre, right, RING_RADIUS * INNER)


func _box(image: Image, cam: Camera3D, centre: Vector3, right: Vector3, half: float) -> Dictionary:
	var fwd := Vector3.UP.cross(right).normalized()
	var a := cam.unproject_position(centre - right * half + fwd * half)
	var b := cam.unproject_position(centre + right * half - fwd * half)
	var c := cam.unproject_position(centre)
	var half_px := maxf(2.0, minf(absf(b.x - a.x), absf(b.y - a.y)) * 0.5)
	var rect := Rect2i(int(c.x - half_px), int(c.y - half_px), int(half_px * 2.0), int(half_px * 2.0))
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var total := 0.0
	var n := 0
	var top := -1.0
	var bottom := 101.0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var l: float = DefenceBars._lab(image.get_pixel(x, y)).x
			total += l
			top = maxf(top, l)
			bottom = minf(bottom, l)
			n += 1
	return {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "on_screen": clipped == rect and n > 0,
		"mean_l": total / n if n > 0 else -1.0, "max_l": top, "min_l": bottom}
