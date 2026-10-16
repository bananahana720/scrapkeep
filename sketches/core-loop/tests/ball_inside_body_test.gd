extends "res://tests/rivet_kit_test.gd"

const Warden := preload("res://src/combat/warden.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const RideRail := preload("res://src/world/ride_rail.gd")

# BITE-PIN (completionist runner_gunner seed 1, stage 5): Rivet's Juggernaut Drive excepts a
# staggered Warden so the ball passes through it. When the guard closed, drive_step dropped the
# exception with the ball 0.6 m from the Warden's axis, inside its 2.8 m cylinder, and the
# solver held the ball at speed 0 for 130 s (rivet_kit.gd drive_step and _release_exceptions at
# e357a8c8). Here the real Rivet kit drives the ball into a staggered Warden and both real drive
# ends run with the ball inside: the guard re-closing (drive_step) and the drive's own end
# (_clear_piece). The ball must end clear of the Warden and on the floor, red at e357a8c8.
# Controls: the same spot with the exception dropped raw still traps the ball, so the detector
# fires; a closed Warden met from outside still blocks the ball.
# Expected: 10 checks, including the count assertion.

const FLOOR_TOP := 120.0
const SECONDS := 2.5
const INSIDE := 0.6


func _initialize() -> void:
	_t = T.new("ball_inside_body_test")
	_expected_checks = 10
	super._initialize()


# Read through get() so the test runs, and fails on behaviour, at e357a8c8 too.
func _holding(warden: Node3D) -> bool:
	var held = _player.get("exceptions")
	return held != null and held.holding(warden)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _drive() -> void:
	var ult = _combat.ultimate
	var from: Vector3 = _player.ball_position()
	var to: Vector3 = from + Vector3.RIGHT * 25.0
	_player.abilities.ultimate_id = "juggernaut_drive"
	ult._id = "juggernaut_drive"
	ult._plan = {"path": "line", "from": from, "to": to, "flight": 2.4, "seconds": 2.75, "beats": 7,
		"legs": [{"mode": "line", "to": to, "seconds": 2.4, "beats": 7, "strike": true}]}
	ult.last_plan = ult._plan
	ult._leg = 1
	ult._beats = 7
	ult._beat_len = 2.4 / 7.0
	ult._phase = "flight"
	ult._record = {"volley_hits": 0}
	_kit._piece = "juggernaut_drive"


func _live_ball(at: Vector3) -> void:
	_player.body().freeze = false
	_player.reset_to(at)
	_player.set_physics_process(true)
	_source.hold = {}
	await _sim(0.4)


func _warden_at(x: float) -> Node3D:
	var at := Vector3(x, FLOOR_TOP + Warden.HALF_HEIGHT, _player.ball_position().z)
	var warden: Node3D = _combat.spawn_enemy("warden", at)
	warden.global_position = at
	warden.set_physics_process(false)
	return warden


# Rolls the ball into a staggered Warden under the drive's exception and stops it INSIDE m past
# the Warden's axis, as in the trace.
func _into(warden: Node3D) -> void:
	warden._posture.staggered = true
	_drive()
	_kit.drive_step(_player.ball_position())
	_player.body().set_velocity_now(Vector3(6.0, 0.0, 0.0))
	var guard := 0
	while _player.ball_position().x < warden.global_position.x - INSIDE and guard < 600:
		guard += 1
		await physics_frame
	_player.body().set_velocity_now(Vector3.ZERO)


func _clear(label: String, warden: Node3D, expect_clear := true) -> void:
	var ball: Vector3 = _player.ball_position()
	var need: float = Warden.RADIUS + Tuning.RADIUS - 0.2
	var clear: bool = _flat(ball, warden.global_position) >= need and ball.y > FLOOR_TOP + 0.3
	_t.check(label, clear == expect_clear, "ball %s, %.2f m from the axis (clear needs %.2f), height %.2f" % [ball, _flat(ball, warden.global_position), need, ball.y])


func _run() -> void:
	await _boot()
	await _live_ball(SHELF)

	# The guard closes on the ball (drive_step), the ball at rest.
	var warden := _warden_at(SHELF.x + 6.0)
	await _into(warden)
	_t.check("the ball is inside the Warden before the guard closes", _flat(_player.ball_position(), warden.global_position) < Warden.RADIUS, str(_player.ball_position()))
	warden._posture.staggered = false
	_kit.drive_step(_player.ball_position())
	await _sim(SECONDS)
	_clear("a guard closing on the ball does not shut it in", warden)
	_t.check("the guard blocks the ball again once it is clear", not _holding(warden))
	_kit._clear_piece()
	warden.queue_free()

	# The drive ends (_clear_piece) with the ball inside a staggered Warden, the stick held on.
	await _fresh()
	await _live_ball(SHELF)
	warden = _warden_at(SHELF.x + 6.0)
	await _into(warden)
	_t.check("the ball is inside the Warden before the drive ends", _flat(_player.ball_position(), warden.global_position) < Warden.RADIUS, str(_player.ball_position()))
	_kit._clear_piece()
	_source.hold = {"move": Vector2(1.0, 0.0)}
	await _sim(SECONDS)
	_source.hold = {}
	_clear("the drive ending inside a Warden does not shut the ball in", warden)
	warden.queue_free()

	# Planted control: the same spot with the exception dropped raw still traps the ball, so a
	# clear result above comes from the hold, not from a trap that no longer exists.
	await _fresh()
	await _live_ball(SHELF)
	warden = _warden_at(SHELF.x + 6.0)
	await _into(warden)
	_kit._excepted.clear()
	_kit._piece = ""
	if _player.get("exceptions") != null:
		_player.exceptions._held.erase(warden.get_instance_id())
	_player.body().remove_collision_exception_with(warden)
	await _sim(SECONDS)
	_clear("control: a raw drop inside the Warden traps the ball", warden, false)
	warden.queue_free()

	# Control: a closed Warden met from outside still blocks the ball.
	await _fresh()
	await _live_ball(SHELF)
	warden = _warden_at(SHELF.x + 8.0)
	for i in roundi(SECONDS * Engine.physics_ticks_per_second):
		_player.body().set_velocity_now(Vector3(6.0, 0.0, 0.0))
		await physics_frame
	_t.check("control: the ball was driven into the Warden's shell", _player.ball_position().x > SHELF.x + 8.0 - Warden.RADIUS - Tuning.RADIUS - 0.5, str(_player.ball_position()))
	_clear("control: a closed Warden met from outside blocks the ball", warden)
	_t.check("control: no exception is held for it", not _holding(warden))
	warden.queue_free()
	_finish()
