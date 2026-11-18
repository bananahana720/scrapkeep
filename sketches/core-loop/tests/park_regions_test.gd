extends SceneTree

const Regions := preload("res://src/world/park/regions.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Arena := preload("res://src/boss/arena.gd")
const T := preload("res://tests/support/t.gd")
const PURPOSES := ["fight", "rest", "route", "landmark", "reward", "hub"]
# The eight places the map audit found without a purpose. Each witness is an authored park row.
const WITNESSES := {
	"park_dam": {"slickrock_domes": "slickrock_domes", "top_shelf_deck": "top_shelf", "corkscrew_slot": "corkscrew_slot", "east_rim_bench": "east_rim"},
	"park_flume": {"main_canal": "canal_fields", "weir_deck": "weir_mesa", "bench_run_wash": "bench_run", "lower_gorge": "lower_gorge"},
}

var t := T.new("park_regions_test")
var measured := {"regions": 0, "without_purpose": 0, "verbs_unbacked": 0, "route_nodes_outside": 0}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id: String in ["park_dam", "park_flume", "slag_bowl"]:
		var facts := _bowl_facts() if map_id == "slag_bowl" else _park_facts(map_id)
		var path := "res://src/boss/arena_regions.json" if map_id == "slag_bowl" else "res://assets/park/%s/regions.json" % map_id
		var rows = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else []
		if not t.check("%s regions loaded" % map_id, rows is Array and not rows.is_empty()):
			continue
		var ids := {}
		for row: Dictionary in rows:
			t.check("unique region %s/%s" % [map_id, row.id], not ids.has(row.id))
			ids[row.id] = true
			_measure(map_id, row, facts)
	print("RECEIPT ", JSON.stringify(measured))
	for key in ["without_purpose", "verbs_unbacked", "route_nodes_outside"]:
		t.eq(key, measured[key], 0)
	t.eq("unknown map", Regions.at("unknown", Vector2.ZERO), {})
	t.eq("a path is not a map id", Regions.at("../park/park_dam", Vector2(-110, -520)), {})
	t.eq("outside the park", Regions.at("park_dam", Vector2(2000, 2000)), {})
	quit(t.verdict())


func _park_facts(map_id: String) -> Dictionary:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
	var facts := {"hook": [], "jump": [], "roll": [], "shoot": [], "dash": []}
	var posts := ParkRecipes.field_posts(ParkRecipes.placed_rows(park), ParkRecipes.clear_zones(park))
	for field in posts.values():
		facts.hook.append_array(field)
	for row in park.park_rows:
		var at := Vector2(row.at[0], row.at[1])
		if row.element in ["kicker", "ramp"] or row.stamp == "ramp":
			facts.jump.append(at)
		if row.element == "bank":
			facts.roll.append(at)
	for home in park.home_rows:
		facts.shoot.append(ParkMap.place_of(park, home.site))
	for route in park.routes:
		var previous := Vector2.INF
		for id in [route.from] + route.via + [route.to]:
			var point := ParkMap.place_of(park, id)
			if point == Vector2.INF or Regions.at(map_id, point).is_empty():
				measured.route_nodes_outside += 1
				print("Outside: ", map_id, "/", route.id, "/", id)
			if previous.is_finite() and point.is_finite() and previous.distance_to(point) >= 40.0:
				facts.dash.append([previous, point])
			previous = point
	for place in WITNESSES[map_id]:
		var region := Regions.at(map_id, ParkMap.place_of(park, place))
		t.eq("%s/%s" % [map_id, place], region.get("id", ""), WITNESSES[map_id][place])
	return facts


func _bowl_facts() -> Dictionary:
	var facts := {"hook": [], "jump": [], "roll": []}
	var entry := Vector2.RIGHT.rotated(deg_to_rad(Arena.ENTRY_ANGLE)) * Arena.ENTRY_R
	t.check("first steerable bowl position has a purpose", not Regions.at("slag_bowl", entry).is_empty())
	for angle in Arena.MAST_ANGLES:
		facts.hook.append(Vector2.RIGHT.rotated(deg_to_rad(angle)) * Arena.MAST_R)
	for angle in Arena.RAMP_ANGLES:
		facts.jump.append(Vector2.RIGHT.rotated(deg_to_rad(angle)) * Arena.RAMP_TO)
	for i in Arena.SEGMENTS:
		var angle := TAU * i / Arena.SEGMENTS
		var point := Vector2.RIGHT.rotated(angle) * (Arena.FLOOR_R + Arena.BANK_R) * 0.5
		facts.roll.append(point)
		t.check("bank segment %d serves the ride" % i, "roll" in Regions.at("slag_bowl", point).get("verbs", []))
	return facts


func _measure(map_id: String, row: Dictionary, facts: Dictionary) -> void:
	var polygon := PackedVector2Array()
	for vertex in row.polygon:
		polygon.append(Vector2(vertex[0], vertex[1]))
	t.check("%s polygon has area" % row.id, Geometry2D.triangulate_polygon(polygon).size() >= 3)
	var plant := OS.get_environment("PLANT")
	if map_id == "park_dam" and row.id == "upper_slot":
		if plant == "no_purpose":
			row.erase("purpose")
		if plant == "fake_hook":
			row.verbs.append("hook")
	measured.regions += 1
	if row.get("purpose", "") not in PURPOSES or String(row.get("why", "")).strip_edges().is_empty():
		measured.without_purpose += 1
	if row.verbs.is_empty():
		measured.verbs_unbacked += 1
	for verb in row.verbs:
		if not _backed(verb, polygon, facts, map_id, row.id):
			print("Unbacked: ", map_id, "/", row.id, "/", verb)
			measured.verbs_unbacked += 1


func _backed(verb: String, polygon: PackedVector2Array, facts: Dictionary, map_id: String, id: String) -> bool:
	for witness in facts.get(verb, []):
		if verb == "dash":
			for segment in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array(witness), polygon):
				if segment[0].distance_to(segment[-1]) >= 40.0:
					return true
		elif Regions.at(map_id, witness).get("id", "") == id:
			return true
	return false
