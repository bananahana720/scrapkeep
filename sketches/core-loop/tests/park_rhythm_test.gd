extends SceneTree

# Owner map point 3 (10 Nov 2026; map-audit section G): a stage's fights come in a rhythm, heavy then quiet then heavy,
# never one long press. Per world 1 park, the floor line (assets/park/<map>/lines.json "floor", drop-in to landmark) is
# walked every STEP_M and each step is heavy when it stands within HEAVY_M flat of a fight site
# (ParkMap.fight_sites(): crew homes, event sites, the Warden's engage ring and the yard lock's ring), else quiet.
# Read at CRUISE_MPS, a quiet strip shorter than MIN_QUIET_S between two heavy runs folds into them; then the strip must
# switch between heavy and quiet at least MIN_SWITCHES times, and its longest heavy run must last at most MAX_HEAVY_S.
# Start values, set before calibration. The director's timer packs are not sites (see park_breath_test.gd).
#
# Output: `MAPCHECK <stage> <measure> <value> pass<op><line> PASS|FAIL|OWED` for rhythm_switches and longest_heavy_s,
# and the strip itself as a `[rhythm]` line (each heavy H or quiet q run with its seconds). OWED lists the
# measures under the line today; the test fails if an OWED entry now meets its line (prune it) and if an unlisted one
# is under it.
#
# Planted: a 1,000 m straight line whose only fights stand in its last 300 m reads one switch and fails; a line that is
# heavy all along fails the longest-run line; two fights 60 m of quiet apart (3 s) read as one heavy run.

