# smoke: solo timeout=60s
extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

# MOTION-SPEC row 210: a mid-air velocity set (launch, fling, rebound, ride tick) must not
# zero the lattice's spin. The body still takes the forced floor-roll spin (it feeds translation
# through contact friction, so it is physics and stays put); the lattice carries its own spin
# through the set. A grounded hand-off resets it.
const SPIN := Vector3(0.0, 8.0, 0.0)
const LAUNCH := Vector3(12.0, 6.0, 0.0)

var t = T.new("keep_spin_test")
var _player
var _events
var _world: Node3D


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0.0, -1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	_events = GameEvents.new()
	_world.add_child(_events)
	_run.call_deferred()


func _spawn(at: Vector3) -> void:
	if _player != null:
		_player.queue_free()
	_player = PlayerBall.new()
	_world.add_child(_player)
	_player.setup(Tuning.new(), _events, at)
	_player.source = Intent.Scripted.new()
	_player.fit_class(ClassDef.by_id("tally"))


func _lattice() -> Basis:
	return (_player.roll_node().get_parent() as Node3D).basis


# Steps frames and returns the lattice's turn over them (rad) and its axis.
func _spin_over(frames: int) -> Dictionary:
	var before := _lattice()
	for i in frames:
		await process_frame
	var q := (_lattice() * before.inverse()).get_rotation_quaternion()
	return {"angle": q.get_angle(), "axis": q.get_axis() if q.get_angle() > 0.001 else Vector3.ZERO}


func _run() -> void:
	# Mid-air: spin about Y, then one launch.
	_spawn(Vector3(0.0, 400.0, 0.0))
	for i in 6:
		await physics_frame
	_player._rigid.angular_velocity = SPIN
	for i in 3:
		await physics_frame
	var held_before: Vector3 = _player._rigid.angular_velocity
	_player.set_velocity_now(LAUNCH)
	await physics_frame
	await physics_frame
	var body_after: Vector3 = _player._rigid.angular_velocity
	var across: Dictionary = await _spin_over(10)
	t.check("body spin before the set is the injected yaw", held_before.dot(Vector3.UP) > 6.0, "got %s" % held_before)
	t.check("body still takes the forced floor-roll spin (physics untouched)", body_after.dot(Vector3.UP) < 2.0 and body_after.length() > 3.0,
		"got %s" % body_after)
	t.check("lattice keeps its yaw spin across one mid-air set", absf(across.axis.dot(Vector3.UP)) > 0.9 and across.angle > 0.02,
		"axis %s turned %.3f rad (want about Y, over 0.02)" % [across.axis, across.angle])

	# Grounded hand-off: the spin resets (no carry) as it always did.
	_spawn(Vector3(0.0, 1.03, 0.0))
	for i in 30:
		await physics_frame
	t.check("fixture is grounded", _player.state.grounded, "grounded=%s" % _player.state.grounded)
	_player._rigid.angular_velocity = SPIN
	_player.set_velocity_now(Vector3(5.0, 0.0, 0.0))
	t.check("grounded set starts no carried spin", not _player._spin_on, "spin_on=%s" % _player._spin_on)
	await _more()
	quit(t.verdict())


# Turn (rad) between two bases.
func _turn(a: Basis, b: Basis) -> float:
	return (b * a.inverse()).get_rotation_quaternion().get_angle()


func _airborne_spin() -> void:
	_spawn(Vector3(0.0, 400.0, 0.0))
	for i in 6:
		await physics_frame
	_player._rigid.angular_velocity = SPIN
	for i in 3:
		await physics_frame


