extends SceneTree

# Owner map point 2 (10 Nov 2026; map-audit section G): a stage leaves room to breathe between fights. Per world 1
# park, the share of the baked graph's LINE nodes (the riding lines, every pilot's) that stand more than QUIET_M flat
# from every fight site (ParkMap.fight_sites(): crew homes, event sites, the Warden's engage ring and the yard lock's
# ring) must be at least QUIET_SHARE_MIN. The line is a start value, set before calibration.
#
# Blind spot: the director's timer packs spawn 60-90 m ahead of the ball anywhere off the pilot corridors, so no line
# node is quiet from them. This check reads only the authored sites; breather zones (src/world/breather_rows.gd, where
# the director places no pack of its own, map-audit unit 7) cover the timer packs and are checked in
# director_breather_test.gd.
#
# Output: `MAPCHECK <stage> line_quiet_share <value> pass>=<line> PASS|FAIL|OWED`. OWED lists the stages under the line
# today; the test fails if an OWED stage now meets it (prune the entry) and if an unlisted stage is under it.
#
# Planted: a fight site on every line node reads 0 and fails; a site-free copy reads 1 and passes.

const T := preload("res://tests/support/t.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const FightReach := preload("res://tests/support/fight_reach.gd")

const OUT_DIR := "res://assets/park"
const PARK_DIR := "res://src/world/park"
const WORLD1 := ["park_dam", "park_flume"]
const QUIET_M := 60.0
const QUIET_SHARE_MIN := 0.25

# {"<stage>": {"value": measured share, "why": "..."}}
const OWED := {}

var t := T.new("park_breath_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id in WORLD1:
		_stage(map_id)
	quit(t.verdict())


# The share of `points` more than QUIET_M from every site.
static func quiet_share(sites: Array, points: Array) -> float:
	if points.is_empty():
		return 0.0
	var quiet := 0
	for p in points:
		if FightReach.nearest(sites, p) > QUIET_M:
			quiet += 1
	return float(quiet) / points.size()


static func line_points(g) -> Array:
	var out := []
	for n in g.node_count():
		if g.flags(n) & ParkGraph.LINE:
			var p: Vector3 = g.position(n)
			out.append(Vector2(p.x, p.z))
	return out


func _stage(map_id: String) -> void:
	var map := ParkMap.new("%s/%s.json" % [PARK_DIR, map_id])
	var g = ParkGraph.read("%s/%s/graph.bin" % [OUT_DIR, map_id])
	if not t.check("%s inputs load" % map_id, map.ok and g != null, "map, graph"):
		return
	var sites := map.fight_sites()
	var points := line_points(g)
	if not t.check("%s has fight sites and line nodes" % map_id, sites.size() > 0 and points.size() > 0, "%d sites, %d line nodes" % [sites.size(), points.size()]):
		return
	# A lightning row is its strike disc, not the landform it sits on, and a fighting activity (a camp, an altar, a
	# relay) is a fight site of its own (park_map.gd fight_sites).
	var by_id := {}
	for s in sites:
		by_id[String(s["id"])] = s
	for row in map.park["event_rows"]:
		if row["kind"] == "lightning":
			var bolt: Dictionary = by_id.get(String(row["id"]), {})
			t.check("%s: lightning %s is a fight site the size of its strike" % [map_id, row["id"]],
				bolt.get("ring", Vector2.INF) == Vector2(0.0, float(row["effect"]["strike_m"])), "%s" % [bolt])
	for row in map.park["event_rows"]:
		if row["kind"] in ParkMap.NOT_FIGHTS:
			t.check("%s: %s, which never hurts, is not a fight site" % [map_id, row["id"]], not by_id.has(String(row["id"])), "%s" % [by_id.keys()])
	for row in map.park.get("activity_rows", []):
		if not row.get("pack", []).is_empty():
			t.check("%s: activity %s, which fights, is a fight site" % [map_id, row["id"]], by_id.has(String(row["id"])), "%s" % [by_id.keys()])
	var share := quiet_share(sites, points)
	var kinds := {}
	for s in sites:
		kinds[s["kind"]] = int(kinds.get(s["kind"], 0)) + 1
	print("[breath] %s: %d line nodes, sites %s, quiet past %.0f m" % [map_id, points.size(), kinds, QUIET_M])
	var covers := []
	for s in sites:
		var near := points.filter(func(p: Vector2) -> bool: return FightReach.distance(s, p) <= QUIET_M).size()
		if near > 0:
			covers.append("%s %d" % [s["id"], near])
	print("[breath] %s: line nodes within %.0f m of each site: %s" % [map_id, QUIET_M, ", ".join(covers)])
	_report(map_id, "line_quiet_share", share)
	if map_id == WORLD1[0]:
		_planted(points)


func _report(stage: String, measure: String, value: float) -> void:
	var meets := value >= QUIET_SHARE_MIN
	var owed := OWED.has(stage)
	print("MAPCHECK %s %s %.2f pass>=%.2f %s" % [stage, measure, value, QUIET_SHARE_MIN, "PASS" if meets else ("OWED" if owed else "FAIL")])
	if owed:
		t.check("%s OWED %s still under its line (prune the entry when it meets it)" % [stage, measure], not meets, "%.2f vs %.2f" % [value, QUIET_SHARE_MIN])
	else:
		t.check("%s %s >= %.2f" % [stage, measure, QUIET_SHARE_MIN], meets, "%.2f" % value)


func _planted(points: Array) -> void:
	var everywhere := []
	for p in points:
		everywhere.append({"id": "planted", "kind": "home", "at": p, "half": Vector2(2.0, 2.0), "yaw_deg": 0.0})
	var share := quiet_share(everywhere, points)
	print("PLANTED home_on_every_line_node line_quiet_share %.2f pass>=%.2f %s" % [share, QUIET_SHARE_MIN, "PASS" if share >= QUIET_SHARE_MIN else "FAIL"])
	t.check("planted: a home on every line node fails the breathing line", share < QUIET_SHARE_MIN, "%.2f" % share)
	t.near("control: a stage with no fight sites is all quiet", quiet_share([], points), 1.0)
