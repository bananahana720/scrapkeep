extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")

# A bolt hits and kills, for each class, through the live game. The camera is aimed at
# a chaser the way a player would aim, fire is held, and the test watches the bus:
# the shot is sent at the point under the reticle, the bolts strike with the class's
# kind, the chaser dies once, and the kill publishes its scrap. For the engineer a
# second chaser stands beside the first, and the arc caster's chain must reach it.

const AHEAD := 16.0
const BESIDE := 5.0
const TIMEOUT := 6.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := ""
var _clock := 0.0
var _target: Node3D
var _buddy: Node3D
var _struck := {}
var _kills := []
var _on_target := 0
var _shots := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	if _phase == "":
		var events = _game.events
		events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
			var key := "%s:%s" % ["target" if enemy == _target else ("buddy" if enemy == _buddy else "other"), kind]
			_struck[key] = _struck.get(key, 0) + 1)
		events.enemy_killed.connect(func(kind: String, _at: Vector3, scrap: int): _kills.append([kind, scrap]))
		events.shot_fired.connect(_on_shot)
		_game.ctx.calm = true
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_start("runner")
		return false
	_clock += delta
	if is_instance_valid(_target):
		_aim_at(_target.global_position + Vector3.UP * 0.4)
	_drive_fire()
	var done: bool = _kills.size() >= 1 and (_phase == "runner" or _struck.get("buddy:arc", 0) >= 1)
	if not done and _clock < TIMEOUT:
		return false
	_source.hold = {}
	_source.press = {}
	if _phase == "runner":
		_check("runner", "runner")
		# Die on purpose, then start a new run as the engineer.
		_game.run.damage(99999.0, "test")
		_game.flow.open_class_select()
		_game.flow.choose_class(0)
		_start("engineer")
		return false
	_check("engineer", "arc")
	_report("chain", _struck.get("buddy:arc", 0) >= 1,
		"the arc caster's chain reached the chaser beside the target %d times" % _struck.get("buddy:arc", 0))
	_check_muzzle_origin()
	var ok := _failures == 0
	print("combat_bolt_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


func _start(phase: String) -> void:
	_phase = phase
	_clock = 0.0
	_struck = {}
	_kills = []
	_on_target = 0
	_shots = 0
	_game.run.set_max_hp(99999.0)
	var ctx = _game.ctx
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	var at: Vector3 = ctx.terrain.spawn_point(1)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_game.camera.snap(heading, -0.1)
	var ahead: Vector3 = at + heading * AHEAD
	_target = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(ahead.x, ahead.z, 1.6))
	_buddy = null
	if phase == "engineer":
		var side: Vector3 = heading.cross(Vector3.UP).normalized() * BESIDE
		_buddy = ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(ahead.x + side.x, ahead.z + side.z, 1.6))
	_source.hold = {}
	_source.press = {"fire_pressed": true}


func _drive_fire() -> void:
	var snap: Dictionary = _game.ctx.spawner.weapon_driver.state_snapshot()
	if _phase == "runner":
		_source.hold = {}
		if bool(snap.get("reloading", false)):
			if bool(snap.get("window_open", false)):
				_source.press = {"fire_pressed": true}
		elif bool(snap.get("ready", false)):
			_source.press = {"fire_pressed": true}
	else:
		if bool(snap.get("charge_armed", false)):
			if float(snap.get("charge", 0.0)) >= 0.9999:
				_source.hold = {}
				_source.press = {"fire_released": true}
			else:
				_source.hold = {"fire_held": true}
		elif bool(snap.get("ready", false)):
			_source.press = {"fire_pressed": true}
			_source.hold = {"fire_held": true}
		else:
			_source.hold = {}


func _check(label: String, kind: String) -> void:
	var hits: int = _struck.get("target:%s" % kind, 0)
	var chaser_kills := 0
	for kill in _kills:
		if kill[0] == "chaser" and kill[1] == 3:
			chaser_kills += 1
	_report("%s_aim" % label, _on_target >= 1,
		"%d of %d shots were sent at a point on the chaser under the reticle" % [_on_target, _shots])
	_report("%s_hit" % label, hits >= 1, "%d bolt strikes of kind '%s' on the target" % [hits, kind])
	_report("%s_kill" % label, chaser_kills >= 1 and not is_instance_valid(_target) and _clock < TIMEOUT,
		"chaser killed %d time(s) with 3 scrap each, %.2f s after fire began (limit %.0f)" % [chaser_kills, _clock, TIMEOUT])


# The shot's committed point, compared with the target under the reticle.
func _on_shot(_weapon: String, _from: Vector3, _to: Vector3) -> void:
	_shots += 1
	if not is_instance_valid(_target):
		return
	var point: Vector3 = _game.ctx.spawner.last_shot["point"]
	var flat := Vector2(point.x - _target.global_position.x, point.z - _target.global_position.z)
	if flat.length() < _target.radius + 0.3 and absf(point.y - _target.global_position.y) < _target.half_height + 0.3:
		_on_target += 1


