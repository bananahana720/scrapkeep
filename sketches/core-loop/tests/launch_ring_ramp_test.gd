extends SceneTree

const Launch := preload("res://src/world/launch.gd")

# The guide rings sit where the ball really is at each ring's time. The rail's own flight is stepped at the
# physics step and the ball's place is read at each ring's time (linearly between the two frames around it);
# an entry at 5 m/s raised to the floor speed is checked straight and turned, and a launch with no ramp is
# checked against the plain arc it was drawn on before the ramp was read. The stepped ball moves each tick with the
# velocity it held when the tick began, less one tick of gravity, and takes the rail's velocity after the move;
# launch_ring_real_ball_test measured that on the real body. Its first tick holds the ball's own horizontal speed
# and no lift.

const FLOOR := 14.0
const ENTRY := 5.0
const NEAR := 0.1
const SAME := 0.01

var _failures := 0


func _initialize() -> void:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	_ramped(dt, Vector3.ZERO, "5 m/s entry, straight")
	_ramped(dt, Vector3(0.6, 0.0, -0.8), "5 m/s entry, turned")
	_unramped(dt)
	print("launch_ring_ramp_test: %s" % ("FAIL" if _failures > 0 else "PASS"))
	quit(1 if _failures > 0 else 0)


func _launch(heading: Vector3) -> Node3D:
	var launch := Launch.new()
	root.add_child(launch)
	launch.setup()
	if heading != Vector3.ZERO:
		launch.aim(heading)
	return launch


func _ring_time(i: int) -> float:
	return Launch.RING_FIRST + i * Launch.RING_STEP


func _ramped(dt: float, heading: Vector3, label: String) -> void:
	var from := Vector3(0.0, 0.0, -ENTRY) + Vector3.UP * Launch.LIFT
	var velocity := Launch.launch_velocity(Vector3(0.0, 0.0, -ENTRY), FLOOR, Vector3.FORWARD)
	var launch := _launch(heading)
	var origin := Vector3(3.0, 10.0, -7.0)
	launch.fire(origin, velocity, from)
	var rings: Array = launch.get_children().filter(func(c): return c is MeshInstance3D and c.mesh is TorusMesh).slice(0, Launch.RINGS)
	var at := origin
	var held := Vector3(from.x, 0.0, from.z)
	var time := 0.0
	var next := 0
	var worst := 0.0
	var line := ""
	while next < Launch.RINGS:
		var before := at
		var v = launch.rail(dt)
		time += dt
		at += (held - Vector3.UP * launch.gravity * dt) * dt
		held = v
		while next < Launch.RINGS and _ring_time(next) <= time:
			var ring: MeshInstance3D = rings[next]
			var here := before.lerp(at, (_ring_time(next) - (time - dt)) / dt)
			var gap := here.distance_to(ring.position)
			worst = maxf(worst, gap)
			if not ring.visible:
				_fail("%s: ring %d expired before the ball reached it" % [label, next])
			line += " %.3f" % gap
			next += 1
	if worst > NEAR:
		_fail("%s: ball %.3f m from a ring at its time" % [label, worst])
	print("%s: ball to ring centre at each ring's time (m):%s" % [label, line])
	launch.queue_free()


func _unramped(dt: float) -> void:
	var velocity := Launch.launch_velocity(Vector3(0.0, 0.0, -20.0), FLOOR, Vector3.FORWARD)
	var origin := Vector3(1.0, 4.0, 2.0)
	var worst := 0.0
	var low := 0.0
	var launch := _launch(Vector3.ZERO)
	launch.fire(origin, velocity, velocity)
	var rings: Array = launch.get_children().filter(func(c): return c is MeshInstance3D and c.mesh is TorusMesh).slice(0, Launch.RINGS)
	for i in Launch.RINGS:
		var arc := Launch.arc_point(origin, velocity, launch.gravity, _ring_time(i))
		var off: Vector3 = rings[i].position - arc
		worst = maxf(worst, Vector2(off.x, off.z).length())
		low = maxf(low, -off.y)
	var lag: float = dt * (velocity.y + launch.gravity * _ring_time(Launch.RINGS - 1)) + 0.02
	if worst > SAME or low > lag:
		_fail("no ramp, no turn: a ring is %.4f m off the plain arc along the ground, %.3f m below it (one tick allows %.3f)" % [worst, low, lag])
	print("no ramp, no turn: largest ring offset from the plain arc %.5f m along the ground, %.3f m below" % [worst, low])
	launch.queue_free()


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
	print("FAIL ", message)
