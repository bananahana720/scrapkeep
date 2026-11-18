extends SceneTree

# The view on arrival in Brindle's bowl: the ball arrives on the entry heading and the camera
# looks down it, as the stub boss does. A view turned off the carried heading takes the player's
# aim (transitions audit: a camera turn is allowed only inside a directed set piece).

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")

const WORLD := 1
# Camera yaw and the velocity heading differ by well under a degree when they agree.
const YAW_TOLERANCE_DEG := 0.5

var _t := T.new("brindle_arrival_view_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	var flow = _game.flow
	flow.enter_stage(_game.ctx.stages.last_of(WORLD), Vector3.ZERO, false)
	flow._set_state(flow.GATES)
	flow.enter_boss(Vector3.ZERO)
	var velocity: Vector3 = _game.player.planar_velocity()
	_t.check("the ball arrives moving", velocity.length() > 1.0, "%.2f m/s" % velocity.length())
	var heading_yaw := atan2(-velocity.x, -velocity.z)
	var off := rad_to_deg(absf(angle_difference(_game.ctx.camera.yaw, heading_yaw)))
	_t.check("the camera looks down the carried heading on arrival", off <= YAW_TOLERANCE_DEG,
		"%.2f degrees off, tolerance %.1f" % [off, YAW_TOLERANCE_DEG])
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())
