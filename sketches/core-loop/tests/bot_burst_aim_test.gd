extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# The burst-aim guard in bot_driver.gd _drive: a pilot whose Shift verb throws the ball along
# the camera (claw pull, blink, recoil, a slow surge) presses Shift only when the camera's
# flat forward is within BURST_AIM_LINED of the steer; Rivet's sprint, which keeps the
# velocity's line, presses as before. The world, the camera turn and the walls are stubbed so
# only the press decision is under test. The ball rolls toward the steer at -Z.

const STEER := Vector3(0.0, 0.0, -20.0)


class FakeKit:
	var key := ""
	var hooked := false
	var line_state := 0
	var slamming := false

	func on(k: String) -> bool:
		return k == key


class FakeState:
	var grounded := true
	var velocity := Vector3.ZERO
	var air_actions := 0


class FakePlayer:
	var kit := FakeKit.new()
	var state := FakeState.new()
	var speed := 10.0

	func ball_position() -> Vector3:
		return Vector3.ZERO

	func planar_velocity() -> Vector3:
		return Vector3(0.0, 0.0, -speed)

	func verb_ready(_verb: String) -> bool:
		return true


class FakeCamera:
	var yaw := 0.0


class FakeGame:
	var bot_driven := false
	var player := FakePlayer.new()
	var camera := FakeCamera.new()


class Probe extends BotDriver:
	func _init(game_ref) -> void:
		super(game_ref, "completionist", 15)

	func _plate_shortcut(_steer: Vector3, _ball: Vector3) -> Dictionary:
		return {}

	func _inside_thermal(_ball: Vector3) -> bool:
		return false

	func _around_walls(_ball: Vector3, heading: Vector3) -> Vector3:
		return heading

	func _throw_hold(_aim) -> bool:
		return false

	func _look(_ball: Vector3, _point: Vector3, _pitch_to: bool, _delta: float) -> void:
		pass

	func _in_boss() -> bool:
		return false

	func _card_hands() -> void:
		pass


# yaw 0 looks along -Z (lined up with the steer); PI/2 looks along -X (90 degrees off).
func _pressed(key: String, yaw: float, speed := 10.0) -> bool:
	var game := FakeGame.new()
	game.player.kit.key = key
	game.player.speed = speed
	game.camera.yaw = yaw
	var probe := Probe.new(game)
	probe._drive(STEER, null, 1.0 / 90.0)
	return probe.source.press.get("shift_pressed", false)


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_burst_aim_test")
	var off := PI * 0.5
	# Just past the threshold either side: cos(25 deg) = 0.906 passes, cos(27 deg) = 0.891 waits.
	var inside := deg_to_rad(25.0)
	var outside := deg_to_rad(27.0)

	t.check("claw pull, aim 90 deg off the steer: no press", not _pressed(Augments.CLAW_PULL, off))
	t.check("claw pull, aim 27 deg off: no press", not _pressed(Augments.CLAW_PULL, outside))
	t.check("claw pull, aim 25 deg off: press", _pressed(Augments.CLAW_PULL, inside))
	t.check("claw pull, aim lined up: press", _pressed(Augments.CLAW_PULL, 0.0))
	t.check("blink, aim 90 deg off: no press", not _pressed(Augments.BLINK, off))
	t.check("blink, aim lined up: press", _pressed(Augments.BLINK, 0.0))
	t.check("recoil, aim 90 deg off: no press", not _pressed(Augments.RECOIL, off))
	t.check("surge below its minimum speed, aim 90 deg off: no press", not _pressed(Augments.SURGE, off, 1.0))
	t.check("surge at speed, aim 90 deg off: press (it keeps the travel line)", _pressed(Augments.SURGE, off))
	t.check("Rivet's sprint, aim 90 deg off: press as before", _pressed(Augments.SPRINT, off))
	quit(t.verdict())
	return false
