extends SceneTree

# A ball rolling under the flume's landed trestle ramp is on the floor, not fallen (line-rider red team, w20
# e646632d). terrain.height() takes the ramp's sheet (the trestle_ramp_after overlay) over the floor beneath it,
# and where the gap passed RESCUE_DEPTH flow._rescue_if_fallen teleported the completionist line's ball 22 m up
# onto the ramp at (-25.4, 4, 164.7), on main a4c5b963 too. This boots the real flume stage on the park table,
# lands hollow_trestle_collapse's swap, rests a ball on the floor under the ramp there for two seconds of the
# real flow, and checks it is never teleported. A ball dropped well under that floor is still rescued.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")

const EVENT := "hollow_trestle_collapse"
const SPOT := Vector2(-25.4, 164.7)
const RESCUE_DEPTH := 14.0

var t := T.new("park_trestle_under_rescue_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in 60:
		await physics_frame
	var rec: Dictionary = game.world.event_families.natural._prepared.get(EVENT, {})
	if not t.check("%s is prepared on the flume stage" % EVENT, not rec.is_empty()):
		quit(t.verdict())
		return
	var row := {}
	for event: Dictionary in game.ctx.terrain.map().park.event_rows:
		if event.id == EVENT:
			row = event
	EventGround.set_overlay(game.world, row, rec, true)
	for i in 5:
		await physics_frame
	var terrain = game.ctx.terrain
	var deck: float = terrain.height(SPOT.x, SPOT.y)
	var floor_y: float = terrain.floor_height(SPOT.x, SPOT.y)
	t.check("the landed ramp stands more than RESCUE_DEPTH over the floor at the spot", deck - floor_y > RESCUE_DEPTH,
		"deck %.1f, floor %.1f" % [deck, floor_y])
	var rest := Vector3(SPOT.x, floor_y + Tuning.RADIUS + 0.2, SPOT.y)
	game.player.reset_to(rest, Vector3.ZERO)
	game.player.body().global_position = rest
	var highest := -INF
	var jump := 0.0
	var prev := rest
	for i in int(2.0 * Engine.physics_ticks_per_second):
		await physics_frame
		var b: Vector3 = game.player.ball_position()
		highest = maxf(highest, b.y)
		jump = maxf(jump, b.distance_to(prev))
		prev = b
	t.check("a ball on the floor under the ramp stays on the floor", highest < floor_y + 4.0,
		"highest %.1f, floor %.1f, deck %.1f" % [highest, floor_y, deck])
	t.check("and is never teleported", jump < 2.0, "largest one-tick move %.1f m" % jump)
	# The rescue still catches a real fall: a ball well under the floor is put back on the map.
	var under := Vector3(SPOT.x, floor_y - RESCUE_DEPTH - 6.0, SPOT.y)
	game.player.reset_to(under, Vector3.ZERO)
	game.player.body().global_position = under
	for i in 3:
		await physics_frame
	var after: Vector3 = game.player.ball_position()
	t.check("a ball under the floor is still rescued", after.y > floor_y, "ball %s, floor %.1f" % [after, floor_y])
	quit(t.verdict())
