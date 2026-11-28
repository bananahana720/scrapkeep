extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const TRACE_FRAMES := 360
const REST_FRAMES := 27

var _game
var _t := T.new("enemy_lobber_windup_test")
var _frame := 0
var _release_frames := []
var _release_angles := []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	# Hold one real target at the same terrain coordinate in both seeded traces.
	# Count physics ticks only; a process frame can contain more than one tick.
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	_game.player.reset_to(_game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05))
	_game.player.body().freeze = true
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn():
	var at: Vector3 = _game.player.ball_position() + Vector3(15.0, 0.0, 0.0)
	var enemy = _game.combat.spawn_enemy("lobber", _game.ctx.terrain.drop_point(at.x, at.z, 2.1))
	for i in 90:
		if enemy.is_on_floor():
			break
		await _frames(1)
	_t.check("fixture grounded", enemy.is_on_floor())
	enemy.hp = 100000.0
	enemy._clock = 0.0
	enemy._show_charge(0.0)
	return enemy


func _angle(enemy) -> float:
	var rest: Basis = enemy._barrel_rest.basis
	var posed: Basis = enemy._cart.basis * enemy._barrel.basis
	return rad_to_deg(rest.get_rotation_quaternion().angle_to(posed.get_rotation_quaternion()))


func _rest(enemy) -> bool:
	return enemy._cart.transform == enemy._cart_rest and enemy._barrel.transform == enemy._barrel_rest


func _samples() -> void:
	var enemy = await _spawn()
	enemy.set_physics_process(false)
	var angles := []
	var bulb_ok := true
	var pivot_untouched := true
	for progress in [0.0, 0.5, 1.0]:
		var pivot_before: Transform3D = enemy.reaction_pivot.transform
		enemy._show_charge(progress)
		pivot_untouched = pivot_untouched and enemy.reaction_pivot.transform == pivot_before
		angles.append(_angle(enemy))
		bulb_ok = bulb_ok and enemy._muzzle.scale.is_equal_approx(Vector3.ONE * (1.0 + progress * 0.9))
		bulb_ok = bulb_ok and is_equal_approx(enemy._muzzle_material.emission_energy_multiplier, 0.8 + progress * 5.0)
	var monotonic := true
	var previous := -1.0
	for i in 101:
		enemy._show_charge(float(i) / 100.0)
		var angle := _angle(enemy)
		monotonic = monotonic and angle >= previous - 0.0001
		previous = angle
	enemy._show_charge(0.0)
	_t.check("WL-1 e02_tube_raise", _rest(enemy) and angles[0] < 0.001 and absf(angles[1] - 15.0) < 0.01 and absf(angles[2] - 30.0) < 0.01 and monotonic,
		"progress 0 / 0.5 / 1: %.3f / %.3f / %.3f deg; 101 monotonic samples" % angles)
	_t.check("WL-2 barrel in enemy space", angles[2] >= 25.0, "%.3f deg at full pose" % angles[2])
	_t.check("existing bulb swell and light", bulb_ok)
	_t.check("WL-6 pose preserves pivot immediately", pivot_untouched and enemy.reaction_pivot.transform == Transform3D.IDENTITY,
		"unhit identity before and after the sampled pose calls")
	enemy.free()


func _release(_origin: Vector3, _landing: Vector3, _flight: float, enemy) -> void:
	_release_frames.append(_frame)
	_release_angles.append(_angle(enemy))


func _trace(enabled: bool) -> Array:
	await _boot()
	var enemy = await _spawn()
	enemy.windup_pose_enabled = enabled
	enemy.fired.connect(_release.bind(enemy))
	_release_frames.clear()
	_release_angles.clear()
	var trace := []
	var identity := true
	var full_frames := []
	var kick_peak := 0.0
	var kick_aligned := true
	var rocked_positive := false
	var rested := false
	var control_rest := true
	var shape: CollisionShape3D = enemy.find_children("*", "CollisionShape3D", true, false)[0]
	for frame in TRACE_FRAMES:
		_frame = frame
		await _frames(1)
		identity = identity and enemy.reaction_pivot.transform == Transform3D.IDENTITY
		control_rest = control_rest and _rest(enemy)
		if enabled and absf(_angle(enemy) - 30.0) < 0.001:
			full_frames.append(frame)
		if enemy.shots > 0:
			kick_peak = maxf(kick_peak, enemy._barrel.position.distance_to(enemy._barrel_rest.origin))
			var retreat: Vector3 = enemy._barrel.position - enemy._barrel_rest.origin
			if retreat.length() > 0.001:
				var tube_axis: Vector3 = enemy._barrel.basis * Vector3(0.0, cos(0.35), sin(0.35))
				kick_aligned = kick_aligned and retreat.normalized().dot(-tube_axis) > 0.99999
			rocked_positive = rocked_positive or enemy._cart.rotation.x > 0.001
			if enemy._clock >= 0.3 and enemy._clock < 0.5:
				rested = rested or _rest(enemy)
		var rings := []
		for shot in get_nodes_in_group("enemy_shot"):
			if shot.get("lobber") == enemy and is_instance_valid(shot.ring):
				rings.append(shot.ring.descriptor())
		var tele = enemy.telegraph()
		trace.append([enemy.global_position, enemy.velocity, shape.transform, shape.global_transform,
			{} if tele == null else tele.descriptor(), rings, enemy.shots, enemy.charge, enemy._clock])
	if enabled:
		var gap: int = absi(int(full_frames[0]) - int(_release_frames[0])) if not full_frames.is_empty() and not _release_frames.is_empty() else 999
		_t.check("WL-3 full pose on release", _release_frames.size() == 1 and gap <= 1 and absf(float(_release_angles[0]) - 30.0) < 0.001,
			"first full frames %s; fired frames %s; fired angles %s; gap %d physics frames" % [full_frames, _release_frames, _release_angles, gap])
		_t.check("WL-4 cycle recovery", rested, "rest by 0.3 s after release")
		_t.check("release kick and one cart rock", kick_peak > 0.2 and kick_aligned and rocked_positive,
			"barrel kick peak %.3f m along posed tube: %s; cart recoils across rest" % [kick_peak, kick_aligned])
		_t.check("WL-6 unhit pivot identity", identity, "%d physics frames" % TRACE_FRAMES)
	else:
		_t.check("pose-disabled control stays at rest", control_rest, "%d physics frames" % TRACE_FRAMES)
	_game.free()
	_game = null
	return trace


