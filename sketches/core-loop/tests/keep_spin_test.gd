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
	quit(t.verdict())