# Turns the camera so its centre ray passes through the point, as a player's mouse would.
func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


class ParityDummy extends Node3D:
	var radius := 0.5
	var half_height := 0.9
	var weak: Array = []

	func is_dead() -> bool:
		return false

	func weak_points() -> Array:
		return weak


func _make_bolt(origin: Vector3, dir: Vector3, weapon_id := "arc_caster", source := "weapon", extra := {}) -> Dictionary:
	var b := {
		"origin": origin, "dir": dir.normalized(), "speed": 60.0, "max_dist": 20.0,
		"damage": 10.0, "kind": "runner" if weapon_id == "rapid_laser" else "arc",
		"weapon_id": weapon_id, "radius": 0.25, "knock": 0.0,
		"chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0,
		"color": Color.WHITE, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
		"pierce": 0, "source": source,
	}
	for k in extra:
		b[k] = extra[k]
	return b


static func _line_distance(point: Vector3, line_origin: Vector3, line_dir: Vector3) -> float:
	var rel := point - line_origin
	return (rel - line_dir * rel.dot(line_dir)).length()


func _check_muzzle_origin() -> void:
	var bolts := Bolts.new()
	root.add_child(bolts)
	bolts.setup()

	# 1. Explicit draw_origin starts at the side muzzle at travelled == 0, eases monotonically
	# toward the true line, and matches the true line identically (0.0 m offset) at travelled >= 4.0 m.
	var origin := Vector3(0.0, 2.0, 0.0)
	var dir := Vector3.FORWARD
	var side_muzzle := Vector3(-0.75, 2.17, 0.0)
	var explicit := _make_bolt(origin, dir, "arc_caster", "weapon", {"draw_origin": side_muzzle})
	var plain := _make_bolt(origin, dir, "arc_caster", "weapon")
	bolts.fire(explicit)
	bolts.fire(plain)
	var head0 := Bolts.drawn_position(explicit)
	var xf0: Transform3D = Bolts.instance(explicit, 1.0)[0]
	var expected_xf0 := side_muzzle - dir * 0.1
	var start_ok := head0.distance_to(side_muzzle) < 0.0001 and xf0.origin.distance_to(expected_xf0) < 0.0001
	var head_dists: Array[float] = []
	var xf_dists: Array[float] = []
	var samples := [0.0, 0.5, 1.0, 2.0, 3.0, Bolts.DRAW_MERGE_M]
	for d in samples:
		explicit["travelled"] = d
		explicit["shown"] = origin + dir * d
		head_dists.append(Bolts.drawn_position(explicit).distance_to(explicit["shown"]))
		var xf_d: Transform3D = Bolts.instance(explicit, 1.0)[0]
		xf_dists.append(_line_distance(xf_d.origin, origin, dir))
	var mono_ok := true
	for i in range(1, samples.size()):
		if not (head_dists[i] < head_dists[i - 1] and xf_dists[i] < xf_dists[i - 1]):
			mono_ok = false
	plain["travelled"] = Bolts.DRAW_MERGE_M
	plain["shown"] = origin + dir * Bolts.DRAW_MERGE_M
	explicit["travelled"] = Bolts.DRAW_MERGE_M
	explicit["shown"] = origin + dir * Bolts.DRAW_MERGE_M
	var xf_at_merge: Transform3D = Bolts.instance(explicit, 1.0)[0]
	var xf_plain_merge: Transform3D = Bolts.instance(plain, 1.0)[0]
	var merge_ok := Bolts.drawn_position(explicit).distance_to(explicit["shown"]) < 1e-6 \
		and xf_at_merge.origin.distance_to(xf_plain_merge.origin) < 1e-6 \
		and xf_at_merge.basis.is_equal_approx(xf_plain_merge.basis)
	explicit["travelled"] = Bolts.DRAW_MERGE_M + 3.0
	explicit["shown"] = origin + dir * (Bolts.DRAW_MERGE_M + 3.0)
	plain["travelled"] = explicit["travelled"]
	plain["shown"] = explicit["shown"]
	var xf_past: Transform3D = Bolts.instance(explicit, 1.0)[0]
	var xf_plain_past: Transform3D = Bolts.instance(plain, 1.0)[0]
	merge_ok = merge_ok and Bolts.drawn_position(explicit).distance_to(explicit["shown"]) < 1e-6 \
		and xf_past.origin.distance_to(xf_plain_past.origin) < 1e-6
	_report("muzzle_explicit_merge", start_ok and mono_ok and merge_ok,
		"start=%s mono=%s merge=%s head_dists=%s xf_dists=%s" % [start_ok, mono_ok, merge_ok, head_dists, xf_dists])

	# 2. Rivet (rapid_laser) shots alternate left (-RIVET_MUZZLE_SIDE_M, -1.26 m) and right (+1.26 m); clear() resets to left.
	bolts.clear()
	var rivet_xs: Array[float] = []
	for i in 4:
		var rb := _make_bolt(origin, dir, "rapid_laser", "weapon")
		bolts.fire(rb)
		rivet_xs.append(snappedf(Bolts.drawn_position(rb).x - origin.x, 0.0001))
	bolts.clear()
	var after_clear_xs: Array[float] = []
	for i in 2:
		var rb2 := _make_bolt(origin, dir, "rapid_laser", "weapon")
		bolts.fire(rb2)
		after_clear_xs.append(snappedf(Bolts.drawn_position(rb2).x - origin.x, 0.0001))
	var other_b := _make_bolt(origin, dir, "arc_caster", "weapon")
	bolts.fire(other_b)
	var side_m := Bolts.RIVET_MUZZLE_SIDE_M
	var alt_ok := rivet_xs == [-side_m, side_m, -side_m, side_m] \
		and after_clear_xs == [-side_m, side_m] \
		and Bolts.drawn_position(other_b).distance_to(origin) < 1e-6
	_report("muzzle_rivet_alternation", alt_ok,
		"shots=%s after_clear=%s other_off=%.4f" % [rivet_xs, after_clear_xs, Bolts.drawn_position(other_b).distance_to(origin)])

	# 3. item_proc bolts, child() split bolts, and _glance() bounced bolts carry zero side-muzzle offset.
	bolts.clear()
	var proc_b := _make_bolt(origin, dir, "rapid_laser", "item_proc")
	bolts.fire(proc_b)
	var proc_zero := Bolts.drawn_position(proc_b).distance_to(origin) < 1e-6 \
		and (proc_b["draw_offset"] as Vector3).length() < 1e-6
	# Firing an item_proc bolt must not advance Rivet's weapon alternation counter (next shot stays left).
	var parent_b := _make_bolt(origin, dir, "rapid_laser", "weapon",
		{"bits": ShotBits.bit("split") | ShotBits.bit("bounce"), "draw_origin": side_muzzle})
	bolts.fire(parent_b)
	var hit_pt := origin + dir * 1.5
	var direct_child := Bolts.child(parent_b, {"origin": hit_pt})
	var kids := Bolts.split_children(parent_b, hit_pt, 101, 1.5)
	var kids_ok := kids.size() == 2 and not direct_child.has("draw_origin") \
		and (direct_child["draw_offset"] as Vector3).length() < 1e-6
	for kid in kids:
		bolts.fire(kid)
		kids_ok = kids_ok and not kid.has("draw_origin") \
			and (kid["draw_offset"] as Vector3).length() < 1e-6 \
			and Bolts.drawn_position(kid).distance_to(hit_pt) < 1e-6
	# Next Rivet weapon shot after proc + explicit draw_origin + split children is still shot 0 (left).
	var next_rivet := _make_bolt(origin, dir, "rapid_laser", "weapon")
	bolts.fire(next_rivet)
	var phase_preserved := is_equal_approx(Bolts.drawn_position(next_rivet).x - origin.x, -side_m)
	# Bounce inside the 4 m window clears draw_offset and draw_origin so the reflected bolt starts on the wall.
	var bounce_b := _make_bolt(origin, dir, "rapid_laser", "weapon",
		{"bits": ShotBits.bit("bounce"), "draw_origin": side_muzzle})
	bolts.fire(bounce_b)
	var wall_pt := origin + dir * 1.5
	var glanced := bolts._glance(bounce_b, wall_pt, Vector3.BACK, 1.5)
	var bounce_ok := glanced and not bounce_b.has("draw_origin") \
		and (bounce_b["draw_offset"] as Vector3).length() < 1e-6 \
		and Bolts.drawn_position(bounce_b).distance_to(bounce_b["origin"]) < 1e-6
	_report("muzzle_zero_proc_split_bounce", proc_zero and kids_ok and phase_preserved and bounce_ok,
		"proc=%s kids=%s phase=%s bounce=%s" % [proc_zero, kids_ok, phase_preserved, bounce_ok])

	# 4. Hit-detection & world-stop parity: firing inside the 4 m merge zone with and without
	# draw_origin / Rivet side offset produces exact identical hit enemy, point, part, and world stop.
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var spawn_pt: Vector3 = _game.ctx.terrain.spawn_point(1)
	var sky_origin := spawn_pt + Vector3(0.0, 12.0, 0.0)
	var dummy := ParityDummy.new()
	root.add_child(dummy)
	dummy.global_position = sky_origin + Vector3.FORWARD * 2.0
	dummy.weak = [{"id": "core", "at": dummy.global_position + Vector3(0.0, 0.35, 0.4), "radius": 0.45}]
	var weak_origin := sky_origin + Vector3(0.0, 0.35, 0.0)

	var hit_results: Array = []
	var variants := [
		["plain", _make_bolt(weak_origin, Vector3.FORWARD, "arc_caster", "weapon")],
		["rivet_side", _make_bolt(weak_origin, Vector3.FORWARD, "rapid_laser", "weapon")],
		["explicit_far", _make_bolt(weak_origin, Vector3.FORWARD, "arc_caster", "weapon",
			{"draw_origin": weak_origin + Vector3(2.5, 0.4, 0.0)})],
	]
	for entry in variants:
		bolts.clear()
		var rec: Dictionary = {}
		bolts.on_hit = func(_b: Dictionary, enemy: Node3D, point: Vector3, part: String) -> void:
			rec["enemy"] = enemy
			rec["point"] = point
			rec["part"] = part
		bolts.fire(entry[1])
		for _step in 10:
			if not rec.is_empty() or bolts.live() == 0:
				break
			bolts.step(1.0 / 90.0, space, [dummy])
		hit_results.append(rec)

	# Body hit (aim below weak point so it hits the capsule body, not weak point).
	var body_origin := sky_origin + Vector3(0.0, -0.5, 0.0)
	var body_results: Array = []
	for entry in [
		_make_bolt(body_origin, Vector3.FORWARD, "arc_caster", "weapon"),
		_make_bolt(body_origin, Vector3.FORWARD, "rapid_laser", "weapon"),
	]:
		bolts.clear()
		var rec: Dictionary = {}
		bolts.on_hit = func(_b: Dictionary, enemy: Node3D, point: Vector3, part: String) -> void:
			rec["enemy"] = enemy
			rec["point"] = point
			rec["part"] = part
		bolts.fire(entry)
		for _step in 10:
			if not rec.is_empty() or bolts.live() == 0:
				break
			bolts.step(1.0 / 90.0, space, [dummy])
		body_results.append(rec)

	# World-stop parity against real terrain inside the 4 m merge window.
	var ground_y: float = _game.ctx.terrain.height(spawn_pt.x, spawn_pt.z)
	var floor_origin := Vector3(spawn_pt.x, ground_y + 1.5, spawn_pt.z + 1.5)
	var floor_dir := Vector3(0.0, -1.0, -1.0).normalized()
	var stop_points: Array[Vector3] = []
	for entry in [
		_make_bolt(floor_origin, floor_dir, "arc_caster", "weapon"),
		_make_bolt(floor_origin, floor_dir, "rapid_laser", "weapon"),
		_make_bolt(floor_origin, floor_dir, "arc_caster", "weapon",
			{"draw_origin": floor_origin + Vector3(2.0, 0.3, 0.0)}),
	]:
		bolts.clear()
		var stopped_at: Array[Vector3] = []
		bolts.on_hit = Callable()
		bolts.on_stop = func(pt: Vector3, _col: Color) -> void:
			stopped_at.append(pt)
		bolts.fire(entry)
		for _step in 12:
			if not stopped_at.is_empty() or bolts.live() == 0:
				break
			bolts.step(1.0 / 90.0, space, [])
		if not stopped_at.is_empty():
			stop_points.append(stopped_at[0])

	var weak_parity: bool = hit_results.size() == 3 \
		and not hit_results[0].is_empty() and String(hit_results[0]["part"]) == "core" \
		and hit_results[1].get("enemy") == hit_results[0]["enemy"] \
		and hit_results[2].get("enemy") == hit_results[0]["enemy"] \
		and String(hit_results[1].get("part", "")) == String(hit_results[0]["part"]) \
		and String(hit_results[2].get("part", "")) == String(hit_results[0]["part"]) \
		and (hit_results[1]["point"] as Vector3).distance_to(hit_results[0]["point"] as Vector3) < 1e-6 \
		and (hit_results[2]["point"] as Vector3).distance_to(hit_results[0]["point"] as Vector3) < 1e-6
	var body_parity: bool = body_results.size() == 2 \
		and not body_results[0].is_empty() and String(body_results[0]["part"]) == "" \
		and body_results[1].get("enemy") == body_results[0]["enemy"] \
		and String(body_results[1].get("part", "")) == "" \
		and (body_results[1]["point"] as Vector3).distance_to(body_results[0]["point"] as Vector3) < 1e-6
	var world_parity: bool = stop_points.size() == 3 \
		and stop_points[1].distance_to(stop_points[0]) < 1e-6 \
		and stop_points[2].distance_to(stop_points[0]) < 1e-6
	_report("muzzle_hit_and_world_parity", weak_parity and body_parity and world_parity,
		"weak=%s body=%s world=%s stops=%d" % [weak_parity, body_parity, world_parity, stop_points.size()])

	bolts.free()
	dummy.free()
