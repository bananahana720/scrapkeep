extends SceneTree

# Wave 50 (W50-MAP-W3-ROBOQUEST): World 3 (park_islands & park_crown) Roboquest + RoR2 parity verification.
# Validates schema, bake/graph freshness, 3-district partitions, aerial cables (0-pack cable_rows + contraption_rows
# kind=cable end clearance), survival arenas, 12 seated destructibles per map, expanded activity rows (including
# ore_chute_surge's grind-line course), seamless islands -> crown -> mind_sky_deck handover & horizon approach cues,
# landmark sight, verticality relief & ride edges, and planted failing controls proving every guard can fail.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const SurgeCourse := preload("res://src/world/surge_course.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")
const CableEndsTest := preload("res://tests/park_cable_ends_test.gd")
const HandoverTest := preload("res://tests/handover_rows_test.gd")
const SightTest := preload("res://tests/park_landmark_sight_test.gd")

const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"
const SURVIVAL_FORMS := ["yard", "muster", "flood"]

const W3_SPECS := {
	"park_islands": {
		"districts": ["acoma_mesas", "shiprock_fins", "gypsum_net"],
		"new_cables": ["fin_thermal_tram", "mooring_anvil_tram", "lens_dunk_cable", "west_wing_signal_cable"],
		"min_cables": 14,
		"survival_ids": ["west_shelf_yard", "east_net_muster"],
		"destructibles": 12,
		"activities": 6,
		"far_to": "park_crown",
		"min_relief_m": 200.0,
		"min_ride_edges": 15,
	},
	"park_crown": {
		"districts": ["bajada_flats", "hoodoo_lightning", "spire_forecourt"],
		"new_cables": ["bajada_storm_wire", "hoodoo_thermal_wire", "needle_thermal_wire", "gauntlet_dunk_wire"],
		"min_cables": 11,
		"survival_ids": ["bajada_storm_yard", "east_wash_muster"],
		"destructibles": 12,
		"activities": 5,
		"far_to": "mind_sky_deck",
		"min_relief_m": 200.0,
		"min_ride_edges": 15,
	},
}

const SEAT_MAX_M := 0.15
const PIECE_GAP_MIN_M := 10.0
const SURVIVAL_GAP_MIN_M := 100.0
const SURVIVAL_BEACON_MIN_M := 120.0
const DESTRUCT_SURVIVAL_MIN_M := 20.0
const HANDOVER_HEADING_MAX_DEG := 30.0
const HANDOVER_RAIL_TURN_MAX_DEG := 45.0
const HANDOVER_SPEED_MIN := 0.85
const HANDOVER_AHEAD_MAX_DEG := 45.0
const SIGHT_MIN := 0.85
const BAND_SHARE_MIN := 0.04

