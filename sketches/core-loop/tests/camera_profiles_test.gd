extends SceneTree

const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const T := preload("res://tests/support/t.gd")

# C3: the chase camera's situation rows. The camera is built on a stand-in target and
# stepped with a fixed delta; nothing reads the clock.

const DT := 1.0 / 60.0
const FALL_V := -9.0
# One frame of the pitch bias may move this much at most: the full swing times the ease.
const BIAS_STEP := 0.21 * (1.0 - exp(-ChaseCamera.PROFILE_EASE * DT)) + 0.0005

var _t = T.new("camera_profiles_test")


class Tuning:
	func f(_key: String) -> float:
		return 20.0


class Target:
	var state := BallState.new()

	func shown_position() -> Vector3:
		return Vector3.ZERO


func _process(_delta: float) -> bool:
	_fov_cap()
	_falling()
	_boss()
	_lock()
	_combined()
	quit(_t.verdict())
	return true


func _rig() -> Array:
	var target := Target.new()
	var cam := ChaseCamera.new()
	root.add_child(cam)
	cam.setup(target, Tuning.new())
	cam.snap(Vector3.FORWARD)
	return [cam, target]


func _step(cam, frames: int) -> void:
	for i in frames:
		cam._process(DT)


func _fov_cap() -> void:
	var rig := _rig()
	var cam = rig[0]
	_step(cam, 60)
	_t.near("C3-1 at rest the lens is 65", cam.cam.fov, 65.0, 0.01)
	rig[1].state.velocity = Vector3(0.0, 0.0, -60.0)
	cam.punch_fov(100.0, 100.0)
	var worst := 0.0
	for i in 120:
		cam._process(DT)
		worst = maxf(worst, cam.cam.fov)
	_t.check("C3-1 top speed with the largest punch stays at or under 88", worst <= ChaseCamera.FOV_CAP, "peak %.3f" % worst)
	_t.check("C3-1 the cap is reached, so the clamp is what holds it", worst >= 87.9, "peak %.3f" % worst)
	cam.free()


func _falling() -> void:
	var rig := _rig()
	var cam = rig[0]
	var state = rig[1].state
	_step(cam, 30)
	var yaw_before: float = cam.yaw
	var pitch_before: float = cam.pitch
	var aim_before: Vector3 = cam.aim_forward()
	state.grounded = false
	state.velocity = Vector3(0.0, -8.0, 0.0)
	_step(cam, 5)
	_t.eq("C3-2 exactly -8 m/s is not falling", cam.active_profiles(), [])
	state.grounded = true
	state.velocity = Vector3(0.0, -20.0, 0.0)
	_step(cam, 5)
	_t.eq("C3-2 grounded is not falling", cam.active_profiles(), [])
	state.grounded = false
	state.velocity = Vector3(0.0, FALL_V, 0.0)
	var previous: float = cam._pitch_bias
	var worst_step := 0.0
	for i in 120:
		cam._process(DT)
		worst_step = maxf(worst_step, absf(cam._pitch_bias - previous))
		previous = cam._pitch_bias
	_t.eq("C3-2 below -8 m/s airborne is falling", cam.active_profiles(), ["falling"])
	_t.check("C3-2 the arm pitches down", cam._pitch_bias < -0.2, "bias %.3f" % cam._pitch_bias)
	_t.check("C3-2 no frame snaps the pitch", worst_step <= BIAS_STEP, "largest step %.4f, allowed %.4f" % [worst_step, BIAS_STEP])
	_t.check("C3-2 the arm lengthens to 12", absf(cam.arm.spring_length - 12.0) < 0.05, "arm %.3f" % cam.arm.spring_length)
	_t.eq("C3-2 pitch and yaw are unchanged in the fall", [cam.pitch, cam.yaw], [pitch_before, yaw_before])
	_t.check("C3-2 aim is identical in the fall", cam.aim_forward().is_equal_approx(aim_before), "before %s during %s" % [aim_before, cam.aim_forward()])
	state.grounded = true
	state.velocity = Vector3.ZERO
	worst_step = 0.0
	for i in 180:
		cam._process(DT)
		worst_step = maxf(worst_step, absf(cam._pitch_bias - previous))
		previous = cam._pitch_bias
	_t.check("C3-2 the pitch returns after landing without a snap", absf(cam._pitch_bias) < 0.005 and worst_step <= BIAS_STEP, "bias %.4f, largest step %.4f" % [cam._pitch_bias, worst_step])
	_t.eq("C3-2 pitch and yaw are unchanged after landing", [cam.pitch, cam.yaw], [pitch_before, yaw_before])
	_t.check("C3-2 aim_forward matches before and after", cam.aim_forward().is_equal_approx(aim_before), "before %s after %s" % [aim_before, cam.aim_forward()])
	cam.free()


