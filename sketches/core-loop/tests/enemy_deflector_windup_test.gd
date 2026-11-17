extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const TeardownNoise := preload("res://tests/support/teardown_noise.gd")

# E10 e10_dish_wall: real slice game, clock samples, live release, cancellation,
# reaction composition and a seeded per-physics-frame control with the pose disabled.
var _game
var _t := T.new("enemy_deflector_windup_test")
var _release := -1
var _exit_rest := false
var _exit_seam := false


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


func _spawn(enabled := true):
	var base: Vector3 = _game.ctx.terrain.spawn_point(1)
	var at: Vector3 = _game.ctx.terrain.drop_point(base.x + 10.0, base.z, 1.1)
	var enemy = _game.combat.spawn_enemy("deflector", at)
	enemy.hp = 100000.0
	enemy._strafe = 1.0
	enemy.windup_pose_enabled = enabled
	enemy._pose()
	return enemy


func _rest(enemy) -> bool:
	return enemy._wall.transform.is_equal_approx(enemy._wall_rest) and enemy._body.transform.is_equal_approx(Transform3D.IDENTITY)


func _full(enemy) -> bool:
	return enemy._wall.transform.is_equal_approx(enemy._wall_full) and enemy._body.position.is_equal_approx(Vector3(0, -0.165, 0)) and enemy._body.scale.is_equal_approx(Vector3(1, 0.85, 1))


func _clock_samples() -> void:
	var enemy = _spawn()
	var samples := []
	var rest: Transform3D = enemy._wall_rest
	var full: Transform3D = enemy._wall_full
	var angle := rest.basis.get_rotation_quaternion().angle_to(full.basis.get_rotation_quaternion())
	var distance := rest.origin.distance_to(full.origin)
	var exact := true
	# Literal wall poses at progress 0 / 0.5 / 1: origin metres and rotation quaternion (x, y, z, w), body y and body scale y.
	var wall_origins := [Vector3(0.6, 0.75, 1.15), Vector3(0.3, 0.475, 1.225), Vector3(0.0, 0.2, 1.3)]
	var wall_turns := [Quaternion(-0.369254, 0.243469, 0.014104, 0.896758), Quaternion(-0.189585, 0.125004, 0.007241, 0.973848), Quaternion(0.0, 0.0, 0.0, 1.0)]
	var body_ys := [0.0, -0.0825, -0.165]
	var body_scales := [1.0, 0.925, 0.85]
	for index in 3:
		var progress: float = [0.0, 0.5, 1.0][index]
		enemy.phase = enemy.Phase.WARN
		enemy._t = enemy.warn_seconds * progress
		enemy._pose()
		var wall: Transform3D = enemy._wall.transform
		samples.append(rest.basis.get_rotation_quaternion().angle_to(wall.basis.get_rotation_quaternion()) / angle)
		exact = exact and wall.origin.is_equal_approx(wall_origins[index]) and wall.basis.get_rotation_quaternion().is_equal_approx(wall_turns[index])
		exact = exact and is_equal_approx(enemy._body.position.y, body_ys[index]) and is_equal_approx(enemy._body.scale.y, body_scales[index])
	_t.check("WF-1 e10_dish_wall samples", exact and is_zero_approx(samples[0]) and is_equal_approx(samples[1], 0.5) and is_equal_approx(samples[2], 1.0), "progress 0/0.5/1 -> %.6f / %.6f / %.6f" % samples)
	var monotonic := true
	var previous := Vector4(-1, -1, -1, -1)
	for step in 101:
		enemy._t = enemy.warn_seconds * float(step) / 100.0
		enemy._pose()
		var travel := Vector4(rest.origin.distance_to(enemy._wall.position) / distance,
			rest.basis.get_rotation_quaternion().angle_to(enemy._wall.quaternion) / angle,
			-enemy._body.position.y / 0.165, (1.0 - enemy._body.scale.y) / 0.15)
		for axis in 4:
			monotonic = monotonic and travel[axis] >= previous[axis] - 0.00001
		previous = travel
	_t.check("WF-1 monotonic travel", monotonic and _full(enemy), "101 clock samples; dish translation/rotation and crew crouch/scale never reverse")
	var moved_angle := rest.basis.get_rotation_quaternion().angle_to(enemy._wall.quaternion)
	var moved_distance := rest.origin.distance_to(enemy._wall.position)
	_t.check("WF-2 dish travel", moved_angle >= deg_to_rad(25) or moved_distance >= 0.35, "enemy space %.3f degrees; %.3f m" % [rad_to_deg(moved_angle), moved_distance])
	enemy.phase = enemy.Phase.ROAM
	enemy._pose()
	_t.check("WF-4 rests", _rest(enemy), "both posed nodes return immediately")
	enemy.free()