var t := T.new("w50_map_w3_roboquest_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loaded := {}
	for map_id in W3_SPECS:
		loaded[map_id] = _check_park(map_id, W3_SPECS[map_id])
	_check_handover(loaded)
	_planted(loaded)
	quit(t.verdict())


func _check_park(map_id: String, spec: Dictionary) -> Dictionary:
	var park_path := "%s/%s.json" % [PARK_DIR, map_id]
	var out_dir := "%s/%s" % [OUT_DIR, map_id]
	var read: Dictionary = ParkSchema.load_park(park_path)
	t.check("%s passes ParkSchema.load_park" % map_id, read["errors"].is_empty(), ParkSchema.describe(read["errors"]))
	var park: Dictionary = read["data"]
	var pm := ParkMap.new(park_path)
	t.check("%s ParkMap loads cleanly" % map_id, not pm.park.is_empty(), map_id)

	var bake_stale: Array = ParkBake.freshness(park_path, out_dir)
	var graph_stale: Array = GraphTool.freshness(park_path, out_dir, out_dir)
	t.eq("%s bake is fresh" % map_id, bake_stale, [])
	t.eq("%s graph is fresh" % map_id, graph_stale, [])

	var bake: Dictionary = GraphTool.load_bake(out_dir)
	t.check("%s bake binary loads" % map_id, bake["errors"].is_empty(), str(bake["errors"]))
	var ground: PackedFloat32Array = bake["ground"]
	var holes: PackedByteArray = bake["holes"]

	var g = ParkGraph.read("%s/graph.bin" % out_dir)
	t.check("%s graph.bin loads" % map_id, g != null, map_id)
	var gjson: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/graph.json" % out_dir))
	t.check("%s graph.json parses" % map_id, gjson is Dictionary and not gjson.is_empty(), map_id)
	t.eq("%s graph has zero breaches" % map_id, gjson.get("breaches", ["missing"]), [])
	t.eq("%s graph has zero line_errors" % map_id, gjson.get("line_errors", ["missing"]), [])
	t.check("%s beacon_ok and spawn.ok pass" % map_id, bool(gjson.get("beacon_ok", false)) and bool(gjson.get("spawn", {}).get("ok", false)), str(gjson.get("spawn", {})))

	_check_districts(map_id, park, spec["districts"])
	_check_cables(map_id, park, ground, spec)
	_check_survival(map_id, park, holes, spec["survival_ids"])
	_check_destructibles(map_id, park, ground, spec["destructibles"])
	_check_activities(map_id, park, gjson, int(spec["activities"]))
	_check_approach(map_id, park, String(spec["far_to"]))
	_check_sight_and_verticality(map_id, park, ground, holes, g, gjson, spec)

	return {"park": park, "map": pm, "ground": ground, "holes": holes, "graph": g, "gjson": gjson}


static func _rect_of(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func _district_errors(park: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var rows: Array = park.get("district_rows", [])
	if rows.size() != 3:
		errs.append("expected 3 districts, got %d" % rows.size())
		return errs
	var play := _rect_of(park["play_rect"])
	var rects: Array[Rect2] = []
	var ids := {}
	var area_sum := 0.0
	for row in rows:
		var id := String(row.get("id", ""))
		if id.is_empty() or ids.has(id):
			errs.append("duplicate or empty district id: %s" % id)
		ids[id] = true
		if String(row.get("name", "")).strip_edges().is_empty():
			errs.append("%s missing name" % id)
		if String(row.get("grade", "")).strip_edges().is_empty():
			errs.append("%s missing grade" % id)
		var r := _rect_of(row["rect"])
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			errs.append("%s non-positive rect" % id)
		if r.position.x < play.position.x - 0.01 or r.position.y < play.position.y - 0.01 \
				or r.end.x > play.end.x + 0.01 or r.end.y > play.end.y + 0.01:
			errs.append("%s escapes play_rect" % id)
		for prev in rects:
			var inter := prev.intersection(r)
			if inter.size.x > 0.01 and inter.size.y > 0.01:
				errs.append("%s overlaps previous district" % id)
		rects.append(r)
		area_sum += r.get_area()
	if absf(area_sum - play.get_area()) > 1.0:
		errs.append("district area sum %.1f != play_rect area %.1f" % [area_sum, play.get_area()])
	var spawn := Vector2(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))
	var beacon := Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))
	if not rects[0].has_point(spawn):
		errs.append("spawn %s not in opening district" % str(spawn))
	if not rects[2].has_point(beacon):
		errs.append("beacon %s not in closing district" % str(beacon))
	return errs


func _check_districts(map_id: String, park: Dictionary, expected_ids: Array) -> void:
	var errs := _district_errors(park)
	t.eq("%s district_rows form a valid 3-district partition" % map_id, errs, [])
	var got_ids: Array = []
	for row in park.get("district_rows", []):
		got_ids.append(String(row["id"]))
	t.eq("%s district ids match W3 design" % map_id, got_ids, expected_ids)
	print("W3_DISTRICTS %s %s" % [map_id, str(got_ids)])


