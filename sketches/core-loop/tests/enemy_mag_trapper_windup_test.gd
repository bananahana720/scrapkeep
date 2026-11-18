extends SceneTree

# PLANT --plant-deployed -> [W1-126 one disc seats at the committed centre]
# PLANT --plant-floating -> [W1-126 one disc seats at the committed centre]

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const HOIST := 1.4
const LEAN := 0.22
const SPIN := TAU * 1.25
const FRAMES := 430
# A pose read back from float32 transforms is this close to the value written.
const TOLERANCE := 0.0001
# The stack's top face and the top disc's thickness, in stack space (enemy_mag_trapper.py).
const STACK_TOP := 0.6
const DISC_HALF := 0.1
# The deployed disc's lowest point rests on the terrain under it to this distance; it is a mesh
# bound against a terrain height, so neither number comes from the code that places the disc.
const SEAT_TOLERANCE := 0.05
# The casing is seated along the slope's normal, which moves its middle sideways a little.
const CENTRE_TOLERANCE := 0.1
const FLOAT_PLANT := 0.5

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
	enemy.windup_pose_enabled = enabled
	enemy._rest = 0.0
	return enemy


# The lowest vertex of a mesh node in world space. A tilted disc's AABB corner hangs below the disc
# itself, so the box would call a seated disc sunk.
func _lowest_point(node: MeshInstance3D) -> Vector3:
	var low := Vector3(0.0, INF, 0.0)
	for vertex in node.mesh.get_faces():
		var world: Vector3 = node.global_transform * vertex
		if world.y < low.y:
			low = world
	return low


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
		and absf(values[2] - HOIST) < TOLERANCE and leans[0] == 0.0 and spins[0] == 0.0 \
		and is_equal_approx(leans[2], LEAN) and is_equal_approx(spins[2], SPIN), detail)
	var monotonic := true
	var last := Vector3(-1.0, -1.0, -1.0)
	for step in 101:
		enemy._t = enemy.warn_seconds * step / 100.0
		enemy._pose()
		var value := Vector3((parts[1].position - rest).y, -parts[0].rotation.x, parts[1].rotation.y)
		monotonic = monotonic and value.x >= last.x and value.y >= last.y and value.z >= last.z
		last = value
	_link(enemy)
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
	var warn_full := []
	var live_shorter := true
	var deployed_frames := 0
	var worst_gap := 0.0
	var centred := true
	var capped := true
	var seated := true
	var profile_kept := true
	var quiet := true
	var deployed: WeakRef
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
			if parts[1].position.distance_to(enemy._top_rest + Vector3.UP * HOIST) < TOLERANCE:
				full_frames.append(Engine.get_physics_frames())
				warn_full.append(enemy.phase == 1)
			var disc := tele.get_node_or_null("DeployedDisc") as MeshInstance3D if tele != null else null
			if enemy.phase == 2:
				live_shorter = live_shorter and not parts[1].visible and enemy._stack.visible and enemy.find_child("MagDiscs", true, false).visible
				if disc != null:
					if deployed == null:
						deployed = weakref(disc)
						if "--plant-deployed" in OS.get_cmdline_user_args():
							disc.position.x += 1.0
						if "--plant-floating" in OS.get_cmdline_user_args():
							disc.position.y += FLOAT_PLANT
					deployed_frames += 1
					var box: AABB = disc.global_transform * disc.mesh.get_aabb()
					var low := _lowest_point(disc)
					var ground: float = _game.ctx.terrain.height(low.x, low.z)
					worst_gap = maxf(worst_gap, absf(low.y - ground))
					centred = centred and Vector2(disc.global_position.x - tele.center.x, disc.global_position.z - tele.center.z).length() < CENTRE_TOLERANCE
					capped = capped and box.end.y > tele.global_position.y
					seated = seated and disc.mesh == parts[1].mesh
					seated = seated and disc.get_child_count() == 0 and disc.is_visible_in_tree()
					profile_kept = profile_kept and is_equal_approx(disc.global_basis.y.length(), 1.5) \
						and is_equal_approx(disc.global_basis.x.length(), 1.0) and is_equal_approx(disc.global_basis.z.length(), 1.0)
			else:
				quiet = quiet and disc == null
			if not _strike_frames.is_empty() and enemy.phase == 0 and not saw_rest:
				rest_after = _rest(enemy)
				saw_rest = true
	if enabled:
		var delta := 999
		if not full_frames.is_empty() and not _strike_frames.is_empty():
			delta = int(full_frames[0]) - int(_strike_frames[0])
			# The warn tick just before release has a clock a float32 ulp short of warn_seconds, so its pose is
			# full to within TOLERANCE; any earlier warn tick at full pose is a fault.
			for i in full_frames.size():
				if warn_full[i] and int(full_frames[i]) < int(_strike_frames[0]) - 1:
					pre_release_full = true
		_test.check("WG-3 release frame", not pre_release_full and not full_frames.is_empty() and abs(delta) <= 1,
			"strike frames %s; full frames %s; difference %d physics frames" % [_strike_frames, full_frames, delta])
		_test.check("WG-4 completed cycle", rest_after and _rest(enemy), "exact rest on first ROAM frame after LIVE")
		_test.check("WG-4 one disc leaves", live_shorter and not _strike_frames.is_empty(), "only top disc hidden throughout LIVE")
		_test.check("W1-126 one disc seats at the committed centre", seated and centred and worst_gap < SEAT_TOLERANCE and deployed_frames >= 250,
			"%d live frames with the original mesh, no collider; lowest point at most %.4f m from the terrain" % [deployed_frames, worst_gap])
		_test.check("W1-126 the disc top shows above the pit paint", capped and deployed_frames > 0)
		_test.check("W1-126 the taller casing keeps its horizontal footprint", profile_kept and deployed_frames > 0)
		_test.check("W1-126 the disc only exists during the live pit", quiet and deployed != null and deployed.get_ref() == null,
			"no preview disc and no remnant after the pit expires")
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


