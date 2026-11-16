extends SceneTree

# Stills for PF-52 (a threat mark behind a ridge painted the screen flat orange): the game on its
# park map with the play camera and HUD, a hostile INSTANT landing (the solid flash, crack ring
# and dust, the layers that draw with the tinted material) laid once behind terrain from the
# camera, and once in plain view. Each still is taken with the game held on the landing's first
# frame. frames.json records, per shot, the share of screen pixels within TONE_DISTANCE of the
# mark's tone (the HUD is in the frame, so compare shots of one build with each other).
#   gpu-run.sh <worktree> pf52 --path sketches/core-loop --script res://tools/pf52_occlusion_still.gd -- --out=/abs/dir [--ball=x,z] [--heading=deg]
# Without --ball the ball stays where the run starts. The tool walks sight lines from the camera
# for a spot the ground hides and a spot it does not, and stops with an error, writing no still,
# if it finds none or if the landing is not live at the shot.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const SETTLE := 45
const WAIT_TICKS := 2400
const LANDED := 1.6
const RADIUS := 5.0
# Colour distance (sRGB, 0 to 1 per channel) under which a pixel counts as the mark's tone.
const TONE_DISTANCE := 0.12
# Ground the sight line must clear a point by, metres, for it to count as hidden.
const HIDE_BY := 1.5
const SEARCH_FROM := 8.0
const SEARCH_TO := 90.0

var game
var out := ""
var ball_arg := Vector2.INF
var heading_arg := INF
var stage := 0
var records := []
var failed := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ball="):
			var parts := arg.trim_prefix("--ball=").split(",")
			if parts.size() == 2:
				ball_arg = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--stage="):
			stage = int(arg.trim_prefix("--stage="))
		elif arg.begins_with("--heading="):
			heading_arg = deg_to_rad(float(arg.trim_prefix("--heading=")))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0

	if stage > 0:
		game.player.body().freeze = false
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _ticks(180)
		ground = game.ctx.spawner.ground
		game.run.set_max_hp(999999.0)
	var spot: Vector3 = game.player.ball_position()
	if ball_arg != Vector2.INF:
		spot = Vector3(ball_arg.x, Telegraph.ground_under(ground, Vector3(ball_arg.x, 0.0, ball_arg.y)) + 1.2, ball_arg.y)
	var ahead := _flat(game.flow.beacon.global_position - spot) if is_instance_valid(game.flow.beacon) else Vector3.BACK
	if heading_arg != INF:
		ahead = Vector3(cos(heading_arg), 0.0, sin(heading_arg))
	await _place(spot, ahead)
	await _ticks(600)
	var cam := root.get_camera_3d().global_position
	var hidden := Vector3.INF
	var seen := Vector3.INF
	var profile := []
	var d := SEARCH_FROM
	while d <= SEARCH_TO:
		var at := spot + ahead * d
		var y := Telegraph.ground_under(ground, at)
		var spot_y := Vector3(at.x, y, at.z)
		var gap := _cover(ground, cam, spot_y)
		profile.append([snappedf(d, 0.1), snappedf(y, 0.1), snappedf(gap, 0.1)])
		if hidden == Vector3.INF and gap >= HIDE_BY and d > 14.0:
			hidden = spot_y
		if seen == Vector3.INF and gap <= 0.0 and d >= 10.0 and d <= 18.0:
			seen = spot_y
		d += 2.0
	print("PF52 camera %s ball %s heading %s profile %s" % [cam, spot, ahead, str(profile)])
	if hidden == Vector3.INF:
		return _fail("no spot ahead of the camera is hidden by terrain; try --ball= and --heading=")
	if seen == Vector3.INF:
		return _fail("no spot ahead of the camera is in plain view")
	await _shot("hidden", hidden, spot, ahead, ground)
	await _shot("visible", seen, spot, ahead, ground)
	if failed != "":
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "pf52_occlusion_still.gd", "size": [size.x, size.y], "tone_distance": TONE_DISTANCE,
		"tone": "ff5a3c",
		"adapter": RenderingServer.get_video_adapter_name(), "look": Threat.look(), "frames": records}, "\t"))
	file.close()
	quit(0)


# How far the ground stands above the camera's sight line to `point`, the most over its length
# (positive: the ground hides the point; negative: the line clears it).
func _cover(ground, cam: Vector3, point: Vector3) -> float:
	var worst := -INF
	for i in range(1, 40):
		var t := float(i) / 40.0
		var p := cam.lerp(point, t)
		var h := Telegraph.ground_under(ground, p)
		worst = maxf(worst, h - p.y)
	return worst


func _shot(id: String, at: Vector3, ball: Vector3, ahead: Vector3, ground) -> void:
	if failed != "":
		return
	await _place(ball, ahead)
	var ring = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, at, RADIUS)
	ring.set_progress(1.0)
	ring.free()
	paused = true
	await _frames(3)
	var flash = _flash()
	if flash == null:
		paused = false
		return _fail("%s: no landing flash is live" % id)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out.path_join("%s.png" % id)
	if image.save_png(path) != OK:
		paused = false
		return _fail("could not save %s" % path)
	var tone := Color("ff5a3c")
	var near := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := image.get_pixel(x, y)
			if Vector3(c.r - tone.r, c.g - tone.g, c.b - tone.b).length() < TONE_DISTANCE:
				near += 1
	var share := float(near) / float((w / 2) * (h / 2))
	records.append({"id": id, "at": [at.x, at.y, at.z], "tone_share": snappedf(share, 0.0001), "sha256": FileAccess.get_sha256(path)})
	print("PF52 shot %s tone_share %.4f" % [id, share])
	paused = false
	flash.queue_free()
	await _ticks(2)


# The live landing Flash: the node with a tone and a fill, under the game's root.
func _flash():
	for node in game.ctx.root.get_children():
		if node.get("_tone") != null and node.get("_fill") != null and node.is_inside_tree():
			return node
	return null


func _place(point: Vector3, heading: Vector3, settle := SETTLE) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	await _frames(settle)


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("pf52_occlusion_still: %s" % why)
	paused = false
	quit(4)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()
