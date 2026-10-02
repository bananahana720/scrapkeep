extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")

# Unit P2 probe harness (throwaway): measures the Highdraft probe map through a real Game,
# real physics and scripted input. One mode per run:
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/p2_probe.gd -- --mode=smoke
const PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster"}

var game
var player
var source := Intent.Scripted.new()
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1]
	game = Game.new()
	game.test_mode = true
	game.table = "probe_highdraft"
	root.add_child(game)
	_run()


func sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func pilot(name: String) -> void:
	var def: Resource = ClassDef.by_id(PILOTS[name])
	game.run.class_def = def
	player.fit_class(def)
	player.abilities.refill()
	source.hold = {}
	source.press = {}


func ball() -> Vector3:
	return player.ball_position()


const Map := preload("res://src/world/map_highdraft_probe.gd")
const R := 12.0

var terrain
var map


func islands() -> Array:
	return Map.ISLANDS


func isl_c(i: int) -> Vector2:
	return Map.ISLANDS[i]["at"]


func isl_top(i: int) -> float:
	return Map.ISLANDS[i]["top"]


func post_pos(i: int, k: int) -> Vector3:
	var isl: Dictionary = Map.ISLANDS[i]
	var p: Dictionary = isl["posts"][k]
	var at: Vector2 = isl_c(i) + (p["at"] as Vector2)
	return Vector3(at.x, isl_top(i) + float(p["height"]), at.y)


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func look_at_point(p: Vector3) -> void:
	var cam = game.camera
	var d: Vector3 = p - cam.global_position
	cam.yaw = atan2(-d.x, -d.z)
	var horiz := Vector2(d.x, d.z).length()
	cam.pitch = clampf(atan2(d.y, horiz) + 0.0, -1.25, 0.55)


func on_island(b: Vector3) -> int:
	for i in Map.ISLANDS.size():
		if Vector2(b.x, b.z).distance_to(isl_c(i)) <= R and absf(b.y - isl_top(i)) < 2.0:
			return i
	return -1


func in_view(p: Vector3) -> bool:
	var cam: Camera3D = game.camera.cam
	return not cam.is_position_behind(p) and cam.is_position_in_frustum(p)


