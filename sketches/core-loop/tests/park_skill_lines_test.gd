extends SceneTree

# One skill per park (Andrew, Q4, 22:12Z 17 Oct; stage pages 5 and 6): each Highdraft park has a skill line,
# assets/park/<map>/skill_line.json, that tools/traversal_line.gd rides end to end with --lines. This holds what the
# ride needs without running it: every named waymark resolves, the line passes within reach of each cable it names
# (a cable hooks the ball within its radius of its start, contraptions.gd), and every cable laid for the skill line
# alone (own_cables) starts at least CLEAR_M from every pilot and floor line in lines.json. A start on another pilot's
# line hooked that pilot off it: on 17 Oct four islands pilots stalled 60 to 109 times after a lookout or bench cable.

const TraversalLine := preload("res://tools/traversal_line.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

const PARKS := {"park_islands": "grapple", "park_crown": "everything"}
const CLEAR_M := 25.0

var _t := T.new("park_skill_lines_test")


func _initialize() -> void:
	for map in PARKS:
		_park(map, PARKS[map])
	quit(_t.verdict())


func _park(map: String, skill: String) -> void:
	var park: Dictionary = ParkSchema.load_park("res://src/world/park/%s.json" % map)["data"]
	var skill_lines := TraversalLine.load_lines("res://assets/park/%s/skill_line.json" % map)
	var lines := TraversalLine.load_lines("res://assets/park/%s/lines.json" % map)
	_t.eq("%s skill" % map, skill_lines.get("skill"), skill)
	var pilots: Dictionary = skill_lines.get("pilots", {})
	_t.eq("%s has one skill pilot" % map, pilots.size(), 1)
	var pilot: String = pilots.keys()[0]
	for point in pilots[pilot]["waypoints"]:
		if point is String:
			_t.check("%s waymark %s resolves" % [map, point], TraversalLine.place_of(park, point) != Vector2.INF)
	var route: Array[Vector2] = TraversalLine.line_of(skill_lines, pilot, park)["route"]
	route.push_front(TraversalLine.place_of(park, ParkSchema.DROP_IN))
	var cables := {}
	for row in park["contraption_rows"]:
		if row["kind"] == "cable":
			cables[row["id"]] = row
	for id in skill_lines.get("cables", []):
		if not _t.check("%s cable %s exists" % [map, id], cables.has(id)):
			continue
		var start := Vector2(float(cables[id]["from"][0]), float(cables[id]["from"][2]))
		var reach := _distance(start, route)
		_t.check("%s skill line reaches %s" % [map, id], reach <= float(cables[id]["radius"]), "%.1f m" % reach)
	var others: Array = []
	for key in lines.get("pilots", {}):
		others.append(TraversalLine.line_of(lines, key, park)["route"])
	others.append(TraversalLine.line_of(lines, TraversalLine.FLOOR, park)["route"])
	for id in skill_lines.get("own_cables", []):
		if not cables.has(id):
			continue
		var start := Vector2(float(cables[id]["from"][0]), float(cables[id]["from"][2]))
		var nearest := INF
		for other in others:
			nearest = minf(nearest, _distance(start, other))
		_t.check("%s %s starts clear of every other line" % [map, id], nearest >= CLEAR_M, "%.1f m" % nearest)


static func _distance(p: Vector2, route: Array) -> float:
	var best := INF
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var ab := b - a
		var t := 0.0 if ab.length_squared() == 0.0 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best
