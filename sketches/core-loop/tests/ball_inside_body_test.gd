extends SceneTree

const PlayerBall := preload("res://src/movement/player_ball.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# A pass-through that ends with the ball inside a body must not shut it in. Rivet's
# juggernaut drive excepts a staggered Warden; the stagger closed and the drive let the
# exception go with the ball 0.6 m from the Warden's axis (BITE-PIN, completionist
# runner_gunner seed 1, stage 5). The ball sat at speed 0 for 130 s: no stick, jump or bite
# moved it. Here the same body (a Warden's 2.8 m cylinder on a trimesh floor) takes the ball
# inside it under an exception and the exception is removed: the ball must end clear of the
# body and on the floor. A control body the ball meets from outside keeps blocking it, so the
# rule does not turn bodies into ghosts.

# The Warden's own kind of body: kinematic, colliding with the world only, so it never
# pushes the ball itself. Contact calls these.
class Body extends CharacterBody3D:
	func knock(_direction: Vector3, _force: float) -> void:
		pass
	func flash() -> void:
		pass

const WARDEN_RADIUS := 2.8
const WARDEN_HALF := 1.6
const SECONDS := 2.0

var t := T.new("ball_inside_body_test")
var player
var source


func _initialize() -> void:
	_run.call_deferred()


func _body(at: Vector3) -> Body:
	var body := Body.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(3, true)
	body.set_collision_mask_value(1, true)
	body.add_to_group("enemy")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = WARDEN_RADIUS
	cylinder.height = WARDEN_HALF * 2.0
	shape.shape = cylinder
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	return body


func _ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	# A trimesh like the stage terrain's (terrain.gd builds its floor with create_trimesh_shape).
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	plane.subdivide_width = 20
	plane.subdivide_depth = 20
	var shape := CollisionShape3D.new()
	shape.shape = plane.create_trimesh_shape()
	ground.add_child(shape)
	root.add_child(ground)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _roll(seconds: float, move: Vector2) -> void:
	source.hold = {"move": move}
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	_ground()
	var events := GameEvents.new()
	root.add_child(events)
	player = PlayerBall.new()
	root.add_child(player)
	player.setup(Tuning.new(), events, Vector3(0.6, Tuning.RADIUS, 0.0))
	source = Intent.Scripted.new()
	player.source = source
	for i in 3:
		await physics_frame

	# Two traps seen when the exception ends inside the body, each red at e357a8c8. Resting, the
	# ball stays inside it, sunk into the floor; rolling on with the stick, it is pushed through
	# the floor and falls out of the world.
	var i := 0
	for trap in [{"offset": -0.55, "speed": 0.0, "stick": 0.0}, {"offset": 0.0, "speed": 5.0, "stick": 1.0}]:
		i += 1
		var at := Vector3(20.0 * i, WARDEN_HALF, 0.0)
		var warden := _body(at)
		player.body().add_collision_exception_with(warden)
		player.reset_to(at + Vector3(-6.0, Tuning.RADIUS - WARDEN_HALF, 0.0), Vector3(5.0, 0.0, 0.0))
		source.hold = {}
		while player.ball_position().x < at.x + float(trap["offset"]):
			await physics_frame
		player.body().set_velocity_now(Vector3(float(trap["speed"]), 0.0, 0.0))
		player.body().remove_collision_exception_with(warden)
		await _roll(SECONDS, Vector2(float(trap["stick"]), 0.0))
		var ball: Vector3 = player.ball_position()
		t.check("trap %s: the ball is clear of the body" % [trap], _flat(ball, at) >= WARDEN_RADIUS + Tuning.RADIUS - 0.2,
			"ball %s, %.2f m from the body's axis, needs %.2f" % [ball, _flat(ball, at), WARDEN_RADIUS + Tuning.RADIUS - 0.2])
		t.check("trap %s: the ball is on the floor" % [trap], ball.y > 0.5, "ball height %.2f" % ball.y)
		warden.queue_free()
		await physics_frame
	player.body().set_velocity_now(Vector3.ZERO)

	# Control: a ball outside the same body is blocked by it, not passed through.
	var wall := _body(Vector3(-12.0, WARDEN_HALF, 0.0))
	player.reset_to(Vector3(-20.0, Tuning.RADIUS, 0.0))
	await _roll(SECONDS, Vector2(1.0, 0.0))
	var end: Vector3 = player.ball_position()
	t.check("a ball outside a body stays outside it", _flat(end, wall.global_position) >= WARDEN_RADIUS + Tuning.RADIUS - 0.2,
		"ball %s, %.2f m from the body's axis" % [end, _flat(end, wall.global_position)])
	quit(t.verdict())