func _check_cables(map_id: String, park: Dictionary, _ground: PackedFloat32Array, spec: Dictionary) -> void:
	var lock_cables: Array = park.get("cable_rows", [])
	t.eq("%s top-level cable_rows stays [] on 0-pack W3 gate" % map_id, lock_cables.size(), 0)
	var ground_fn: Callable = ParkGround.ground(map_id)
	t.check("%s ParkGround callable valid" % map_id, ground_fn.is_valid(), map_id)
	var aerial: Array = []
	var seen := {}
	var worst_over := 9999.0
	for row in park.get("contraption_rows", []):
		if String(row.get("kind", "")) != "cable":
			continue
		aerial.append(row)
		var cid := String(row["id"])
		seen[cid] = true
		var to_arr: Array = row["to"]
		var end := Vector3(float(to_arr[0]), float(to_arr[1]), float(to_arr[2]))
		var over: float = end.y - float(ground_fn.call(end.x, end.z))
		var ok: bool = CableEndsTest.end_clear(end, ground_fn)
		worst_over = minf(worst_over, over)
		t.check("%s cable %s clears ground (%.2f m >= %.2f m)" % [map_id, cid, over, CableEndsTest.MIN_OVER_M], ok, "%.2f m" % over)
	t.check("%s has >= %d aerial cables" % [map_id, int(spec["min_cables"])], aerial.size() >= int(spec["min_cables"]), "%d" % aerial.size())
	for req_id in spec["new_cables"]:
		t.check("%s includes new W50 cable %s" % [map_id, req_id], seen.has(req_id), str(req_id))
	print("W3_CABLES %s count=%d min_over_m=%.2f" % [map_id, aerial.size(), worst_over])


func _check_survival(map_id: String, park: Dictionary, holes: PackedByteArray, expected_ids: Array) -> void:
	var rows: Array = park.get("survival_rows", [])
	t.eq("%s has 2 survival arenas" % map_id, rows.size(), 2)
	var play := _rect_of(park["play_rect"])
	var beacon := Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))
	var pts: Array[Vector2] = []
	var got_ids: Array = []
	for row in rows:
		var sid := String(row["id"])
		got_ids.append(sid)
		var form := String(row["form"])
		t.check("%s survival %s has valid form" % [map_id, sid], form in SURVIVAL_FORMS, form)
		var p := Vector2(float(row["at"][0]), float(row["at"][1]))
		t.check("%s survival %s inside play_rect" % [map_id, sid], play.has_point(p), str(p))
		var b_dist := p.distance_to(beacon)
		t.check("%s survival %s clears warden beacon (%.1f m >= %.1f m)" % [map_id, sid, b_dist, SURVIVAL_BEACON_MIN_M], b_dist >= SURVIVAL_BEACON_MIN_M, "%.1f m" % b_dist)
		var ci := clampi(floori((p.x + 800.0) / 2.0), 0, 799)
		var cj := clampi(floori((p.y + 800.0) / 2.0), 0, 799)
		t.eq("%s survival %s stands on non-hole ground" % [map_id, sid], int(holes[cj * 800 + ci]), 0)
		pts.append(p)
	t.eq("%s survival ids match" % map_id, got_ids, expected_ids)
	if pts.size() == 2:
		var gap := pts[0].distance_to(pts[1])
		t.check("%s survival arenas well separated (%.1f m >= %.1f m)" % [map_id, gap, SURVIVAL_GAP_MIN_M], gap >= SURVIVAL_GAP_MIN_M, "%.1f m" % gap)


static func _seat_error_m(ground: PackedFloat32Array, row: Dictionary) -> float:
	var at: Array = row["at"]
	var gy: float = SightTest.height(ground, float(at[0]), float(at[2]))
	var want_y: float = gy + float(row["size"][1]) * 0.5
	return absf(float(at[1]) - want_y)


