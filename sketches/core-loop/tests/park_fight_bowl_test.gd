extends SceneTree

# Owner map point 8a (10 Nov 2026; map-audit section G): a fight floor sits lower than its rim.
# For each world 1 fight site the test measures the ground at the site's ring radius, in BOWL_DIRS
# evenly spaced directions, minus the ground at the centre. The stage's pass reading is the MEDIAN
# rim-minus-centre, at least BOWL_MIN_M; the minimum is printed beside it.
#
# Fight sites, as the game decides them:
#  - the dam and flume yard locks (lock_rows.row(map_id), stage_locks.gd lock_arms() and _lock()): the
#    first time the ball is grounded on level ground within `within_m` of the beacon, or on any ground
#    within its inner share, the yard shuts, centred `ahead_m` (capped at
#    half the radius) from the ball toward the beacon, `radius_m` round. So the centre follows the
#    ball, not a fixed point. Reading used here: every ground LINE node of the stage graph whose
#    flat distance to the beacon is within SITE_BAND_M of `within_m`, run on toward the beacon over
#    sloped ground to the first level point or the inner share (PF-46), stands in for the ball crossing
#    the circle, and its centre is that node moved ahead_m toward the beacon. The stage reading is the
#    WORST site's median (so one good approach cannot hide a flat one), and the minimum over all sites
#    of the minimum.
#    The ground is the baked ground.bin height (bilinear, as park_landmark_sight_test.gd reads it).
#  - the Slag Bowl (src/boss/arena.gd): surface_height(r) is radial, so the rim is read at BANK_R,
#    where the bank tops out, minus the floor at 0.
#
# Output, one line per stage and measure: `MAPCHECK <stage> <measure> <value> pass>=<line> PASS|FAIL|OWED`.
# OWED lists the stages under the line today with the measured value. The test fails if an OWED stage
# now meets the line (prune it) and fails if a stage not listed is under it.
#
# Planted: the same measuring function given a flat height function reads 0 and fails; the Slag Bowl
# shape with its bank scaled to 0 reads 0 and fails.

const T := preload("res://tests/support/t.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const Arena := preload("res://src/boss/arena.gd")
const Tool := preload("res://tools/park_graph.gd")

const OUT_DIR := "res://assets/park"
const PARK_DIR := "res://src/world/park"
const WORLD1 := ["park_dam", "park_flume"]
const BOWL_MIN_M := 2.0
const BOWL_DIRS := 16
const SITE_BAND_M := 4.0
const HALF_M := 800.0
const BAKE_SIDE := 801

# Stages under their line today. {"<stage>": {"value": measured median m, "why": "..."}}. Pruned by the
# test itself: an entry that now meets the line fails it.
const OWED := {
	"park_flume": {"value": -0.41, "why": "both lock sites (the ball crossing 210 m from the beacon on the two lines) stand on flat forecourt ground; the ring rim reads no higher than the floor, and 10 m lower in places"},
}

var t := T.new("park_fight_bowl_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id in WORLD1:
		_park_yard(map_id)
	_slag_bowl()
	_planted()
	quit(t.verdict())


# {median, min, centre, rims}: the ground at `radius` round (cx, cz) in `dirs` directions minus the
# ground at the centre. `height` is a Callable(x: float, z: float) -> float.
static func rim_minus_centre(height: Callable, cx: float, cz: float, radius: float, dirs: int = BOWL_DIRS) -> Dictionary:
	var centre: float = height.call(cx, cz)
	var diffs: Array = []
	for k in dirs:
		var a := TAU * float(k) / float(dirs)
		diffs.append(float(height.call(cx + cos(a) * radius, cz + sin(a) * radius)) - centre)
	diffs.sort()
	var mid := dirs / 2
	var median: float = diffs[mid] if dirs % 2 == 1 else 0.5 * (float(diffs[mid - 1]) + float(diffs[mid]))
	return {"median": median, "min": diffs[0], "centre": centre, "dirs": dirs}


static func ground_height(ground: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + HALF_M) / 2.0, 0.0, BAKE_SIDE - 1.001)
	var fz := clampf((z + HALF_M) / 2.0, 0.0, BAKE_SIDE - 1.001)
	var i := floori(fx)
	var j := floori(fz)
	var u := fx - i
	var v := fz - j
	var h00 := ground[j * BAKE_SIDE + i]
	var h10 := ground[j * BAKE_SIDE + i + 1]
	var h01 := ground[(j + 1) * BAKE_SIDE + i]
	var h11 := ground[(j + 1) * BAKE_SIDE + i + 1]
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)


# The yard centres the lock can take on this stage, as stage_locks.gd lock_arms() and _lock() decide:
# ground LINE nodes at the lock circle's edge stand in for a ball crossing it. Where the ground there
# is level the yard shuts on the spot; where it is not, the ball runs on toward the beacon until it
# meets level ground or the circle's inner share, any ground (PF-46: the dam's incline crosses the
# edge mid-slope). Each centre is that point moved ahead_m toward the beacon.
static func yard_sites(g, beacon: Vector2, lock: Dictionary, height: Callable) -> Array:
	var within := float(lock["within_m"])
	var inner := within * StageLocks.LOCK_ANY_SLOPE_SHARE
	var radius := float(lock["radius_m"])
	var ahead := minf(float(lock["ahead_m"]), radius * 0.5)
	var level_grade := tan(acos(StageLocks.LOCK_LEVEL_DOT))
	var out := []
	for n in g.node_count():
		if g.flags(n) & ParkGraph.LINE == 0 or g.node_row(n) != "":
			continue
		var p: Vector3 = g.position(n)
		var at := Vector2(p.x, p.z)
		if absf(at.distance_to(beacon) - within) > SITE_BAND_M:
			continue
		var toward := (beacon - at).normalized()
		while at.distance_to(beacon) > inner and grade(height, at.x, at.y) > level_grade:
			at += toward * 2.0
		out.append(at + toward * ahead)
	return out


