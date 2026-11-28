extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SETTLE := 45
const WAIT_TICKS := 2400
const LANDED := 1.6
const RADIUS := 5.0
const TONE_DISTANCE := 0.12
const CHANGE_DISTANCE := 0.06
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
	if out.is_empty() or AppShell.headless():
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
	var convex := Vector3.INF
	var best := 0.12
	for dd in range(6, 40, 2):
		for side in range(-24, 25, 3):
			var at := spot + ahead * dd + ahead.cross(Vector3.UP) * side
			var spot_c := Vector3(at.x, Telegraph.ground_under(ground, at), at.z)
			var bulge := _bulge(ground, spot_c)
			if bulge > best and _in_view(ground, cam, spot_c):
				best = bulge
				convex = spot_c
	print("PF52 convex spot %s bulge %.2f m" % [convex, best])
	await _shot("hidden", hidden, spot, ahead, ground)
	await _shot("visible", seen, spot, ahead, ground)
	await _shot("live_hidden", hidden, spot, ahead, ground, true)
	if convex == Vector3.INF:
		return _fail("no plain-view spot bulges 0.12 m over the ground round it; try --ball= and --heading=")
	await _shot("live_convex", convex, spot, ahead, ground, true)
	if failed != "":
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "pf52_occlusion_still.gd", "size": [size.x, size.y], "tone_distance": TONE_DISTANCE,
		"tone": "ff5a3c",
		"adapter": RenderingServer.get_video_adapter_name(), "look": Threat.look(), "convex_bulge_m": best, "frames": records}, "\t"))
	file.close()
	quit(0)


func _cover(ground, cam: Vector3, point: Vector3) -> float:
	var worst := -INF
	for i in range(1, 40):
		var t := float(i) / 40.0
		var p := cam.lerp(point, t)
		var h := Telegraph.ground_under(ground, p)
		worst = maxf(worst, h - p.y)
	return worst


func _shot(id: String, at: Vector3, ball: Vector3, ahead: Vector3, ground, live := false) -> void:
	if failed != "":
		return
	await _place(ball, ahead)
	paused = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var base_image := root.get_texture().get_image()
	paused = false
	var ring = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, at, RADIUS)
	if live:
		ring.lands_on_live = false
	ring.set_progress(1.0)
	var flash = null
	if live:
		await _frames(3)
		if not is_instance_valid(ring) or not ring.is_hostile() or ring.progress < 1.0:
			return _fail("%s: the telegraph is not live" % id)
	else:
		flash = _flash(ring.get_parent())
		ring.free()
	paused = true
	await _frames(3)
	if not live and flash == null:
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
	var changed := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := image.get_pixel(x, y)
			if Vector3(c.r - tone.r, c.g - tone.g, c.b - tone.b).length() < TONE_DISTANCE:
				near += 1
			var o := base_image.get_pixel(x, y)
			if Vector3(c.r - o.r, c.g - o.g, c.b - o.b).length() > CHANGE_DISTANCE:
				changed += 1
	var total := float((w / 2) * (h / 2))
	records.append({"id": id, "live_telegraph": live, "at": [at.x, at.y, at.z], "tone_share": snappedf(near / total, 0.0001),
		"changed_share": snappedf(changed / total, 0.0001), "sha256": FileAccess.get_sha256(path)})
	print("PF52 shot %s tone_share %.4f changed_share %.4f" % [id, near / total, changed / total])
	paused = false
	if flash != null:
		flash.queue_free()
	if live and is_instance_valid(ring):
		ring.free()
	await _ticks(2)


func _in_view(ground, cam: Vector3, at: Vector3) -> bool:
	if _cover(ground, cam, at) > 0.0:
		return false
	var clear := 0
	for i in 8:
		var a := TAU * i / 8.0
		var p := at + Vector3(cos(a), 0.0, sin(a)) * RADIUS
		p.y = Telegraph.ground_under(ground, p)
		if _cover(ground, cam, p) <= 0.0:
			clear += 1
	return clear >= 6


func _bulge(ground, at: Vector3) -> float:
	var rim := 0.0
	for i in 8:
		var a := TAU * i / 8.0
		rim += Telegraph.ground_under(ground, at + Vector3(cos(a), 0.0, sin(a)) * RADIUS)
	return Telegraph.ground_under(ground, at) - rim / 8.0


func _flash(parent: Node):
	for node in parent.get_children():
		if node is Threat.Flash:
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
