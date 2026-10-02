extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const HOIST := 1.4
const LEAN := 0.22
const SPIN := TAU * 1.25
const FRAMES := 430

var _game
var _test := T.new("enemy_mag_trapper_windup_test")
var _strike_frames := []


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
	await _frames(3)
	# Pin the target for exact paired traces; RigidBody contact ordering can vary
	# between sequential game instances. The enemy still runs real physics and attacks.
	_game.player.set_frozen(true)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(enabled := true):
	var at: Vector3 = _game.player.ball_position() + Vector3(15.0, 0.0, 0.0)
	var enemy = _game.combat.spawn_enemy("mag_trapper", _game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	enemy.hp = 100000.0
	enemy._strafe = 1.0 # Counter handedness uses instance id, so pin it in both runs.
	enemy.pose_enabled = enabled
	enemy._rest = 0.0
	return enemy


func _parts(enemy) -> Array:
	return [enemy.find_child("Cart", true, false), enemy.find_child("MagTopDisc", true, false)]


func _rest(enemy) -> bool:
	var parts := _parts(enemy)
	return parts[0].transform == Transform3D.IDENTITY and parts[1].position == enemy._top_rest \
		and parts[1].basis == Basis.IDENTITY and parts[1].visible


func _samples() -> void:
	var enemy = _spawn()
	enemy.set_physics_process(false)
	var parts := _parts(enemy)
	var rest: Vector3 = enemy._top_rest
	var values := []
	var leans := []
	var spins := []
	enemy.phase = 1
	for progress in [0.0, 0.5, 1.0]:
		enemy._t = enemy.warn_seconds * progress
		enemy._pose()
		values.append((parts[1].position - rest).y)
		leans.append(-parts[0].rotation.x)
		spins.append(parts[1].rotation.y)
	var detail := "e05_stack_hoist progress 0/0.5/1: lift %.6f/%.6f/%.6f m; lean %.6f/%.6f/%.6f rad; spin %.6f/%.6f/%.6f rad" % [values[0], values[1], values[2], leans[0], leans[1], leans[2], spins[0], spins[1], spins[2]]
	_test.check("WG-1 clock samples", values[0] == 0.0 and values[1] > values[0] and values[2] > values[1] \
		and is_equal_approx(values[2], HOIST) and leans[0] == 0.0 and spins[0] == 0.0 \
		and is_equal_approx(leans[2], LEAN) and is_equal_approx(spins[2], SPIN), detail)
	var monotonic := true
	var last := Vector3(-1.0, -1.0, -1.0)
	for step in 101:
		enemy._t = enemy.warn_seconds * step / 100.0
		enemy._pose()
		var value := Vector3((parts[1].position - rest).y, -parts[0].rotation.x, parts[1].rotation.y)
		monotonic = monotonic and value.x >= last.x and value.y >= last.y and value.z >= last.z
		last = value
	_test.check("WG-1 monotonic travel", monotonic, "101 samples of lift, lean and unwrapped spin")
	var measured: float = (enemy.transform.affine_inverse() * parts[1].global_position - enemy._stack.position - rest).length()
	_test.check("WG-2 enemy-space travel", measured >= 0.35, "top disc %.6f m from rest" % measured)
	# Rest must not depend on the last pose, even when the clock goes backwards.
	enemy.phase = 0
	enemy._pose()
	_test.check("WG-1 rest transforms", _rest(enemy), "both nodes at exact rest")
	enemy.phase = 1
	enemy._t = 0.0
	enemy._pose()
	_test.check("WG-1 zero transforms", _rest(enemy), "WARN at zero equals rest")
	enemy.free()


func _on_attack(facts: Dictionary) -> void:
	if facts["phase"] == "strike":
		_strike_frames.append(Engine.get_physics_frames())


func _trace(enabled: bool) -> Array:
	await _boot()
	var enemy = _spawn(enabled)
	var parts := _parts(enemy)
	var shape: CollisionShape3D = enemy.find_children("*", "CollisionShape3D", true, false)[0]
	var trace := []
	var full_frames := []
	var pivot_identity := true
	var pre_release_full := false
	var live_shorter := true
	var rest_after := false
	var saw_rest := false
	_strike_frames = []
	enemy.attack_phase.connect(_on_attack)
	var first_frame := Engine.get_physics_frames()
	for frame in FRAMES:
		await physics_frame
		var tele = enemy.telegraph()
		var tele_data: Array = [] if tele == null else [tele.global_transform, tele.descriptor(), tele.progress, tele.age, tele.warn_seconds, tele.speed, tele._flashed]
		trace.append([enemy.global_position, enemy.velocity, shape.transform, shape.global_transform, tele_data, enemy.phase, enemy.last_warn])
		# The base notification can restore the pivot after a bad pose write. Inspect
		# immediately after re-evaluating this same clock, before that restoration.
		enemy._pose()
		if enabled:
			pivot_identity = pivot_identity and enemy.reaction_pivot.transform == Transform3D.IDENTITY
			if parts[1].position == enemy._top_rest + Vector3.UP * HOIST:
				full_frames.append(Engine.get_physics_frames())
				pre_release_full = pre_release_full or enemy.phase == 1
			if enemy.phase == 2:
				live_shorter = live_shorter and not parts[1].visible and enemy._stack.visible and enemy.find_child("MagDiscs", true, false).visible
			if not _strike_frames.is_empty() and enemy.phase == 0 and not saw_rest:
				rest_after = _rest(enemy)
				saw_rest = true
	if enabled:
		var delta := 999
		if not full_frames.is_empty() and not _strike_frames.is_empty():
			delta = int(full_frames[0]) - int(_strike_frames[0])
		_test.check("WG-3 release frame", not pre_release_full and not full_frames.is_empty() and abs(delta) <= 1,
			"strike frames %s; full frames %s; difference %d physics frames" % [_strike_frames, full_frames, delta])
		_test.check("WG-4 completed cycle", rest_after and _rest(enemy), "exact rest on first ROAM frame after LIVE")
		_test.check("WG-4 one disc leaves", live_shorter and not _strike_frames.is_empty(), "only top disc hidden throughout LIVE")
		_test.check("WG-6 unhit pivot identity", pivot_identity, "identity immediately after _pose over %d real physics frames" % FRAMES)
	var relative_strikes := []
	for frame in _strike_frames:
		relative_strikes.append(int(frame) - first_frame)
	trace.append(relative_strikes)
	_game.free()
	_game = null
	return trace


func _difference(a, b) -> float:
	if typeof(a) != typeof(b):
		return INF
	if a is Vector3:
		return a.distance_to(b)
	if a is Transform3D:
		var largest: float = a.origin.distance_to(b.origin)
		for axis in 3:
			largest = maxf(largest, a.basis[axis].distance_to(b.basis[axis]))
		return largest
	if a is Array:
		if a.size() != b.size():
			return INF
		var largest := 0.0
		for i in a.size():
			largest = maxf(largest, _difference(a[i], b[i]))
		return largest
	if a is Dictionary:
		if a.keys() != b.keys():
			return INF
		var largest := 0.0
		for key in a:
			largest = maxf(largest, _difference(a[key], b[key]))
		return largest
	if a is float or a is int:
		return absf(float(a) - float(b))
	return 0.0 if a == b else INF


func _invariance() -> void:
	_game.free()
	_game = null
	var enabled := await _trace(true)
	var control := await _trace(false)
	# Compare strike events relative to each trace's first physics frame.
	var event_a: Array = enabled.pop_back()
	var event_b: Array = control.pop_back()
	var attacks_equal := event_a == event_b and not event_a.is_empty()
	var largest := _difference(enabled, control)
	for i in enabled.size():
		if enabled[i] != control[i]:
			print("first trace mismatch frame %d: active %s control %s" % [i, enabled[i], control[i]])
			break
	_test.check("WG-5 exact physics control", attacks_equal and enabled == control and largest == 0.0,
		"seed 11; %d frames; position, velocity, collider transforms, complete telegraph and attack phase/timing; largest difference %.9f" % [FRAMES, largest])


func _half_windup():
	var enemy = _spawn()
	for frame in 180:
		await physics_frame
		if enemy.phase == 1 and enemy._warn_progress() >= 0.5:
			return enemy
	_test.check("wind-up reached", false, "180-frame limit")
	return enemy


func _interruptions() -> void:
	await _boot()
	var enemy = await _half_windup()
	# Real combat ram knocks above Counter.INTERRUPT and drives the existing reaction.
	var row: Dictionary = EventKinds.impact("ram")
	_game.combat._hit(enemy, "ram", 1.0, Vector3.RIGHT, row["knock"], "", "", "ram")
	var pivot_during_warn: Transform3D = enemy.reaction_pivot.transform
	enemy._pose()
	var preserves_warn: bool = enemy.phase == 1 and enemy.reaction_pivot.transform == pivot_during_warn
	var peak := 0.0
	for frame in 27:
		await physics_frame
		peak = maxf(peak, rad_to_deg(acos(clampf(enemy.reaction_pivot.basis.y.dot(Vector3.UP), -1.0, 1.0))))
	_test.check("WG-4 stagger resets", enemy.phase == 0 and _rest(enemy), "within 0.3 s after real ram")
	var pivot: Transform3D = enemy.reaction_pivot.transform
	enemy._pose()
	_test.check("WG-6 ram composes", preserves_warn and peak > 1.0 and enemy.reaction_pivot.transform == pivot,
		"reaction peak %.6f deg; _pose preserves pivot" % peak)
	enemy.free()
	enemy = await _half_windup()
	var ball_rest: Vector3 = _game.player.ball_position()
	_game.player.body().global_position = enemy.global_position - Vector3.RIGHT * 2.0
	# Use the actual landing callback, including its shockwave and combat strike route.
	_game.player._finish_landing(enemy, 30.0)
	await _frames(27)
	_test.check("WG-4 harpoon smash", enemy.phase == 0 and _rest(enemy), "within 0.3 s of the real smash landing callback")
	enemy.free()
	_game.player.body().global_position = ball_rest
	# Destruction removes the posed nodes, rather than leaving a detached posed mesh.
	for action in ["queue_free", "death", "retry"]:
		enemy = await _half_windup()
		var parts := _parts(enemy)
		var ids := [enemy.get_instance_id(), parts[0].get_instance_id(), parts[1].get_instance_id()]
		match action:
			"queue_free":
				enemy.queue_free()
			"death":
				enemy.take_damage(enemy.hp + 1.0)
			"retry":
				_game.flow.retry_stage()
		await _frames(27)
		var removed := true
		for id in ids:
			removed = removed and not is_instance_id_valid(id)
		var fresh = _spawn()
		fresh.set_physics_process(false)
		_test.check("WG-4 " + action, removed and _rest(fresh), "all old posed nodes removed within 0.3 s; fresh body at rest")
		fresh.free()
	_game.free()
	_game = null


func _run() -> void:
	_test.eq("physics rate", Engine.physics_ticks_per_second, 90)
	_test.eq("E05 pose name", EventKinds.ATTACK_ROWS["E05"]["pose"], "e05_stack_hoist")
	await _boot()
	_samples()
	await _invariance()
	await _interruptions()
	quit(_test.verdict())