func _check_destructibles(map_id: String, park: Dictionary, ground: PackedFloat32Array, expected_count: int) -> void:
	var rows: Array = park.get("destructible_rows", [])
	t.eq("%s has %d destructible rows" % [map_id, expected_count], rows.size(), expected_count)
	var play := _rect_of(park["play_rect"])
	var districts: Array[Rect2] = []
	for d in park.get("district_rows", []):
		districts.append(_rect_of(d["rect"]))
	var per_district := [0, 0, 0]
	var tiers := {}
	var taken := {}
	for c in park.get("contraption_rows", []):
		taken[String(c.get("id", ""))] = true
	var survival_pts: Array[Vector2] = []
	for s in park.get("survival_rows", []):
		survival_pts.append(Vector2(float(s["at"][0]), float(s["at"][1])))

	var worst_seat := 0.0
	var min_gap := 9999.0
	var centres: Array[Vector2] = []
	var radii: Array[float] = []
	var refused: Array[String] = []
	for row in rows:
		var did := String(row.get("id", ""))
		var why: String = Destructibles.validate_row(row, taken)
		if why != "":
			refused.append("%s: %s" % [did, why])
		taken[did] = true
		var p := Vector2(float(row["at"][0]), float(row["at"][2]))
		var r := Vector2(float(row["size"][0]), float(row["size"][2])).length() * 0.5
		t.check("%s destructible %s inside play_rect" % [map_id, did], play.has_point(p), str(p))
		var seat := _seat_error_m(ground, row)
		worst_seat = maxf(worst_seat, seat)
		t.check("%s destructible %s seated on ground (%.3f m <= %.2f m)" % [map_id, did, seat, SEAT_MAX_M], seat <= SEAT_MAX_M, "%.3f m" % seat)
		for sp in survival_pts:
			var sd := p.distance_to(sp) - r
			t.check("%s destructible %s clears survival arena (%.1f m >= %.1f m)" % [map_id, did, sd, DESTRUCT_SURVIVAL_MIN_M], sd >= DESTRUCT_SURVIVAL_MIN_M, "%.1f m" % sd)
		for i in centres.size():
			var gap := p.distance_to(centres[i]) - r - radii[i]
			min_gap = minf(min_gap, gap)
		centres.append(p)
		radii.append(r)
		tiers[int(row["tier"])] = true
		for di in districts.size():
			if districts[di].has_point(p):
				per_district[di] += 1
				break
	t.eq("%s all destructibles validate cleanly (0 refusals)" % map_id, refused, [])
	t.check("%s destructible gap >= %.1f m" % [map_id, PIECE_GAP_MIN_M], min_gap >= PIECE_GAP_MIN_M, "%.1f m" % min_gap)
	for di in 3:
		t.check("%s district %d has destructibles" % [map_id, di], per_district[di] > 0, str(per_district))
	for tier in [1, 2, 3, 4]:
		t.check("%s destructibles include tier %d" % [map_id, tier], tiers.has(tier), str(tiers.keys()))
	print("W3_DESTRUCTIBLES %s count=%d worst_seat=%.3fm min_gap=%.1fm per_district=%s" % [map_id, rows.size(), worst_seat, min_gap, str(per_district)])


func _check_activities(map_id: String, park: Dictionary, gjson: Dictionary, expected_count: int) -> void:
	var rows: Array = park.get("activity_rows", [])
	t.eq("%s activity_rows count" % map_id, rows.size(), expected_count)
	var by_id := {}
	for p in gjson.get("pockets", []):
		by_id[String(p["id"])] = p
	for row in rows:
		var aid := String(row["id"])
		t.check("%s activity %s present in graph.json" % [map_id, aid], by_id.has(aid), aid)
		if by_id.has(aid):
			t.check("%s activity %s has sight_ok" % [map_id, aid], bool(by_id[aid].get("sight_ok", false)), str(by_id[aid]))
		if String(row["activity"]) == "surge_run":
			var ring := Vector2(float(row["at"][0]), float(row["at"][1]))
			var course_line: Dictionary = SurgeCourse.path(park, String(row.get("route", "")), ring)
			var pts: PackedVector2Array = course_line["points"]
			var total_len := 0.0
			for i in range(1, pts.size()):
				total_len += pts[i - 1].distance_to(pts[i])
			t.check("%s surge_run %s resolves >= 2 grind points (>= 100 m)" % [map_id, aid], pts.size() >= 2 and total_len >= 100.0, "pts=%d len=%.1f m" % [pts.size(), total_len])


