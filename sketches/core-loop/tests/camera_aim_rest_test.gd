extends SceneTree

const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const Game := preload("res://src/game.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const T := preload("res://tests/support/t.gd")

# W16-1: shots aim from the lens rest. Camera kick, shake jitter and the comfort Screen
# shake row move the picture, never where a shot lands. Part a measures the stand-in rig
# (stepped with a fixed delta); part b measures the real game's camera, context and harpoon aim.

const DT := 1.0 / 60.0
const SETTLE := 60
const KICK := 0.6
const SHAKE := 1.2
const ORIGIN_TOL := 1e-5
const ANGLE_TOL := 1e-4
const LEAK_LIVE := 0.1
const REACH := 40.0
const SHOT_LEAK := 0.01

var _t := T.new("camera_aim_rest_test")
var _game
var _rig_done := false
var _booted := false
var _frames := 0


class Tuning:
	func f(_key: String) -> float:
		return 20.0


class Target:
	var state := BallState.new()

	func shown_position() -> Vector3:
		return Vector3.ZERO


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if not _rig_done:
		_rig_done = true
		_kick_and_shake()
		_comfort_row()
		_roll_and_impact()
	return false


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_booted = true
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_frames += 1
	if _frames < 30 or not _rig_done:
		return false
	_real_game()
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


func _rest(cam) -> Vector3:
	return (cam.cam.get_parent() as Node3D).global_position


func _kick_and_shake() -> void:
	var calm = _rig()[0]
	var hit = _rig()[0]
	_step(calm, SETTLE)
	_step(hit, SETTLE)
	hit.kick(hit.cam.global_basis.x, KICK)
	hit.shake(SHAKE, 1.0)
	_step(calm, 1)
	_step(hit, 1)
	_t.check("a1 the kick and shake move the lens (leak is live)", hit.cam.position.length() > LEAK_LIVE, "lens offset %.4f m" % hit.cam.position.length())
	var gap: float = hit.aim_origin().distance_to(calm.aim_origin())
	_t.check("a1 aim_origin matches the calm twin", gap < ORIGIN_TOL, "gap %.7f m" % gap)
	_t.check("a1 aim_origin is the lens rest", hit.aim_origin().is_equal_approx(_rest(hit)), "origin %s rest %s" % [hit.aim_origin(), _rest(hit)])
	var angle: float = hit.aim_forward().angle_to(calm.aim_forward())
	_t.check("a1 aim_forward matches the calm twin", angle < ANGLE_TOL, "angle %.7f rad" % angle)
	var worst_gap := 0.0
	var worst_angle := 0.0
	for i in 20:
		_step(calm, 1)
		_step(hit, 1)
		worst_gap = maxf(worst_gap, hit.aim_origin().distance_to(calm.aim_origin()))
		worst_angle = maxf(worst_angle, hit.aim_forward().angle_to(calm.aim_forward()))
	_t.check("a1 aim_origin holds for 20 frames of spring-back", worst_gap < ORIGIN_TOL, "worst %.7f m" % worst_gap)
	_t.check("a1 aim_forward holds for 20 frames of spring-back", worst_angle < ANGLE_TOL, "worst %.7f rad" % worst_angle)
	calm.free()
	hit.free()


func _comfort_row() -> void:
	var scales := [0.0, 0.5, 1.0]
	var rigs := []
	for scale in scales:
		var cam = _rig()[0]
		cam.motion_scale = scale
		_step(cam, SETTLE)
		cam.kick(cam.cam.global_basis.x, KICK)
		cam.shake(SHAKE, 1.0)
		_step(cam, 1)
		rigs.append(cam)
	for i in rigs.size():
		for j in range(i + 1, rigs.size()):
			var gap: float = rigs[i].aim_origin().distance_to(rigs[j].aim_origin())
			_t.check("a2 aim_origin at Screen shake %s and %s agrees" % [scales[i], scales[j]], gap < ORIGIN_TOL, "gap %.7f m" % gap)
			var angle: float = rigs[i].aim_forward().angle_to(rigs[j].aim_forward())
			_t.check("a2 aim_forward at Screen shake %s and %s agrees" % [scales[i], scales[j]], angle < ANGLE_TOL, "angle %.7f rad" % angle)
	for cam in rigs:
		cam.free()
	# Shake alone, so this line reads the picture and leaves kick scaling to presentation_comfort_test.
	var offsets := []
	for scale in [0.0, 1.0]:
		var cam = _rig()[0]
		cam.motion_scale = scale
		_step(cam, SETTLE)
		cam.shake(SHAKE, 1.0)
		_step(cam, 1)
		offsets.append(cam.cam.position.length())
		cam.free()
	_t.check("a2 the Screen shake row still scales the picture", offsets[1] > offsets[0], "shake lens offset at 1.0 %.4f m, at 0.0 %.4f m" % [offsets[1], offsets[0]])


func _roll_and_impact() -> void:
	var calm_rig := _rig()
	var hit_rig := _rig()
	var calm = calm_rig[0]
	var hit = hit_rig[0]
	_step(calm, SETTLE)
	_step(hit, SETTLE)
	hit_rig[1].state.impact = 36.0
	var swerve: Vector3 = hit.yaw_basis().x * 8.0
	calm_rig[1].state.velocity = swerve
	hit_rig[1].state.velocity = swerve
	_step(calm, 1)
	_step(hit, 1)
	_t.check("a3 the jitter roll is live", hit.cam.rotation.z != calm.cam.rotation.z, "roll hit %.5f calm %.5f" % [hit.cam.rotation.z, calm.cam.rotation.z])
	var angle: float = hit.aim_forward().angle_to(calm.aim_forward())
	_t.check("a3 aim_forward ignores roll and the impact shake", angle < ANGLE_TOL, "angle %.7f rad" % angle)
	var gap: float = hit.aim_origin().distance_to(calm.aim_origin())
	_t.check("a3 aim_origin ignores roll and the impact shake", gap < ORIGIN_TOL, "gap %.7f m" % gap)
	calm.free()
	hit.free()


func _real_game() -> void:
	var cam = _game.camera
	cam.kick(cam.cam.global_basis.x, KICK)
	cam.shake(SHAKE, 1.0)
	cam._process(DT)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var ball: Vector3 = _game.player.ball_position()
	var rest := (cam.cam.get_parent() as Node3D).global_position
	var lens: Vector3 = cam.cam.global_position
	_t.check("b1 the kick is live in the real rig", lens.distance_to(rest) > LEAK_LIVE, "lens to rest %.4f m" % lens.distance_to(rest))
	_t.check("b2 ctx.aim_origin is the lens rest", _game.ctx.aim_origin().is_equal_approx(rest), "origin %s rest %s" % [_game.ctx.aim_origin(), rest])
	var angle: float = _game.ctx.aim_forward().angle_to(-cam.cam.global_basis.z)
	_t.check("b2 ctx.aim_forward is the view direction", angle < ANGLE_TOL, "angle %.7f rad" % angle)
	var forward: Vector3 = _game.ctx.aim_forward()
	var at_origin: Vector3 = Hitscan.aim(space, _game.ctx.aim_origin(), forward, ball, REACH)["point"]
	var at_rest: Vector3 = Hitscan.aim(space, rest, forward, ball, REACH)["point"]
	var at_lens: Vector3 = Hitscan.aim(space, lens, forward, ball, REACH)["point"]
	_t.check("b3 the shot lands where the rest aims", at_origin.is_equal_approx(at_rest), "point %s rest point %s" % [at_origin, at_rest])
	_t.check("b3 the shaken lens would have moved the shot", at_lens.distance_to(at_rest) > SHOT_LEAK, "lens point moved %.4f m" % at_lens.distance_to(at_rest))
	var source := FileAccess.get_file_as_string("res://src/game.gd")
	_t.check("b4 the harpoon aim reads the camera's aim functions", source.contains("aim_along(camera.aim_origin(), camera.aim_forward())"))
	_t.check("b4 the harpoon aim no longer reads the shaken lens", not source.contains("aim_along(camera.cam.global_position"))
