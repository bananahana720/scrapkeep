extends "res://tools/bot_run.gd"
# Scratch (untracked, never committed): in-game art stills from a live run on the real renderer.
#   -- --shots=<abs dir> --mode=main|static|camp  [bot_run flags: --table=park --policy=skipper --pilot=pylon_engineer --seeds=N --from-stage=N --until=N]
# main   : a bot run; each subject is shot the first time the game's own camera frames it unoccluded (chase), then a
#          temporary Camera3D is placed near it and aimed at it (close), then the game camera is restored.
# static : a bot run that stops to place the ball (teleport, frozen) in front of fixed things (dam, tower, trade sites)
#          and, for kinds the run did not field, asks the game's own spawner for one; the game camera frames it.
# camp   : the walkable camp, ball placed in front of the launch gate and Moss's stall.
# Output: <shots>/<subject>-<chase|close>.png and rows appended to <shots>/shots.tsv.

const WorldLook := preload("res://src/presentation/world_look.gd")
const Intent := preload("res://src/movement/intent.gd")
const GameScript := preload("res://src/game.gd")

var _as_dir := ""
var _as_mode := "main"
var _as_hooked = null
var _as_done := {}
var _as_busy := false
var _as_tick := 0
var _as_arena := false
var _as_static_started := {}
var _as_cg
var _as_want: Array = []
var _as_static_stage := 0
var _as_last_stagger_msec := 0