func _live_pit():
	var enemy = _spawn()
	for frame in 180:
		await physics_frame
		if enemy.phase == 2:
			break
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
	# Destruction removes the posed nodes, rather than leaving a detached posed mesh. It must hold
	# at half wind-up (the disc hoisted) and with the pit live (the disc thrown into it).
	for phase in ["half wind-up", "live pit"]:
		for action in ["queue_free", "death", "retry"]:
			enemy = await _half_windup() if phase == "half wind-up" else await _live_pit()
			var parts := _parts(enemy)
			var pit: Node3D = enemy.telegraph()
			var disc := pit.get_node_or_null("DeployedDisc") if pit != null else null
			if phase == "live pit":
				_test.check("W1-126 live disc before " + action, enemy.phase == 2 and disc != null)
			else:
				_test.check("hoisted disc and pit mark before " + action, enemy.phase == 1 and pit != null and parts[1].position.y > enemy._top_rest.y)
			var gone := [weakref(enemy), weakref(parts[0]), weakref(parts[1]), weakref(pit), weakref(disc)]
			match action:
				"queue_free":
					enemy.queue_free()
				"death":
					enemy.take_damage(enemy.hp + 1.0)
				"retry":
					_game.flow.retry_stage()
			await _frames(27)
			var removed := true
			for ref in gone:
				removed = removed and ref.get_ref() == null
			var fresh = _spawn()
			fresh.set_physics_process(false)
			_test.check("WG-4 %s at %s" % [action, phase], removed and _rest(fresh), "enemy, cart, disc, pit mark and deployed disc all freed within 0.3 s; fresh body at rest")
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


# PC-3: the mast between the stack and the lifted disc. Its foot sits in the stack's top disc and
# its head reaches into the lifted disc, at progress 0.5 and 1.
func _link(enemy) -> void:
	var link: MeshInstance3D = enemy.find_child("MagTopLink", true, false)
	var disc: Node3D = enemy.find_child("MagTopDisc", true, false)
	if link == null:
		_test.check("PC-3 link exists", false, "no MagTopLink node")
		return
	var spans := true
	var detail := []
	for progress in [0.5, 1.0]:
		enemy._t = enemy.warn_seconds * progress
		enemy._pose()
		var box: AABB = link.transform * link.mesh.get_aabb()
		var foot_ok: bool = box.position.y <= STACK_TOP + TOLERANCE and box.position.y >= STACK_TOP - 2.0 * DISC_HALF
		var head_ok: bool = absf(box.end.y - disc.position.y) <= DISC_HALF + TOLERANCE
		spans = spans and foot_ok and head_ok and link.visible and (box.end.y - box.position.y) > 0.3
		detail.append("%.2f: foot %.3f head %.3f disc %.3f" % [progress, box.position.y, box.end.y, disc.position.y])
	_test.check("PC-3 link spans stack to disc", spans, "stack top %.2f; %s" % [STACK_TOP, "; ".join(detail)])