func _more() -> void:
	# A direct body set (the rivet line haul and the reactor ride call this, not the player's).
	await _airborne_spin()
	_player._rigid.set_velocity_now(LAUNCH)
	await physics_frame
	await physics_frame
	var direct: Dictionary = await _spin_over(10)
	t.check("a direct body velocity set (ride tick, reel) keeps the lattice spin", absf(direct.axis.dot(Vector3.UP)) > 0.9 and direct.angle > 0.02,
		"axis %s turned %.3f rad" % [direct.axis, direct.angle])

	# A real fling.
	await _airborne_spin()
	_player.kit.hooked = true
	_player.tree._knobs["grapple_fling"] = 10.0
	var fling: float = _player.tree.knob("grapple_fling")
	_player._fling()
	await physics_frame
	await physics_frame
	var flung: Dictionary = await _spin_over(10)
	t.check("a real _fling keeps the lattice spin", fling > 0.0 and absf(flung.axis.dot(Vector3.UP)) > 0.9 and flung.angle > 0.02,
		"fling knob %.1f, axis %s turned %.3f rad" % [fling, flung.axis, flung.angle])

	# Held ride ticks decay faster than free air, over the same step.
	await _airborne_spin()
	_player._keep_spin()
	_player._drawn_basis(Basis.IDENTITY, 0.1)
	var free: float = _player._spin_omega.length()
	await _airborne_spin()
	_player._keep_spin()
	await physics_frame
	_player._keep_spin()
	_player._drawn_basis(Basis.IDENTITY, 0.1)
	var held: float = _player._spin_omega.length()
	t.check("consecutive ride ticks decay the spin faster than free air", held < free - 0.5 and _player._spin_held,
		"held %.2f vs free %.2f rad/s" % [held, free])

	# Landing: the carried orientation is far from the body's; the hand-off must not jump.
	_spawn(Vector3(0.0, 3.0, 0.0))
	for i in 4:
		await physics_frame
	_player._rigid.angular_velocity = SPIN
	_player.set_velocity_now(Vector3(0.0, 0.0, 0.0))
	await process_frame
	_player._spin_basis = Basis(Vector3(1.0, 1.0, 0.0).normalized(), 2.0)
	_player._spin_omega = Vector3.ZERO
	var previous := _lattice()
	var prev_step := 0.0
	var worst := 0.0
	var landed := -1
	var body_prev: Basis = _player.shown_transform().basis
	for i in 400:
		await process_frame
		var now := _lattice()
		var body_now: Basis = _player.shown_transform().basis
		var step := _turn(previous, now)
		var body_step := _turn(body_prev, body_now)
		if landed < 0 and _player.state.grounded:
			landed = i
		if landed >= 0:
			# The drawn turn may change across the hand-off only by the body's own turn.
			worst = maxf(worst, absf(step - prev_step) - body_step)
		previous = now
		prev_step = step
		body_prev = body_now
		if landed >= 0 and i > landed + 20:
			break
	t.check("the ball landed", landed >= 0, "landed at frame %d" % landed)
	t.check("landing leaves no jump in the drawn turn", worst < 0.01, "largest per-frame change in drawn turn beyond the body's own %.4f rad (the old ease was about 0.22)" % worst)

	# Take-off seeds from the basis the draw reads (interpolated), not the raw body's.
	paused = false
	physics_interpolation = true
	await _airborne_spin()
	var gap := 0.0
	for i in 40:
		await process_frame
		gap = _turn(_player._rigid.global_transform.basis, _player.shown_transform().basis)
		if gap > 0.02:
			break
	_player._keep_spin()
	var seeded := _turn(_player._spin_basis, _player.shown_transform().basis.orthonormalized() * _player._spin_offset)
	t.check("take-off seed matches the drawn basis", gap > 0.02 and seeded < 0.001, "raw-vs-shown gap %.3f rad, seed off by %.5f rad" % [gap, seeded])
	physics_interpolation = false

	# reset_to clears the carry and the offset.
	await _airborne_spin()
	_player._keep_spin()
	_player._spin_offset = Basis(Vector3.UP, 1.0)
	_player.reset_to(Vector3(0.0, 1.03, 0.0), Vector3.ZERO)
	t.check("reset_to clears the carry and the offset", not _player._spin_on and _player._spin_offset.is_equal_approx(Basis.IDENTITY),
		"on=%s" % _player._spin_on)
