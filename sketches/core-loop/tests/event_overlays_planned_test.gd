# smoke: solo timeout=300s (waits on the overlay workers)
extends SceneTree

# An industrial or ancient row's ground swap was projected on the main thread at its telegraph
# (ancient) or landing (industrial): 484 ms and 461 ms on the cloud for the islands' lens rocks and
# mooring burner (scrapkeep#241). Each handler's setup now projects its stage's swaps on a worker from
# the ground as entered. Checked on park stage 1 (the dam's toe vents and powerhouse boiler): each
# swap is planned; each planned surface equals a live projection vertex for vertex; the handler's
# swap body uses the planned mesh; with an overlay down, or a different stage, the plan is not handed out.
#
# The OverlayMap's copy of the park map (42 ms of the islands' entry frame on the cloud) is made on a worker
# once a park stage is built. For every park map with a natural or swap overlay, the worker's copy equals
# one made the old way on the main thread, field by field, deep, without sharing its containers, and the
# park map is unchanged after it. On stage 1 the overlay the stage made from it equals the old way too,
# and a second take (a retry) gets a fresh copy, not the one in use.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Kinds := preload("res://src/core/event_kinds.gd")

const SETTLE_TICKS := 30

var _game
# Each park map's fields copied before any check takes a copy of it, by park id.
var _before := {}
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
	_check_overlay_maps(world)
	for family in ["ancient", "industrial"]:
		_check_family(world, family)
	_check_stage_overlay(world)
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())


# The park map fields of a and b that differ by deep ==, and those whose Dictionary or Array b shares with a.
func _map_diff(a, b) -> Array:
	var diff := []
	for property in a.get_property_list():
		if int(property.usage) & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE) and property.name != "script":
			var x = a.get(property.name)
			var y = b.get(property.name)
			if typeof(x) != typeof(y) or x != y or ((x is Dictionary or x is Array) and is_same(x, y)):
				diff.append(property.name)
	return diff


func _overlaid(map) -> bool:
	for row in map.park.get("event_rows", []):
		if String(row.get("effect", {}).get("swap", "")) != "" or (row.family == "natural" and (row.kind == "cave_in" or Kinds.HIDING_NATURAL_KINDS.has(row.kind))):
			return true
	return false


func _check_overlay_maps(world) -> void:
	var terrain = world.terrain
	var maps: Array = terrain.maps.filter(func(m): return m is ParkMap and not m is EventGround.OverlayMap and m.ok and _overlaid(m))
	_t.check("park maps with a natural or swap overlay", maps.size() >= 5, str(maps.map(func(m): return m.park.get("map", ""))))
	_t.check("stage 1's build queued its copy on a worker", terrain._overlay_ahead.has(terrain.stage - 1), str(terrain._overlay_ahead.keys()))
	var changed := []
	var unequal := []
	for m in maps:
		var before: EventGround.OverlayMap = EventGround.copy_map(m)
		_before[m.park.get("map", "")] = before
		var copy: EventGround.OverlayMap = EventGround.take_overlay_map(EventGround.queue_overlay_map(m), m)
		var old: EventGround.OverlayMap = EventGround.copy_map(m)
		if copy == null or copy.source != m or not (_map_diff(old, copy) + _map_diff(m, copy)).is_empty():
			unequal.append([m.park.get("map", ""), _map_diff(old, copy) + _map_diff(m, copy) if copy != null else "null"])
		if not _map_diff(m, before).is_empty():
			changed.append(m.park.get("map", ""))
	_t.check("each worker copy equals the old main-thread copy, field by field, unshared", unequal.is_empty(), str(unequal))
	_t.check("each park map is unchanged after its copies", changed.is_empty(), str(changed))


# After _check_family's prepare_overlay calls, which made stage 1's overlay map from the worker's copy.
func _check_stage_overlay(world) -> void:
	var terrain = world.terrain
	var map = terrain.map()
	if not _t.check("stage 1's overlay map is made from its park map", map is EventGround.OverlayMap and map.source is ParkMap, str(map)):
		return
	var source = map.source
	var old: EventGround.OverlayMap = EventGround.copy_map(source)
	_t.check("stage 1's overlay map equals the old main-thread copy", _map_diff(source, map).is_empty(), str(_map_diff(source, map)))
	var again: EventGround.OverlayMap = terrain.take_overlay_map(source)
	_t.check("a retry's take gets a fresh copy, not the one in use", again != null and again != map and again.swaps.is_empty()
		and _map_diff(old, again).is_empty() and not is_same(again.park, map.park), str(again))
	var before = _before.get(source.park.get("map", ""))
	_t.check("stage 1's park map is unchanged after its overlay and the retry's take", before != null and _map_diff(source, before).is_empty(), str(before))


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
