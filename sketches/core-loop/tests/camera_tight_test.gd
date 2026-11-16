extends SceneTree

const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const T := preload("res://tests/support/t.gd")

# W1-14 / PF-06: with a wall close behind the ball the arm shortens until the ball fills the lens.
# The camera rises over the ball instead, keeps the player's aim, and goes back down when the wall
# is gone. A real wall on layer 1, the rig stepped one physics frame at a time.

const DT := 1.0 / 60.0

var _t = T.new("camera_tight_test")


class Tuning:
	func f(_key: String) -> float:
		return 20.0


class Target:
	var state := BallState.new()

	func shown_position() -> Vector3:
		return Vector3.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var target := Target.new()
	var cam := ChaseCamera.new()
	root.add_child(cam)
	cam.setup(target, Tuning.new())
	cam.snap(Vector3.FORWARD)
	await _settle(cam, 90)
	var open_pitch: float = cam.arm.rotation.x
	var open_rise := _rise(cam)
	var aim_open: Vector3 = cam.aim_forward()
	_t.check("T1 in the open the arm is untouched", absf(open_pitch - cam.pitch) < 0.001, "arm pitch %.3f, player pitch %.3f" % [open_pitch, cam.pitch])

	# The default view looks down -Z from the +Z side after snap(FORWARD)... the camera sits at +Z, so the wall goes there.
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 40.0, 1.0)
	box.shape = shape
	wall.add_child(box)
	wall.collision_layer = 1
	root.add_child(wall)
	wall.global_position = Vector3(0.0, 0.0, 2.75 if cam.cam.global_position.z > 0.0 else -2.75)
	await _settle(cam, 120)
	var hit: float = cam.arm.get_hit_length()
	_t.check("T2 the wall shortens the arm under the tight threshold", hit < 4.0, "hit length %.2f" % hit)
	_t.check("T3 the lens rises over the ball", _rise(cam) > open_rise + 0.2, "elevation %.2f rad against %.2f in the open" % [_rise(cam), open_rise])
	_t.check("T4 the arm tips up, not the player's pitch", cam.arm.rotation.x < open_pitch - 0.1 and absf(cam.pitch - (-0.30)) < 0.001, "arm %.3f, open %.3f, pitch %.3f" % [cam.arm.rotation.x, open_pitch, cam.pitch])
	_t.check("T5 the aim stays the player's", cam.aim_forward().is_equal_approx(aim_open), "open %s tight %s" % [aim_open, cam.aim_forward()])

	wall.queue_free()
	await _settle(cam, 240)
	_t.check("T6 the lens comes back down when the wall goes", absf(_rise(cam) - open_rise) < 0.02, "elevation %.2f rad, open %.2f" % [_rise(cam), open_rise])
	quit(_t.verdict())


func _settle(cam, frames: int) -> void:
	for i in frames:
		cam._process(DT)
		await physics_frame


# The lens's elevation angle above the point it follows (the ball plus 0.8 m).
func _rise(cam) -> float:
	var from: Vector3 = cam.cam.global_position - cam.global_position
	return atan2(from.y, Vector2(from.x, from.z).length())
