extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const FRAMES := 360

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
	drone.pose_enabled = enabled
	drone._strafe = 1.0
	drone._rest = 0.1
	drone.hp = 100000.0
	return drone


func _rest(drone) -> bool:
	return drone._aim.transform == Transform3D.IDENTITY and drone._drum.transform == drone._drum_rest \
		and drone._rotor.transform == drone._rotor_rest


func _samples() -> void:
	var drone = _spawn()
	drone.set_physics_process(false)
	drone.phase = drone.Phase.WARN
	var values := []
	var correct := true
	for progress in [0.0, 0.5, 1.0]:
		drone._t = progress * drone.warn_seconds
		drone._pose()
		values.append([rad_to_deg(drone._aim.rotation.x), drone._spin.x, drone._spin.y])
		correct = correct and is_equal_approx(drone._aim.rotation.x, deg_to_rad(32.0) * smoothstep(0.0, 1.0, progress))
		correct = correct and drone._spin.is_equal_approx(Vector2(2.25, 3.25) * TAU * progress * progress)
		correct = correct and drone._drum.transform.is_equal_approx(drone._drum_rest * Transform3D(Basis(Vector3.RIGHT, drone._spin.x), Vector3.ZERO))
		correct = correct and drone._rotor.transform.is_equal_approx(drone._rotor_rest * Transform3D(Basis(Vector3.UP, drone._spin.y), Vector3.ZERO))
		if progress == 0.0:
			correct = correct and _rest(drone)
	for i in range(1, values.size()):
		for component in 3:
			correct = correct and values[i][component] > values[i - 1][component]
	t.check("WD-1 e11_cable_guide", correct, "progress 0 / 0.5 / 1: [pitch deg, drum rad, rotor rad] %s" % [values])
	var in_enemy: Transform3D = drone.global_transform.affine_inverse() * drone._aim.global_transform
	var angle := rad_to_deg(acos(clampf(in_enemy.basis.y.dot(Vector3.UP), -1.0, 1.0)))
	t.check("WD-2 body travel", angle >= 25.0, "%.6f degrees in the enemy's own space" % angle)
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
	game.combat._hit(drone, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "ram")
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
	game.free()
	game = null
	await _invariance()
	await _interruptions()
	quit(t.verdict())