func _on_phase(facts: Dictionary) -> void:
	if facts["phase"] == "strike":
		_release = Engine.get_physics_frames()


func _cycle() -> void:
	var enemy = _spawn()
	enemy.attack_phase.connect(_on_phase)
	enemy._warn(Vector3(1, 0, 0))
	enemy._pose()
	_release = -1
	var first_full := -1
	var warn_frames := 0
	var live_frames := 0
	var pivot_identity := true
	var held := true
	var ended := false
	for frame in 480:
		await _frames(1)
		pivot_identity = pivot_identity and enemy.reaction_pivot.transform == Transform3D.IDENTITY
		if _full(enemy) and first_full < 0:
			first_full = Engine.get_physics_frames()
		if enemy.phase == enemy.Phase.WARN:
			warn_frames += 1
			var progress: float = clampf(enemy._warn_progress(), 0, 1)
			held = held and enemy._wall.transform.is_equal_approx(enemy._wall_rest.interpolate_with(enemy._wall_full, smoothstep(0, 1, progress)))
		elif enemy.phase == enemy.Phase.LIVE:
			live_frames += 1
			held = held and _full(enemy)
		elif _release >= 0:
			ended = true
			break
	_t.check("WF-3 release frame", _release >= 0 and first_full >= 0 and absi(first_full - _release) <= 1, "attack %d; first full pose %d; delta %d physics frames" % [_release, first_full, first_full - _release])
	_t.check("WF-1 live clock and hold", held and warn_frames > 0 and live_frames > 0, "%d warn frames, %d live frames" % [warn_frames, live_frames])
	_t.check("WF-4 whole cycle rests", ended and _rest(enemy), "rest on cycle's end frame")
	_t.check("WF-6 unhit pivot identity", pivot_identity, "whole unhit warn/live/rest cycle")
	enemy.free()


func _half_warn(enemy) -> void:
	enemy._warn(Vector3(1, 0, 0))
	enemy._t = enemy.warn_seconds * 0.5
	enemy._pose()


func _watch_exit(enemy) -> void:
	_exit_rest = false
	enemy.tree_exiting.connect(func():
		_exit_rest = _rest(enemy)
		_exit_seam = enemy.windup_pose_enabled)


func _interruptions() -> void:
	var enemy = _spawn()
	_half_warn(enemy)
	_game.combat._hit(enemy, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "")
	var peak := 0.0
	for frame in 18:
		await _frames(1)
		peak = maxf(peak, rad_to_deg(acos(clampf(enemy.reaction_pivot.basis.y.dot(Vector3.UP), -1, 1))))
	_t.check("WF-4 stagger reset", enemy.phase == enemy.Phase.ROAM and _rest(enemy), "ram interrupted WARN; rest within 0.3 s")
	_t.check("WF-6 ram composes", peak > 1.0, "existing reaction peak %.3f degrees with wind-up pose" % peak)
	enemy.free()

	enemy = _spawn()
	_half_warn(enemy)
	_watch_exit(enemy)
	enemy.queue_free()
	await _frames(2)
	_t.check("WF-4 queue_free reset", not is_instance_valid(enemy) and _exit_rest, "exit hook restores both meshes before disposal")
	_t.check("WF-4 exit leaves the seam on", _exit_seam, "the exit hook rests the meshes without switching the pose off")

	enemy = _spawn()
	_half_warn(enemy)
	_watch_exit(enemy)
	enemy.take_damage(enemy.hp + 1)
	await _frames(2)
	_t.check("WF-4 death reset", not is_instance_valid(enemy) and _exit_rest, "real death path restores meshes on exit")

	enemy = _spawn()
	_half_warn(enemy)
	_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
	_game.events.line_state_changed.emit("smash_committed", enemy, enemy.global_position, "")
	enemy.knock(Vector3.RIGHT, 30.0)
	await _frames(18)
	_t.check("WF-4 harpoon smash reset", enemy.phase == enemy.Phase.ROAM and _rest(enemy), "smash line event plus knock ends wind-up within 0.3 s")
	_game.events.line_state_changed.emit("let_go", null, Vector3.ZERO, "")
	enemy.free()

	enemy = _spawn()
	_half_warn(enemy)
	_watch_exit(enemy)
	_game.flow.retry_stage()
	await _frames(2)
	_t.check("WF-4 retry disposal", not is_instance_valid(enemy) and _exit_rest, "real stage retry clears posed source within two frames")
	var fresh = _spawn()
	_t.check("WF-4 retry fresh rest", _rest(fresh), "new instance has no shared pose transform")
	fresh.free()


