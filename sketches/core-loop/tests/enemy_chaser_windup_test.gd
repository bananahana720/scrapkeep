extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const SAMPLES := [0.0, 0.5, 1.0]
const FULL_SHIFT := Vector3(0.0, 0.3, 0.7)
const FULL_PITCH := 42.0
const PART_NAMES := ["ChaserBody", "ChaserFin", "ChaserClaws"]
var _game
var _t := T.new("enemy_chaser_windup_test")


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
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn():
	var enemy = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6))
	enemy.hp = 100000.0
	return enemy


func _relative(enemy, part_name: String) -> Transform3D:
	var part: Dictionary = enemy._pose_parts[part_name]
	return part.node.transform * (part.rest as Transform3D).affine_inverse()


func _rest(enemy) -> bool:
	for part_name in PART_NAMES:
		if not _relative(enemy, part_name).is_equal_approx(Transform3D.IDENTITY):
			return false
	return enemy._mesh.scale == Vector3.ONE and is_zero_approx(enemy._mesh.rotation.x)


func _brace(enemy) -> bool:
	var body := _relative(enemy, "ChaserBody")
	return body.origin.is_equal_approx(FULL_SHIFT) and is_equal_approx(body.basis.get_euler().x, deg_to_rad(FULL_PITCH))


func _samples() -> void:
	var enemy = _spawn()
	enemy.set_physics_process(false)
	enemy._begin_windup(Vector3.FORWARD)
	var values := []
	var rests := true
	var endpoints := true
	for progress in SAMPLES:
		enemy._clock = enemy.WINDUP * progress
		enemy._pose()
		var body := _relative(enemy, "ChaserBody")
		var fin: Node3D = enemy._pose_parts["ChaserFin"].node
		var fin_rest: Transform3D = enemy._pose_parts["ChaserFin"].rest
		var relative_flare: Basis = body.basis.inverse() * fin.basis * fin_rest.basis.inverse()
		values.append([body.origin.length(), rad_to_deg(body.basis.get_euler().x), rad_to_deg(relative_flare.get_euler().x)])
		if progress == 0.0:
			rests = _rest(enemy)
		if progress == 1.0:
			endpoints = _brace(enemy) and is_equal_approx(values[-1][2], 32.0)
	var monotonic := true
	var previous := [0.0, 0.0, 0.0]
	for i in 61:
		enemy._clock = enemy.WINDUP * float(i) / 60.0
		enemy._pose()
		var body := _relative(enemy, "ChaserBody")
		var fin: Node3D = enemy._pose_parts["ChaserFin"].node
		var metrics := [body.origin.length(), body.basis.get_euler().x, fin.rotation.x]
		for j in 3:
			monotonic = monotonic and metrics[j] + 0.000001 >= previous[j]
		previous = metrics
		monotonic = monotonic and _relative(enemy, "ChaserClaws").is_equal_approx(Transform3D.IDENTITY)
	_t.check("WC-1 e01_brace_back", rests and endpoints and monotonic and values[0][0] < values[1][0] and values[1][0] < values[2][0],
		"progress 0, 0.5, 1: [travel m, nose deg, fin flare deg] %s; rest %s; monotonic %s" % [values, rests, monotonic])
	_t.check("WC-2 range", values[2][0] >= 0.35 and values[2][2] >= 25.0,
		"body %.6f m; hinged fin %.3f deg relative to body (enemy space)" % [values[2][0], values[2][2]])
	# PC-2: head-on the 18 degree brace hid in the silhouette; the rear-up now travels 0.762 m and pitches 42 degrees.
	_t.check("PC-2 rear-up travel", absf(values[2][0] - 0.7616) < 0.001 and absf(values[1][0] - 0.3808) < 0.001
		and absf(values[2][1] - 42.0) < 0.001 and absf(values[1][1] - 21.0) < 0.001,
		"travel %.4f m and nose %.3f deg at progress 1; %.4f m and %.3f deg at 0.5" % [values[2][0], values[2][1], values[1][0], values[1][1]])
	_t.check("pose row", EventKinds.attack_row("E01")["pose"] == "e01_brace_back")
	_t.check("no scale squash", enemy._mesh.scale == Vector3.ONE)
	enemy.free()


