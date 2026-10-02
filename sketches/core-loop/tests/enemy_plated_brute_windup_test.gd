extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

var _game
var _t := T.new("enemy_plated_brute_windup_test")


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
	var enemy = _game.combat.spawn_enemy("plated_brute", Vector3(-20, 38, -20))
	enemy.hp = 100000.0
	enemy._strafe = 1.0
	enemy.windup_pose_enabled = enabled
	return enemy


# Pose translations in enemy space, independent of the reaction pivot's tilt.
func _pad(enemy, index: int) -> Vector3:
	var rig: Skeleton3D = enemy._windup_rig
	var bone: int = enemy._pad_bones[index]
	return rig.get_bone_pose_position(bone) - rig.get_bone_rest(bone).origin


func _rear(enemy) -> float:
	var rig: Skeleton3D = enemy._windup_rig
	var rotation := rig.get_bone_pose_rotation(enemy._rear_bone) * rig.get_bone_rest(enemy._rear_bone).basis.get_rotation_quaternion().inverse()
	return rad_to_deg(rotation.get_angle())


# The pose maths run in float32; a pose read back is this close to the value written.
const TOLERANCE := 0.0001


func _near_all(got: Array, want: Array) -> bool:
	for i in want.size():
		if absf(got[i] - want[i]) > TOLERANCE:
			return false
	return true


func _rest(enemy) -> bool:
	return _pad(enemy, 0) == Vector3.ZERO and _pad(enemy, 1) == Vector3.ZERO and _rear(enemy) == 0.0


func _warn(enemy) -> void:
	enemy._warn(Vector3.RIGHT * 4.0)
	enemy._pose()


func _samples() -> void:
	var enemy = _spawn()
	enemy.set_physics_process(false)
	_warn(enemy)
	var values := []
	var rears := []
	var right := []
	var plate: Node3D = enemy.get_node("ReactionPivot/BrutePlates")
	var plate_rest := plate.transform
	for progress in [0.0, 0.5, 1.0]:
		enemy._t = enemy.warn_seconds * progress
		enemy._pose()
		values.append(_pad(enemy, 0).y)
		right.append(_pad(enemy, 1).y)
		rears.append(_rear(enemy))
	_t.check("WB-1 e09_pads_raise", _near_all(values, [0.0, 0.625, 2.5]) and _near_all(right, values)
		and is_zero_approx(rears[0]) and absf(rears[1] - 7.5) < 0.001 and absf(rears[2] - 30.0) < 0.001,
		"progress 0/0.5/1; pad metres %s; rear degrees %s" % [values, rears])
	var monotonic := true
	var previous := -1.0
	for tick in 101:
		enemy._t = enemy.warn_seconds * float(tick) / 100.0
		enemy._pose()
		var height := _pad(enemy, 0).y
		monotonic = monotonic and height >= previous and (tick == 100 or height < 2.5 - TOLERANCE)
		previous = height
	_t.check("WB-1 monotonic", monotonic, "101 samples; full pose only at progress 1")
	_t.check("WB-2 range", _pad(enemy, 0).length() >= 0.35 and _pad(enemy, 1).length() >= 0.35,
		"both complete arm/fist pads travel %.3f m in enemy space; torso rears %.3f degrees" % [_pad(enemy, 0).length(), _rear(enemy)])
	_skinned_pads(enemy)
	_arms(enemy)
	_t.check("plate untouched", plate.transform == plate_rest, "plate layers and PlateCrack stay at rest")
	enemy.phase = enemy.Phase.LIVE
	enemy._t = 0.08
	enemy._pose()
	_t.check("pads plant", absf(_pad(enemy, 0).y + 0.47) < 0.00001 and _rear(enemy) == 0.0,
		"0.08 seconds after release; pad offset %.3f m, fist bottom at -1.1 m" % _pad(enemy, 0).y)
	enemy._t = 0.14
	enemy._pose()
	_t.check("pads stay planted", absf(_pad(enemy, 0).y + 0.47) < 0.00001)
	enemy._end()
	enemy._pose()
	_t.check("WB-4 cycle rest", _rest(enemy), "all joint poses at rest on the first roam frame")
	enemy.free()