func _trace(enabled: bool) -> Array:
	await _boot()
	var enemy = _spawn(enabled)
	enemy._warn(Vector3(1, 0, 0))
	enemy._pose()
	var trace := []
	var seam_rest := true
	for frame in 480:
		await _frames(1)
		var shape: CollisionShape3D = enemy.find_children("*", "CollisionShape3D", true, false)[0]
		var tele = enemy.telegraph()
		var geometry: Dictionary = {} if tele == null else tele.descriptor()
		var progress: float = -1 if tele == null else tele.progress
		seam_rest = seam_rest and (enabled or _rest(enemy))
		trace.append([enemy.global_position, enemy.velocity, shape.transform, shape.global_transform, geometry, progress, enemy.phase, enemy.last_warn, enemy.attack_facts()])
	if not enabled:
		_t.check("WF-5 disabled seam", seam_rest, "control keeps both meshes at carried rest on every frame")
	_game.free()
	_game = null
	return trace


# Jolt's body ids survive a Game replacement in one process. Fresh processes give
# both runs the same solver identity, including the first post-rest walking contact.
func _control_trace(enabled: bool) -> Array:
	var output := []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/enemy_deflector_windup_test.gd", "--", "--wf-trace=" + ("enabled" if enabled else "disabled")])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var trace := []
	var clean := code == 0
	for line in String(output[0]).split("\n"):
		clean = clean and not line.begins_with("SCRIPT ERROR") and not (line.begins_with("ERROR") and not TeardownNoise.is_noise(line)) and not line.begins_with("FAIL")
		if line.begins_with("WF_TRACE "):
			trace = bytes_to_var(Marshalls.base64_to_raw(line.trim_prefix("WF_TRACE ")))
	_t.check("WF-5 control process " + ("enabled" if enabled else "disabled"), clean and trace.size() == 480,
		"Godot --headless --script enemy_deflector_windup_test.gd -- --wf-trace=%s; exit %d; %d frames" % ["enabled" if enabled else "disabled", code, trace.size()])
	if not clean:
		for line in String(output[0]).split("\n"):
			if not line.begins_with("WF_TRACE "):
				print(line)
	return trace


func _invariance() -> void:
	_game.free()
	_game = null
	var active := _control_trace(true)
	var control := _control_trace(false)
	if active.size() != 480 or control.size() != 480:
		return
	var exact := true
	var largest := 0.0
	var attack_frames := []
	var first_difference := -1
	for frame in active.size():
		# Attack instance ids differ between fresh games; compare the committed facts.
		var a: Array = active[frame]
		var b: Array = control[frame]
		a[8].erase("instance")
		b[8].erase("instance")
		if a != b and first_difference < 0:
			first_difference = frame
			for field in a.size():
				if a[field] != b[field]:
					print("control difference frame %d field %d: %s / %s" % [frame, field, a[field], b[field]])
		exact = exact and a == b
		for index in [0, 1]:
			largest = maxf(largest, a[index].distance_to(b[index]))
		for index in [2, 3]:
			var ta: Transform3D = a[index]
			var tb: Transform3D = b[index]
			largest = maxf(largest, ta.origin.distance_to(tb.origin))
			for axis in 3:
				largest = maxf(largest, ta.basis[axis].distance_to(tb.basis[axis]))
		if a[6] == 2 and (frame == 0 or active[frame - 1][6] != 2):
			attack_frames.append(frame)
	_t.check("WF-5 exact control", exact and largest == 0.0 and not attack_frames.is_empty(), "seed 11; 480 physics frames; position/velocity/collider/telegraph/facts/release; largest difference %.9f; attack frames %s" % [largest, attack_frames])


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wf-trace="):
			var trace := await _trace(arg.trim_prefix("--wf-trace=") == "enabled")
			print("WF_TRACE " + Marshalls.raw_to_base64(var_to_bytes(trace)))
			quit(_t.verdict())
			return
	await _boot()
	_clock_samples()
	await _cycle()
	await _interruptions()
	await _invariance()
	quit(_t.verdict())