# One harpoon leg. Rolls from `start` (a Vector3 on island `from_i`) with stick forward toward
# `post`, fires at `fire_dist` metres from the post (flat), releases once the ball is `rel`
# metres past the post along the leg, then steers to the island `to_i` and waits for the
# landing. look: "track" turns the camera to the post every tick, "held" aims once at the
# fire moment and leaves the camera alone. Returns the measurement record.
func leg(start: Vector3, v0: Vector3, from_i: int, to_i: int, post: Vector3, fire_dist: float, rel: float, look := "track", jump_at := -1.0, reset := true) -> Dictionary:
	if reset:
		player.reset_to(start, v0)
	source.hold = {}
	source.press = {}
	var axis := flat(post - Vector3(isl_c(from_i).x, 0.0, isl_c(from_i).y)).normalized()
	var phase := "roll"
	var settle_left := -1
	var res := {"outcome": "timeout", "fire": null, "release": null, "land": null, "frames": 0, "post_in": 0, "ball_in": 0, "island_in": 0,
		"swing_frames": 0, "swing_post_in": 0, "worst": null, "min_clear": INF}
	var worst_score := INF
	var winch := int(args.get("winch", "0")) == 1
	var leg_tag: String = str(args.get("tag", "leg"))
	var island_mid := Vector3(isl_c(to_i).x, isl_top(to_i), isl_c(to_i).y)
	var yaw_set := false
	var ticks := 0
	var max_ticks := int(14.0 * Engine.physics_ticks_per_second)
	while ticks < max_ticks:
		ticks += 1
		await physics_frame
		var b := ball()
		var v: Vector3 = player.body().linear_velocity
		var to_post := flat(post - b)
		var kit = player.kit
		source.press = {}
		if args.has("trace") and ticks % 18 == 0:
			print("  t=%.2f phase=%s ball=%s v=%.1f vy=%.1f hooked=%s rope=%.1f anchor_d=%.1f grounded=%s" % [float(ticks) / 90.0, phase, fmt(b), v.length(), v.y, kit.hooked, kit.rope, b.distance_to(kit.anchor), player.state.grounded])
		match phase:
			"roll":
				source.hold = {"move": Vector2(0, 1)}
				look_at_point(post)
				if jump_at >= 0.0 and on_island(b) == from_i and (b - Vector3(isl_c(from_i).x, b.y, isl_c(from_i).y)).dot(axis) > jump_at:
					source.press = {"jump_pressed": true}
					jump_at = -1.0
				if to_post.length() <= fire_dist and not player.state.grounded:
					if look == "held":
						look_at_point(post)
					source.press = {"harpoon_pressed": true}
					source.hold = {"harpoon_held": true, "move": Vector2.ZERO}
					phase = "hook"
					res["fire"] = {"at": b, "speed": v.length(), "dist3d": b.distance_to(post)}
				elif to_post.length() <= fire_dist and player.state.grounded:
					# Still on the island at the fire distance: keep rolling until airborne.
					pass
			"hook":
				source.hold = {"harpoon_held": true}
				if winch and kit.hooked:
					source.hold["brake_held"] = true
				if look == "track":
					look_at_point(post)
				if not kit.hooked and ticks > 0 and res["fire"] != null:
					if res.get("hooked_ever", false):
						phase = "air"
					elif ticks - int(res.get("fire_tick", ticks)) > 6:
						res["outcome"] = "no_bite"
						break
				if kit.hooked:
					res["hooked_ever"] = true
					res["rope"] = kit.rope
					res["anchor"] = kit.anchor
				if not res.has("fire_tick"):
					res["fire_tick"] = ticks
				var release_now := false
				if winch:
					release_now = kit.hooked and flat(post - b).length() <= rel and b.y >= isl_top(to_i) + 0.5
				else:
					release_now = kit.hooked and (b - post).dot(axis) >= rel
				if release_now:
					source.press = {"harpoon_released": true}
					source.hold = {}
					res["release"] = {"at": b, "speed": v.length(), "horizontal": flat(v).length(), "vertical": v.y, "past_post": (b - post).dot(axis)}
					phase = "air"
			"air":
				source.hold = {"move": Vector2(0, 1)}
				look_at_point(island_mid + Vector3(0, 1, 0))
		# camera sampling while a line is out or just after release until landing
		if phase != "roll" and settle_left < 0:
			res["frames"] += 1
			var pin := in_view(post)
			var bin := in_view(b)
			var iin := in_view(island_mid)
			if pin:
				res["post_in"] += 1
			if bin:
				res["ball_in"] += 1
			if iin:
				res["island_in"] += 1
			var score := (1 if pin else 0) + (1 if bin else 0) + (1 if iin else 0)
			if score < worst_score:
				worst_score = score
				if still_prefix != "":
					_grab("%s-worst-%s.png" % [still_prefix, leg_tag])
				res["worst"] = {"tick": ticks, "ball": b, "cam": game.camera.cam.global_position, "yaw": game.camera.yaw, "pitch": game.camera.pitch,
					"post_in": pin, "ball_in": bin, "island_in": iin}
		if phase != "roll":
			res["min_clear"] = minf(res["min_clear"], b.y - _net(b.x, b.z))
		if b.y - _net(b.x, b.z) < 1.4 and b.y < isl_top(0) - 1.0 or b.y < -30.0:
			res["outcome"] = "net"
			res["land"] = {"at": b, "speed": v.length()}
			break
		var isl := on_island(b)
		if settle_left >= 0:
			settle_left -= 1
			source.hold = {"brake_held": true}
			res["max_off"] = maxf(res.get("max_off", 0.0), Vector2(b.x, b.z).distance_to(isl_c(to_i)))
			if b.y < isl_top(to_i) - 2.0:
				res["outcome"] = "overran_to_net"
				break
			if settle_left == 0:
				res["outcome"] = "landed_i%d" % (to_i + 1)
				res["stayed"] = on_island(b) == to_i
				res["rest"] = b
				break
			continue
		if player.state.grounded and isl == to_i and phase != "roll":
			res["land"] = {"at": b, "speed": v.length(), "horizontal": flat(v).length(), "island": isl + 1, "tick": ticks}
			settle_left = int(3.0 * Engine.physics_ticks_per_second)
			if player.kit.hooked:
				player.release_grapple()
			continue
		if player.state.grounded and isl >= 0 and isl != to_i and phase != "roll":
			res["outcome"] = "landed_wrong_island"
			break
	res["ticks"] = ticks
	source.hold = {}
	source.press = {}
	if player.kit.hooked:
		player.release_grapple()
	return res


