extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# The harpoon line (DESIGN-NOTES "Harpoon and winch"), through a real Game, real physics and
# scripted input:
#   every pilot RMB fires a line at a body, and Rivet's sprint and Kest's blink stay in the kit
#   lock        an enemy inside harpoon_lock_deg, seen from the ball; a wall refuses it
#   the line    follows a moved body, lets go with the ball's velocity on release, death, stretch,
#               a ride, a hold, and inside the minimum rope; walkable ground cannot be hooked
#   the smash   Ctrl commits a haul that never slows, lands once (slammed and harpoon_smashed), and
#               is never a brake or a slam; the rewind spends the hook until a kill re-seats it
# Evidence limit: rules through real contacts from placed starts and a fixed camera, not a player's
# run; how the line feels is unjudged (the lab sheet's Part 3).

const PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster"}
# The Spillway's middle shelf: flat within 0.3 m over 45 m along -z, so a rolling ball keeps its line.
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _counts := {}
var _origin := Vector3.ZERO
var _smash_speed := 0.0
var _slam_strength := 0.0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _bus() -> void:
	var arity := {"harpoon_bit": 2, "harpoon_smashed": 3, "slammed": 3, "grapple_released": 0, "sprint_started": 1,
		"blink_used": 2, "boosted": 1, "enemy_pinned": 2}
	for kind in arity:
		_counts[kind] = 0
		var tally := _tally.bind(kind)
		_game.events.get(kind).connect(tally.unbind(arity[kind]) if arity[kind] > 0 else tally)
	_game.events.harpoon_smashed.connect(func(_enemy: Node3D, _at: Vector3, speed: float): _smash_speed = speed)
	_game.events.slammed.connect(func(_at: Vector3, strength: float, _flatness: float): _slam_strength = strength)


func _keys_of(slot: String) -> String:
	for record in _player.abilities.slots():
		if record["slot"] == slot:
			return record["key"]
	return ""


func _tally(kind: String) -> void:
	_counts[kind] += 1


# Pilots share one Game: the class is refitted, its slots refilled and the line dropped.
func _pilot(name: String) -> void:
	var def: Resource = ClassDef.by_id(PILOTS[name])
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_source.hold = {}
	_source.press = {}


# A chaser (or another kind) frozen in place: its AI is off, gravity and tows still move it.
func _spawn(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.live = Callable(self, "_never")
	return enemy


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_origin.x + dx, _origin.z + dz, lift)


func _clear_field() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()


func _holds():
	return _combat.fleet.holds


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_player.reset_to(at, velocity)
	_source.hold = {}


func _cam(from: Vector3, to: Vector3) -> void:
	# Shots and the harpoon aim from the lens rest (W16-1): pose the mount the lens
	# sits on and hold the spring arm still, so the per-tick aim reads the posed eye.
	_game.camera.set_process(false)
	_game.camera.arm.set_physics_process_internal(false)
	(_game.camera.cam.get_parent() as Node3D).global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	_game.camera.cam.transform = Transform3D.IDENTITY


func _aim(from: Vector3, to: Vector3) -> Dictionary:
	return _game.aim_along(from, (to - from).normalized())