const T := preload("res://tests/support/t.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const FightReach := preload("res://tests/support/fight_reach.gd")

const PARK_DIR := "res://src/world/park"
const WORLD1 := ["park_dam", "park_flume"]
const HEAVY_M := 60.0
const STEP_M := 1.0
const CRUISE_MPS := 20.0
const MIN_QUIET_S := 5.0
const MIN_SWITCHES := 3
const MAX_HEAVY_S := 45.0

# {"<stage> <measure>": {"value": measured, "why": "..."}}
const OWED := {}

var t := T.new("park_rhythm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id in WORLD1:
		_stage(map_id)
	_planted()
	quit(t.verdict())


# The floor line's points, or [] when the file has none or a waypoint names no place.
static func floor_line(map) -> PackedVector2Array:
	var path := ParkMap.LINES_PATH % map.title
	var out := PackedVector2Array()
	if not FileAccess.file_exists(path):
		return out
	for point in ParkSchema.read_file(path)["data"].get("floor", {}).get("waypoints", []):
		var at := ParkMap.place_of(map.park, point) if point is String else Vector2(float(point[0]), float(point[1]))
		if at == Vector2.INF:
			return PackedVector2Array()
		out.append(at)
	return out


# {"switches", "longest_heavy_s", "length_m", "strip", "raw"} for `line` against `sites`; raw is the strip before
# the short quiet strips fold.
static func rhythm(sites: Array, line: PackedVector2Array) -> Dictionary:
	var heavy := []
	for i in range(1, line.size()):
		var leg := line[i] - line[i - 1]
		var steps := maxi(1, ceili(leg.length() / STEP_M))
		for s in steps:
			heavy.append(FightReach.nearest(sites, line[i - 1] + leg * (float(s) / steps)) <= HEAVY_M)
	var raw := _runs(heavy)
	# A quiet strip shorter than MIN_QUIET_S between two heavy runs is no breath: it folds into them. The line's ends stay.
	var k := 0
	while k < heavy.size():
		var j := k
		while j < heavy.size() and heavy[j] == heavy[k]:
			j += 1
		if not heavy[k] and k > 0 and j < heavy.size() and (j - k) * STEP_M / CRUISE_MPS < MIN_QUIET_S:
			for q in range(k, j):
				heavy[q] = true
		k = j
	var switches := 0
	var run := 0
	var longest := 0
	for n in heavy.size():
		if n > 0 and heavy[n] != heavy[n - 1]:
			switches += 1
		run = run + 1 if heavy[n] else 0
		longest = maxi(longest, run)
	return {"switches": switches, "longest_heavy_s": longest * STEP_M / CRUISE_MPS, "length_m": heavy.size() * STEP_M, "strip": _runs(heavy), "raw": raw}


# Each heavy (H) or quiet (q) run with its seconds at cruise, as one line.
static func _runs(heavy: Array) -> String:
	var out := []
	var k := 0
	while k < heavy.size():
		var j := k
		while j < heavy.size() and heavy[j] == heavy[k]:
			j += 1
		out.append("%s%.0f" % ["H" if heavy[k] else "q", (j - k) * STEP_M / CRUISE_MPS])
		k = j
	return " ".join(out)


func _stage(map_id: String) -> void:
	var map := ParkMap.new("%s/%s.json" % [PARK_DIR, map_id])
	if not t.check("%s park loads" % map_id, map.ok, "park_map"):
		return
	var line := floor_line(map)
	if not t.check("%s floor line resolves" % map_id, line.size() >= 2, "%d points" % line.size()):
		return
	var r := rhythm(map.fight_sites(), line)
	print("[rhythm] %s: floor line %.0f m, %.0f s at %.0f m/s; strip %s (raw %s)" % [map_id, r["length_m"], r["length_m"] / CRUISE_MPS, CRUISE_MPS, r["strip"], r["raw"]])
	_report(map_id, "rhythm_switches", r["switches"], r["switches"] >= MIN_SWITCHES, ">=%d" % MIN_SWITCHES)
	_report(map_id, "longest_heavy_s", r["longest_heavy_s"], r["longest_heavy_s"] <= MAX_HEAVY_S, "<=%.0f" % MAX_HEAVY_S)


func _report(stage: String, measure: String, value: float, meets: bool, line: String) -> void:
	var key := "%s %s" % [stage, measure]
	var owed := OWED.has(key)
	print("MAPCHECK %s %s %.1f pass%s %s" % [stage, measure, value, line, "PASS" if meets else ("OWED" if owed else "FAIL")])
	if owed:
		t.check("%s OWED still under its line (prune the entry when it meets it)" % key, not meets, "%.1f vs %s" % [value, line])
	else:
		t.check("%s %s" % [key, line], meets, "%.1f" % value)


func _planted() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(0, 1000)])
	var late := [{"id": "planted", "kind": "home", "at": Vector2(0, 850), "half": Vector2(10.0, 90.0), "yaw_deg": 0.0}]
	var r := rhythm(late, line)
	print("PLANTED fights_in_last_300m rhythm_switches %d pass>=%d %s" % [r["switches"], MIN_SWITCHES, "PASS" if r["switches"] >= MIN_SWITCHES else "FAIL"])
	t.check("planted: every fight in the last 300 m gives one switch", r["switches"] == 1, "%d" % r["switches"])
	var all := [{"id": "planted", "kind": "yard", "at": Vector2(0, 500), "ring": Vector2(0.0, 600.0)}]
	var h := rhythm(all, line)
	print("PLANTED heavy_all_along longest_heavy_s %.1f pass<=%.0f %s" % [h["longest_heavy_s"], MAX_HEAVY_S, "PASS" if h["longest_heavy_s"] <= MAX_HEAVY_S else "FAIL"])
	t.check("planted: a line heavy all along fails the longest-run line", h["longest_heavy_s"] > MAX_HEAVY_S, "%.1f s" % h["longest_heavy_s"])
	var blip := [{"id": "a", "kind": "home", "at": Vector2(0, 200), "half": Vector2(10.0, 100.0), "yaw_deg": 0.0},
		{"id": "b", "kind": "home", "at": Vector2(0, 680), "half": Vector2(10.0, 200.0), "yaw_deg": 0.0}]
	var b := rhythm(blip, line)
	print("PLANTED three_second_gap strip %s (raw %s)" % [b["strip"], b["raw"]])
	t.check("planted: a 3 s quiet gap folds into the heavy run round it", b["raw"].count("H") == 2 and b["strip"].count("H") == 1, "%s from %s" % [b["strip"], b["raw"]])
	t.near("control: the planted line reads 1,000 m", r["length_m"], 1000.0)