# The ground's steepest rise per metre at (x, z), over a 2 m step each way.
static func grade(height: Callable, x: float, z: float) -> float:
	var dx: float = (float(height.call(x + 2.0, z)) - float(height.call(x - 2.0, z))) / 4.0
	var dz: float = (float(height.call(x, z + 2.0)) - float(height.call(x, z - 2.0))) / 4.0
	return Vector2(dx, dz).length()


func _park_yard(map_id: String) -> void:
	var lock: Dictionary = LockRows.row(map_id).get("lock", {})
	if not t.check("%s has a yard lock row" % map_id, not lock.is_empty(), "lock_rows.row"):
		return
	var map := ParkMap.new("%s/%s.json" % [PARK_DIR, map_id])
	var g = ParkGraph.read("%s/%s/graph.bin" % [OUT_DIR, map_id])
	var bake: Dictionary = Tool.load_bake("%s/%s" % [OUT_DIR, map_id])
	if not t.check("%s inputs load" % map_id, map.ok and g != null and bake["errors"].is_empty(), "map, graph, bake"):
		return
	var ground: PackedFloat32Array = bake["ground"]
	var height := func(x: float, z: float) -> float: return ground_height(ground, x, z)
	var sites := yard_sites(g, map.beacon, lock, height)
	if not t.check("%s yard sites found on the lines" % map_id, sites.size() > 0, "%d sites at %.0f m from the beacon" % [sites.size(), float(lock["within_m"])]):
		return
	var medians := []
	var low := INF
	for s in sites:
		var r := rim_minus_centre(height, s.x, s.y, float(lock["radius_m"]))
		medians.append(r["median"])
		low = minf(low, r["min"])
	print("[bowl] %s yard: %d sites, ring %.0f m, %d directions; site medians min %.2f max %.2f" % [map_id, sites.size(), float(lock["radius_m"]), BOWL_DIRS, float(medians.min()), float(medians.max())])
	_report(map_id, "yard_rim_median_m", float(medians.min()), low)


func _slag_bowl() -> void:
	var height := func(x: float, z: float) -> float: return Arena.surface_height(Vector2(x, z).length())
	var r := rim_minus_centre(height, 0.0, 0.0, Arena.BANK_R)
	print("[bowl] slag_bowl: floor %.0f m, bank to %.0f m at radius %.0f m, %d directions" % [Arena.FLOOR_R, Arena.BANK_H, Arena.BANK_R, BOWL_DIRS])
	_report("slag_bowl", "yard_rim_median_m", r["median"], r["min"])


# Prints the MAPCHECK lines and applies the OWED rule.
func _report(stage: String, measure: String, median: float, low: float) -> void:
	var meets := median >= BOWL_MIN_M
	var owed := OWED.has(stage)
	var status := "PASS" if meets else ("OWED" if owed else "FAIL")
	print("MAPCHECK %s %s %.2f pass>=%.1f %s" % [stage, measure, median, BOWL_MIN_M, status])
	print("MAPCHECK %s %s %.2f report INFO" % [stage, measure.replace("median", "min"), low])
	if owed:
		t.check("%s OWED %s still under its line (prune the entry when it meets it)" % [stage, measure], not meets, "%.2f vs %.1f" % [median, BOWL_MIN_M])
	else:
		t.check("%s %s >= %.1f m" % [stage, measure, BOWL_MIN_M], meets, "%.2f" % median)


func _planted() -> void:
	var flat := func(_x: float, _z: float) -> float: return 12.5
	var r := rim_minus_centre(flat, 100.0, -40.0, 26.0)
	print("PLANTED flat_ground yard_rim_median_m %.2f pass>=%.1f %s" % [r["median"], BOWL_MIN_M, "PASS" if r["median"] >= BOWL_MIN_M else "FAIL"])
	t.check("planted: a flat height function fails the bowl assertion", r["median"] < BOWL_MIN_M, "%.2f vs %.1f" % [r["median"], BOWL_MIN_M])
	var no_bank := func(x: float, z: float) -> float: return Arena.surface_height(Vector2(x, z).length()) * 0.0
	var b := rim_minus_centre(no_bank, 0.0, 0.0, Arena.BANK_R)
	print("PLANTED slag_bowl_bank_0 yard_rim_median_m %.2f pass>=%.1f %s" % [b["median"], BOWL_MIN_M, "PASS" if b["median"] >= BOWL_MIN_M else "FAIL"])
	t.check("planted: the Slag Bowl with its bank at 0 fails the bowl assertion", b["median"] < BOWL_MIN_M, "%.2f vs %.1f" % [b["median"], BOWL_MIN_M])
	# Positive control for the sampler itself: a 6 m bowl read from its centre gives 6 m.
	var bowl := func(x: float, z: float) -> float: return 6.0 if Vector2(x, z).length() >= 25.0 else 0.0
	var c := rim_minus_centre(bowl, 0.0, 0.0, 26.0)
	t.near("control: a 6 m deep bowl reads 6 m", c["median"], 6.0)