func _speed() -> float:
	return _player.body().linear_velocity.length()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_origin = FLAT_SHELF
	var shelf_ok := true
	for dz in [-38.0, -20.0, 0.0]:
		shelf_ok = shelf_ok and absf(_game.ctx.terrain.height(_origin.x, _origin.z + dz) - _origin.y) < 0.3
	_check("shelf is flat", shelf_ok, "the test ground at %s stays within 0.3 m of %.0f m for 38 m" % [_origin, _origin.y])
	_bus()
	_clear_field()
	await _sim(0.2)

	await _pilots()
	await _keys()
	await _aim_shapes()
	await _line_follows_and_exits()
	await _smash()

	print("harpoon_line_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _pilots() -> void:
	var ball := _point(0, 0, 6.0)
	var target := _spawn("chaser", _point(0, -20, 1.5))
	await _sim(0.1)
	for name in PILOTS:
		_pilot(name)
		_place(ball)
		_cam(ball + Vector3(0, 0.8, 4.0), target.global_position)
		await _sim(0.05)
		_source.press = {"harpoon_pressed": true}
		_source.hold = {"harpoon_held": true}
		await _sim(0.05)
		var kit = _player.kit
		_check("%s fires a line at a body" % name, kit.on(Augments.GRAPPLE) and kit.hooked and kit.anchor_body == target,
			"grapple fitted %s, hooked %s, on the chaser %s" % [kit.on(Augments.GRAPPLE), kit.hooked, kit.anchor_body == target])
		_source.hold = {}
		_source.press = {}
		_player.release_grapple()
	_pilot("rivet")
	var sprint: bool = _player.kit.on(Augments.SPRINT)
	_pilot("kest")
	_check("class kit stays", sprint and _player.kit.on(Augments.BLINK), "Rivet keeps its sprint (%s) and Kest its blink (%s) under the harpoon" % [sprint, _player.kit.on(Augments.BLINK)])
	target.queue_free()
	await _sim(0.1)


# The bar's movement chip is Shift for every pilot: Sable's boost, Rivet's sprint and Kest's
# blink (re-pinned 2026-10-10, wave P-B unit B1, design-v3/SKILL-BAR.md sections 1 and 2: the
# harpoon has no slot, so Sable's chip shows her boost). E stays interact for a pilot on a
# line, and Sable's mount.
func _keys() -> void:
	var ball := _point(0, 0, 3.0)
	var labels := []
	for name in ["sable", "rivet", "kest"]:
		_pilot(name)
		labels.append(_keys_of(AbilityState.MOVEMENT))
	_check("the bar's movement key is Shift for every pilot", labels == ["Shift", "Shift", "Shift"],
		"Sable, Rivet, Kest: %s" % [labels])
	_pilot("rivet")
	_place(ball)
	_player.grapple_to(ball + Vector3(0, 0, -8), Vector3(1, 0, 0))
	_check("E stays interact for Rivet on a line", not _player.mobility_started(), "a hooked Rivet has no mobility claim on E")
	_pilot("sable")
	_player.grapple_to(ball + Vector3(0, 0, -8), Vector3(1, 0, 0))
	_check("E stays the mount for Sable on a line", _player.mobility_started(), "a hooked Sable claims E")
	_player.release_grapple()
	_source.press = {}


func _aim_shapes() -> void:
	_pilot("sable")
	var ball := _point(0, 0, 6.0)
	var chaser := _spawn("chaser", _point(0, -20, 1.5))
	await _sim(0.1)
	var eye := ball + Vector3(0, 0.8, 4.0)
	var centre := chaser.global_position
	var aim := _aim(eye, centre)
	_check("lock: the centre ray takes the body", aim.get("state") == Augments.AIM_BODY and aim.get("body") == chaser,
		"state %s (body = %s), body is the chaser %s" % [aim.get("state"), Augments.AIM_BODY, aim.get("body") == chaser])
	var off := centre + (Vector3.RIGHT * (centre - eye).length() * tan(deg_to_rad(3.0)))
	aim = _aim(eye, off)
	_check("lock: 3 degrees off locks it", aim.get("state") == Augments.AIM_BODY and aim.get("body") == chaser,
		"state %s, locked the chaser %s" % [aim.get("state"), aim.get("body") == chaser])
	var wide := centre + (Vector3.RIGHT * (centre - eye).length() * tan(deg_to_rad(16.0)))
	aim = _aim(eye, wide)
	_check("lock: 16 degrees off is outside the cone", aim.get("body") == null, "state %s" % aim.get("state"))

	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 30, 1)
	box.shape = shape
	wall.add_child(box)
	root.add_child(wall)
	wall.global_position = Vector3(centre.x, centre.y + 5.0, centre.z + 8.0)
	await _sim(0.1)
	aim = _aim(eye, off)
	_check("lock: a wall refuses it", aim.get("body") != chaser, "a chaser behind a wall: state %s, body %s" % [aim.get("state"), aim.get("body")])
	wall.free()

	var floor_point := _point(0, -6, 0.0)
	aim = _aim(eye, floor_point)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var plain := Augments.grapple_target(space, eye, (floor_point - eye).normalized(), _player.ball_position(),
		_player.grapple_range(), _game.tuning.f("grapple_assist_deg"))
	_check("walkable ground cannot be hooked", aim.get("state") == Augments.AIM_NONE and plain.get("state") != Augments.AIM_NONE,
		"aimed at open ground: harpoon state %s, unfiltered ray state %s" % [aim.get("state"), plain.get("state")])
	chaser.queue_free()
	await _sim(0.1)