func _cycle() -> void:
	var enemy = _spawn()
	var fired := [-1]
	enemy.attack_phase.connect(func(facts: Dictionary):
		if facts.phase == "strike":
			fired[0] = Engine.get_physics_frames())
	enemy._begin_windup(Vector3.FORWARD)
	enemy._pose()
	var first_full := -1
	var release := -1
	var snap_at := -1
	var release_braced := false
	var pivot_identity := true
	var early := false
	for i in 180:
		await physics_frame
		var frame := Engine.get_physics_frames()
		enemy._pose()
		pivot_identity = pivot_identity and enemy.reaction_pivot.transform == Transform3D.IDENTITY
		if _brace(enemy) and first_full < 0:
			first_full = frame
			early = enemy.state == enemy.State.WINDUP and not is_equal_approx(enemy._clock / enemy.WINDUP, 1.0)
		if enemy.state == enemy.State.LUNGE and release < 0:
			release = frame
			release_braced = _brace(enemy)
		if enemy.state == enemy.State.LUNGE and enemy._clock >= 0.08 and snap_at < 0:
			var body := _relative(enemy, "ChaserBody")
			if is_equal_approx(body.basis.get_euler().x, deg_to_rad(-12.0)) and body.origin.z < 0.0:
				snap_at = frame
	_t.check("WC-3 release", release_braced and first_full >= 0 and release >= 0 and absi(release - first_full) <= 1 and not early and fired[0] >= 0 and absi(fired[0] - first_full) <= 1,
		"first full %d; lunge %d; strike fact %d; braced at release %s; early %s" % [first_full, release, fired[0], release_braced, early])
	_t.check("forward snap under 0.1 s", snap_at >= 0 and float(snap_at - release) / Engine.physics_ticks_per_second < 0.1,
		"nose-down reached after %d physics frames" % (snap_at - release))
	_t.check("WC-4 cycle rest", _rest(enemy), "all three parts at rest after recover")
	_t.check("WC-6 unhit pivot", pivot_identity, "identity through 180 physics frames")
	enemy.free()


func _armed():
	var enemy = _spawn()
	enemy._begin_windup(Vector3.FORWARD)
	await _frames(18)
	_t.check("interruption fixture loaded", not _rest(enemy) and enemy.state == enemy.State.WINDUP)
	return enemy


func _part_ids(enemy) -> Array[int]:
	var ids: Array[int] = []
	for part_name in PART_NAMES:
		ids.append(enemy._pose_parts[part_name].node.get_instance_id())
	return ids


func _gone(ids: Array[int]) -> bool:
	for id in ids:
		if is_instance_id_valid(id):
			return false
	return true


