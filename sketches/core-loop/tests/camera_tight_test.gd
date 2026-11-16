extends SceneTree

const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const T := preload("res://tests/support/t.gd")

# W1-14 / PF-06: with a wall close behind the ball the arm shortens until the ball fills the lens.
# The camera rises over the ball instead, keeps the player's aim, and goes back down when the wall
# is gone. Real boxes on layer 1, the rig stepped one physics frame at a time. After snap(FORWARD)
# the camera sits on the +Z side of the ball, so the wall goes there. T1-T6: a tall wall. L1: a low
# wall whose top the lifted arm clears (the lift must not read its own result and cycle). R1-R2: a
# low roof over the wall, where lifting would shorten the arm further, so the camera must not lift
# and must come back when the wall goes. U1: a rig whose physics never ticked is not lifted.

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
	await _tall_wall()
	await _low_wall()
	await _roof()
	await _unstepped()
	quit(_t.verdict())


func _rig() -> ChaseCamera:
	var cam := ChaseCamera.new()
	root.add_child(cam)
	cam.setup(Target.new(), Tuning.new())
	cam.snap(Vector3.FORWARD)
	return cam


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var piece := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	piece.shape = shape
	body.add_child(piece)
	body.collision_layer = 1
	root.add_child(body)
	body.global_position = at
	return body


func _tall_wall() -> void:
	var cam := _rig()
	await _settle(cam, 90)
	var open_pitch: float = cam.arm.rotation.x
	var open_rise := _rise(cam)
	var aim_open: Vector3 = cam.aim_forward()
	_t.check("T1 in the open the arm is untouched", absf(open_pitch - cam.pitch) < 0.001, "arm pitch %.3f, player pitch %.3f" % [open_pitch, cam.pitch])
	var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	await _settle(cam, 120)
	var hit: float = cam.arm.get_hit_length()
	_t.check("T2 the wall shortens the arm under 4 m", hit < 4.0, "hit length %.2f" % hit)
	_t.check("T3 the lens rises over the ball", _rise(cam) > open_rise + 0.2, "elevation %.2f rad against %.2f in the open" % [_rise(cam), open_rise])
	_t.check("T4 the arm tips up, not the player's pitch", cam.arm.rotation.x < open_pitch - 0.1 and absf(cam.pitch - (-0.30)) < 0.001, "arm %.3f, open %.3f, pitch %.3f" % [cam.arm.rotation.x, open_pitch, cam.pitch])
	_t.check("T5 the aim stays the player's", cam.aim_forward().is_equal_approx(aim_open), "open %s tight %s" % [aim_open, cam.aim_forward()])
	wall.free()
	await _settle(cam, 240)
	_t.check("T6 the lens comes back down when the wall goes", absf(_rise(cam) - open_rise) < 0.02, "elevation %.2f rad, open %.2f" % [_rise(cam), open_rise])
	cam.free()


# A wall whose top is 0.8 m above the pivot: the lifted arm clears it, so the length it reads would
# jump to full and drop the lift again unless the lift reads an arm of its own.
func _low_wall() -> void:
	var cam := _rig()
	var wall := _box(Vector3(40.0, 4.0, 1.0), Vector3(0.0, -0.4, 2.75))
	await _settle(cam, 120)
	var hit_low := INF
	var hit_high := 0.0
	var rot_low := INF
	var rot_high := -INF
	for i in 60:
		cam._process(DT)
		await physics_frame
		var hit: float = cam.arm.get_hit_length()
		hit_low = minf(hit_low, hit)
		hit_high = maxf(hit_high, hit)
		rot_low = minf(rot_low, cam.arm.rotation.x)
		rot_high = maxf(rot_high, cam.arm.rotation.x)
	_t.check("L1 over a low wall the arm length holds steady", hit_high - hit_low < 0.2, "hit length %.2f to %.2f" % [hit_low, hit_high])
	_t.check("L1 over a low wall the arm angle holds steady", rot_high - rot_low < 0.02, "arm angle %.3f to %.3f" % [rot_low, rot_high])
	wall.free()
	cam.free()


func _roof() -> void:
	var cam := _rig()
	var roof := _box(Vector3(40.0, 1.0, 40.0), Vector3(0.0, 2.9, 0.0))
	await _settle(cam, 90)
	var roof_pitch: float = cam.arm.rotation.x
	var roof_rise := _rise(cam)
	var wall := _box(Vector3(40.0, 40.0, 1.0), Vector3(0.0, 0.0, 2.75))
	await _settle(cam, 60)
	_t.check("R1 under a roof the lift would shorten the arm, so the arm is not lifted", absf(cam.arm.rotation.x - roof_pitch) < 0.02, "arm %.3f, with the roof alone %.3f" % [cam.arm.rotation.x, roof_pitch])
	wall.free()
	await _settle(cam, 240)
	_t.check("R2 the lens is where the roof alone left it after the wall goes", absf(_rise(cam) - roof_rise) < 0.02, "elevation %.2f rad, roof alone %.2f" % [_rise(cam), roof_rise])
	roof.free()
	cam.free()


# camera_profiles_test never ticks physics; the arm there has read no hit yet and must not lift.
func _unstepped() -> void:
	var cam := _rig()
	for i in 60:
		cam._process(DT)
	_t.check("U1 a rig that never ticked physics is not lifted", absf(cam.arm.rotation.x - cam.pitch) < 0.001, "arm %.3f, pitch %.3f" % [cam.arm.rotation.x, cam.pitch])
	cam.free()


func _settle(cam, frames: int) -> void:
	for i in frames:
		cam._process(DT)
		await physics_frame


# The lens's elevation angle above the point it follows (the ball plus 0.8 m).
func _rise(cam) -> float:
	var from: Vector3 = cam.cam.global_position - cam.global_position
	return atan2(from.y, Vector2(from.x, from.z).length())