func _initialize() -> void:
	var a := _parse(OS.get_cmdline_user_args())
	_as_dir = String(a.get("shots", ""))
	_as_mode = String(a.get("mode", "main"))
	if DisplayServer.get_name() == "headless" or _as_dir == "":
		printerr("art_stills: needs a rendered display and --shots=<abs dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_as_dir)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if not FileAccess.file_exists(_as_dir.path_join("shots.tsv")):
		var f := FileAccess.open(_as_dir.path_join("shots.tsv"), FileAccess.WRITE)
		f.store_string("subject\tcamera\tfile\tstage\tgame_time_s\tlighting\tnote\n")
		f.close()
	process_frame.connect(_as_frame)
	if _as_mode == "camp":
		_camp_start.call_deferred()
		return
	super._initialize()


# --------------------------------------------------------------------------- shared helpers

func _lighting() -> String:
	var g = _as_cg if _as_cg != null else _game
	var parts := ""
	if _as_mode == "camp":
		parts = "camp look (WorldLook.CAMP: late-afternoon sun, hdri sky graded afternoon), fixed"
	elif _as_arena:
		parts = "noon (Brindle arena, WorldLook.DAYLIT_ARENAS brindle->noon), fixed for the fight"
	else:
		var st: int = g.run.stage
		parts = "%s (WorldLook.STAGE_TIME[%d], fixed for the whole stage; no day arc inside a stage)" % [WorldLook.time_id(st), st]
	var best: DirectionalLight3D = null
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l is DirectionalLight3D and l.is_visible_in_tree() and (best == null or l.light_energy > best.light_energy):
			best = l
	if best != null:
		parts += "; live sun pitch=%.0f yaw=%.0f energy=%.2f color=#%s" % [best.rotation_degrees.x, best.rotation_degrees.y, best.light_energy, best.light_color.to_html(false)]
	return parts


func _game_time() -> float:
	if _driver != null:
		return _driver.ticks / float(Engine.physics_ticks_per_second)
	return Time.get_ticks_msec() / 1000.0


func _save(subject: String, camera: String, note: String) -> void:
	var img := root.get_texture().get_image()
	var lum := 0.0
	var n := 0
	for y in range(20, img.get_height(), 60):
		for x in range(20, img.get_width(), 60):
			lum += img.get_pixel(x, y).get_luminance()
			n += 1
	var file := "%s-%s.png" % [subject, camera]
	img.save_png(_as_dir.path_join(file))
	var g = _as_cg if _as_cg != null else _game
	var row := "%s\t%s\t%s\t%d\t%.1f\t%s\t%s" % [subject, camera, file, g.run.stage, _game_time(), _lighting(),
		note + " | size=%dx%d mean_lum=%.3f stage_time=%.1f" % [img.get_width(), img.get_height(), lum / maxf(n, 1.0), g.run.stage_time]]
	var f := FileAccess.open(_as_dir.path_join("shots.tsv"), FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line(row)
	f.close()
	print("art_stills: SHOT ", row)


# t: {aim: Vector3, close_d, close_h, side (deg, default 35), note}
func _frame_ok(t: Dictionary) -> bool:
	var cam := root.get_camera_3d()
	if cam == null:
		return false
	var p: Vector3 = t.aim
	if cam.is_position_behind(p):
		return false
	var sp := cam.unproject_position(p)
	if not Rect2(Vector2(330, 190), Vector2(1260, 700)).has_point(sp):
		return false
	var d := cam.global_position.distance_to(p)
	if d < float(t.get("min_d", 3.0)) or d > float(t.get("max_d", 70.0)):
		return false
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit.position.distance_to(p) > float(t.get("slack", 4.0)):
		return false
	return true


func _shoot(subject: String, t: Dictionary, with_close := true) -> void:
	_as_busy = true
	var cam := root.get_camera_3d()
	await RenderingServer.frame_post_draw
	if t.has("node") and is_instance_valid(t.node) and t.has("lift"):
		t["aim"] = t.node.global_position + Vector3.UP * float(t.lift)
	if t.get("recheck", true) and not _frame_ok(t):
		_as_busy = false
		return
	cam = root.get_camera_3d()
	_save(subject, "chase", String(t.get("note", "")) + " | cam_dist=%.1f screen=%s" % [cam.global_position.distance_to(t.aim), str(cam.unproject_position(t.aim).round())])
	if with_close:
		await _close(subject, t)
	_as_done[subject] = true
	_as_busy = false


func _close(subject: String, t: Dictionary) -> void:
	var g = _as_cg if _as_cg != null else _game
	var prev := root.get_camera_3d()
	var ball: Vector3 = g.player.ball_position()
	var aim: Vector3 = t.aim
	var toward := Vector3(ball.x - aim.x, 0.0, ball.z - aim.z)
	if toward.length() < 0.5:
		toward = Vector3(0, 0, 1)
	toward = toward.normalized().rotated(Vector3.UP, deg_to_rad(float(t.get("side", 35.0))))
	var d := float(t.get("close_d", 8.0))
	var h := float(t.get("close_h", 2.0))
	var space := prev.get_world_3d().direct_space_state
	var pos := aim + toward * d + Vector3.UP * h
	if t.get("scan_az", false):
		for az in [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 180.0]:
			var cand: Vector3 = aim + toward.rotated(Vector3.UP, deg_to_rad(az)) * d + Vector3.UP * h
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(aim, cand, 1)).is_empty():
				pos = cand
				break
	for i in 6:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim, pos, 1))
		if hit.is_empty():
			break
		d *= 0.75
		pos = aim + toward * d + Vector3.UP * h
	var c := Camera3D.new()
	c.fov = float(t.get("fov", 55.0))
	c.near = 0.1
	c.far = 3000.0
	g.add_child(c)
	var off := pos - aim
	c.global_position = pos
	c.look_at(aim, Vector3.UP)
	c.make_current()
	for i in 3:
		await process_frame
		if t.has("node") and is_instance_valid(t.node):
			aim = t.node.global_position + Vector3.UP * float(t.get("lift", 0.0))
			c.global_position = aim + off
			c.look_at(aim, Vector3.UP)
	await RenderingServer.frame_post_draw
	_save(subject, "close", String(t.get("note", "")) + " | temp Camera3D at %.1f m (fov %.0f), aimed at node; ball %.1f m from subject" % [pos.distance_to(aim), c.fov, ball.distance_to(aim)])
	prev.make_current()
	c.queue_free()
	await process_frame


func _bounds(node: Node3D, limit: float) -> AABB:
	var out := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D) or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.size.length() > limit:
			continue
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	if first:
		return AABB(node.global_position - Vector3.ONE, Vector3.ONE * 2.0)
	return out


func _enemy(kind: String) -> Array:
	var out := []
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and str(e.get("kind")) == kind:
			out.append(e)
	return out


# --------------------------------------------------------------------------- main mode

func _as_hook() -> void:
	_as_hooked = _game
	var ev = _game.ctx.events
	ev.stage_entered.connect(func(_s: int, _r: bool): _as_arena = false)
	ev.boss_arena_entered.connect(func(): _as_arena = true)
	ev.posture_changed.connect(func(e, _p, stg):
		if stg:
			_as_last_stagger_msec = Time.get_ticks_msec()
			_on_stagger(e))


var _as_stagger_pending: Node = null


func _on_stagger(e) -> void:
	_as_stagger_pending = e