func _line_follows_and_exits() -> void:
	_pilot("sable")
	var ball := _point(0, 0, 6.0)
	var chaser := _spawn("chaser", _point(0, -20, 1.5))
	await _sim(0.1)
	_place(ball, Vector3(0, 0, -10))
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	var kit = _player.kit
	_check("bite flashes and announces", _counts["harpoon_bit"] >= 1 and kit.line_state == Augments.LINE_LATCHED,
		"harpoon_bit fired %d, line state %d (latched = %d)" % [_counts["harpoon_bit"], kit.line_state, Augments.LINE_LATCHED])
	chaser.global_position += Vector3(6, 0, 0)
	await _sim(0.05)
	var follow: float = kit.anchor.distance_to(chaser.global_position + kit.anchor_offset)
	_check("anchor follows a moved body", follow < 0.2, "anchor %.3f m from the body's bite point after it moved 6 m" % follow)

	_place(ball, Vector3(0, 0, -10))
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	var before := _speed()
	_source.press = {"harpoon_released": true}
	await _sim(0.03)
	_check("release keeps velocity", not kit.hooked and _speed() > before - 0.5, "hooked %s, speed %.2f -> %.2f" % [kit.hooked, before, _speed()])

	_place(ball, Vector3(0, 0, -10))
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	before = _speed()
	chaser.global_position += Vector3(0, 0, -100)
	await _sim(0.03)
	_check("over-stretch lets go", not kit.hooked and _speed() > before - 0.5, "line 100 m long: hooked %s, speed %.2f -> %.2f" % [kit.hooked, before, _speed()])
	chaser.global_position = _point(0, -20, 1.5)

	_place(ball, Vector3(0, 0, -10))
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	before = _speed()
	_player.set_velocity_now(Vector3(0, 0, -12))
	await _sim(0.03)
	_check("a ride or launch drops the line", not kit.hooked, "set_velocity_now from world: hooked %s" % kit.hooked)

	_place(ball, Vector3(0, 0, -10))
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	var held: bool = _holds().catch(chaser, "tether", [], 1.0)
	_check("a landed hold cuts the line", held and not kit.hooked, "hold landed %s, hooked %s" % [held, kit.hooked])
	_holds().clear()

	# Passing a latched body: the line lets go inside the minimum rope and radii, so no dead stop.
	_place(_point(0, -8, 3.0), Vector3(0, 0, -14))
	chaser.global_position = _point(4, -20, 1.5)
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	before = _speed()
	await _sim(1.2)
	_check("passing a body drops the line, no dead stop", not kit.hooked and _speed() > before * 0.9,
		"passed a latched body at 4 m: hooked %s, speed %.1f -> %.1f (>= 90%%)" % [kit.hooked, before, _speed()])
	chaser.global_position = _point(0, -20, 1.5)

	_place(ball, Vector3(0, 0, -10))
	await _sim(0.02)
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	before = _speed()
	_combat.strike(chaser, "runner", 99999.0)
	await _sim(0.05)
	_check("anchor death drops the line", not kit.hooked and _speed() > before - 0.5, "hooked %s, speed %.2f -> %.2f" % [kit.hooked, before, _speed()])
	await _sim(0.3)


func _haul(chaser: Node3D, start: Vector3, hold_ctrl_first := false) -> Dictionary:
	var kit = _player.kit
	_place(start, Vector3.ZERO)
	_counts["slammed"] = 0
	_counts["harpoon_smashed"] = 0
	_player.grapple_to(chaser.global_position, Vector3.UP, chaser)
	_source.hold = {"harpoon_held": true, "brake_held": true} if hold_ctrl_first else {"harpoon_held": true}
	await _sim(0.03)
	var hp_before: float = chaser.hp
	_source.hold = {"harpoon_held": true, "brake_held": true}
	var floor_speed := 0.0
	var min_speed := INF
	var slammed_ever := false
	var committed := false
	for tick in roundi(1.6 * Engine.physics_ticks_per_second):
		await physics_frame
		if kit.line_state == Augments.LINE_SMASH:
			if not committed:
				committed = true
				floor_speed = kit.smash_floor
			min_speed = minf(min_speed, _speed())
		slammed_ever = slammed_ever or kit.slamming
		if not kit.hooked and committed:
			break
	_source.hold = {}
	return {"committed": committed, "floor": floor_speed, "min": min_speed, "slammed_ever": slammed_ever,
		"hp_before": hp_before, "chaser_alive": is_instance_valid(chaser) and not chaser.is_dead()}


