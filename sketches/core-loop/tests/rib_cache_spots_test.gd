extends SceneTree

const Activities := preload("res://src/world/activities.gd")
const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")

# Rib cache spots on the Spillway parks (director.rib_spots on the shipped graphs), 40 draws each:
# (a) every draw holds RIB_CACHES distinct spots;
# (b) each spot is a dead end a player hunting the park rolls into: at most RIB_DETOUR_MAX_M over
#     the drop-in to landmark path and RIB_LANDMARK_CLEAR_M or more short of the landmark;
# (c) no spot stands on a line or a grind line's deck, and on the flume none lands within NOTCH_CLEAR_M of
#     the drum lip notch (#481);
# (d) the same seed draws the same spots, and both parks' draws vary: the flume's at its own door
#     floor (Director.RIB_MIN_DOORS, ruling az) qualifies FLUME_SPOTS_MIN spots or more, and at the
#     graph's own floor (the control) only the three far-west ends every seed drew before;
# (e) the later worlds' parks still draw RIB_CACHES distinct spots.

const EXPECTED_CHECKS := 15
const DRAWS := 40
const COUNT := 3
const NOTCH := Vector2(271, 488)
const NOTCH_CLEAR_M := 60.0
const FLUME_SPOTS_MIN := 8
const OTHER_PARKS := ["park_pit", "park_sinkhole", "park_islands", "park_crown"]
const PARKS := {"park_dam": Vector2(-150, -690), "park_flume": Vector2(-460, -650)}

var _t := T.new("rib_cache_spots_test")


func _initialize() -> void:
	for map_id in PARKS:
		_park(map_id, PARKS[map_id])
	_other_parks()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _park(map_id: String, spawn: Vector2) -> void:
	var graph = Activities.shared_graph("res://assets/park/%s/graph.bin" % map_id)
	var grind: Dictionary = Director.grind_rows(JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id)))
	var direct: float = graph.d_landmark(spawn)
	var min_doors: int = Director.rib_min_doors(map_id)
	var sized := true
	var fair := true
	var worst := 0.0
	var near_notch := false
	var decked := false
	var spots := {}
	for seed in DRAWS:
		var out: Array[Vector3] = Director.rib_spots(graph, spawn, COUNT, seed, grind, min_doors)
		var keys := {}
		for p in out:
			keys[p] = true
			spots[Vector2(p.x, p.z)] = true
			var node: int = graph.nearest(Vector2(p.x, p.z))
			var land: float = graph.d_landmark_node(node)
			var detour: float = graph.d_spawn_node(node) + land - direct
			worst = maxf(worst, detour)
			if detour > Director.RIB_DETOUR_MAX_M or land < Director.RIB_LANDMARK_CLEAR_M:
				fair = false
			if _on_deck(graph, p, grind):
				decked = true
			if Vector2(p.x, p.z).distance_to(NOTCH) < NOTCH_CLEAR_M:
				near_notch = true
		if out.size() != COUNT or keys.size() != COUNT:
			sized = false
	_t.check("%s: %d distinct spots a draw" % [map_id, COUNT], sized)
	_t.check("%s: every spot within the detour and clear of the landmark" % map_id, fair, "worst detour %.0f m" % worst)
	_t.check("%s: no spot on a line or grind deck" % map_id, not decked)
	_t.check("%s: same seed, same spots" % map_id, Director.rib_spots(graph, spawn, COUNT, 7, grind, min_doors) == Director.rib_spots(graph, spawn, COUNT, 7, grind, min_doors))
	if map_id == "park_dam":
		_t.check("park_dam: more than one set of spots across draws", spots.size() > COUNT, "%d spots" % spots.size())
	if map_id == "park_flume":
		_t.check("park_flume: at least %d spots across draws" % FLUME_SPOTS_MIN, spots.size() >= FLUME_SPOTS_MIN, "%d spots" % spots.size())
		var old := {}
		for seed in DRAWS:
			for p in Director.rib_spots(graph, spawn, COUNT, seed, grind):
				old[Vector2(p.x, p.z)] = true
		_t.check("park_flume control: the graph's own door floor draws only %d spots" % COUNT, old.size() == COUNT, "%d spots" % old.size())
		_t.check("park_flume: no spot by the drum lip notch", not near_notch)
		# Control: W50-MAP-W1-ROBOQUEST connected siphon_span via weir_trestle_zip and
		# siphon_overlook_cannon so no off-route flume anchor sits on a grind_line anymore; plant
		# drawn flume rows as grind rows to verify Director.rib_spots excludes grind-deck nodes.
		var planted_grind := {"crew_ledges": true, "spill_leap_kicker": true}
		var drawn_without := false
		var avoided_with := true
		for seed in DRAWS:
			for p in Director.rib_spots(graph, spawn, COUNT, seed, {}, min_doors):
				if _on_deck(graph, p, planted_grind):
					drawn_without = true
			for p in Director.rib_spots(graph, spawn, COUNT, seed, planted_grind, min_doors):
				if _on_deck(graph, p, planted_grind):
					avoided_with = false
		_t.check("park_flume control: planted grind rows are drawn without the grind rule and avoided with it",
			drawn_without and avoided_with, "without=%s with_avoided=%s" % [drawn_without, avoided_with])


# Every later world's park still gets its full set of caches from the same rule.
func _other_parks() -> void:
	var short := []
	for map_id in OTHER_PARKS:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
		var graph = Activities.shared_graph("res://assets/park/%s/graph.bin" % map_id)
		var spawn := Vector2(float(park.spawn.at[0]), float(park.spawn.at[1]))
		for seed in 8:
			var out: Array[Vector3] = Director.rib_spots(graph, spawn, COUNT, seed, Director.grind_rows(park))
			var keys := {}
			for p in out:
				keys[p] = true
			if keys.size() != COUNT:
				short.append("%s seed %d: %d" % [map_id, seed, keys.size()])
	_t.check("later parks: %d distinct spots a draw" % COUNT, short.is_empty(), ", ".join(short))


# The graph node standing exactly at a drawn spot: a line or grind deck node there means the cache
# hangs over the ground the ball rolls on.
func _on_deck(graph, p: Vector3, grind: Dictionary) -> bool:
	for node in graph.node_count():
		if graph.position(node).is_equal_approx(p) and Director.off_ground(graph, node, grind):
			return true
	return false