func _invariance() -> void:
	var active := await _trace(true)
	var control := await _trace(false)
	var largest := 0.0
	var exact := active == control
	for frame in active.size():
		for index in [0, 1]:
			largest = maxf(largest, active[frame][index].distance_to(control[frame][index]))
		for index in [2, 3]:
			var a: Transform3D = active[frame][index]
			var b: Transform3D = control[frame][index]
			largest = maxf(largest, a.origin.distance_to(b.origin))
			for axis in 3:
				largest = maxf(largest, a.basis[axis].distance_to(b.basis[axis]))
		for index in [6, 7, 8]:
			largest = maxf(largest, absf(float(active[frame][index]) - float(control[frame][index])))
	_t.check("WL-5 exact physics control", exact and largest == 0.0,
		"seed 11; %d physics frames; position, velocity, collider, telegraph, shell rings, shots, charge and clock; largest difference %.9f" % [TRACE_FRAMES, largest])
	await _boot()


func _windup(enemy) -> void:
	enemy._clock = enemy.CYCLE - enemy.TELEGRAPH * 0.5
	enemy._show_charge(0.5)
	_t.check("fixture mid wind-up", _angle(enemy) > 10.0)


func _interruptions() -> void:
	var enemy = await _spawn()
	_windup(enemy)
	enemy.knock(Vector3.UP, 36.0)
	await _frames(1)
	_t.check("WL-4 stagger clears body", _rest(enemy), "one physics frame after an airborne stagger; attack clock still pauses as before")
	enemy.free()
	enemy = await _spawn()
	var control = await _spawn()
	control.windup_pose_enabled = false
	_windup(enemy)
	control._clock = enemy._clock
	control._show_charge(0.5)
	_game.combat.deal_hit(enemy, "ram", 1.0, Vector3.RIGHT, EventKinds.impact("ram")["knock"])
	_game.combat.deal_hit(control, "ram", 1.0, Vector3.RIGHT, EventKinds.impact("ram")["knock"])
	var peak := 0.0
	var pivot_exact := true
	for i in 10:
		await _frames(1)
		peak = maxf(peak, rad_to_deg(acos(clampf(enemy.reaction_pivot.basis.y.dot(Vector3.UP), -1.0, 1.0))))
		pivot_exact = pivot_exact and enemy.reaction_pivot.transform == control.reaction_pivot.transform
	_t.check("WL-6 ram composes", peak > 1.0 and pivot_exact, "ReactionPivot peak %.3f deg during wind-up; all 10 transforms equal pose-disabled control" % peak)
	enemy.free()
	control.free()
	enemy = await _spawn()
	_windup(enemy)
	_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
	_game.events.line_state_changed.emit("smash_committed", enemy, enemy.global_position, "")
	await _frames(1)
	_t.check("WL-4 harpoon smash clears body", _rest(enemy))
	enemy.free()
	_game.events.line_state_changed.emit("let_go", null, Vector3.ZERO, "")
	for action in ["queue_free", "death", "retry"]:
		enemy = await _spawn()
		_windup(enemy)
		var reset := [false]
		var meshes := [enemy._cart, enemy._barrel]
		var rest := [enemy._cart_rest, enemy._barrel_rest]
		enemy.tree_exiting.connect(func(): reset[0] = meshes[0].transform == rest[0] and meshes[1].transform == rest[1])
		match action:
			"queue_free": enemy.queue_free()
			"death": enemy.take_damage(enemy.hp + 1.0)
			"retry": _game.flow.retry_stage()
		await _frames(REST_FRAMES)
		_t.check("WL-4 " + action, reset[0] and not is_instance_valid(enemy) and not is_instance_valid(meshes[0]) and not is_instance_valid(meshes[1]),
			"both transforms restored at tree_exiting; both nodes gone within 0.3 s")
	var fresh = await _spawn()
	_t.check("WL-4 retry fresh rest", _rest(fresh))
	fresh.free()


func _run() -> void:
	_t.eq("physics frame rate", Engine.physics_ticks_per_second, 90)
	await _boot()
	await _samples()
	_game.free()
	_game = null
	await _invariance()
	await _interruptions()
	_game.free()
	quit(_t.verdict())