func _smash() -> void:
	_pilot("sable")
	var kit = _player.kit
	var chaser := _spawn("chaser", _point(0, -22, 1.5))
	# A light ball, so the landing wounds the chaser without killing it and the rewind can be read.
	_combat.heft_override = 0.4
	await _sim(0.1)
	var run := await _haul(chaser, _point(0, 0, 1.4))
	_check("smash commits and never slows", run["committed"] and run["min"] >= run["floor"] - 0.6,
		"committed %s at %.1f m/s, slowest during the haul %.1f" % [run["committed"], run["floor"], run["min"]])
	_check("the landing carries the closing speed", _smash_speed >= run["floor"] - 0.6 and _slam_strength >= 0.7,
		"harpoon_smashed at %.1f m/s (committed at %.1f), slam strength %.2f (24 m/s is 0.8)" % [_smash_speed, run["floor"], _slam_strength])
	_check("smash lands once", _counts["harpoon_smashed"] == 1 and _counts["slammed"] == 1 and not kit.hooked,
		"harpoon_smashed %d, slammed %d, line released %s" % [_counts["harpoon_smashed"], _counts["slammed"], not kit.hooked])
	var hp_after: float = chaser.hp if is_instance_valid(chaser) else 0.0
	_check("smash hurts the body and never slams", hp_after < run["hp_before"] and not run["slammed_ever"],
		"chaser hp %.1f -> %.1f, kit.slamming ever true %s" % [run["hp_before"], hp_after, run["slammed_ever"]])
	_check("rewind starts at the landing", kit.rewind_left > 0.0 and kit.rewind_left <= _game.tuning.f("harpoon_rewind"),
		"%.2f s of %.1f s left with the chaser alive at %.1f hp" % [kit.rewind_left, _game.tuning.f("harpoon_rewind"), hp_after])

	_combat.heft_override = 1.0
	# The spent hook: a press with rewind left fires nothing, and a kill re-seats it at once.
	_place(_point(0, 0, 1.4))
	_cam(_point(0, 0, 2.2) + Vector3(0, 0, 4.0), chaser.global_position)
	kit.rewind_left = 0.8
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	var spent_ok: bool = not kit.hooked
	_combat.strike(chaser, "runner", 99999.0)
	await _sim(0.05)
	_check("a kill re-seats the hook", spent_ok and kit.rewind_left == 0.0, "press with rewind left fired nothing %s; after the kill rewind %.2f s" % [spent_ok, kit.rewind_left])
	var next := _spawn("chaser", _point(0, -22, 1.5))
	await _sim(0.1)
	_place(_point(0, 0, 1.4))
	_cam(_point(0, 0, 2.2) + Vector3(0, 0, 4.0), next.global_position)
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	_check("a seated hook fires", kit.hooked and kit.anchor_body == next, "hooked %s on the next chaser %s" % [kit.hooked, kit.anchor_body == next])
	_player.release_grapple()

	# Ctrl held before the bite has no edge, so no commit; it is still not a brake and not a slam.
	_place(_point(0, 0, 1.4), Vector3(0, 0, -12))
	_source.hold = {"brake_held": true}
	await _sim(0.03)
	_player.grapple_to(next.global_position, Vector3.UP, next)
	await _sim(0.5)
	_check("held Ctrl never brakes a body line", kit.line_state == Augments.LINE_LATCHED and _speed() > 11.0,
		"line state %d (latched %d), speed %.1f after 0.5 s of Ctrl from 12 m/s" % [kit.line_state, Augments.LINE_LATCHED, _speed()])
	_player.release_grapple()
	_place(_point(0, 0, 9.0), Vector3(0, 0, -4))
	_source.hold = {"brake_held": true}
	await _sim(0.03)
	_player.grapple_to(next.global_position, Vector3.UP, next)
	var slammed := false
	for tick in roundi(0.3 * Engine.physics_ticks_per_second):
		await physics_frame
		slammed = slammed or kit.slamming
	_check("held Ctrl in the air never starts a slam", not slammed, "kit.slamming ever true over 0.3 s on a body line: %s" % slammed)
	_source.hold = {}
	_player.release_grapple()

	# Escapes: a jump, a boost or a dash lets a committed haul go, keeping the speed.
	for escape in ["jump_pressed", "boost_pressed", "movement_pressed"]:
		_pilot("sable")
		_place(_point(0, 0, 3.0), Vector3(0, 0, -6))
		_player.grapple_to(next.global_position, Vector3.UP, next)
		_source.hold = {"harpoon_held": true, "brake_held": true}
		await _sim(0.1)
		var committed: bool = kit.line_state == Augments.LINE_SMASH
		var speed_in := _speed()
		_source.press = {escape: true}
		await _sim(0.03)
		_check("%s lets a haul go" % escape, committed and not kit.hooked and _speed() > speed_in - 1.0,
			"committed %s, hooked %s, speed %.1f -> %.1f" % [committed, kit.hooked, speed_in, _speed()])
		_source.hold = {}
		await _sim(0.1)

	# Timeout: a haul that cannot arrive (a wall across the path) lets go after SMASH_MAX.
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 40, 1)
	box.shape = shape
	wall.add_child(box)
	root.add_child(wall)
	wall.global_position = _point(0, -6, 0.0)
	_place(_point(0, 0, 3.0), Vector3(0, 0, -6))
	_player.grapple_to(next.global_position, Vector3.UP, next)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	await _sim(0.1)
	var timed_in: bool = kit.line_state == Augments.LINE_SMASH
	await _sim(Augments.SMASH_MAX + 0.2)
	_source.hold = {}
	_check("a haul that cannot land times out", timed_in and not kit.hooked, "committed %s, hooked %.1f s later: %s" % [timed_in, Augments.SMASH_MAX + 0.3, kit.hooked])
	wall.queue_free()
	next.queue_free()
	await _sim(0.1)