func _as_frame() -> void:
	if _as_mode == "camp" or _game == null or not is_instance_valid(_game) or _game.get("ctx") == null or _game.ctx.get("events") == null or _game.flow == null:
		return
	if _as_hooked != _game:
		_as_hook()
	if _as_busy:
		return
	_as_tick += 1
	if _as_mode == "static":
		_static_poll()
		return
	if _as_tick % 4 != 0 or not _game.flow.in_play():
		return
	var st: int = _game.run.stage
	var stime: float = _game.run.stage_time
	# Sable's ball at launch: stage 1, first moments after the run starts.
	if not _as_done.has("ball-launch") and st == 1 and stime > 0.8 and stime < 6.0:
		var b: Vector3 = _game.player.ball_position()
		_shoot("sable-ball-launch", {"aim": b + Vector3(0, 0.4, 0), "node": _game.player.body(), "lift": 0.4, "close_d": 3.2, "close_h": 1.0, "side": 40.0, "min_d": 1.0, "max_d": 30.0, "slack": 100.0,
			"note": "pilot pylon_engineer (Sable); first seconds of the run in the dam; ball is the subject"})
		_as_done["ball-launch"] = true
		return
	# staggered Warden: weak point open
	if _as_stagger_pending != null and is_instance_valid(_as_stagger_pending):
		var e: Node = _as_stagger_pending
		if str(e.get("kind")) == "warden" and not _as_done.has("warden-weakpoint") and e.has_method("family_point_at"):
			if Time.get_ticks_msec() - _as_last_stagger_msec > 350:
				_as_stagger_pending = null
				var at: Vector3 = e.family_point_at()
				var open: bool = e.family_open()
				var t := {"aim": at, "close_d": 7.0, "close_h": 2.0, "min_d": 3.0, "max_d": 120.0, "slack": 12.0,
					"note": "Warden staggered, family point '%s' open=%s (warden.gd family_open); aim at family_point_at()" % [e.family_point(), str(open)]}
				if open and _frame_ok(t):
					_shoot("warden-weakpoint", t)
					_as_done["warden-weakpoint"] = true
					return
		elif str(e.get("kind")) == "brindle_hull" or e.get_script() != null and "brindle" in str(e.get("kind")):
			if Time.get_ticks_msec() - _as_last_stagger_msec > 350 and not _as_done.has("brindle-weakpoint"):
				_as_stagger_pending = null
				var ship = e.boss.ship if e.get("boss") != null else null
				if ship != null and is_instance_valid(ship):
					var ck: Node3D = ship._cockpit
					var t2 := {"aim": ck.global_position, "close_d": 9.0, "close_h": 3.0, "min_d": 4.0, "max_d": 140.0, "slack": 12.0,
						"note": "Brindle staggered: cockpit opened (boss.gd _sync_stagger -> ship.cockpit_open); cockpit visible=%s" % str(ck.visible)}
					if _frame_ok(t2):
						_shoot("brindle-weakpoint", t2)
						_as_done["brindle-weakpoint"] = true
						return
	# opportunistic enemies
	var table := {
		"lobber": {"close_d": 6.0, "close_h": 1.5, "max_d": 60.0, "lift": 1.2},
		"boom_tender": {"close_d": 8.0, "close_h": 2.0, "max_d": 60.0, "lift": 2.0},
		"foreman": {"close_d": 9.0, "close_h": 2.5, "max_d": 70.0, "lift": 2.0},
		"bola_thrower": {"close_d": 8.0, "close_h": 2.0, "max_d": 60.0, "lift": 1.5},
		"netcaster": {"close_d": 9.0, "close_h": 3.0, "max_d": 60.0, "lift": 2.5},
		"rogue_crane": {"close_d": 26.0, "close_h": 8.0, "max_d": 90.0, "lift": 6.0, "box_limit": 40.0},
		"warden": {"close_d": 32.0, "close_h": 8.0, "max_d": 110.0, "lift": 8.0, "slack": 25.0, "box_limit": 30.0},
		"brindle_hull": {"close_d": 40.0, "close_h": 12.0, "max_d": 140.0, "lift": 3.0, "slack": 25.0},
	}
	for kind in table:
		var name: String = {"brindle_hull": "brindle-ship", "boom_tender": "boom-tender", "bola_thrower": "bola-thrower", "rogue_crane": "rogue-crane-no14"}.get(kind, kind)
		if _as_done.has(name):
			continue
		for e in _enemy(kind):
			var spec: Dictionary = table[kind].duplicate()
			var aim: Vector3 = e.global_position + Vector3.UP * float(spec.get("lift", 1.5))
			if kind == "brindle_hull" and e.get("boss") != null and e.boss.ship != null:
				aim = e.boss.ship.global_position + Vector3.UP * 4.0
				e = e.boss.ship
			else:
				var bb := _bounds(e, float(spec.get("box_limit", 8.0)))
				aim = bb.get_center()
				spec["close_d"] = clampf(bb.size.length() * 1.9, float(spec.close_d) * 0.6, float(spec.close_d) * 1.6)
				spec["lift"] = aim.y - e.global_position.y
			spec["aim"] = aim
			spec["node"] = e
			spec["note"] = "live %s node %s at stage_time %.1f" % [kind, e.name, stime]
			if _frame_ok(spec):
				_shoot(name, spec)
				return