func _boss() -> void:
	var rig := _rig()
	var cam = rig[0]
	_step(cam, 120)
	var speed_arm: float = cam.arm.spring_length
	cam.set_boss_reach(true)
	_step(cam, 240)
	_t.check("C3-3 boss reach takes the arm to 12 m", absf(cam.arm.spring_length - 12.0) < 0.05, "arm %.3f from %.3f" % [cam.arm.spring_length, speed_arm])
	cam.shake(1.2)
	cam._process(DT)
	_t.check("C3-3 shake is capped at 0.6", cam._shake <= 0.6 + 0.0001 and cam._shake > 0.5, "shake %.3f" % cam._shake)
	cam.set_boss_reach(false)
	_step(cam, 240)
	_t.check("C3-3 releasing returns to the speed arm", absf(cam.arm.spring_length - speed_arm) < 0.05, "arm %.3f, speed arm %.3f" % [cam.arm.spring_length, speed_arm])
	cam.shake(1.2)
	cam._process(DT)
	_t.check("C3-3 the cap lifts with the row", cam._shake > 1.0, "shake %.3f" % cam._shake)
	cam.free()


func _lock() -> void:
	var rig := _rig()
	var cam = rig[0]
	_step(cam, 60)
	var yaw: float = cam.yaw
	var fov_before: float = cam.cam.fov
	cam.set_lock(Vector3(5.0, 2.0, -30.0))
	_step(cam, 120)
	_t.check("C3-4 lock widens the lens", cam.cam.fov > fov_before + 2.9, "fov %.2f from %.2f" % [cam.cam.fov, fov_before])
	_t.near("C3-4 lock lifts the arm (its pitch bias)", cam._pitch_bias, -0.21, 0.002)
	_t.check("C3-4 lock reaches the arm out to 12 m", cam.arm.spring_length > 11.5, "%.2f" % cam.arm.spring_length)
	_t.eq("C3-4 yaw is untouched", cam.yaw, yaw)
	cam.set_lock(null)
	_step(cam, 240)
	_t.eq("C3-4 null releases the row", cam.active_profiles(), [])
	_t.check("C3-4 lens and pitch return", absf(cam.cam.fov - fov_before) < 0.05 and absf(cam._pitch_bias) < 0.002, "fov %.2f, bias %.4f" % [cam.cam.fov, cam._pitch_bias])
	cam.free()


func _combined() -> void:
	var rig := _rig()
	var cam = rig[0]
	var state = rig[1].state
	state.velocity = Vector3(0.0, FALL_V, 0.0)
	cam.set_lock(Vector3.ONE)
	_step(cam, 400)
	_t.eq("C3-5 falling and locked are both active", cam.active_profiles(), ["falling", "locked"])
	_t.check("C3-5 arm is the largest", absf(cam.arm.spring_length - 12.0) < 0.05, "arm %.3f" % cam.arm.spring_length)
	_t.near("C3-5 fov add is the largest (6)", cam._fov_add, 6.0, 0.02)
	_t.near("C3-5 pitch bias is the sum (-0.21 - 0.21), held at the -0.21 limit", cam._pitch_bias, -0.21, 0.002)
	cam.shake(2.0)
	cam._process(DT)
	_t.check("C3-5 shake cap is the smallest (1.2)", cam._shake <= 1.2001, "shake %.3f" % cam._shake)
	cam.set_boss_reach(true)
	_step(cam, 400)
	_t.near("C3-5 three rows sum the bias (-0.35), held at the -0.21 limit", cam._pitch_bias, -0.21, 0.002)
	cam.shake(2.0)
	cam._process(DT)
	_t.check("C3-5 the boss row lowers the cap to 0.6", cam._shake <= 0.6001, "shake %.3f" % cam._shake)
	state.velocity = Vector3.ZERO
	state.grounded = true
	cam.set_lock(null)
	_step(cam, 400)
	_t.near("C3-5 boss alone leaves its own bias", cam._pitch_bias, 0.07, 0.002)
	cam.free()
