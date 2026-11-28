extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const FRAMES := 360
# The rotor's idle turn and the spin-up's end rate, as literal numbers: 2 * 3.25 * TAU rad/s at progress 1.
const IDLE_RATE := 4.0
const TOLERANCE := 0.0001
# Literal expectations at progress 0 / 0.5 / 1 (pitch degrees, drum rad, rotor rad). TAU * 2.25 * p^2 and TAU * 3.25 * p^2.
const WARN_VALUES := [[0.0, 0.0, 0.0], [16.0, 3.534292, 5.105088], [32.0, 14.137167, 20.420352]]

var game
var t := T.new("enemy_winch_drone_windup_test")
var ball := Vector3.ZERO
var tick := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _spawn(enabled := true):
	var at := Vector3(ball.x + 9.0, 0.0, ball.z + 3.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + 5.5
	var drone = game.combat.spawn_enemy("winch_drone", at)
	drone.windup_pose_enabled = enabled
	drone._strafe = 1.0
	drone._rest = 0.1
	drone.hp = 100000.0
	return drone


# At rest the aim and the drum sit at their rest transforms; the rotor is at its rest position and only
# yawed about its own axis by the idle turn.
func _rest(drone) -> bool:
	var yaw: Transform3D = drone._rotor.transform * drone._rotor_rest.affine_inverse()
	return drone._aim.transform == Transform3D.IDENTITY and drone._drum.transform == drone._drum_rest \
		and yaw.origin.is_zero_approx() and yaw.basis.y.is_equal_approx(Vector3.UP)


func _rotor_yaw(drone) -> float:
	return (drone._rotor.transform * drone._rotor_rest.affine_inverse()).basis.get_euler().y


func _samples() -> void:
	var drone = _spawn()
	drone.set_physics_process(false)
	drone.phase = drone.Phase.WARN
	var values := []
	var correct := true
	drone._idle_from = Engine.get_physics_frames()
	var rates := []
	for index in 3:
		var progress: float = [0.0, 0.5, 1.0][index]
		drone._t = progress * drone.warn_seconds
		drone._pose()
		values.append([rad_to_deg(drone._aim.rotation.x), drone._spin.x, drone._spin.y])
		for axis in 3:
			correct = correct and absf(values[index][axis] - WARN_VALUES[index][axis]) < 0.001
		correct = correct and drone._drum.transform.is_equal_approx(drone._drum_rest * Transform3D(Basis(Vector3.RIGHT, drone._spin.x), Vector3.ZERO))
		correct = correct and drone._rotor.transform.is_equal_approx(drone._rotor_rest * Transform3D(Basis(Vector3.UP, drone._spin.y), Vector3.ZERO))
		if progress == 0.0:
			correct = correct and _rest(drone)
	for i in range(1, values.size()):
		for component in 3:
			correct = correct and values[i][component] > values[i - 1][component]
	# PC-4: the rotor's rate through the wind-up (rad/s) beats the idle rate from progress 0.25 on.
	var beats := true
	for progress in [0.25, 0.5, 0.75, 1.0]:
		# Backward difference over 0.01 of the clock: it measures the rate at progress - 0.005.
		drone._t = (progress - 0.01) * drone.warn_seconds
		drone._pose()
		var before: float = drone._spin.y
		drone._t = progress * drone.warn_seconds
		drone._pose()
		var rate: float = (drone._spin.y - before) / (0.01 * drone.warn_seconds)
		rates.append(rate)
		beats = beats and rate > IDLE_RATE
	var rate_pinned: bool = absf(rates[0] - 10.006) < 0.01 and absf(rates[3] - 40.636) < 0.01 and rates[0] > IDLE_RATE
	t.check("PC-4 wind-up rate beats idle", beats and rate_pinned, "rotor rad/s at progress 0.25/0.5/0.75/1: %s; idle %.1f rad/s" % [rates, IDLE_RATE])
	t.check("WD-1 e11_cable_guide", correct, "progress 0 / 0.5 / 1: [pitch deg, drum rad, rotor rad] %s" % [values])
	var in_enemy: Transform3D = drone.global_transform.affine_inverse() * drone._aim.global_transform
	var angle := rad_to_deg(acos(clampf(in_enemy.basis.y.dot(Vector3.UP), -1.0, 1.0)))
	t.check("WD-2 body travel", angle >= 25.0, "%.6f degrees in the enemy's own space" % angle)
	drone.free()


# PC-4: a hovering drone's rotor turns at the idle rate, and not at all with the pose off.
func _idle() -> void:
	var drone = _spawn()
	drone.set_physics_process(false)
	drone._idle_from = Engine.get_physics_frames()
	await _frames(15)
	drone._pose()
	var first := _rotor_yaw(drone)
	await _frames(15)
	drone._pose()
	var second := _rotor_yaw(drone)
	var seconds := 15.0 / float(Engine.physics_ticks_per_second)
	var rate := (second - first) / seconds
	t.check("PC-4 idle turn", absf(first - IDLE_RATE * seconds) < 0.001 and absf(second - 2.0 * IDLE_RATE * seconds) < 0.001 and absf(rate - IDLE_RATE) < 0.01,
		"rotor yaw %.4f rad after 15 frames, %.4f after 30; %.3f rad/s against the %.1f rad/s the code names (%d ticks/s)" % [first, second, rate, IDLE_RATE, Engine.physics_ticks_per_second])
	var still = _spawn(false)
	still.set_physics_process(false)
	await _frames(15)
	still._pose()
	t.check("PC-4 control seam rotor still", still._rotor.transform == still._rotor_rest, "pose off: the rotor stays at its rest transform")
	still.free()
	drone.free()


func _trace(enabled: bool) -> Dictionary:
	await _boot()
	var drone = _spawn(enabled)
	var released := []
	drone.attack_phase.connect(func(fact: Dictionary):
		if fact["phase"] == "strike":
			released.append(tick))
	var trace := []
	var full_frame := -1
	var saw_warn := false
	var saw_live := false
	var live_holds := true
	var live_frames := 0
	var held_frames := 0
	var pivot_identity := true
	var settled := false
	for frame in FRAMES:
		tick = frame
		# Keep the real ball in the committed lane without changing the drone's attack clock.
		game.player.reset_to(ball)
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
		var shape: CollisionShape3D = drone.find_children("*", "CollisionShape3D", true, false)[0]
		var tele = drone.telegraph()
		var geometry: Dictionary = tele.descriptor() if tele != null else {}
		trace.append([drone.global_position, drone.velocity, shape.transform, shape.global_transform,
			geometry, tele.progress if tele != null else -1.0, drone.phase, drone._t, drone.caught, drone.warned])
		# Call the pose directly too: enemy.gd must not mask an illegal pivot write.
		drone._pose()
		pivot_identity = pivot_identity and drone.reaction_pivot.transform == Transform3D.IDENTITY
		saw_warn = saw_warn or drone.phase == drone.Phase.WARN
		if enabled and full_frame < 0 and is_equal_approx(drone._aim.rotation.x, deg_to_rad(32.0)):
			full_frame = frame
		if drone.phase == drone.Phase.LIVE:
			saw_live = true
			live_frames += 1
			if drone._holding():
				held_frames += 1
			if enabled:
				live_holds = live_holds and is_equal_approx(drone._aim.rotation.x, deg_to_rad(32.0))
		if saw_live and drone.phase == drone.Phase.ROAM and drone._t >= 0.3:
			settled = _rest(drone)
	if enabled:
		t.check("WD-3 release frame", saw_warn and saw_live and released.size() == 1 and abs(full_frame - released[0]) <= 1,
			"first full pose frame %d; attack strike frames %s; physics tolerance 1 frame" % [full_frame, released])
		t.check("WD-4 live and cycle rest", live_holds and settled and held_frames > 1, "full aim while live for %d frames, cable held %d frames; exact rest within 0.3 s after cycle" % [live_frames, held_frames])
		t.check("WD-6 unhit pivot", pivot_identity, "identity through %d physics frames" % FRAMES)
	game.free()
	game = null
	return {"trace": trace, "release": released}


func _windup_jump(drone) -> float:
	var previous := _rotor_yaw(drone)
	var largest := 0.0
	var frames := int(round(drone.warn_seconds * Engine.physics_ticks_per_second))
	drone.phase = drone.Phase.WARN
	for frame in range(frames + 1):
		drone._t = float(frame) / float(Engine.physics_ticks_per_second)
		drone._pose()
		var angle := _rotor_yaw(drone)
		largest = maxf(largest, absf(wrapf(angle - previous, -PI, PI)))
		previous = angle
		await physics_frame
	return largest


func _coast_restart() -> void:
	var normal = _spawn()
	normal.set_physics_process(false)
	normal._idle_from = Engine.get_physics_frames()
	var normal_jump := await _windup_jump(normal)
	normal.free()
	var drone = _spawn()
	drone.set_physics_process(false)
	drone._idle_from = Engine.get_physics_frames()
	drone.phase = drone.Phase.WARN
	drone._t = 0.5 * drone.warn_seconds
	drone._pose()
	drone.phase = drone.Phase.ROAM
	drone._t = 1.0 / float(Engine.physics_ticks_per_second)
	drone._pose()
	var coasting: bool = drone._recovering and drone._pose_phase == drone.Phase.ROAM
	var restart_jump := await _windup_jump(drone)
	t.check("DR-3 coast restart continuity", coasting and normal_jump > 0.0 and restart_jump <= normal_jump + TOLERANCE,
		"largest rotor step: normal %.6f rad, restart during coast %.6f rad; recovering %s" % [normal_jump, restart_jump, coasting])
	drone.free()


func _invariance() -> void:
	var active := await _trace(true)
	var control := await _trace(false)
	var exact: bool = active == control
	var largest := 0.0
	for frame in FRAMES:
		var a: Array = active.trace[frame]
		var b: Array = control.trace[frame]
		for index in [0, 1]:
			largest = maxf(largest, a[index].distance_to(b[index]))
		for index in [2, 3]:
			var ta: Transform3D = a[index]
			var tb: Transform3D = b[index]
			largest = maxf(largest, ta.origin.distance_to(tb.origin))
			for axis in 3:
				largest = maxf(largest, ta.basis[axis].distance_to(tb.basis[axis]))
	t.check("WD-5 visual only", exact and largest == 0.0, "seed 11 x %d physics frames; position, velocity, collider, telegraph geometry/progress, phases, clock, catches and attack frames exact; largest difference %.9f" % [FRAMES, largest])


func _interruptions() -> void:
	await _boot()
	var drone = _spawn()
	while drone.phase != drone.Phase.WARN or drone._t < 0.5:
		game.player.reset_to(ball)
		await physics_frame
	game.combat.deal_hit(drone, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "ram")
	var tipped := false
	for frame in 27:
		await physics_frame
		tipped = tipped or drone.reaction_pivot.transform != Transform3D.IDENTITY
	t.check("WD-4 stagger and WD-6 ram", tipped and drone.phase == drone.Phase.ROAM and _rest(drone),
		"real ram tips reaction_pivot; interrupted pose restores all nodes within 0.3 s")
	# A smash clears a live hold; the kind's next physics tick uses its existing _end route.
	drone._knock = Vector3.ZERO
	drone._warn(drone._flat_to_ball())
	drone._t = 0.5
	drone._pose()
	game.events.line_state_changed.emit("smash_committed", drone, drone.global_position, "")
	drone.knock(Vector3.RIGHT, 20.0)
	await _frames(27)
	t.check("WD-4 harpoon smash", drone.phase == drone.Phase.ROAM and _rest(drone), "smash brace plus interrupting knock; pose at exact rest")
	drone.free()
	for ending in ["queue_free", "death", "retry"]:
		drone = _spawn()
		drone._warn(drone._flat_to_ball())
		drone._t = 0.5
		drone._pose()
		var nodes := [weakref(drone), weakref(drone._aim), weakref(drone._drum), weakref(drone._rotor)]
		if ending == "queue_free":
			drone.queue_free()
		elif ending == "death":
			drone.take_damage(drone.hp + 1.0)
		else:
			game.flow.retry_stage()
		await _frames(27)
		var gone := true
		for node in nodes:
			gone = gone and node.get_ref() == null
		var fresh = _spawn()
		var clean := _rest(fresh)
		t.check("WD-4 " + ending, gone and clean, "old posed nodes freed; next drone starts at exact rest within 0.3 s")
		fresh.free()
	game.free()
	game = null


func _run() -> void:
	await _boot()
	_samples()
	await _idle()
	await _coast_restart()
	game.free()
	game = null
	await _invariance()
	await _interruptions()
	quit(t.verdict())