func _net(x: float, z: float) -> float:
	return net_map.net_height(x, z)


var net_map


func _run() -> void:
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	player = game.player
	player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	await sim(0.6)
	game.run.set_max_hp(99999.0)
	terrain = game.ctx.terrain
	net_map = terrain.map()
	match args.get("mode", "smoke"):
		"smoke":
			print("spawn ", terrain.spawn_point(1), " height at i1 ", terrain.height(0, -90))
			await sim(2.0)
			print("after 2 s ball ", ball(), " grounded ", player.state.grounded)
		"grid":
			await mode_grid()
		"chain":
			await mode_chain()
		"falls":
			await mode_falls()
		"visual":
			await mode_visual()
	game.free()
	quit(0)


func fmt(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func brief(r: Dictionary) -> String:
	var out := "%s" % r["outcome"]
	if r.has("max_off"):
		out += " (stayed=%s, max_off=%.1f)" % [r.get("stayed"), r["max_off"]]
	if r["fire"] != null:
		out += " fire@%s v=%.1f" % [fmt(r["fire"]["at"]), r["fire"]["speed"]]
	if r["release"] != null:
		out += " rel@%s v=%.1f (h %.1f, y %.1f) past=%.1f" % [fmt(r["release"]["at"]), r["release"]["speed"], r["release"]["horizontal"], r["release"]["vertical"], r["release"]["past_post"]]
	if r["land"] != null:
		out += " land@%s v=%.1f" % [fmt(r["land"]["at"]), r["land"]["speed"]]
	out += " rope=%.1f anchor=%s" % [r.get("rope", -1.0), fmt(r.get("anchor", Vector3.ZERO))]
	out += " minclear=%.1f t=%.1fs" % [r["min_clear"], float(r["ticks"]) / Engine.physics_ticks_per_second]
	return out


func mode_grid() -> void:
	var from_i := int(args.get("from", "0"))
	var to_i := from_i + 1
	var k := int(args.get("post", "0"))
	var post := post_pos(to_i, k)
	var a := isl_c(from_i)
	var axis := flat(post - Vector3(a.x, 0.0, a.y)).normalized()
	var start := Vector3(a.x, isl_top(from_i) + 1.2, a.y) - axis * 6.0
	for fd in _floats(args.get("fd", "30,36,42")):
		for rel in _floats(args.get("rel", "-8,0,8")):
			var r = await leg(start, Vector3.ZERO, from_i, to_i, post, fd, rel, "track")
			print("fd=%.0f rel=%.0f  %s" % [fd, rel, brief(r)])


func _floats(text: String) -> Array:
	var out := []
	for t in text.split(","):
		out.append(float(t))
	return out


# Rolls toward a point with the stick, camera on it, until within tol (flat) or time is up.
func goto(point: Vector3, tol := 3.0, max_seconds := 12.0, brake_at_end := false) -> bool:
	var ticks := 0
	var max_ticks := int(max_seconds * Engine.physics_ticks_per_second)
	while ticks < max_ticks:
		ticks += 1
		await physics_frame
		var b := ball()
		if flat(point - b).length() <= tol:
			source.hold = {"brake_held": true} if brake_at_end else {}
			return true
		look_at_point(point + Vector3(0, 1, 0))
		source.hold = {"move": Vector2(0, 1)}
	source.hold = {}
	return false


func mode_chain() -> void:
	var look: String = args.get("look", "track")
	var rels := _floats(args.get("rel", "-4"))
	var fd: float = float(args.get("fd", "36"))
	player.reset_to(Vector3(0.0, isl_top(0) + 1.2, -96.0), Vector3.ZERO)
	await sim(0.5)
	var r1 = await leg(Vector3.ZERO, Vector3.ZERO, 0, 1, post_pos(1, 0), fd, rels[0], look, -1.0, false)
	print("leg1 I1->I2: ", brief(r1))
	print("leg1 camera(%s): frames=%d post_in=%d (%.0f%%) ball_in=%d (%.0f%%) island_in=%d (%.0f%%)" % [look, r1["frames"], r1["post_in"], 100.0 * r1["post_in"] / maxf(1, r1["frames"]), r1["ball_in"], 100.0 * r1["ball_in"] / maxf(1, r1["frames"]), r1["island_in"], 100.0 * r1["island_in"] / maxf(1, r1["frames"])])
	if not str(r1["outcome"]).begins_with("landed"):
		return
	await sim(0.3)
	var c2 := isl_c(1)
	var axis2 := flat(post_pos(2, 0) - Vector3(c2.x, 0.0, c2.y)).normalized()
	var runup := Vector3(c2.x, isl_top(1), c2.y) - axis2 * 6.0
	await goto(runup, 2.5, 8.0, true)
	await sim(1.0)
	var r2 = await leg(Vector3.ZERO, Vector3.ZERO, 1, 2, post_pos(2, 0), float(args.get("fd2", fd)), float(args.get("rel2", rels[0])), look, -1.0, false)
	print("leg2 I2->I3: ", brief(r2))
	print("leg2 camera(%s): frames=%d post_in=%d (%.0f%%) ball_in=%d (%.0f%%) island_in=%d (%.0f%%)" % [look, r2["frames"], r2["post_in"], 100.0 * r2["post_in"] / maxf(1, r2["frames"]), r2["ball_in"], 100.0 * r2["ball_in"] / maxf(1, r2["frames"]), r2["island_in"], 100.0 * r2["island_in"] / maxf(1, r2["frames"])])


# 200 falls. Seeded. Each starts at a point and velocity from the mix below and runs until the
# ball rests on the net or 15 s pass. With --recover=1 a scripted recovery line (to the nearest
# ramp foot, up the ramp to its island) runs from the first net contact.
func mode_falls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args.get("seed", "7"))
	var count := int(args.get("count", "200"))
	var recover := int(args.get("recover", "0")) == 1
	var worst_bounce := 0.0
	var worst_case := ""
	var misses := 0
	var through := 0
	var out := 0
	var slow := 0
	var fastest := 0.0
	var recov_times := []
	var recov_fail := 0
	var rows := []
	for n in count:
		var p: Vector3
		var v: Vector3
		var kind := ""
		if n % 2 == 0:
			# Over the island corridor: near an island, off its rim, with a swing-miss velocity.
			var i := rng.randi() % 3
			var ang := rng.randf() * TAU
			var rad := R + rng.randf_range(0.5, 40.0)
			p = Vector3(isl_c(i).x + cos(ang) * rad, isl_top(i) + rng.randf_range(-8.0, 30.0), isl_c(i).y + sin(ang) * rad)
			var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
			v = dir * rng.randf_range(0.0, 36.0) + Vector3(0, rng.randf_range(-15.0, 12.0), 0)
			kind = "corridor"
		else:
			p = Vector3(rng.randf_range(-170.0, 170.0), rng.randf_range(-10.0, 40.0), rng.randf_range(-170.0, 170.0))
			var dir2 := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
			v = dir2 * rng.randf_range(0.0, 40.0) + Vector3(0, rng.randf_range(-20.0, 15.0), 0)
			kind = "anywhere"
		# Keep the start out of the deck colliders.
		var clear := true
		for i in 3:
			if Vector2(p.x, p.z).distance_to(isl_c(i)) < R + 2.0 and p.y < isl_top(i) + 2.0 and p.y > isl_top(i) - ISLAND_THICK - 3.0:
				clear = false
		if not clear:
			p.y = isl_top(0) + 20.0
		player.reset_to(p, v)
		source.hold = {}
		var contact_tick := -1
		var apex_after := -INF
		var contact_y := 0.0
		var min_rel := INF
		var ticks := 0
		var rest := 0
		var landed_on_island := false
		var t_island := -1.0
		var wp := []
		var wp_i := 0
		var lost := false
		var maxt := int(15.0 * Engine.physics_ticks_per_second)
		if recover:
			maxt = int(40.0 * Engine.physics_ticks_per_second)
		while ticks < maxt:
			ticks += 1
			await physics_frame
			var b := ball()
			var net := _net(b.x, b.z)
			var isl := on_island(b)
			if args.has("trace") and ticks % 45 == 0:
				print("   n=%d t=%.1f ball=%s v=%.1f grounded=%s wp_i=%d/%d net=%.1f" % [n, ticks / 90.0, fmt(b), player.body().linear_velocity.length(), player.state.grounded, wp_i, wp.size(), net])
			if contact_tick < 0 and isl < 0 and b.y - net <= 1.4:
				contact_tick = ticks
				contact_y = b.y
				if recover:
					wp = _recovery_waypoints(b)
			if contact_tick < 0 and isl >= 0 and player.state.grounded:
				landed_on_island = true
				break
			if contact_tick >= 0:
				var rel := b.y - net
				min_rel = minf(min_rel, rel)
				if rel > 1.4 + 0.01 and ticks - contact_tick < 90:
					apex_after = maxf(apex_after, rel - 1.4)
				if absf(b.x) > 198.0 or absf(b.z) > 198.0:
					lost = true
					break
				if recover:
					if isl == to_island_of(wp) and player.state.grounded:
						t_island = float(ticks - contact_tick) / Engine.physics_ticks_per_second
						break
					if wp_i < wp.size():
						var target: Vector3 = wp[wp_i]
						if flat(target - b).length() < 8.0:
							wp_i += 1
						else:
							look_at_point(target + Vector3(0, 1, 0))
							source.hold = {"move": Vector2(0, 1)}
							if wp_i == 0 and flat(target - b).length() < 45.0 and player.body().linear_velocity.length() > 13.0:
								source.hold["brake_held"] = true
					else:
						look_at_point(Vector3(isl_c(to_island_of(wp)).x, 0, isl_c(to_island_of(wp)).y))
						source.hold = {"move": Vector2(0, 1)}
				else:
					if player.body().linear_velocity.length() < 0.6:
						rest += 1
						if rest > 45:
							break
					else:
						rest = 0
			if b.y < net - 2.0 and contact_tick >= 0:
				through += 1
				lost = true
				break
			if b.y < -80.0 or absf(b.x) > 199.5 or absf(b.z) > 199.5:
				lost = true
				break
		source.hold = {}
		if lost and contact_tick < 0:
			out += 1
		elif lost:
			if absf(ball().x) > 198.0 or absf(ball().z) > 198.0:
				out += 1
		if landed_on_island:
			rows.append("%d %s on_island_directly" % [n, kind])
			continue
		if contact_tick < 0:
			misses += 1
			rows.append("%d %s NO_CONTACT p=%s v=%s end=%s state=%s frozen=%s" % [n, kind, fmt(p), fmt(v), fmt(ball()), game.flow.state_name(), player.frozen()])
			continue
		if apex_after > worst_bounce:
			worst_bounce = apex_after
			worst_case = "%d %s p=%s v=%s" % [n, kind, fmt(p), fmt(v)]
		if recover:
			if t_island < 0.0:
				recov_fail += 1
				rows.append("%d %s RECOVER_FAIL p=%s v=%s end=%s" % [n, kind, fmt(p), fmt(v), fmt(ball())])
			else:
				recov_times.append(t_island)
		rows.append("%d %s net_contact_y=%.1f bounce=%.2f lost=%s end=%s p=%s v=%s" % [n, kind, contact_y, apex_after, lost, fmt(ball()), fmt(p), fmt(v)])
	for r in rows:
		print(r)
	var landed := rows.filter(func(r): return "net_contact" in r).size()
	print("FALLS count=%d net_landings=%d direct_island=%d no_contact=%d through=%d out_of_world=%d worst_bounce_m=%.2f (%s)" % [count, landed, rows.filter(func(r): return "on_island_directly" in r).size(), misses, through, out, worst_bounce, worst_case])
	if recover:
		recov_times.sort()
		var med: float = recov_times[recov_times.size() / 2] if not recov_times.is_empty() else -1.0
		var p90: float = recov_times[int(recov_times.size() * 0.9)] if not recov_times.is_empty() else -1.0
		print("RECOVER ok=%d fail=%d min=%.1f median=%.1f p90=%.1f max=%.1f s" % [recov_times.size(), recov_fail, recov_times[0] if not recov_times.is_empty() else -1.0, med, p90, recov_times[-1] if not recov_times.is_empty() else -1.0])