func _interruptions() -> void:
	var enemy = await _armed()
	enemy.knock(Vector3.RIGHT, 14.0)
	await _frames(2)
	_t.check("WC-4 stagger rest", enemy.state == enemy.State.RECOVER and _rest(enemy), "rest within two physics frames")
	enemy.free()
	enemy = await _armed()
	_game.combat.deal_hit(enemy, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"])
	await _frames(3)
	var tipped: bool = enemy.reaction_pivot.transform != Transform3D.IDENTITY
	var before: Transform3D = enemy.reaction_pivot.transform
	enemy._pose()
	_t.check("WC-6 ram composes", tipped and enemy.reaction_pivot.transform == before and _rest(enemy), "ram tips pivot; direct pose call preserves its exact transform; attack resets")
	enemy.free()
	enemy = await _armed()
	_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
	await _frames(2)
	_game.events.line_state_changed.emit("smash_committed", enemy, Vector3.ZERO, "")
	_game.combat.deal_hit(enemy, "ram", 1.0, Vector3.RIGHT, enemy.INTERRUPT + 5.0)
	await _frames(2)
	_t.check("WC-4 harpoon smash rest", enemy.state == enemy.State.RECOVER and _rest(enemy))
	enemy.free()
	enemy = await _armed()
	var freed_id: int = enemy.get_instance_id()
	var freed_parts := _part_ids(enemy)
	enemy.queue_free()
	await _frames(2)
	var fresh = _spawn()
	_t.check("WC-4 queue_free cleanup", not is_instance_id_valid(freed_id) and _gone(freed_parts) and _rest(fresh), "old posed nodes gone; new instance at rest in two frames")
	fresh.free()
	enemy = await _armed()
	var dead_id: int = enemy.get_instance_id()
	var dead_parts := _part_ids(enemy)
	enemy.take_damage(enemy.hp + 1.0)
	await _frames(2)
	fresh = _spawn()
	_t.check("WC-4 death cleanup", not is_instance_id_valid(dead_id) and _gone(dead_parts) and _rest(fresh))
	fresh.free()
	enemy = await _armed()
	var retry_id: int = enemy.get_instance_id()
	var retry_parts := _part_ids(enemy)
	_game.flow.retry_stage()
	await _frames(2)
	fresh = _spawn()
	_t.check("WC-4 stage retry cleanup", not is_instance_id_valid(retry_id) and _gone(retry_parts) and _rest(fresh) and _game.flow.state == _game.flow.STAGE,
		"real retry removes posed instance; replacement rests in two frames")
	fresh.free()


func _trace(enabled: bool) -> Array:
	await _boot()
	# Harpoon lean reads the real ball. Freeze its identical endpoint in both traces.
	var ball: RigidBody3D = _game.player.body()
	ball.freeze = true
	ball.global_position = Vector3(0.0, 30.0, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	var enemy = _spawn()
	enemy.windup_pose_enabled = enabled
	var shape: CollisionShape3D = enemy.find_children("*", "CollisionShape3D", true, false)[0]
	var trace := []
	var phases := []
	var tick := [-1]
	enemy.attack_phase.connect(func(facts: Dictionary):
		phases.append([tick[0], facts.row, facts.phase, facts.progress, facts.geometry.duplicate(true)]))
	var control_rest := true
	for frame in 240:
		tick[0] = frame
		if frame in [0, 180]:
			enemy._begin_windup(Vector3.FORWARD)
		if frame == 198:
			_game.combat.deal_hit(enemy, "ram", 1.0, Vector3.RIGHT, 14.0)
		if frame == 200:
			_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
		if frame == 205:
			_game.events.line_state_changed.emit("smash_committed", enemy, Vector3.ZERO, "")
		if frame == 207:
			_game.events.line_state_changed.emit("broke", null, Vector3.ZERO, "")
		await physics_frame
		var lane = enemy.telegraph()
		trace.append([enemy.global_position, enemy.velocity, shape.transform, shape.global_transform,
			{} if lane == null else lane.descriptor(), -1.0 if lane == null else lane.progress,
			enemy.state, enemy._clock, enemy.lunges, enemy.collision_layer, enemy.collision_mask, phases.duplicate(true), enemy.reaction_pivot.transform])
		if not enabled:
			control_rest = control_rest and _rest(enemy)
	if not enabled:
		_t.check("WC-5 disabled pose rests", control_rest, "all parts rest through 240 control frames")
	_game.free()
	_game = null
	return trace


func _invariance() -> void:
	_game.free()
	_game = null
	var active := await _trace(true)
	var control := await _trace(false)
	var largest := 0.0
	var pivots_equal := true
	var physics_equal := true
	for frame in active.size():
		physics_equal = physics_equal and active[frame].slice(0, -1) == control[frame].slice(0, -1)
		if pivots_equal and active[frame][-1] != control[frame][-1]:
			print("pivot first difference frame %d: %s versus %s" % [frame, active[frame][-1], control[frame][-1]])
		pivots_equal = pivots_equal and active[frame][-1] == control[frame][-1]
		for i in 2:
			largest = maxf(largest, (active[frame][i] as Vector3).distance_to(control[frame][i]))
		for i in [2, 3]:
			var a: Transform3D = active[frame][i]
			var b: Transform3D = control[frame][i]
			largest = maxf(largest, a.origin.distance_to(b.origin))
			for axis in 3:
				largest = maxf(largest, a.basis[axis].distance_to(b.basis[axis]))
	_t.check("WC-6 reaction control", pivots_equal, "ram and harpoon pivot transforms equal pose-off control at every physics frame")
	_t.check("WC-5 exact physics", physics_equal and largest == 0.0,
		"seed 11; 240 physics frames; position, velocity, collider, telegraph, attack state/clock/facts; largest difference %.9f" % largest)


func _run() -> void:
	await _boot()
	_samples()
	await _cycle()
	await _interruptions()
	await _invariance()
	quit(_t.verdict())