static func _approach_far_outside(park: Dictionary) -> bool:
	var approach: Dictionary = park.get("approach", {})
	if not approach.has("far_card"):
		return false
	var fc: Dictionary = approach["far_card"]
	var play := _rect_of(park["play_rect"])
	var at := Vector2(float(fc["at"][0]), float(fc["at"][1]))
	return not play.has_point(at) and at.y > play.end.y


func _check_approach(map_id: String, park: Dictionary, expected_far_to: String) -> void:
	var approach: Dictionary = park.get("approach", {})
	t.eq("%s approach points to mind_sky_deck" % map_id, String(approach.get("to", "")), "mind_sky_deck")
	t.eq("%s approach.far_card.to matches horizon stage" % map_id, String(approach.get("far_card", {}).get("to", "")), expected_far_to)
	t.check("%s approach.far_card sits strictly outside +z of play_rect" % map_id, _approach_far_outside(park), str(approach.get("far_card", {})))


func _check_handover(loaded: Dictionary) -> void:
	var isles_map: ParkMap = loaded["park_islands"]["map"]
	var crown_map: ParkMap = loaded["park_crown"]["map"]
	var isles_h: Dictionary = isles_map.handover()
	var crown_h: Dictionary = crown_map.handover()
	t.check("park_islands and park_crown declare handover rows", not isles_h.is_empty() and not crown_h.is_empty(), "atlas/exit/arrives")
	t.check("both stages declare exit and arrives", isles_h.has("exit") and isles_h.has("arrives") and crown_h.has("exit") and crown_h.has("arrives"), "keys")

	var m: Dictionary = HandoverTest.measure(isles_h["exit"], isles_h["atlas"], crown_h["arrives"], crown_h["atlas"])
	t.check("islands->crown kind pair valid (launch->land)", float(m["kind"]) >= 1.0, str(m))
	t.check("islands->crown heading aligned <= %.0f deg (rail <= %.0f deg)" % [HANDOVER_HEADING_MAX_DEG, HANDOVER_RAIL_TURN_MAX_DEG],
		float(m["heading"]) <= HANDOVER_HEADING_MAX_DEG and float(m["heading"]) <= HANDOVER_RAIL_TURN_MAX_DEG, "%.2f deg" % float(m["heading"]))
	t.check("islands->crown speed ratio >= %.2f" % HANDOVER_SPEED_MIN, float(m["speed"]) >= HANDOVER_SPEED_MIN, "%.2f" % float(m["speed"]))
	t.check("islands->crown ahead angle <= %.0f deg" % HANDOVER_AHEAD_MAX_DEG, float(m["ahead"]) <= HANDOVER_AHEAD_MAX_DEG, "%.2f deg" % float(m["ahead"]))
	t.check("islands exit speed_cruise >= %.2f" % HANDOVER_SPEED_MIN, float(isles_h["exit"]["speed_cruise"]) >= HANDOVER_SPEED_MIN, str(isles_h["exit"]["speed_cruise"]))
	t.check("crown exit to mind_sky_deck: launch, speed >= %.2f, heading 0" % HANDOVER_SPEED_MIN,
		String(crown_h["exit"]["kind"]) == "launch" and float(crown_h["exit"]["speed_cruise"]) >= HANDOVER_SPEED_MIN
		and absf(float(crown_h["exit"]["heading_deg"])) <= HANDOVER_HEADING_MAX_DEG, str(crown_h["exit"]))
	print("W3_HANDOVER islands_to_crown kind=%.0f heading=%.2fdeg speed=%.2f ahead=%.2fdeg" % [float(m["kind"]), float(m["heading"]), float(m["speed"]), float(m["ahead"])])


