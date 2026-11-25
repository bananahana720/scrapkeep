extends SceneTree

# W50-MAP-W1-ROBOQUEST: tightened Roboquest flow + RoR2 vista pins on World 1 (park_dam & park_flume),
# read from the committed park JSONs, lines.json, bakes and stage graphs (no scene boot).
#
# Tightened bars over the base ten-point map standard:
#   park_dam:
#     - low height-band (y < 50 m) open-node share >= 0.08 (base floor 0.05; was 0.053)
#     - >= 10 m vertical climb ride translators >= 5 (base floor 4; was 4, 0-margin)
#     - floor-line rhythm >= 4 switches and longest heavy stretch <= 36.0 s (base 3 / 45 s; was 3 / 41.8 s)
#     - landmark open sight >= 0.85, line sight >= 0.85, scrap on lines >= 0.30
#     - existing activity_rows keys intact, off-spine flank routes connected, shortcut destructible present
#   park_flume:
#     - line_quiet_share >= 0.30 (base floor 0.25; was 0.255, 0-margin)
#     - rideable aerial zipline cables (contraption_rows kind=="cable") >= 3 spanning Weir Bobsled,
#       Trestle Span and Headhouse Overlook with every landing >= 2.35 m over baked ground
#       (top-level gate-pack cable_rows stays matched to lock_rows.gd)
#     - >= 10 m vertical climb ride translators >= 5 (base floor 4; was 4, 0-margin)
#     - authored survival_rows arena holds >= 2 inside play_rect (was 1)
#     - authored hard-cover sightline bastions (cover=="hard") and destructibles intact
#
# Planted controls: each tightened bar has a synthetic failing control that must be caught.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Breath := preload("res://tests/park_breath_test.gd")
const Rhythm := preload("res://tests/park_rhythm_test.gd")
const Census := preload("res://tests/park_feature_census_test.gd")
const Sight := preload("res://tests/park_landmark_sight_test.gd")
const ScrapLines := preload("res://tests/park_scrap_lines_test.gd")
const CableEnds := preload("res://tests/park_cable_ends_test.gd")

const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"

const DAM_LOW_BAND_MIN := 0.08
const DAM_CLIMBS_MIN := 5
const DAM_SWITCHES_MIN := 4
const DAM_HEAVY_MAX_S := 36.0
const DAM_ACTIVITIES := ["domes_camp", "rim_cache", "bench_altar", "shelf_relay", "incline_cache"]
const DAM_OFF_SPINE_ROUTES := ["east_flank_loop", "west_basin_dunk"]

const FLUME_QUIET_MIN := 0.30
const FLUME_AERIAL_CABLES_MIN := 3
const FLUME_CLIMBS_MIN := 5
const FLUME_SURVIVAL_MIN := 2
const FLUME_ACTIVITIES := ["siphon_camp", "bend_cache", "trestle_cache", "bench_bounty", "weir_surge", "canal_altar"]
const FLUME_DISTRICTS := ["Weir Bobsled", "Trestle Span", "Headhouse Overlook"]

const SIGHT_MIN := 0.85
const SCRAP_MIN := 0.30

