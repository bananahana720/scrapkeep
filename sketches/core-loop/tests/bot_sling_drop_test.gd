extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The engineer's dismount in bot_driver.gd _turret (FINAL-STALL item 1). Leaving a plant she reads
# the aim cone (kit.slingshot_aim) and drops off the post (E) when the slingshot would come down
# more than LEVEL_BAND below both the ball's ground and the fight's floor; otherwise she slingshots
# (Space). The ground is an island SHELF_TOP high within SHELF_RADIUS of the origin over a net at
# NET_TOP, the Highdraft crown's shape; the look and the threats are stubbed, the aim is the Warden.

const SHELF_TOP := 37.0
const SHELF_RADIUS := 20.0
const NET_TOP := 11.0
const STEP := 1.0 / 90.0


class FakeTuning:
	func f(key: String) -> float:
		return 26.0 if key == "gravity" else 0.0


class FakeKit:
	var slingshot_aim := {}


class FakePlayer:
	var at := Vector3.ZERO
	var kit := FakeKit.new()
	var tuning := FakeTuning.new()

	func ball_position() -> Vector3:
		return at


class FakeGame:
	var bot_driven := false
	var player := FakePlayer.new()


class Probe extends BotDriver:
	func _init(game_ref) -> void:
		super(game_ref, "completionist", 2)

	func _ground_point(x: float, z: float) -> Vector3:
		var top := SHELF_TOP if Vector2(x, z).length() <= SHELF_RADIUS else NET_TOP
		return Vector3(x, top + 1.0, z)

	func _look(_ball: Vector3, _point: Vector3, _pitch_to: bool, _delta: float) -> void:
		pass

	func _threats() -> Array:
		return []


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_sling_drop_test")
	var warden := Node3D.new()
	root.add_child(warden)
	warden.global_position = Vector3(6.0, SHELF_TOP + 1.0, 0.0)

	# A stacked capacitor slingshot off the crown shelf: 60 m/s, out over the rim.
	var off := _leave(warden, Vector3(-4.0, SHELF_TOP + 1.0, 0.0), Vector3(-0.8, 0.33, 0.5), 60.0)
	t.eq("off the shelf: drops off the post", off.get("mount_pressed", false), true)
	t.eq("off the shelf: no slingshot", off.get("jump_pressed", false), false)

	# Control: a short hop that comes down on the same shelf slingshots as before.
	var on := _leave(warden, Vector3(-4.0, SHELF_TOP + 1.0, 0.0), Vector3(0.6, 0.6, 0.0), 12.0)
	t.eq("on the shelf: slingshots", on.get("jump_pressed", false), true)
	t.eq("on the shelf: no drop", on.get("mount_pressed", false), false)

	# Control: planted on the net below the shelf, a slingshot that lands on the net loses no height.
	var net := _leave(warden, Vector3(60.0, NET_TOP + 1.0, 0.0), Vector3(0.6, 0.5, 0.6), 30.0)
	t.eq("on the net: slingshots", net.get("jump_pressed", false), true)
	t.eq("on the net: no drop", net.get("mount_pressed", false), false)

	warden.free()
	quit(t.verdict())
	return false


# One turret tick past TURRET_SECONDS with the given aim cone; returns the presses it made.
func _leave(warden: Node3D, ball: Vector3, dir: Vector3, speed: float) -> Dictionary:
	var game := FakeGame.new()
	game.player.at = ball
	game.player.kit.slingshot_aim = {"dir": dir.normalized(), "speed": speed, "fill": 0.0}
	var probe := Probe.new(game)
	probe._plant_target = warden
	probe._plant_state = "mounted"
	probe._plant_clock = BotDriver.TURRET_SECONDS + 0.1
	probe._turret(warden, STEP)
	return probe.source.press