# --------------------------------------------------------------------------- static mode

var _as_static_busy := false


func _static_poll() -> void:
	if _as_static_busy or not _game.flow.in_play():
		return
	if _game.run.stage_time < 2.0:
		return
	_as_static_busy = true
	_static_run.call_deferred()


func _wait_phys(n: int) -> void:
	for i in n:
		await physics_frame


func _place_ball(at: Vector3, face: Vector3, pitch := -0.18) -> void:
	_game.player.set_frozen(false)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_game.player.set_frozen(true)
	_game.camera.snap(face - at, pitch)


func _static_run() -> void:
	_game.run.set_max_hp(999999.0)
	_game.ctx.calm = true
	var terr = _game.ctx.terrain
	var stage: int = _game.run.stage
	var picks: Array = String(_parse(OS.get_cmdline_user_args()).get("subjects", "")).split(",", false)
	print("art_stills: static run stage %d subjects %s" % [stage, str(picks)])
	for n in _game.find_children("*", "Node3D", true, false):
		if String(n.name).begins_with("Activity_"):
			print("art_stills: site ", n.name, " at ", n.global_position, " class ", n.get_class(), " in_tree ", n.is_inside_tree())
	# trade sites
	for n in _game.find_children("Activity_trade_*", "Node3D", true, false):
		var which := "risky-trade" if String(n.name).ends_with("risk") else "safe-trade"
		if which not in picks and "trade" not in picks:
			continue
		var site: Node3D = n
		var centre := site.global_position
		var door: Array = site.get("interior").get("entrances", [{"at": [0, 12]}])[0].get("at", [0, 12]) if site.get("interior") is Dictionary and not site.get("interior").is_empty() else [0, 12]
		var door_w := site.to_global(Vector3(door[0], 0, door[1]))
		var out := Vector3(door_w.x - centre.x, 0, door_w.z - centre.z)
		if out.length() < 1.0:
			out = Vector3(0, 0, 1)
		out = out.normalized()
		var stand := centre + out * 17.0
		var gp: Vector3 = terr.drop_point(stand.x, stand.z, 2.0)
		var space = _game.get_world_3d().direct_space_state
		for az in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
			var cs: Vector3 = centre + out.rotated(Vector3.UP, deg_to_rad(az)) * 17.0
			var cg: Vector3 = terr.drop_point(cs.x, cs.z, 2.0)
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(cg + Vector3.UP * 3.0, centre + Vector3.UP * 1.5, 1)).is_empty():
				stand = cs
				gp = cg
				break
		var hd := Vector3(centre.x - gp.x, 0.0, centre.z - gp.z).rotated(Vector3.UP, deg_to_rad(17.0))
		_place_ball(gp, gp + hd, -0.2)
		await _wait_phys(120)
		var devices := []
		for c in site.get_children():
			if c.get_script() != null and "spent" in c:
				devices.append(c)
		var aim := centre + Vector3.UP * 1.5
		var prices := site.get_node_or_null("TradePrices")
		var t := {"aim": aim, "scan_az": true, "close_d": 15.0, "close_h": 7.0, "side": 0.0, "min_d": 3.0, "max_d": 200.0, "slack": 100.0,
			"note": "%s site node %s (activities.gd trade rule %s), %d devices; ball teleported+frozen 17 m from the site on the first azimuth with a clear line, camera.snap yawed 17 deg off the site so the ball does not cover it%s" % [
				which, site.name, str(site.get("rule").get("pay", {}).get("source", "?")) if site.get("rule") is Dictionary else "?", devices.size(),
				" | prices label: " + prices.text.replace("\n", " / ") if prices != null else ""]}
		await _shoot_static(which, t)
	# dam / tower landmarks
	for lm in [["Landmark_spillway_dam", "dam", Vector3(0, 70, 0), 130.0, 60.0], ["Landmark_penstock_tower", "penstock-tower", Vector3(0, 45, 58.3), 130.0, 60.0]]:
		if lm[1] not in picks:
			continue
		var node := _game.find_child(lm[0], true, false) as Node3D
		if node == null:
			continue
		var aim: Vector3 = node.to_global(lm[2])
		var stand := node.to_global(Vector3(lm[2].x, 0.0, lm[2].z + lm[3]))
		var gp: Vector3 = terr.drop_point(stand.x, stand.z, 2.0)
		_place_ball(gp, Vector3(aim.x, gp.y + 20.0, aim.z), 0.12)
		await _wait_phys(150)
		var t2 := {"aim": aim, "close_d": 260.0 if lm[1] == "dam" else 150.0, "close_h": 50.0, "side": 50.0, "fov": 60.0, "min_d": 3.0, "max_d": 900.0, "slack": 1000.0,
			"note": "landmark node %s; ball teleported+frozen %.0f m in front, game camera snapped toward it (pitch up)" % [lm[0], lm[3]]}
		await _shoot_static(lm[1], t2)
	# fielded kinds via the game's own spawner
	for kind in ["bola_thrower", "netcaster", "foreman"]:
		var nm: String = kind.replace("_", "-")
		if nm not in picks:
			continue
		var b: Vector3 = _game.player.ball_position()
		var fwd := Vector3(-sin(_game.camera.yaw), 0, -cos(_game.camera.yaw)).rotated(Vector3.UP, deg_to_rad(-26.0))
		var at: Vector3 = terr.drop_point(b.x + fwd.x * 17.0, b.z + fwd.z * 17.0, 0.0)
		var e = _game.ctx.spawner.spawn_enemy(kind, at)
		await _wait_phys(120)
		if e == null or not is_instance_valid(e):
			print("art_stills: spawn of %s failed" % kind)
			continue
		_place_ball(b, e.global_position)
		await _wait_phys(90)
		var bb2 := _bounds(e, 8.0)
		var t3 := {"aim": bb2.get_center(), "node": e, "lift": bb2.get_center().y - e.global_position.y, "close_d": clampf(bb2.size.length() * 1.9, 6.0, 14.0), "close_h": 2.5, "min_d": 3.0, "max_d": 80.0, "slack": 6.0,
			"note": "not fielded by the skipper run's director; spawned by the game's own spawner (ctx.spawner.spawn_enemy) 17 m ahead of the ball, 26 deg off the view axis at stage %d; node %s" % [stage, e.name]}
		await _shoot_static(nm, t3)
		if is_instance_valid(e):
			e.queue_free()
		await _wait_phys(20)
	print("art_stills: static done")
	quit(0)