var t := T.new("w50_map_w1_roboquest_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_dam()
	_check_flume()
	_planted_controls()
	quit(t.verdict())


func _load_bundle(map_id: String) -> Dictionary:
	var park_path := "%s/%s.json" % [PARK_DIR, map_id]
	var out_dir := "%s/%s" % [OUT_DIR, map_id]
	var read := ParkSchema.load_park(park_path)
	t.check("%s passes ParkSchema.load_park" % map_id, read["errors"].is_empty(), ParkSchema.describe(read["errors"]))
	var lines_read := ParkSchema.read_file(out_dir + "/lines.json")
	var line_errs: Array = ParkSchema.validate_lines(lines_read["data"], read["data"]) if lines_read["errors"].is_empty() else lines_read["errors"]
	t.check("%s lines.json passes ParkSchema.validate_lines" % map_id, line_errs.is_empty(), ParkSchema.describe(line_errs))
	var bake_stale: Array = ParkBake.freshness(park_path, out_dir)
	t.check("%s bake is fresh" % map_id, bake_stale.is_empty(), str(bake_stale))
	var graph_stale: Array = GraphTool.freshness(park_path, out_dir, out_dir)
	t.check("%s stage graph is fresh" % map_id, graph_stale.is_empty(), str(graph_stale))
	var map := ParkMap.new(park_path)
	var g = ParkGraph.read(out_dir + "/graph.bin")
	var bake: Dictionary = GraphTool.load_bake(out_dir)
	var graph_info = JSON.parse_string(FileAccess.get_file_as_string(out_dir + "/graph.json"))
	var ground: Callable = ParkGround.ground(map_id)
	t.check("%s bundle loads cleanly" % map_id, map.ok and g != null and bake["errors"].is_empty() and graph_info is Dictionary and ground.is_valid())
	return {"map": map, "park": read["data"], "graph": g, "bake": bake, "graph_info": graph_info, "ground": ground}


static func _node_heights(g) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	for n in g.node_count():
		ys.append(g.position(n).y)
	return ys


static func _flags_of(g) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in g.node_count():
		out.append(g.flags(n))
	return out


static func _scrap_share(map_id: String, g) -> float:
	var world := ParkProps.world_for(map_id)
	var map: ParkMap = world["map"]
	var at: Callable = world["ground"]
	var pieces := ScrapField.trail_spots(map.scrap_trail, func(x: float, z: float) -> float: return at.call(x, z, 0.0).y)
	var r := ScrapLines.measure(pieces, ScrapLines.marks(g, _node_heights(g), true))
	return float(r["share"])


static func _aerial_cables(park: Dictionary) -> Array:
	var out := []
	for c in park.get("contraption_rows", []):
		if String(c.get("kind", "")) == "cable":
			out.append(c)
	return out


static func _district_name_at(park: Dictionary, xz: Vector2) -> String:
	for d in park.get("district_rows", []):
		var r: Array = d["rect"]
		var box := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if box.has_point(xz):
			return String(d["name"])
	return ""


static func _districts_touched_by_cables(park: Dictionary, cables: Array) -> Array:
	var seen := {}
	for c in cables:
		for key in ["from", "to"]:
			var pt: Array = c[key]
			var name := _district_name_at(park, Vector2(float(pt[0]), float(pt[2])))
			if name != "":
				seen[name] = true
	var out := seen.keys()
	out.sort()
	return out


static func _dam_bars_ok(census: Dictionary, rhythm_r: Dictionary) -> bool:
	var shares: Array = census["band_shares"]
	return int(census["height_bands_populated"]) >= 3 \
		and float(shares[0]) >= DAM_LOW_BAND_MIN \
		and int(census["ride_climb_rows"]) >= DAM_CLIMBS_MIN \
		and int(rhythm_r["switches"]) >= DAM_SWITCHES_MIN \
		and float(rhythm_r["longest_heavy_s"]) <= DAM_HEAVY_MAX_S


static func _flume_bars_ok(quiet_share: float, census: Dictionary, cables: Array, survival_rows: Array) -> bool:
	return quiet_share >= FLUME_QUIET_MIN \
		and int(census["ride_climb_rows"]) >= FLUME_CLIMBS_MIN \
		and cables.size() >= FLUME_AERIAL_CABLES_MIN \
		and survival_rows.size() >= FLUME_SURVIVAL_MIN


func _check_dam() -> void:
	var b := _load_bundle("park_dam")
	var map: ParkMap = b["map"]
	var park: Dictionary = b["park"]
	var g = b["graph"]
	var bake: Dictionary = b["bake"]
	var graph_info: Dictionary = b["graph_info"]
	var ground: Callable = b["ground"]

	var ys := _node_heights(g)
	var census := Census.measure("park_dam", park, g, ys, g.crossings())
	var low_share := float(census["band_shares"][0])
	t.check("park_dam low height-band open-node share >= %.2f" % DAM_LOW_BAND_MIN,
		low_share >= DAM_LOW_BAND_MIN, "%.4f" % low_share)
	t.check("park_dam height bands populated == 3", int(census["height_bands_populated"]) == 3,
		str(census["band_shares"]))
	t.check("park_dam >=10m vertical climb translators >= %d" % DAM_CLIMBS_MIN,
		int(census["ride_climb_rows"]) >= DAM_CLIMBS_MIN,
		"%d (%s)" % [int(census["ride_climb_rows"]), ",".join(census["ride_climb_names"])])

	var floor_pts := Rhythm.floor_line(map)
	var rhythm_r := Rhythm.rhythm(map.fight_sites(), floor_pts)
	t.check("park_dam floor-line rhythm switches >= %d" % DAM_SWITCHES_MIN,
		int(rhythm_r["switches"]) >= DAM_SWITCHES_MIN, "%d (%s)" % [int(rhythm_r["switches"]), rhythm_r["strip"]])
	t.check("park_dam floor-line longest heavy stretch <= %.1f s" % DAM_HEAVY_MAX_S,
		float(rhythm_r["longest_heavy_s"]) <= DAM_HEAVY_MAX_S, "%.1f s" % float(rhythm_r["longest_heavy_s"]))
	t.check("park_dam combined W50 bar holds", _dam_bars_ok(census, rhythm_r))

	var sight_r := Sight.measure(park, bake["ground"], bake["holes"])
	var line_sight_r := Sight.line_sight(_flags_of(g))
	t.check("park_dam open landmark sight >= %.2f" % SIGHT_MIN, float(sight_r["share"]) >= SIGHT_MIN, "%.4f" % float(sight_r["share"]))
	t.check("park_dam line landmark sight >= %.2f" % SIGHT_MIN, float(line_sight_r["share"]) >= SIGHT_MIN, "%.4f" % float(line_sight_r["share"]))

	var scrap := _scrap_share("park_dam", g)
	t.check("park_dam scrap on skill lines >= %.2f" % SCRAP_MIN, scrap >= SCRAP_MIN, "%.3f" % scrap)

	var act_ids := []
	for a in park["activity_rows"]:
		act_ids.append(String(a["id"]))
	for key in DAM_ACTIVITIES:
		t.check("park_dam preserves activity key %s" % key, act_ids.has(key), str(act_ids))

	for route_id in DAM_OFF_SPINE_ROUTES:
		var breaks = graph_info["routes"].get(route_id, ["missing"])
		t.check("park_dam off-spine route %s connected" % route_id, breaks is Array and breaks.is_empty(), str(breaks))

	var shortcuts := (park.get("destructible_rows", []) as Array).filter(func(r): return bool(r.get("shortcut", false)))
	t.eq("park_dam keeps authored destructible shortcut", shortcuts.size(), 1)

	for c in _aerial_cables(park):
		var end := Vector3(float(c["to"][0]), float(c["to"][1]), float(c["to"][2]))
		t.check("park_dam cable %s clears ground >= %.2f m" % [c["id"], CableEnds.MIN_OVER_M],
			CableEnds.end_clear(end, ground), "%.2f m" % (end.y - float(ground.call(end.x, end.z))))

	print("W50_DAM low_band=%.4f climbs=%d switches=%d heavy_s=%.1f sight=%.4f scrap=%.3f" % [
		low_share, int(census["ride_climb_rows"]), int(rhythm_r["switches"]),
		float(rhythm_r["longest_heavy_s"]), float(sight_r["share"]), scrap])


func _check_flume() -> void:
	var b := _load_bundle("park_flume")
	var map: ParkMap = b["map"]
	var park: Dictionary = b["park"]
	var g = b["graph"]
	var bake: Dictionary = b["bake"]
	var ground: Callable = b["ground"]

	var quiet := Breath.quiet_share(map.fight_sites(), Breath.line_points(g))
	t.check("park_flume line_quiet_share >= %.2f" % FLUME_QUIET_MIN, quiet >= FLUME_QUIET_MIN, "%.4f" % quiet)

	var cables := _aerial_cables(park)
	t.check("park_flume rideable aerial zipline cables >= %d" % FLUME_AERIAL_CABLES_MIN,
		cables.size() >= FLUME_AERIAL_CABLES_MIN, "%d" % cables.size())
	for c in cables:
		var end := Vector3(float(c["to"][0]), float(c["to"][1]), float(c["to"][2]))
		t.check("park_flume cable %s clears ground >= %.2f m" % [c["id"], CableEnds.MIN_OVER_M],
			CableEnds.end_clear(end, ground), "%.2f m" % (end.y - float(ground.call(end.x, end.z))))

	var touched := _districts_touched_by_cables(park, cables)
	for district in FLUME_DISTRICTS:
		t.check("park_flume aerial cables connect district %s" % district, touched.has(district), str(touched))

	var gate_packs := int(LockRows.row("park_flume")["gate"]["packs"])
	t.eq("park_flume top-level cable_rows stays matched to gate packs", (park.get("cable_rows", []) as Array).size(), gate_packs)

	var ys := _node_heights(g)
	var census := Census.measure("park_flume", park, g, ys, g.crossings())
	t.check("park_flume >=10m vertical climb translators >= %d" % FLUME_CLIMBS_MIN,
		int(census["ride_climb_rows"]) >= FLUME_CLIMBS_MIN,
		"%d (%s)" % [int(census["ride_climb_rows"]), ",".join(census["ride_climb_names"])])

	var survival_rows: Array = park.get("survival_rows", [])
	t.check("park_flume survival_rows >= %d" % FLUME_SURVIVAL_MIN,
		survival_rows.size() >= FLUME_SURVIVAL_MIN, "%d" % survival_rows.size())
	var pr: Array = park["play_rect"]
	var play_box := Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3]))
	for s in survival_rows:
		var pt := Vector2(float(s["at"][0]), float(s["at"][1]))
		t.check("park_flume survival row %s inside play_rect" % s["id"], play_box.has_point(pt), str(pt))

	var hard_tagged := (park["park_rows"] as Array).filter(func(r): return String(r.get("cover", "")) == "hard")
	t.check("park_flume carries explicit hard-cover sightline bastions", hard_tagged.size() >= 2, "%d" % hard_tagged.size())

	var act_ids := []
	for a in park["activity_rows"]:
		act_ids.append(String(a["id"]))
	for key in FLUME_ACTIVITIES:
		t.check("park_flume preserves activity key %s" % key, act_ids.has(key), str(act_ids))

	var sight_r := Sight.measure(park, bake["ground"], bake["holes"])
	var line_sight_r := Sight.line_sight(_flags_of(g))
	t.check("park_flume open landmark sight >= %.2f" % SIGHT_MIN, float(sight_r["share"]) >= SIGHT_MIN, "%.4f" % float(sight_r["share"]))
	t.check("park_flume line landmark sight >= %.2f" % SIGHT_MIN, float(line_sight_r["share"]) >= SIGHT_MIN, "%.4f" % float(line_sight_r["share"]))

	var scrap := _scrap_share("park_flume", g)
	t.check("park_flume scrap on skill lines >= %.2f" % SCRAP_MIN, scrap >= SCRAP_MIN, "%.3f" % scrap)
	t.check("park_flume combined W50 bar holds", _flume_bars_ok(quiet, census, cables, survival_rows))

	print("W50_FLUME quiet=%.4f aerial_cables=%d climbs=%d survival=%d hard_cover=%d sight=%.4f scrap=%.3f" % [
		quiet, cables.size(), int(census["ride_climb_rows"]), survival_rows.size(),
		hard_tagged.size(), float(sight_r["share"]), scrap])