static func _verticality(ground: PackedFloat32Array, g) -> Dictionary:
	var lo := INF
	var hi := -INF
	for h in ground:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	var relief := hi - lo
	var bands := [0, 0, 0]
	var open_n := 0
	for n in g.node_count():
		if (g.flags(n) & ParkGraph.OPEN) == 0:
			continue
		open_n += 1
		var y: float = SightTest.height(ground, float(g.px[n]), float(g.pz[n]))
		var frac := (y - lo) / relief if relief > 0.01 else 0.0
		var idx := clampi(int(floor(frac * 3.0)), 0, 2)
		bands[idx] += 1
	var shares: Array[float] = []
	for b in bands:
		shares.append(float(b) / float(open_n) if open_n > 0 else 0.0)
	return {"min": lo, "max": hi, "relief": relief, "shares": shares, "open": open_n}


func _check_sight_and_verticality(map_id: String, park: Dictionary, ground: PackedFloat32Array, holes: PackedByteArray, g, gjson: Dictionary, spec: Dictionary) -> void:
	var sight: Dictionary = SightTest.measure(park, ground, holes)
	t.check("%s open-grid landmark sight >= %.2f" % [map_id, SIGHT_MIN], float(sight["share"]) >= SIGHT_MIN, "%.4f" % float(sight["share"]))
	var flags := PackedInt32Array()
	for n in g.node_count():
		flags.append(g.flags(n))
	var line_s: Dictionary = SightTest.line_sight(flags)
	t.check("%s LINE node sight share >= %.2f" % [map_id, SIGHT_MIN], float(line_s["share"]) >= SIGHT_MIN, "%.4f (%d/%d)" % [float(line_s["share"]), int(line_s["ok"]), int(line_s["line"])])

	var v := _verticality(ground, g)
	t.check("%s vertical relief >= %.0f m" % [map_id, float(spec["min_relief_m"])], float(v["relief"]) >= float(spec["min_relief_m"]), "%.2f m (%.2f..%.2f)" % [float(v["relief"]), float(v["min"]), float(v["max"])])
	var shares: Array[float] = v["shares"]
	for bi in 3:
		t.check("%s height band %d populated (>= %.0f%%)" % [map_id, bi, BAND_SHARE_MIN * 100.0], shares[bi] >= BAND_SHARE_MIN, "%.3f" % shares[bi])
	var ride_edges := 0
	for r in g.ride:
		if r > 0:
			ride_edges += 1
	t.check("%s graph ride edges >= %d" % [map_id, int(spec["min_ride_edges"])], ride_edges >= int(spec["min_ride_edges"]), "%d" % ride_edges)
	print("W3_SIGHT_VERT %s open_sight=%.4f line_sight=%.4f relief=%.2fm bands=[%.2f,%.2f,%.2f] ride_edges=%d" % [
		map_id, float(sight["share"]), float(line_s["share"]), float(v["relief"]), shares[0], shares[1], shares[2], ride_edges])