func _shoot_static(subject: String, t: Dictionary) -> void:
	if not _frame_ok(t):
		t["note"] = String(t.get("note", "")) + " | WARNING chase frame_ok failed (subject may be off-frame or occluded)"
	t["recheck"] = false
	await _shoot(subject, t)


# --------------------------------------------------------------------------- camp mode

func _camp_start() -> void:
	seed(171022)
	_as_cg = GameScript.new()
	_as_cg.test_mode = true
	_as_cg.table = "park"
	_as_cg.ground_behind_menu = false
	root.add_child(_as_cg)
	while _as_cg.flow == null:
		await process_frame
	_as_cg.ctx.calm = true
	_as_cg.player.source = Intent.Scripted.new()
	var hub = _as_cg.camp_hub
	_as_cg.screens.toggle_camp()
	for i in 90:
		await physics_frame
	var origin: Vector3 = hub.root.global_position
	for spec in [["camp_launch_gate", "launch-gate", 16.0, Vector3(0, 6, 0), 22.0, 6.0], ["camp_moss_stall", "moss-stall", 14.0, Vector3(0, 2.5, 0), 11.0, 3.0]]:
		var piece: Node3D = hub.piece(spec[0])
		if piece == null:
			print("art_stills: camp piece %s missing" % spec[0])
			continue
		var pc := piece.global_position
		var inward := Vector3(origin.x - pc.x, 0, origin.z - pc.z).normalized()
		var stand := pc + inward * float(spec[2])
		stand.y = hub.plaza_top(Vector2(stand.x - origin.x, stand.z - origin.z)) + origin.y + 1.2 if hub.has_method("plaza_top") else pc.y + 1.2
		_as_cg.player.set_frozen(false)
		_as_cg.player.reset_to(stand)
		_as_cg.player.body().global_position = stand
		_as_cg.player.set_frozen(true)
		_as_cg.camera.snap(pc - stand, -0.12)
		for i in 120:
			await physics_frame
		var aim: Vector3 = pc + spec[3]
		var t := {"aim": aim, "close_d": spec[4], "close_h": spec[5], "side": 20.0, "min_d": 3.0, "max_d": 100.0, "slack": 30.0,
			"note": "camp piece %s at %s; ball placed and frozen %.0f m inward of it, camp lit by WorldLook.CAMP" % [spec[0], str(pc.snapped(Vector3.ONE * 0.1)), spec[2]]}
		await _shoot(spec[1], t)
	print("art_stills: camp done")
	quit(0)