func _cycle() -> void:
	var enemy = _spawn()
	_warn(enemy)
	var first_full := -1
	var first_attack := -1
	var pivot_identity := true
	for frame in 140:
		await physics_frame
		if first_full < 0 and _pad(enemy, 0).y >= 2.5 - TOLERANCE:
			first_full = frame
		if first_attack < 0 and enemy.slams > 0:
			first_attack = frame
		pivot_identity = pivot_identity and enemy.reaction_pivot.transform == Transform3D.IDENTITY
	# The warn tick before release has a clock a float32 ulp short of warn_seconds, and its pose is full to within TOLERANCE.
	_t.check("WB-3 release", first_full >= 0 and first_attack - first_full in [0, 1],
		"first full frame %d; first attack frame %d; difference %d physics frames" % [first_full, first_attack, first_full - first_attack])
	_t.check("WB-6 unhit pivot", pivot_identity, "identity at every frame of a 140-frame live cycle")
	_t.check("WB-4 live cycle", _rest(enemy), "rest after the real warn/live/roam cycle")
	enemy.free()


func _cuts() -> void:
	var enemy = _spawn()
	_warn(enemy)
	await _frames(45)
	var before: Transform3D = enemy.reaction_pivot.transform
	_game.combat._hit(enemy, "ram", 1.0, Vector3.RIGHT, 12.0)
	await _frames(3)
	_t.check("WB-6 ram composition", enemy.reaction_pivot.transform != before and _pad(enemy, 0).y > 0.0,
		"real combat ram tips the reaction pivot while pads remain raised")
	_t.check("base uninterruptible", not enemy.interruptible and enemy.phase == enemy.Phase.WARN,
		"ram leaves this kind's warning intact; the base has no brute stagger cancellation")
	var tilted: Transform3D = enemy.reaction_pivot.transform
	enemy._pose()
	_t.check("WB-6 pose preserves pivot", enemy.reaction_pivot.transform == tilted)
	_game.events.line_state_changed.emit("latched_body", enemy, enemy.global_position, "")
	await _frames(10)
	_game.events.line_state_changed.emit("smash_committed", enemy, enemy.global_position, "")
	await _frames(10)
	_t.check("harpoon smash composition", enemy._line_lean < 0.0 and _pad(enemy, 0).y > 0.0,
		"existing smash brace and rising pad pose compose")
	_game.events.line_state_changed.emit("broke", null, Vector3.ZERO, "")
	# Exercise the common cancellation path without inventing a new stagger rule.
	enemy._end()
	await _frames(2)
	_t.check("WB-4 cancellation", _rest(enemy), "existing _end path resets in 2 frames, under 0.3 seconds")
	enemy.free()
	for removal in ["queue_free", "death", "retry"]:
		enemy = _spawn()
		_warn(enemy)
		await _frames(35)
		_t.check(removal + " starts posed", _pad(enemy, 0).y > 0.0)
		var rig: Skeleton3D = enemy._windup_rig
		if removal == "queue_free":
			enemy.queue_free()
		elif removal == "death":
			enemy.take_damage(enemy.hp + 1.0)
		else:
			_game.flow.retry_stage()
		await _frames(3)
		_t.check("WB-4 " + removal, not is_instance_valid(enemy) and not is_instance_valid(rig),
			"posed body and rig removed in 3 frames; no surviving pose")
		if removal == "retry":
			var replacement = _spawn()
			_t.check("WB-4 retry rest", _rest(replacement), "new stage brute starts with every joint at rest")
			replacement.free()


func _trace(enabled: bool) -> Array:
	await _boot()
	var enemy = _spawn(enabled)
	_warn(enemy)
	var trace := []
	var peak := 0.0
	var control_rest := true
	for frame in 160:
		await physics_frame
		peak = maxf(peak, _pad(enemy, 0).y)
		control_rest = control_rest and _rest(enemy)
		var collider: CollisionShape3D = enemy.find_children("*", "CollisionShape3D", true, false)[0]
		var tele = enemy.telegraph()
		var geometry := {}
		if tele != null:
			geometry = {"transform": tele.global_transform, "shape": tele.shape, "radius": tele.radius,
				"progress": tele.progress, "center": tele.center, "type": tele.type,
				"reach_up": tele.reach_up, "dir": tele.dir, "half_angle": tele.half_angle,
				"length": tele.length, "width": tele.width}
		trace.append([enemy.global_position, enemy.velocity, collider.transform, collider.global_transform,
			geometry, enemy.slams, enemy.phase, enemy._t])
	_t.check("WB-5 control seam " + str(enabled), enemy.slams == 1 and (peak >= 2.5 - TOLERANCE if enabled else control_rest),
		"one real attack; maximum pad rise %.3f m" % peak)
	_game.free()
	_game = null
	return trace