func _planted_controls() -> void:
	# Plant 1: dam low-band share at old 5.3% (< 8%) fails tightened dam verticality predicate.
	var low_census := {"height_bands_populated": 3, "band_shares": [0.053, 0.605, 0.342], "ride_climb_rows": 6}
	var good_rhythm := {"switches": 5, "longest_heavy_s": 19.6}
	t.check("planted: dam 5.3% low band fails tightened >=8% predicate", not _dam_bars_ok(low_census, good_rhythm))

	# Plant 2: dam 0-margin 4 climb rows fails tightened >=5 predicate.
	var four_climb_census := {"height_bands_populated": 3, "band_shares": [0.096, 0.562, 0.342], "ride_climb_rows": 4}
	t.check("planted: dam 4 climb rows fails tightened >=5 predicate", not _dam_bars_ok(four_climb_census, good_rhythm))

	# Plant 3: old dam rhythm (3 switches, 41.8 s heavy) fails tightened >=4 switches / <=36 s predicate.
	var good_dam_census := {"height_bands_populated": 3, "band_shares": [0.096, 0.562, 0.342], "ride_climb_rows": 6}
	var old_rhythm := {"switches": 3, "longest_heavy_s": 41.8}
	t.check("planted: old dam rhythm (3 switches / 41.8 s) fails tightened predicate", not _dam_bars_ok(good_dam_census, old_rhythm))

	# Plant 4: old flume line_quiet_share (0.255 < 0.30) fails tightened breather predicate.
	var good_flume_census := {"ride_climb_rows": 6}
	var three_cables := [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	var two_surv := [{"id": "s1"}, {"id": "s2"}]
	t.check("planted: flume 0.255 quiet share fails tightened >=0.30 predicate",
		not _flume_bars_ok(0.255, good_flume_census, three_cables, two_surv))

	# Plant 5: flume with only 1 cable fails >=3 aerial cable predicate, and low cable landing fails clearance.
	t.check("planted: flume 1 aerial cable fails >=3 predicate",
		not _flume_bars_ok(0.35, good_flume_census, [{"id": "only_one"}], two_surv))
	var flat_ground := func(_x: float, _z: float) -> float: return 20.0
	t.check("planted: cable landing 1.0 m over ground fails CableEnds.end_clear",
		not CableEnds.end_clear(Vector3(0.0, 21.0, 0.0), flat_ground))

	# Plant 6: flume with only 1 survival row fails >=2 survival arena predicate.
	t.check("planted: flume 1 survival_rows entry fails >=2 predicate",
		not _flume_bars_ok(0.35, good_flume_census, three_cables, [{"id": "fields_muster"}]))

	# Plant 7: unregistered recipe in a park copy fails ParkSchema.validate.
	var bad_park: Dictionary = ParkSchema.read_file("%s/park_dam.json" % PARK_DIR)["data"].duplicate(true)
	bad_park["park_rows"][0]["recipe"] = "unregistered_w50_placeholder"
	t.check("planted: unregistered recipe fails ParkSchema.validate", not ParkSchema.validate(bad_park).is_empty())
