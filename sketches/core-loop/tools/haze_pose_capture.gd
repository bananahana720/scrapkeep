extends SceneTree
# Held-pose still pair for the haze live-over-pending read (ruling #241 6331787112, item 2; PR #284).
# In stage 2 (morning) and the Mind's arena (the last place, "arena-w3" in grade_probe), the ball is
# frozen and two hostile INSTANT rings lie side by side on the ground ahead of it, in one frame: a
# pending ring at progress PENDING_PROGRESS and a live one (progress 1.0). The frame is the game's own
# chase camera with the HUD hidden, so it shows what a player sees. Needs a display:
#   godot --path sketches/core-loop --resolution 1280x720 --script res://tools/haze_pose_capture.gd -- --out=<abs dir>
# Cloud check under xvfb:
#   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT_BIN --path sketches/core-loop --resolution 1280x720 --script res://tools/haze_pose_capture.gd -- --out=<abs dir>
# On the RTX 3060 bench run it without xvfb; the frame is SIZE (1280x720, as day_arc_capture). Writes <out>/haze-pose-<place>.png
# (stage2-morning, arena-w3) and <out>/haze-pose.json: the head, HAZE_FILL and HAZE_SOLID, and per
# ring its screen rect and the mean CIE L* of an inner box (INNER share of the ring's projected
# radius), plus a ground-only box in the gap between the rings. The rings' rim lines and the landing
# flash (gone after SETTLE_FRAMES) are not in the boxes. Exit 2 without a display or --out.
# Evidence limit: on llvmpipe (GL Compatibility, no Forward+ glow or volumetric air) the numbers are
# colour only and a trend; the 3060 judges. An arena may start its own attacks inside the settle
# frames (calm is set); read the PNG as well as the boxes.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const PENDING_PROGRESS := 0.95
const RING_RADIUS := 3.0
# Metres ahead of the ball along the camera's flat lens-to-ball heading, and each ring's offset to its side.
const AHEAD := 8.0
const SIDE := 4.0
# Inner box, as a share of the ring's projected radius; the gap box is this share of RING_RADIUS in metres.
const INNER := 0.4
const GAP_HALF := 0.5
const SETTLE_FRAMES := 40
const SIZE := Vector2i(1280, 720)


# The surface under a ring: Telegraph reads height(x, z) from it. A place's floor can stand above the
# terrain (the launch pad, an arena), so the height is the physics floor under the ring, not the terrain's.
class FloorAt:
	var y := 0.0

	func height(_x: float, _z: float) -> float:
		return y


var out := ""
var game
var recs: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


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
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(40)
	await _pose("stage2-morning")
	game.flow.enter_stage(game.ctx.stages.COUNT, Vector3.ZERO, false)
	await _frames(40)
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	await _pose("arena-w3")
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("haze-pose.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "haze_pose_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"adapter": RenderingServer.get_video_adapter_name(), "haze": Threat.haze(), "HAZE_FILL": Threat.HAZE_FILL,
		"HAZE_SOLID": Threat.HAZE_SOLID, "pending_progress": PENDING_PROGRESS, "viewport": root.get_visible_rect().size, "places": recs}, "\t"))
	f.close()
	quit(0)


func _pose(place: String) -> void:
	game.player.body().freeze = true
	var cam: Camera3D = game.camera.cam
	cam.current = true
	var ball: Vector3 = game.player.ball_position()
	# The chase camera sits behind the ball, so the flat line from lens to ball is the way it looks.
	var fwd: Vector3 = ball - cam.global_position
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var pending := _ring(ball + fwd * AHEAD - right * SIDE, ball.y)
	var live := _ring(ball + fwd * AHEAD + right * SIDE, ball.y)
	pending.set_progress(PENDING_PROGRESS)
	live.set_progress(1.0)
	await _frames(SETTLE_FRAMES)
	paused = true
	var shown: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.visible)
	for n in shown:
		n.visible = false
	for i in 12:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join("haze-pose-%s.png" % place))
	var rec := {"place": place, "image": [image.get_width(), image.get_height()], "camera_to_ball": cam.global_position.distance_to(ball)}
	rec["pending"] = _ring_box(image, cam, pending.center, right)
	rec["live"] = _ring_box(image, cam, live.center, right)
	var mid: Vector3 = (pending.center + live.center) * 0.5
	rec["ground"] = _box(image, cam, mid, right, GAP_HALF)
	recs.append(rec)
	for n in shown:
		n.visible = true
	paused = false
	pending.free()
	live.free()
	game.player.body().freeze = false
	print("pose ", place, " ", rec)


func _ring(at: Vector3, from_y: float) -> Node3D:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y + 20.0, at.z), Vector3(at.x, from_y - 40.0, at.z))
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	var floor_at := FloorAt.new()
	floor_at.y = float(hit["position"].y) if not hit.is_empty() else from_y
	# reach 0 draws no fence (threat_grammar.gd: no posts or rail at reach <= 0.05), so no rail
	# projects over the ring or gap boxes; the fill and slag being read are unchanged.
	return Telegraph.ring(game, floor_at, Threat.Type.INSTANT, at, RING_RADIUS, 0.0)


func _ring_box(image: Image, cam: Camera3D, centre: Vector3, right: Vector3) -> Dictionary:
	return _box(image, cam, centre, right, RING_RADIUS * INNER)


# A world square of half-size `half` metres about `centre`, as its screen rect and mean L* (the
# rect is the projection of the centre plus and minus `half` along the right and the forward axis).
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
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			total += DefenceBars._lab(image.get_pixel(x, y)).x
			n += 1
	return {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "on_screen": clipped == rect and n > 0,
		"mean_l": total / n if n > 0 else -1.0}