func _invariance() -> void:
	_game.free()
	_game = null
	var posed := await _trace(true)
	var control := await _trace(false)
	var exact := true
	var largest := 0.0
	for frame in posed.size():
		exact = exact and posed[frame] == control[frame]
		for index in [0, 1]:
			largest = maxf(largest, posed[frame][index].distance_to(control[frame][index]))
		for index in [2, 3]:
			var a: Transform3D = posed[frame][index]
			var b: Transform3D = control[frame][index]
			largest = maxf(largest, a.origin.distance_to(b.origin))
			for axis in 3:
				largest = maxf(largest, a.basis[axis].distance_to(b.basis[axis]))
	_t.check("WB-5 visual-only", exact and largest == 0.0,
		"seed 11; 160 physics frames; position, velocity, collider, telegraph, attack frame/phase/clock exact; largest difference %.9f" % largest)


func _run() -> void:
	_t.eq("E09 pose name", EventKinds.ATTACK_ROWS["E09"]["pose"], "e09_pads_raise")
	await _boot()
	_samples()
	await _cycle()
	await _cuts()
	await _invariance()
	quit(_t.verdict())


# Apply the imported skin matrices to actual pad vertices; a moving joint with an
# unbound mesh cannot satisfy the range check. Skinning does not need a GPU.
func _skinned_pads(enemy) -> void:
	var body: MeshInstance3D = enemy._crew
	var rig: Skeleton3D = enemy._windup_rig
	rig.force_update_all_bone_transforms()
	var minimum_travel := INF
	var lowest := INF
	var seen := [0, 0]
	for surface in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		for vertex in vertices.size():
			var bind := joints[vertex * 4]
			var bone := body.skin.get_bind_bone(bind)
			if bone < 0:
				bone = rig.find_bone(body.skin.get_bind_name(bind))
			var pad: int = enemy._pad_bones.find(bone)
			if pad < 0:
				continue
			seen[pad] += 1
			var moved: Vector3 = rig.get_bone_global_pose(bone) * body.skin.get_bind_pose(bind) * vertices[vertex]
			minimum_travel = minf(minimum_travel, moved.distance_to(vertices[vertex]))
			lowest = minf(lowest, moved.y)
	_t.check("WB-2 skinned geometry", seen[0] > 0 and seen[1] > 0 and minimum_travel >= 2.499 and lowest > 1.55,
		"actual pad vertices %s; minimum travel %.3f m; full-pose bottom %.3f m above resting shoulders" % [seen, minimum_travel, lowest])


# PC-1: each arm stays joined to its shoulder and to its pad through the whole raise. The pad's
# arm top is read from the skinned vertices; the arm link is the node that must span the shoulder
# joint (the arm top at rest) to that arm top. The arm's top ring is tilted with the arm, so its
# highest vertex sits 0.014 m above the ring centre the link meets; 0.02 m is that, not slack.
func _arms(enemy) -> void:
	var rig: Skeleton3D = enemy._windup_rig
	var body: MeshInstance3D = enemy._crew
	var worst := 0.0
	var samples := 0
	for side in 2:
		var link: MeshInstance3D = enemy._arm_link
		var joint := NAN
		for progress in [0.0, 0.5, 1.0]:
			enemy._t = enemy.warn_seconds * progress
			enemy._pose()
			rig.force_update_all_bone_transforms()
			var top := -INF
			for surface in body.mesh.get_surface_count():
				var arrays := body.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				for vertex in vertices.size():
					var bind := joints[vertex * 4]
					var bone := body.skin.get_bind_bone(bind)
					if bone < 0:
						bone = rig.find_bone(body.skin.get_bind_name(bind))
					if bone == enemy._pad_bones[side]:
						var moved: Vector3 = rig.get_bone_global_pose(bone) * body.skin.get_bind_pose(bind) * vertices[vertex]
						top = maxf(top, moved.y)
			if is_nan(joint):
				joint = top
			var box: AABB = link.transform * link.mesh.get_aabb()
			worst = maxf(worst, maxf(absf(box.end.y - top), absf(box.position.y - joint)))
			samples += 1
	_t.check("PC-1 arm joined", samples == 6 and worst < 0.02,
		"each arm at progress 0/0.5/1: link top to pad arm top, link foot to shoulder joint; widest gap %.4f m" % worst)
