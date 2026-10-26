extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The bot's wall steering (bot_driver.gd _around_walls) with the side it holds (#478). Posts stand
# at chosen bearings of the WALL_TURNS fan around a still ball heading +z, each in one ray's way
# and clear of its neighbours, and the turn the driver returns is read:
#   held     the side holds where both widest turns are clear (the seed 2867 dither fix): with
#            -1 held, -1.5 is taken over +1.5, which the fan lists first.
#   boxed    every turn on the held side is walled and -0.5 is clear: the side drops and -0.5 is
#            taken. Under #478 the bot pressed +1.5 into the posts (random seed 2869 on the park
#            table stalled riding the pit Warden with it, and clears without it).
#   walled   every turn walled: the heading goes straight on, as before the side was held.
#
# Evidence limit: posts on a flat static world and one call per case. It does not show a run.

const POST_AT_M := 2.0
const POST_SIZE := Vector3(0.4, 2.0, 0.4)
const BALL := Vector3(0.0, 0.2, 0.0)
const HEADING := Vector3(0.0, 0.0, 10.0)


class FakeFlow:
	func state_name() -> String:
		return "stage"


class FakeGame extends Node3D:
	var bot_driven := false
	var flow := FakeFlow.new()


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_run.call_deferred()
	return false


func _run() -> void:
	var t := T.new("bot_wall_side_test")
	var game := FakeGame.new()
	root.add_child(game)
	var driver := BotDriver.new(game, "random", 1)

	var held: Dictionary = await _steer(game, driver, -1.0, [0.0, 0.5, -0.5, 1.0, -1.0])
	t.check("held: the held side's widest turn is taken", absf(held["turn"] + 1.5) < 0.01, str(held))
	t.eq("held: the side is kept", held["side"], -1.0)

	var boxed: Dictionary = await _steer(game, driver, 1.0, [0.0, 0.5, 1.0, 1.5])
	t.check("boxed: the clear turn across is taken", absf(boxed["turn"] + 0.5) < 0.01, str(boxed))
	t.eq("boxed: the side moves across", boxed["side"], -1.0)

	var walled: Dictionary = await _steer(game, driver, 1.0, BotDriver.WALL_TURNS)
	t.check("walled: straight on", absf(walled["turn"]) < 0.01, str(walled))
	t.check("walled: full length", is_equal_approx(walled["length"], HEADING.length()), str(walled))
	t.eq("walled: no side held", walled["side"], 0.0)

	game.free()
	quit(t.verdict())


# Posts at the given bearings, the side set, one _around_walls call: {"turn" (rad, + toward +x), "side", "length"}.
func _steer(game: Node3D, driver, side: float, bearings: Array) -> Dictionary:
	for child in game.get_children():
		child.free()
	for bearing: float in bearings:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = POST_SIZE
		shape.shape = box
		body.add_child(shape)
		game.add_child(body)
		body.position = BALL + Vector3(sin(bearing), 0.0, cos(bearing)) * POST_AT_M
		body.rotation.y = bearing
	await physics_frame
	await physics_frame
	driver._wall_side = side
	driver._wall_dir = HEADING.normalized()
	var out: Vector3 = driver._around_walls(BALL, HEADING)
	return {"turn": atan2(out.x, out.z), "side": driver._wall_side, "length": out.length()}
