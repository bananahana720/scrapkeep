extends SceneTree
# SCRATCH ONLY (PC lane jobs BB and BC, 14 Nov 2026): never for the repo's tests or a game branch.
# SCRATCH ONLY (PC job BM, PR 1023 stills; based on job BB/BC w41_stills.gd). Rendered stills for PR 957 (dam yard fight bowl) and PR 1009 (survey posts, flume muster, camp ring).
# Set-ups follow the PRs' own tests: dam_incline_yard_test, survey_posts_test, stocktake_muster_test, camp_ring_test.
#   gamescope ... -- <godot> --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 \
#     --script res://tools/w41_stills.gd -- --out=<abs dir> --mode=bowl|posts1|posts2|muster|ring
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SIZE := Vector2i(1920, 1080)

var out := ""
var mode := ""
var game

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	if out.is_empty() or mode.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _save(name: String) -> void:
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-%s.png" % [out, mode, name])
	print("STILL ", mode, "-", name)

func _hide_ui() -> void:
	if game.get("presentation") != null:
		game.presentation.hide_ui()
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# A still from a camera above and behind a point, looking down on it.
func _overview(name: String, at: Vector3, back: Vector3, up: float) -> void:
	var play: Camera3D = root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.global_position = at + back + Vector3.UP * up
	cam.look_at(at, Vector3.UP)
	cam.make_current()
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(cam)
	await _save(name)
	if play != null:
		play.make_current()
		for t in root.find_children("*", "Terrain3D", true, false):
			t.set_camera(play)
	cam.queue_free()

func _boot(table: String) -> void:
	game = Game.new()
	game.test_mode = true
	game.table = table
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame

func _start() -> void:
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)

func _run() -> void:
	seed(1)
	match mode:
		"bowl":
			await _bowl()
		"posts1":
			await _posts(1)
		"posts2":
			await _posts(2)
		"muster":
			await _muster()
		"ring":
			await _ring()
		"approach":
			await _approach()
		"yard":
			await _yard()
		_:
			print("STILL unknown mode ", mode)
			quit(2)
			return
	quit(0)

# PR 957: ride down the incline at x 0 at cruise (dam_incline_yard_test), let the yard shut, hold a few seconds.
func _bowl() -> void:
	await _boot("park")
	await _start()
	await _frames(120)
	var locks = game.flow.gate
	print("STILL bowl lock_state before ", locks.lock_state)
	var cruise: float = game.player.tuning.tier_cruise()
	game.player.body().global_position = game.ctx.terrain.drop_point(0.0, 330.0, 1.0)
	game.player.set_velocity_now(Vector3(0.0, 0.0, cruise), "probe")
	var t := 0.0
	while t < 12.0 and locks.lock_state != "locked":
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
	print("STILL bowl lock_state ", locks.lock_state, " after ", snappedf(t, 0.1), " s")
	await _frames(int(2.5 * Engine.physics_ticks_per_second))
	_hide_ui()
	var ball: Vector3 = game.player.ball_position()
	var c: Vector3 = locks.lock_centre if locks.lock_state == "locked" else ball
	print("STILL bowl ball ", ball, " centre ", c, " ground at ball ", game.ctx.terrain.height(ball.x, ball.z))
	await _save("play")
	await _overview("overview", c, Vector3(0, 0, -70), 45.0)
	await _overview("side", c, Vector3(-75, 0, 0), 14.0)