const ISLAND_THICK := 4.0


# Recovery line: the foot nearest the landing, then up the ramp's centre line to the island.
# The last entry is the island index as a Vector3.x marker (read with to_island_of).
func _recovery_waypoints(b: Vector3) -> Array:
	var best := 0
	var best_d := INF
	for i in 3:
		var d := Vector2(b.x, b.z).distance_to(net_map.feet[i])
		if d < best_d:
			best_d = d
			best = i
	var u: Vector2 = (Map.ISLANDS[best]["out"] as Vector2).normalized()
	var wps := []
	var c := isl_c(best)
	var steps := 5
	for k in range(steps + 1):
		var s := Map.RAMP_LENGTH + R - (Map.RAMP_LENGTH * float(k) / float(steps))
		var q := c + u * s
		wps.append(Vector3(q.x, 0.0, q.y))
	rec_island = best
	return wps


var rec_island := -1
var still_prefix := ""
var frame_log: Array = []


func to_island_of(_wp: Array) -> int:
	return rec_island


func _grab(path: String) -> void:
	var img := root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		printerr("grab failed: " + path)
	else:
		print("still ", path, " ", img.get_size())


func cam_to(from: Vector3, to: Vector3, fov := 65.0) -> void:
	game.camera.set_process(false)
	var cam: Camera3D = game.camera.cam
	cam.fov = fov
	cam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


