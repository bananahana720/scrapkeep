# smoke: solo timeout=300s (waits on the overlay workers)
extends SceneTree

# An industrial or ancient row's ground swap was projected on the main thread at its telegraph
# (ancient) or landing (industrial): 484 ms and 461 ms on the cloud for the islands' lens rocks and
# mooring burner (scrapkeep#241). Each handler's setup now projects its stage's swaps on a worker from
# the ground as entered. Checked on park stage 1 (the dam's toe vents and powerhouse boiler): each
# swap is planned; each planned surface equals a live projection vertex for vertex; the handler's
# swap body uses the planned mesh; with an overlay down on its ground (one whose footprint meets its
# rectangle, or one with no profile to tell), or a different stage, the plan is not handed out.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")

const SETTLE_TICKS := 30

var _game
var _t := T.new("event_overlays_planned_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SimClock.ticks = true
	seed(11)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await physics_frame
	await physics_frame
	_game.run.run_seed_override = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in SETTLE_TICKS:
		await physics_frame
	var world = _game.world
	_t.check("the run is on park stage 1", _game.flow.stage() == 1, "stage %d" % _game.flow.stage())
	for family in ["ancient", "industrial"]:
		_check_family(world, family)
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())


func _check_family(world, family: String) -> void:
	var handler = world.event_families.get(family)
	if not _t.check("%s: a handler on stage 1" % family, handler != null):
		return
	var plan: Dictionary = handler._plan
	EventGround.settle_overlays(plan)
	var rows: Array = world.terrain.map().park.event_rows.filter(func(row): return row.family == family and String(row.get("effect", {}).get("swap", "")) != "")
	_t.check("%s: the stage has a swap row" % family, not rows.is_empty())
	for row in rows:
		var id := String(row.id)
		_t.check("%s %s: its swap is planned" % [family, row.id], plan.get("out", {}).has(id), str(plan.get("out", {}).keys()))
		if not plan.get("out", {}).has(id):
			continue
		var site: Dictionary = handler._site(row) if handler.has_method("_site") else handler._sites[row.site]
		var geometry: Dictionary = handler._geometry(site, Vector3(float(site.at[0]), 0.0, float(site.at[1])))
		var live: EventGround.Surface = EventGround.overlay_surface(world, row.kind, geometry)
		_t.check("%s %s: the planned surface equals a live projection" % [family, row.id], plan.out[id].vertices == live.vertices,
			"%d vs %d vertices" % [plan.out[id].vertices.size(), live.vertices.size()])
		var terrain = world.terrain
		terrain.overlays.append("some_overlay")
		_t.check("%s %s: with an overlay down the plan is not handed out" % [family, row.id], EventGround.planned_overlay(world, plan, id).is_empty())
		terrain.overlays.erase("some_overlay")
		var other := plan.duplicate()
		other.stage = plan.stage + 1
		_t.check("%s %s: nor on another stage" % [family, row.id], EventGround.planned_overlay(world, other, id).is_empty())
		var prepared := EventGround.planned_overlay(world, plan, id)
		_t.check("%s %s: on the ground as planned it is handed out, its mesh built" % [family, row.id],
			prepared.get("surface") == plan.out[id] and plan.out[id].mesh != null)
		var record := {"site": site, "at": geometry.at, "overlay": null, "geometry": geometry}
		EventGround.prepare_overlay(world, handler, row, record, Callable(), prepared)
		var body: Node = record.overlay
		_t.check("%s %s: the swap body uses the planned mesh" % [family, row.id],
			body != null and body.get_child(0).mesh == plan.out[id].mesh)
		# An overlay down counts only where its footprint (where overlay_height answers) meets the
		# swap's rectangle: the dam's boiler lands with the toe vents' lip down across the dam.
		var overlay_map = world.terrain.map()
		overlay_map.profiles["far_after"] = {"site": {"at": [site.at[0] + 5000.0, site.at[1]], "size": [4.0, 2.0, 4.0], "yaw_deg": 0.0}}
		terrain.overlays.append("far_after")
		_t.check("%s %s: with an overlay down away from it the plan is still handed out" % [family, row.id],
			EventGround.planned_overlay(world, plan, id).get("surface") == plan.out[id])
		terrain.overlays.append(id + "_after")
		_t.check("%s %s: with one down across its own ground it is not" % [family, row.id], EventGround.planned_overlay(world, plan, id).is_empty())
		terrain.overlays.erase(id + "_after")
		terrain.overlays.erase("far_after")
		overlay_map.profiles.erase("far_after")