# PR 1009: posts on (survey_posts_test set-up, run seed 7), roll through the first row at 14 m/s.
func _posts(stage: int) -> void:
	await _boot("park")
	game.ctx.rng.seed = 23
	await _start()
	game.run.run_seed = 7
	game.ctx.tuning.set_option("posts", "on")
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await _frames(4)
	var posts = game.world.survey_posts
	print("STILL posts stage ", stage, " rows ", posts.standing.size())
	if posts.standing.is_empty():
		return
	var row: Dictionary = posts.standing[0]
	var p0: Vector3 = row["posts"][0].global_position
	var p4: Vector3 = row["posts"][4].global_position
	var heading := (p4 - p0)
	heading.y = 0.0
	heading = heading.normalized()
	var at := p0 - heading * 30.0
	game.player.reset_to(game.ctx.terrain.drop_point(at.x, at.z, 1.0), heading * 14.0)
	_hide_ui()
	var shot_rest := false
	for i in int(6.0 * Engine.physics_ticks_per_second):
		game.player.set_velocity_now(heading * 14.0 + Vector3.UP * game.player.state.velocity.y)
		await physics_frame
		var ball: Vector3 = game.player.ball_position()
		var along := (ball - p0).dot(heading)
		if not shot_rest and along > -12.0:
			shot_rest = true
			await _save("approach")
		if along > (p4 - p0).dot(heading) * 0.5:
			break
	await _save("through")
	for i in 12:
		await physics_frame
	await _save("falling")
	print("STILL posts hit ", row["hit"], " of 5")
	for i in 90:
		await process_frame
	await _overview("row", (p0 + p4) * 0.5, Vector3(-heading.z, 0, heading.x) * 22.0 - heading * 10.0, 9.0)

# PR 1009: flume muster on (stocktake_muster_test set-up): a called run seed, the siren near the row, then the ring lands.
func _muster() -> void:
	await _boot("park")
	await _start()
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	game.ctx.tuning.set_option("stocktake", "on")
	var acts = game.world.activities
	var map = game.ctx.terrain.map()
	var called := -1
	for s in 60:
		game.run.run_seed = s
		if not acts.survival_spec(map, "stocktake_muster").is_empty():
			called = s
			break
	print("STILL muster called seed ", called)
	if called < 0:
		return
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	var site = acts.site("stocktake_muster")
	if site == null:
		print("STILL muster no site")
		return
	var row := Vector2(site.global_position.x, site.global_position.z)
	var near: Vector3 = game.ctx.terrain.drop_point(row.x - float(site.rule["call_m"]) + 20.0, row.y, 1.05)
	var siren := float(site.rule["siren_s"])
	for i in int((siren + 1.5) * Engine.physics_ticks_per_second):
		if site.started:
			break
		game.player.reset_to(near, Vector3.ZERO)
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	print("STILL muster started ", site.started, " visible ", site.visible)
	await _frames(int(3.0 * Engine.physics_ticks_per_second))
	_hide_ui()
	await _save("play")
	var ring: Vector3 = site.global_position
	print("STILL muster site at ", ring, " ground ", game.ctx.terrain.height(ring.x, ring.z))
	await _overview("overview", ring, Vector3(0, 0, -55), 38.0)
	await _overview("side", ring, Vector3(-60, 0, 0), 12.0)

# PR 1009: the camp ring (camp_ring_test set-up): into the camp, onto the yard, begin the ring.
func _ring() -> void:
	await _boot("alpha")
	await physics_frame
	var hub = game.camp_hub
	hub.ensure_built()
	var ring: Node = hub.root.get_node_or_null("CampRing")
	if ring == null:
		print("STILL ring none")
		return
	game.screens.toggle_camp()
	await physics_frame
	var yard: Vector3 = hub.piece("camp_sandbox_yard").global_position
	game.player.reset_to(yard + Vector3.UP * 1.5, Vector3.ZERO)
	await _frames(30)
	ring.begin()
	print("STILL ring running ", ring.running(), " count ", ring.count.count if ring.get("count") != null else -1)
	await _frames(int(4.0 * Engine.physics_ticks_per_second))
	_hide_ui()
	await _save("play")
	await _overview("overview", ring.board.global_position, Vector3(0, 0, -30), 20.0)


# PR 1023: the dam yard's gate and stand (stocktake_yard_test set-up): a run seed that plans the yard, flag on.
func _yard() -> void:
	await _boot("park")
	await _start()
	await _frames(4)
	game.ctx.tuning.set_option("stocktake", "on")
	var acts = game.world.activities
	var map = game.ctx.terrain.map()
	var called := -1
	for s in 60:
		game.run.run_seed = s
		if not acts.survival_spec(map, "stocktake_yard").is_empty():
			called = s
			break
	print("STILL yard seed ", called)
	if called < 0:
		return
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(30)
	var site = acts.site("stocktake_yard")
	if site == null:
		print("STILL yard no site")
		return
	var dress = site.get("yard_dress")
	print("STILL yard at ", site.global_position, " dress ", dress != null)
	_hide_ui()
	var c: Vector3 = site.global_position
	var ring := float(site.rule["ring"])
	if dress != null:
		var g: Vector3 = dress._gate.global_position if dress.get("_gate") != null else c
		var out := (g - c)
		out.y = 0.0
		out = out.normalized()
		await _overview("overview", c, out * (ring + 30.0) + Vector3(-out.z, 0, out.x) * 15.0, 30.0)
		await _overview("gate", g, out * 16.0 + Vector3(-out.z, 0, out.x) * 8.0, 5.0)
	else:
		await _overview("overview", c, Vector3(0, 0, -(ring + 30.0)), 30.0)