func _planted(loaded: Dictionary) -> void:
	var isles_park: Dictionary = loaded["park_islands"]["park"]
	var isles_ground: PackedFloat32Array = loaded["park_islands"]["ground"]
	var isles_holes: PackedByteArray = loaded["park_islands"]["holes"]
	var isles_g = loaded["park_islands"]["graph"]

	# 1. Overlapping district fails partition check.
	var bad_dist := isles_park.duplicate(true)
	bad_dist["district_rows"][1]["rect"] = bad_dist["district_rows"][0]["rect"]
	t.check("planted: overlapping district_rows fails partition check", not _district_errors(bad_dist).is_empty(), str(_district_errors(bad_dist)))

	# 2. Non-empty top-level cable_rows on 0-pack park_islands fails ParkSchema.
	var bad_cables := isles_park.duplicate(true)
	bad_cables["cable_rows"] = [{"id": "bogus_lock_cable", "pack": 0, "points": [[0, 0], [0, 50]]}]
	var cable_errs: Array = ParkSchema.validate(bad_cables)
	t.check("planted: non-empty cable_rows on 0-pack W3 park fails schema", not cable_errs.is_empty(), ParkSchema.describe(cable_errs))

	# 3. Low cable end (1.0 m above ground) fails CableEndsTest.end_clear.
	var isles_ground_fn: Callable = ParkGround.ground("park_islands")
	var low_y: float = float(isles_ground_fn.call(0.0, 0.0)) + 1.0
	t.check("planted: cable ending 1.0 m above ground fails end_clear", not CableEndsTest.end_clear(Vector3(0.0, low_y, 0.0), isles_ground_fn), "1.0 m < 2.35 m")

	# 4. Bent handovers: each mutation fails its own check and no other.
	var atlas := {"origin": Vector2.ZERO, "heading_deg": 0.0}
	var exit_row := {"kind": "launch", "at": Vector2.ZERO, "heading_deg": 0.0, "speed_cruise": 1.0}
	var clean := {"kind": "land", "at": Vector2(0.0, 120.0), "heading_deg": 0.0, "speed_cruise": 1.0}
	var bent := {
		"kind": {"kind": "slide"},
		"heading": {"heading_deg": 90.0},
		"speed": {"speed_cruise": 0.5},
		"ahead": {"at": Vector2(0.0, -120.0)},
	}
	for k in bent:
		var row := clean.duplicate()
		row.merge(bent[k], true)
		var m: Dictionary = HandoverTest.measure(exit_row, atlas, row, atlas)
		var failed: Array = []
		if float(m["kind"]) < 1.0:
			failed.append("kind")
		if float(m["heading"]) > HANDOVER_RAIL_TURN_MAX_DEG:
			failed.append("heading")
		if float(m["speed"]) < HANDOVER_SPEED_MIN:
			failed.append("speed")
		if float(m["ahead"]) > HANDOVER_AHEAD_MAX_DEG:
			failed.append("ahead")
		t.eq("planted: bent handover (%s) fails only its own check" % k, failed, [k])

	# 5. far_card inside play_rect fails outside check.
	var bad_far := isles_park.duplicate(true)
	bad_far["approach"]["far_card"]["at"] = [0, 200]
	t.check("planted: far_card inside play_rect fails approach check", not _approach_far_outside(bad_far), "at [0, 200]")

	# 6. Floating destructible and bad tier fail their checks.
	var floated: Dictionary = isles_park["destructible_rows"][0].duplicate(true)
	floated["at"][1] = float(floated["at"][1]) + 2.0
	t.check("planted: floating destructible (+2.0 m) fails seat check", _seat_error_m(isles_ground, floated) > SEAT_MAX_M, "%.2f m" % _seat_error_m(isles_ground, floated))
	var bad_tier: Dictionary = isles_park["destructible_rows"][0].duplicate(true)
	bad_tier["id"] = "bad_tier_plant"
	bad_tier["tier"] = 9
	t.check("planted: tier-9 destructible fails Destructibles.validate_row", Destructibles.validate_row(bad_tier, {}) != "", Destructibles.validate_row(bad_tier, {}))

	# 7. 300 m wall across park_islands drops landmark sight below 0.85.
	var walled := isles_ground.duplicate()
	for j in range(580, 620):
		for i in 801:
			walled[j * 801 + i] = 600.0
	var walled_sight: Dictionary = SightTest.measure(isles_park, walled, isles_holes)
	t.check("planted: 600 m barrier wall drops landmark sight below %.2f" % SIGHT_MIN, float(walled_sight["share"]) < SIGHT_MIN, "%.4f" % float(walled_sight["share"]))

	# 8. Flattened ground fails vertical relief and multi-band spread checks.
	var flat := PackedFloat32Array()
	flat.resize(isles_ground.size())
	flat.fill(10.0)
	var flat_v := _verticality(flat, isles_g)
	var flat_shares: Array[float] = flat_v["shares"]
	t.check("planted: flattened ground fails verticality relief >= 200 m", float(flat_v["relief"]) < 200.0, "%.2f m" % float(flat_v["relief"]))
	t.check("planted: flattened ground leaves upper height bands empty", flat_shares[1] < BAND_SHARE_MIN and flat_shares[2] < BAND_SHARE_MIN, str(flat_shares))