# Native run (not headless, 1920x1080): scenic stills, then the chain at real time with the
# render times of every frame, and the worst-camera still of each leg.
func mode_visual() -> void:
	var out: String = args.get("out", "/tmp/claude-1000/p2")
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await sim(0.5)
	# scenic stills
	player.reset_to(Vector3(0.0, isl_top(0) + 1.2, -96.0), Vector3.ZERO)
	player.set_frozen(true)
	cam_to(Vector3(-70.0, 38.0, -125.0), Vector3(8.0, -4.0, -30.0), 62.0)
	await sim(0.4)
	_grab(out + "/p2-overview.png")
	cam_to(Vector3(30.0, 8.0, -95.0), Vector3(14.0, -22.0, -60.0), 70.0)
	await sim(0.2)
	_grab(out + "/p2-net-from-deck.png")
	cam_to(Vector3(5.0, 14.0, -100.0), Vector3(10.0, 12.0, -30.0), 65.0)
	await sim(0.2)
	_grab(out + "/p2-posts.png")
	player.set_frozen(false)
	game.camera.set_process(true)
	# the chain, timed
	still_prefix = out + "/p2-cam"
	var t0 := Time.get_ticks_usec()
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	game.run.stage_time = 0.0
	frame_log.clear()
	process_frame.connect(_frame_sample.bind(rid))
	player.reset_to(Vector3(0.0, isl_top(0) + 1.2, -96.0), Vector3.ZERO)
	await sim(0.5)
	args["tag"] = "leg1"
	var look: String = args.get("look", "track")
	var r1 = await leg(Vector3.ZERO, Vector3.ZERO, 0, 1, post_pos(1, 0), 34.0, 18.0, look, -1.0, false)
	print("leg1: ", brief(r1))
	print("leg1 camera: frames=%d post_in=%d ball_in=%d island_in=%d" % [r1["frames"], r1["post_in"], r1["ball_in"], r1["island_in"]])
	await sim(0.3)
	var c2 := isl_c(1)
	var axis2 := flat(post_pos(2, 0) - Vector3(c2.x, 0.0, c2.y)).normalized()
	await goto(Vector3(c2.x, isl_top(1), c2.y) - axis2 * 6.0, 2.5, 8.0, true)
	await sim(1.0)
	args["tag"] = "leg2"
	var r2 = await leg(Vector3.ZERO, Vector3.ZERO, 1, 2, post_pos(2, 0), 28.0, 24.0, look, -1.0, false)
	print("leg2: ", brief(r2))
	print("leg2 camera: frames=%d post_in=%d ball_in=%d island_in=%d" % [r2["frames"], r2["post_in"], r2["ball_in"], r2["island_in"]])
	process_frame.disconnect(_frame_sample.bind(rid))
	var frames: Array = frame_log.duplicate()
	var f_ms := []
	var cpu := []
	var gpu := []
	for f in frames:
		f_ms.append(f[0])
		cpu.append(f[1])
		gpu.append(f[2])
	print("PERF frames=%d wall_s=%.1f frame_ms p50=%.2f p99=%.2f | render_cpu_ms p50=%.2f p99=%.2f | gpu_ms p50=%.2f p99=%.2f" % [frames.size(), (Time.get_ticks_usec() - t0) / 1e6, _pct(f_ms, 0.5), _pct(f_ms, 0.99), _pct(cpu, 0.5), _pct(cpu, 0.99), _pct(gpu, 0.5), _pct(gpu, 0.99)])


var _last_frame_usec := 0


func _frame_sample(rid: RID) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		frame_log.append([float(now - _last_frame_usec) / 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid)])
	_last_frame_usec = now


func _pct(values: Array, q: float) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * q)) - 1)])
