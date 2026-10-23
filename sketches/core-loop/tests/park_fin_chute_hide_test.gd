extends SceneTree

# fin_chute lies wholly inside twin_fins, where fin_rim_collapse drops the ground 8 m. Its row hides on that collapse,
# so its ground sheet (isle_ride_fin_chute) parks down with the fins and never hangs over the dropped ground (ghost
# solid, #183). This boots the real islands stage, applies and reverts the collapse's swap, and checks the placed
# Park_fin_chute node leaves and comes home with Park_twin_fins. fin_nose_kicker, the seated lip at the fins' north
# edge, also stands on the collapsing ground, so it hides on the same event with its collider.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")

const EVENT := "fin_rim_collapse"

var t := T.new("park_fin_chute_hide_test")
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
	game.flow.enter_stage(5, Vector3.ZERO, false)
	for i in 60:
		await physics_frame
	var rec: Dictionary = game.world.event_families.natural._prepared.get(EVENT, {})
	if not t.check("%s is prepared on the islands stage" % EVENT, not rec.is_empty()):
		quit(t.verdict())
		return
	var names := []
	for hidden in rec.overlay_map.swaps[rec.swap].get("hidden", []):
		names.append(String(hidden.node.name))
	names.sort()
	t.eq("%s hides fin_chute and fin_nose_kicker" % EVENT, names, ["Park_fin_chute", "Park_fin_nose_kicker"])
	var geometry: Node = game.world.terrain.geometry_root(game.world.terrain.stage)
	var chute := geometry.find_child("Park_fin_chute", true, false) as Node3D
	var fins := geometry.find_child("Park_twin_fins", true, false) as Node3D
	if not t.check("fin_chute and twin_fins are placed", chute != null and fins != null):
		quit(t.verdict())
		return
	t.eq("fin_chute draws its sheet", chute.get_meta("park_recipe", ""), "isle_ride_fin_chute")
	var kicker := geometry.find_child("Park_fin_nose_kicker", true, false) as Node3D
	var home := chute.position
	var kicker_home := kicker.position if kicker != null else Vector3.ZERO
	var row := {}
	for event: Dictionary in game.ctx.terrain.map().park.event_rows:
		if event.id == EVENT:
			row = event
	EventGround.set_overlay(game.world, row, rec, true)
	t.check("the collapse hides fin_chute with twin_fins", not chute.visible and not fins.visible)
	t.check("the collapse hides fin_nose_kicker", kicker != null and not kicker.visible and kicker.position.y < kicker_home.y - 8.0)
	t.check("fin_chute parks below the dropped ground", chute.position.y < home.y - 8.0, "dy %.1f" % (chute.position.y - home.y))
	EventGround.set_overlay(game.world, row, rec, false)
	t.check("the revert brings fin_chute home", chute.visible and chute.position.is_equal_approx(home))
	t.check("the revert brings fin_nose_kicker home", kicker != null and kicker.visible and kicker.position.is_equal_approx(kicker_home))
	quit(t.verdict())
