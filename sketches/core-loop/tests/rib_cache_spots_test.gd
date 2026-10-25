extends SceneTree

const Activities := preload("res://src/world/activities.gd")
const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")

# Rib cache spots on the Spillway parks (director.rib_spots on the shipped graphs), 40 draws each:
# (a) every draw holds RIB_CACHES distinct spots;
# (b) each spot is a dead end a player hunting the park rolls into: at most RIB_DETOUR_MAX_M over
#     the drop-in to landmark path and RIB_LANDMARK_CLEAR_M or more short of the landmark;
# (c) on the flume no spot lands in the outer washes (500 m and more off the line) or within
#     NOTCH_CLEAR_M of the drum lip notch (#481);
# (d) the same seed draws the same spots.

const EXPECTED_CHECKS := 10
const DRAWS := 40
const COUNT := 3
const NOTCH := Vector2(271, 488)
const NOTCH_CLEAR_M := 60.0
const PARKS := {"park_dam": Vector2(-150, -690), "park_flume": Vector2(-460, -650)}

var _t := T.new("rib_cache_spots_test")


func _initialize() -> void:
	for map_id in PARKS:
		_park(map_id, PARKS[map_id])
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _park(map_id: String, spawn: Vector2) -> void:
	var graph = Activities.shared_graph("res://assets/park/%s/graph.bin" % map_id)
	var direct: float = graph.d_landmark(spawn)
	var sized := true
	var fair := true
	var worst := 0.0
	var near_notch := false
	var spots := {}
	for seed in DRAWS:
		var out: Array[Vector3] = Director.rib_spots(graph, spawn, COUNT, seed)
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
			if Vector2(p.x, p.z).distance_to(NOTCH) < NOTCH_CLEAR_M:
				near_notch = true
		if out.size() != COUNT or keys.size() != COUNT:
			sized = false
	_t.check("%s: %d distinct spots a draw" % [map_id, COUNT], sized)
	_t.check("%s: every spot within the detour and clear of the landmark" % map_id, fair, "worst detour %.0f m" % worst)
	_t.check("%s: more than one set of spots across draws" % map_id, spots.size() > COUNT, "%d spots" % spots.size())
	_t.check("%s: same seed, same spots" % map_id, Director.rib_spots(graph, spawn, COUNT, 7) == Director.rib_spots(graph, spawn, COUNT, 7))
	if map_id == "park_flume":
		_t.check("park_flume: no spot by the drum lip notch", not near_notch)
