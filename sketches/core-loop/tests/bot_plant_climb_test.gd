extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The engineer's plant precedence in bot_driver.gd _act: while the fight climb is on, the climb
# waypoint is the steer; off the climb, a plant face can still replace it. The kit, threats
# and the stick are stubbed so only _act's choice is under test.

const CLIMB_STEP := Vector3(10.0, 24.0, -62.0)
const FACE := Vector3(4.0, 30.0, -76.0)


class FakeKit:
	var mounted := false


class FakePlayer:
	var kit := FakeKit.new()

	func ball_position() -> Vector3:
		return Vector3(20.0, 17.0, -42.0)


class FakeGame:
	var bot_driven := false
	var player := FakePlayer.new()


class Probe extends BotDriver:
	var climbing := false
	var plants := 0
	var steered := Vector3.INF

	func _init(game_ref) -> void:
		super(game_ref, "completionist", 6)

	func _engineer() -> bool:
		return true

	func _climbing(_ball: Vector3, _at: Vector3) -> bool:
		return climbing

	func _plant(_fight: Node3D, _delta: float) -> Vector3:
		plants += 1
		return FACE

	func _threats() -> Array:
		return []

	func _specials(_fight: Node3D, _pressed_by_threat: bool) -> void:
		pass

	func _drive(steer: Vector3, _aim, _delta: float) -> void:
		steered = steer


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_plant_climb_test")
	var fight := Node3D.new()
	root.add_child(fight)
	fight.global_position = Vector3(-20.0, 37.6, -115.0)

	var up := Probe.new(FakeGame.new())
	up.climbing = true
	up._act(CLIMB_STEP, null, 1.0 / 90.0, fight)
	t.check("climbing: the climb waypoint stays the steer", up.steered == CLIMB_STEP, str(up.steered))
	t.eq("climbing: the plant cycle does not run", up.plants, 0)

	var stale := Probe.new(FakeGame.new())
	stale._plant_state = "seek"
	stale.climbing = true
	stale._act(CLIMB_STEP, null, 1.0 / 90.0, fight)
	t.eq("climbing: a seek in progress drops to idle", stale._plant_state, "idle")
	t.check("climbing: the dropped seek does not steer", stale.steered == CLIMB_STEP, str(stale.steered))

	var level := Probe.new(FakeGame.new())
	level.climbing = false
	level._act(CLIMB_STEP, null, 1.0 / 90.0, fight)
	t.check("level: the plant face replaces the steer", level.steered == FACE, str(level.steered))
	t.eq("level: the plant cycle runs", level.plants, 1)

	fight.free()
	quit(t.verdict())
	return false
