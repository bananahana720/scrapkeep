extends SceneTree

const StageDefs := preload("res://src/core/stage_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")

# GP1 (wave 11): the six alpha maps' side sites. Each site is an activity row, a rescue row or
# the relic spot. World three carries as much to do as the Dig: Highdraft and its crown each
# hold at least three activities, Highdraft one rescue, and the Reach a relic spot. Per map
# every site id is unique and no two sites, the Warden's beacon among them, stand within
# APART metres. Every site lies within NEAR metres of its stage's line in
# tools/traversal_lines.json: the pilots' lines on the Reach, the provisional alpha_stages
# line elsewhere. Evidence limit: map data and polylines only, no bot ride or terrain read.

const LINES := "res://tools/traversal_lines.json"
const NEAR := 8.0
const APART := 25.0
const WARDEN := "warden"
const REACH_STAGE := 2
const MIN_ACTIVITIES := {"highdraft": 3, "highdraft_crown": 3}
# Sites placed off their stage's line before GP1, kept until each map's own unit moves them,
# and the Reach relic, which ruling 1 puts behind the valve's secret, off every pilot's line.
# The list must stay exact: a listed site that comes onto its line, or is gone, fails here too.
const OFF_LINE := [
	"spillway/enemy_camp", "spillway/rivet_cage",
	"reach/enemy_camp", "reach/ambush_altar", "reach/hauler_bounty", "reach/relic_spot",
	"dig/enemy_camp", "dig/ambush_altar", "dig/cracked_cache", "dig/kest_cage", "dig/relic_spot",
	"dig_deep/enemy_camp", "dig_deep/ambush_altar", "dig_deep/cracked_cache", "dig_deep/kest_cage", "dig_deep/relic_spot",
	"highdraft/enemy_camp", "highdraft/hauler_bounty", "highdraft/relic_spot",
	"highdraft_crown/enemy_camp", "highdraft_crown/hauler_bounty", "highdraft_crown/relic_spot",
]
# Pairs closer than APART before GP1: the crown's relic stands on the beacon island.
const CLOSE := ["highdraft_crown/relic_spot~warden"]

var _t := preload("res://tests/support/t.gd").new("world_sites_test")


func _initialize() -> void:
	var routes = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	_t.check("the line file parses", routes is Dictionary and routes.get("alpha_stages") is Dictionary, LINES)
	if not routes is Dictionary:
		quit(_t.verdict())
		return
	var seen := []
	var names := []
	for row in StageDefs.DEFS:
		var stage := int(row["stage"])
		var key := String(row["map"])
		seen.append(key)
		var map = Terrain.MAPS[key].new()
		var sites := sites_of(map)
		for site in sites:
			names.append("%s/%s" % [key, site["id"]])
		_check_counts(key, map)
		_check_unique(key, sites)
		_check_apart(key, sites, map.beacon)
		_check_on_line(key, sites, lines_for(routes, stage, key))
	var stale := OFF_LINE.filter(func(name): return not names.has(name))
	_t.check("every listed off-line site still stands", stale.is_empty(), str(stale))
	_t.check("the walk covers the six alpha maps", seen.size() == 6 and seen.has("highdraft_crown") and seen.has("reach"), str(seen))
	quit(_t.verdict())


# [{id, at}] for every activity row, rescue row and the relic spot.
static func sites_of(map) -> Array:
	var out := []
	for row in map.activity_sites:
		out.append({"id": String(row["id"]), "at": row["at"]})
	if "rescue_sites" in map:
		for row in map.rescue_sites:
			out.append({"id": String(row["id"]), "at": row["at"]})
	if "relic_spot" in map:
		out.append({"id": "relic_spot", "at": map.relic_spot})
	return out


# The stage's polylines: every pilot's on the Reach, the one provisional line elsewhere.
static func lines_for(routes: Dictionary, stage: int, key: String) -> Array:
	var raw := []
	if stage == REACH_STAGE:
		for pilot in routes.get("pilots", {}).values():
			raw.append(pilot.get("waypoints", []))
	else:
		var row: Dictionary = routes["alpha_stages"].get(str(stage), {})
		if String(row.get("map", "")) == key and row.get("provisional") == true:
			raw.append(row.get("waypoints", []))
	var lines := []
	for points in raw:
		var line := PackedVector2Array()
		for p in points:
			line.append(Vector2(float(p[0]), float(p[1])))
		if line.size() > 1:
			lines.append(line)
	return lines


static func off_line(at: Vector2, lines: Array) -> float:
	var best := INF
	for line: PackedVector2Array in lines:
		for i in line.size() - 1:
			best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, line[i], line[i + 1])))
	return best


func _check_counts(key: String, map) -> void:
	if MIN_ACTIVITIES.has(key):
		_t.check("%s holds at least %d activities" % [key, MIN_ACTIVITIES[key]], map.activity_sites.size() >= MIN_ACTIVITIES[key],
			str(map.activity_sites.map(func(s): return s["id"])))
	if key == "highdraft":
		_t.check("highdraft holds one rescue", map.rescue_sites.size() == 1, str(map.rescue_sites))
	if key == "reach":
		_t.check("the Reach holds a relic spot", "relic_spot" in map and map.relic_spot is Vector2, "")


func _check_unique(key: String, sites: Array) -> void:
	var ids: Array = sites.map(func(s): return s["id"])
	var dupes := ids.filter(func(id): return ids.count(id) > 1)
	_t.check("%s site ids are unique" % key, dupes.is_empty() and not ids.has(""), str(ids))


func _check_apart(key: String, sites: Array, beacon: Vector2) -> void:
	var all := sites + [{"id": WARDEN, "at": beacon}]
	var close := []
	for i in all.size():
		for j in range(i + 1, all.size()):
			var gap: float = (all[i]["at"] as Vector2).distance_to(all[j]["at"])
			var pair := "%s/%s~%s" % [key, all[i]["id"], all[j]["id"]]
			if (gap < APART) != CLOSE.has(pair):
				close.append("%s %.1f m" % [pair, gap])
	_t.check("%s sites stand %d m apart (listed pairs excepted)" % [key, int(APART)], close.is_empty(), str(close))


func _check_on_line(key: String, sites: Array, lines: Array) -> void:
	_t.check("%s has a line" % key, not lines.is_empty(), "")
	var wrong := []
	for site in sites:
		var name := "%s/%s" % [key, site["id"]]
		var gap := off_line(site["at"], lines)
		if (gap > NEAR) != OFF_LINE.has(name):
			wrong.append("%s %.1f m" % [name, gap])
	_t.check("%s sites lie within %d m of the line (listed sites excepted)" % [key, int(NEAR)], wrong.is_empty(), str(wrong))