# PR 1028: the approach to Brindle's bowl on the flume (bowl_approach_test set-up), flag on.
func _cam_at(name: String, from: Vector3, at: Vector3, fov: float) -> void:
	var play: Camera3D = root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 4000.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.make_current()
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(cam)
	await _save(name)
	if play != null:
		play.make_current()
		for t in root.find_children("*", "Terrain3D", true, false):
			t.set_camera(play)
	cam.queue_free()

func _approach() -> void:
	await _boot("park")
	game.ctx.rng.seed = 23
	await _start()
	game.run.run_seed = 2026
	game.ctx.tuning.set_option("approach", "on")
	var terrain = game.ctx.terrain
	var named := 0
	for stage in [1, 2]:
		if not terrain.map_for(stage).approach.is_empty():
			named = stage
	game.flow.enter_stage(named, Vector3.ZERO, false)
	await _frames(30)
	var ap = game.world.bowl_approach
	print("STILL approach stage ", named, " racks ", ap.racks.size(), " bridge ", not ap.bridge.is_empty())
	if ap.bridge.is_empty():
		return
	_hide_ui()
	var plate: Vector3 = ap.bridge["at"]
	var h2: Vector2 = ap.bridge["heading"]
	var heading := Vector3(h2.x, 0.0, h2.y).normalized()
	# (1) Roll across the weighbridge at 14 m/s; shoot just after the ball crosses it.
	var start := plate - heading * 30.0
	game.player.reset_to(terrain.drop_point(start.x, start.z, 1.0), heading * 14.0)
	var crossed := false
	for i in int(6.0 * Engine.physics_ticks_per_second):
		game.player.set_velocity_now(heading * 14.0 + Vector3.UP * game.player.state.velocity.y)
		await physics_frame
		if (game.player.ball_position() - plate).dot(heading) > 4.0:
			crossed = true
			break
	print("STILL approach crossed ", crossed, " weighed ", ap.weighed)
	await _save("bridge-cross")
	for i in 20:
		await physics_frame
	await _save("bridge-after")
	await _overview("bridge-overview", plate, -heading * 18.0 + Vector3(-heading.z, 0, heading.x) * 10.0, 8.0)
	# (2) A tag rack with its crates, from the chase camera, ball parked short of it.
	var row: Dictionary = ap.racks[0]
	var crate0: Vector3 = row["crates"][0].global_position
	var to_rack := crate0 - plate
	to_rack.y = 0.0
	var park := crate0 + (heading * -1.0) * 14.0
	game.player.reset_to(terrain.drop_point(park.x, park.z, 1.0), heading * 2.0)
	for i in 120:
		game.player.set_velocity_now(heading * 2.0 + Vector3.UP * game.player.state.velocity.y)
		await physics_frame
	print("STILL approach rack crates ", row["crates"].size(), " at ", crate0, " burst so far ", ap.crates_burst)
	await _save("rack-play")
	await _overview("rack-overview", crate0, -heading * 10.0 + Vector3(-heading.z, 0, heading.x) * 6.0, 5.0)
	# (3) The furnace smoke column, from the bridge and from the tally fields.
	var works: Vector3 = ap.furnace_home()
	var aim := works + Vector3.UP * 40.0
	print("STILL approach furnace at ", works)
	var eye := plate + Vector3.UP * 2.0
	await _cam_at("smoke-from-bridge", eye, aim, 70.0)
	var tf := Vector3(-242.0, terrain.height(-242.0, 65.0) + 2.5, 65.0)
	await _cam_at("smoke-from-tally", tf, aim, 70.0)
