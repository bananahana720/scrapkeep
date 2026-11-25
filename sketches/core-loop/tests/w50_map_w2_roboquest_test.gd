extends SceneTree

# W50-MAP-W2-ROBOQUEST: Roboquest + RoR2 parity verification for World 2 (park_pit & park_sinkhole).
# Validates schema, bake/graph freshness, 3 named districts per map, 0-pack cable_rows + new high-speed
# zipline contraption cables (>= 2.35 m landing clearance), 2 survival arenas with rim escapes per map,
# expanded destructible_rows (pit: 14, sinkhole: 12) clear of scenic timber_rock_strut props and PF-41/43,
# expanded activity_rows (5 each, 0 graph breaches), seamless handover math (pit -> sinkhole -> waking_shaft),
# approach horizon cues, landmark sight, verticality, and planted failing controls.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")

const PARK_DIR := "res://src/world/park"
const BAKED_DIR := "res://assets/park"

const CABLE_CLEAR_M := 2.35
const CABLE_EPS_M := 0.001
const HEADING_MAX_DEG := 30.0
const RAIL_TURN_MAX_DEG := 45.0
const SPEED_MIN := 0.85
const AHEAD_MAX_DEG := 45.0
const STRUT_CLEAR_M := 90.0

# Exact scenic timber_rock_strut.glb positions from dig_scenery.gd::_place_moab_struts.
const MOAB_STRUTS := [
	Vector2(-360.0, -345.0), Vector2(-35.0, -295.0), Vector2(265.0, -205.0), Vector2(355.0, -10.0),
	Vector2(-345.0, 145.0), Vector2(265.0, 240.0), Vector2(-165.0, 315.0), Vector2(135.0, 315.0),
]

const PIT_DISTRICTS := ["Moab Rim Archway", "Copper Bench Amphitheater", "Headframe Collar"]
const SINKHOLE_DISTRICTS := ["Malpais Basalt Tube", "Sunlit Cenote Room", "Deep Caisson Gallery"]
const PIT_NEW_ZIPS := ["moab_canal_arch_zip", "copper_amphitheater_east_zip", "conveyor_to_collar_zip", "hoist_overlook_zip"]
const SINKHOLE_NEW_ZIPS := ["cinder_mouth_zip", "skylight_balcony_zip", "great_room_cenote_zip", "caisson_gallery_zip"]

var t := T.new("w50_map_w2_roboquest_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pit_path := "%s/park_pit.json" % PARK_DIR
	var sink_path := "%s/park_sinkhole.json" % PARK_DIR
	var pit_read := ParkSchema.load_park(pit_path)
	var sink_read := ParkSchema.load_park(sink_path)
	if not t.check("park_pit.json passes ParkSchema with 0 errors", pit_read["errors"].is_empty(), ParkSchema.describe(pit_read["errors"])):
		quit(t.verdict())
		return
	if not t.check("park_sinkhole.json passes ParkSchema with 0 errors", sink_read["errors"].is_empty(), ParkSchema.describe(sink_read["errors"])):
		quit(t.verdict())
		return

	var pit: Dictionary = pit_read["data"]
	var sink: Dictionary = sink_read["data"]
	var pit_map := ParkMap.new(pit_path)
	var sink_map := ParkMap.new(sink_path)
	t.check("ParkMap loads both W2 parks cleanly", pit_map.ok and sink_map.ok, "%s / %s" % [pit_map.errors, sink_map.errors])

	_check_freshness("park_pit", pit_path)
	_check_freshness("park_sinkhole", sink_path)

	_check_districts("park_pit", pit, PIT_DISTRICTS)
	_check_districts("park_sinkhole", sink, SINKHOLE_DISTRICTS)

	_check_cables("park_pit", pit, pit_map, PIT_NEW_ZIPS, 10)
	_check_cables("park_sinkhole", sink, sink_map, SINKHOLE_NEW_ZIPS, 15)

	_check_survival("park_pit", pit, pit_map)
	_check_survival("park_sinkhole", sink, sink_map)

	_check_activities("park_pit", pit, 5)
	_check_activities("park_sinkhole", sink, 5)

	_check_destructibles("park_pit", pit, 14, 4, true)
	_check_destructibles("park_sinkhole", sink, 12, 4, false)

	_check_handovers(pit, sink, pit_map, sink_map)
	_check_sight_and_verticality("park_pit", pit, pit_map)
	_check_sight_and_verticality("park_sinkhole", sink, sink_map)

	_planted_controls(pit, sink)
	quit(t.verdict())


func _check_freshness(map_id: String, park_path: String) -> void:
	var baked := "%s/%s" % [BAKED_DIR, map_id]
	var bake_stale := ParkBake.freshness(park_path, baked)
	var graph_stale := ParkGraphTool.freshness(park_path, baked, baked)
	t.check("%s committed bake is fresh" % map_id, bake_stale.is_empty(), str(bake_stale))
	t.check("%s committed graph is fresh" % map_id, graph_stale.is_empty(), str(graph_stale))


func _check_districts(map_id: String, park: Dictionary, expected_names: Array) -> void:
	var rows: Array = park.get("district_rows", [])
	t.eq("%s has 3 district_rows" % map_id, rows.size(), 3)
	var names := []
	var grades := {}
	var area := 0.0
	for row: Dictionary in rows:
		names.append(String(row["name"]))
		var grade := String(row["grade"])
		t.check("%s district %s has distinct non-empty grade" % [map_id, row["id"]], grade != "" and not grades.has(grade), grade)
		grades[grade] = true
		var r: Array = row["rect"]
		area += float(r[2]) * float(r[3])
	t.eq("%s district names match W2 design" % map_id, names, expected_names)
	var pr: Array = park["play_rect"]
	var play_area := float(pr[2]) * float(pr[3])
	t.near("%s districts cover 100%% of play_rect area" % map_id, area, play_area, 1.0)
	var spawn_at: Array = park["spawn"]["at"]
	var beacon_at: Array = park["landmark"]["beacon"]
	t.check("%s spawn resolves to a district grade" % map_id,
		WorldLook.district_at(park, Vector3(float(spawn_at[0]), 0.0, float(spawn_at[1]))) != "")
	t.check("%s beacon resolves to a district grade" % map_id,
		WorldLook.district_at(park, Vector3(float(beacon_at[0]), 0.0, float(beacon_at[1]))) != "")


func _check_cables(map_id: String, park: Dictionary, map: ParkMap, new_ids: Array, min_total: int) -> void:
	t.check("%s declares 0-pack top-level cable_rows []" % map_id,
		park.has("cable_rows") and park["cable_rows"] is Array and (park["cable_rows"] as Array).is_empty())
	var ground: Callable = ParkGround.ground(map_id)
	var cables := map.contraptions.filter(func(c: Dictionary) -> bool: return c["kind"] == "cable")
	t.check("%s has >= %d rideable zipline cables (got %d)" % [map_id, min_total, cables.size()], cables.size() >= min_total)
	var by_id := {}
	var worst_clear := INF
	for c: Dictionary in cables:
		var cid := String(c["id"])
		by_id[cid] = c
		var to_pt: Vector3 = c["to"]
		var clear := to_pt.y - float(ground.call(to_pt.x, to_pt.z))
		worst_clear = minf(worst_clear, clear)
		t.check("%s cable %s landing clear %.2f m >= %.2f m" % [map_id, cid, clear, CABLE_CLEAR_M],
			_cable_end_clear(to_pt, ground))
	for req_id in new_ids:
		var present := by_id.has(req_id)
		var span := 0.0
		if present:
			span = (by_id[req_id]["from"] as Vector3).distance_to(by_id[req_id]["to"] as Vector3)
		t.check("%s carries new Roboquest zipline %s (span %.1f m >= 35 m)" % [map_id, req_id, span],
			present and span >= 35.0)


func _check_survival(map_id: String, park: Dictionary, map: ParkMap) -> void:
	var rows: Array = park.get("survival_rows", [])
	t.eq("%s has 2 survival_rows" % map_id, rows.size(), 2)
	t.eq("%s ParkMap loads 2 survival_sites" % map_id, map.survival_sites.size(), 2)
	var g = ParkGraph.read("%s/%s/graph.bin" % [BAKED_DIR, map_id])
	var pr: Array = park["play_rect"]
	var rect := Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3]))
	for row: Dictionary in rows:
		var at := Vector2(float(row["at"][0]), float(row["at"][1]))
		t.check("%s survival %s lies inside play_rect" % [map_id, row["id"]], rect.has_point(at), str(at))
		var node: int = g.nearest(at)
		t.check("%s survival %s stands on an OPEN graph node" % [map_id, row["id"]],
			(g.flags(node) & ParkGraph.OPEN) != 0, str(g.flag_names(node)))
		var nearest_escape := _nearest_vertical_escape(park, at)
		t.check("%s survival %s has vertical rim escape within 140 m (%.1f m)" % [map_id, row["id"], nearest_escape],
			nearest_escape <= 140.0)


func _check_activities(map_id: String, park: Dictionary, want_count: int) -> void:
	var acts: Array = park.get("activity_rows", [])
	t.eq("%s has %d activity_rows" % [map_id, want_count], acts.size(), want_count)
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/graph.json" % [BAKED_DIR, map_id]))
	t.eq("%s graph.json has 0 pocket breaches" % map_id, graph.get("breaches", ["missing"]), [])
	var pockets: Array = graph.get("pockets", [])
	t.eq("%s graph.json lists all %d activities + 1 hidden pocket" % [map_id, want_count], pockets.size(), want_count + 1)
	for p: Dictionary in pockets:
		t.check("%s pocket %s has sight_ok and empty clear_ring" % [map_id, p["id"]],
			bool(p.get("sight_ok", false)) and (p.get("clear_ring", ["bad"]) as Array).is_empty(), str(p))


func _check_destructibles(map_id: String, park: Dictionary, want_count: int, min_shortcuts: int, check_struts: bool) -> void:
	var rows: Array = park.get("destructible_rows", [])
	t.eq("%s has %d destructible_rows" % [map_id, want_count], rows.size(), want_count)
	var taken := {}
	var shortcuts := 0
	var worst_strut := INF
	for row: Dictionary in rows:
		var why := Destructibles.validate_row(row, taken)
		t.eq("%s destructible %s passes Destructibles.validate_row" % [map_id, row.get("id", "")], why, "")
		taken[String(row["id"])] = true
		if bool(row.get("shortcut", false)):
			shortcuts += 1
		var p := Vector2(float(row["at"][0]), float(row["at"][2]))
		if check_struts:
			worst_strut = minf(worst_strut, _min_strut_dist(p))
		else:
			# Keep sinkhole destructibles clear of PF-41 junction (-78.9, -2.9) and PF-43 caisson core (0, 350).
			t.check("%s destructible %s clears PF-41 junction" % [map_id, row["id"]],
				p.distance_to(Vector2(-78.9, -2.9)) >= 20.0)
			t.check("%s destructible %s clears PF-43 caisson center" % [map_id, row["id"]],
				p.distance_to(Vector2(0.0, 350.0)) >= 40.0)
	t.check("%s has >= %d shortcut breach walls (got %d)" % [map_id, min_shortcuts, shortcuts], shortcuts >= min_shortcuts)
	if check_struts:
		t.check("%s all destructibles clear scenic timber_rock_strut props by >= %.0f m (min %.1f m)" % [map_id, STRUT_CLEAR_M, worst_strut],
			worst_strut >= STRUT_CLEAR_M)


func _check_handovers(pit: Dictionary, sink: Dictionary, pit_map: ParkMap, sink_map: ParkMap) -> void:
	var pit_h := pit_map.handover()
	var sink_h := sink_map.handover()
	t.check("park_pit and park_sinkhole declare full handover rows",
		not pit_h.is_empty() and not sink_h.is_empty())
	t.check("park_pit exit & arrives speed_cruise >= %.2f" % SPEED_MIN,
		float(pit_h["exit"]["speed_cruise"]) >= SPEED_MIN and float(pit_h["arrives"]["speed_cruise"]) >= SPEED_MIN)
	t.check("park_sinkhole exit & arrives speed_cruise >= %.2f" % SPEED_MIN,
		float(sink_h["exit"]["speed_cruise"]) >= SPEED_MIN and float(sink_h["arrives"]["speed_cruise"]) >= SPEED_MIN)

	# Seam 1: park_pit -> park_sinkhole
	var s1 := _measure_handover(pit_h["exit"], pit_h["atlas"], sink_h["arrives"], sink_h["atlas"])
	t.check("pit -> sinkhole kind is a declared pair", s1["kind"] >= 1.0, str(s1))
	t.check("pit -> sinkhole heading <= %.0f deg (got %.1f)" % [HEADING_MAX_DEG, s1["heading"]], s1["heading"] <= HEADING_MAX_DEG)
	t.check("pit -> sinkhole speed ratio >= %.2f (got %.2f)" % [SPEED_MIN, s1["speed"]], s1["speed"] >= SPEED_MIN)
	t.check("pit -> sinkhole ahead angle <= %.0f deg (got %.1f)" % [AHEAD_MAX_DEG, s1["ahead"]], s1["ahead"] <= AHEAD_MAX_DEG)

	# Seam 2: park_sinkhole -> waking_shaft (vertical drop entry ahead of sinkhole gate along exit heading)
	var sink_exit_at: Vector2 = sink_h["exit"]["at"]
	var sink_exit_dir := _yaw_dir(float(sink_h["exit"]["heading_deg"]))
	var waking_arrives := {
		"kind": "drop",
		"at": sink_exit_at + sink_exit_dir * 12.0,
		"heading_deg": float(sink_h["exit"]["heading_deg"]),
		"speed_cruise": 1.0,
		"from": "sinkhole gallery gate",
	}
	var s2 := _measure_handover(sink_h["exit"], sink_h["atlas"], waking_arrives, sink_h["atlas"])
	t.check("sinkhole -> waking_shaft kind is a declared pair", s2["kind"] >= 1.0, str(s2))
	t.check("sinkhole -> waking_shaft heading <= %.0f deg (got %.1f)" % [HEADING_MAX_DEG, s2["heading"]], s2["heading"] <= HEADING_MAX_DEG)
	t.check("sinkhole -> waking_shaft speed ratio >= %.2f (got %.2f)" % [SPEED_MIN, s2["speed"]], s2["speed"] >= SPEED_MIN)
	t.check("sinkhole -> waking_shaft ahead angle <= %.0f deg (got %.1f)" % [AHEAD_MAX_DEG, s2["ahead"]], s2["ahead"] <= AHEAD_MAX_DEG)

	# Approach horizon cues (smoke + far_card strictly outside play_rect)
	for pair in [["park_pit", pit, "park_sinkhole"], ["park_sinkhole", sink, "waking_shaft"]]:
		var id: String = pair[0]
		var data: Dictionary = pair[1]
		var want_card_to: String = pair[2]
		var app: Dictionary = data.get("approach", {})
		t.eq("%s approach.to targets waking_shaft" % id, String(app.get("to", "")), "waking_shaft")
		t.check("%s approach has smoke [x, z]" % id, app.get("smoke") is Array and (app["smoke"] as Array).size() == 2)
		var card: Dictionary = app.get("far_card", {})
		t.eq("%s approach.far_card.to targets %s" % [id, want_card_to], String(card.get("to", "")), want_card_to)


func _check_sight_and_verticality(map_id: String, park: Dictionary, map: ParkMap) -> void:
	var bake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/bake.json" % [BAKED_DIR, map_id]))
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/graph.json" % [BAKED_DIR, map_id]))
	var span := float(bake["height"]["max"]) - float(bake["height"]["min"])
	t.check("%s landmark sight_share >= 0.85" % map_id, float(park["landmark"]["sight_share"]) >= 0.85)
	t.check("%s beacon_ok and spawn qualified" % map_id,
		bool(graph.get("beacon_ok", false)) and bool(graph.get("spawn", {}).get("ok", false)) and bool(graph.get("spawn", {}).get("run", false)))
	t.check("%s terrain vertical span >= 100 m (got %.1f m)" % [map_id, span], span >= 100.0)
	var translators := _vertical_translators(map, ParkGround.ground(map_id))
	t.check("%s has >= 5 vertical translators (>= 10 m rise/drop; got %d)" % [map_id, translators], translators >= 5)


func _planted_controls(pit: Dictionary, sink: Dictionary) -> void:
	# 1. Planted overlapping districts fail ParkSchema.
	var bad_dist := pit.duplicate(true)
	bad_dist["district_rows"][1]["rect"][1] = -300
	var errs := ParkSchema.validate(bad_dist)
	t.check("planted: overlapping W2 districts fail ParkSchema [district]",
		errs.any(func(e): return e["rule"] == "district"), ParkSchema.describe(errs))

	# 2. Planted non-empty cable_rows on 0-pack W2 fails ParkSchema; synthetic gate_packs=3 passes.
	var bad_cable := pit.duplicate(true)
	bad_cable["cable_rows"] = [{"id": "c1", "pip": 1, "to": "tailings_burrowers", "via": [[0, 0]]}]
	errs = ParkSchema.validate(bad_cable)
	t.check("planted: non-empty cable_rows on 0-pack park_pit fails ParkSchema [cable]",
		errs.any(func(e): return e["rule"] == "cable"), ParkSchema.describe(errs))
	var ctx3 := ParkSchema.stage_context("park_pit").merged({"gate_packs": 3}, true)
	var ok_cables := pit.duplicate(true)
	ok_cables["cable_rows"] = [
		{"id": "c1", "pip": 1, "to": "tailings_burrowers", "via": [[10, 200]]},
		{"id": "c2", "pip": 2, "to": "adit_drill_crews", "via": [[20, 210]]},
		{"id": "c3", "pip": 3, "to": "winze_lamps", "via": [[-20, 210]]},
	]
	errs = ParkSchema.validate(ok_cables, ctx3)
	t.check("control: 3 valid command cables pass with synthetic gate_packs=3", errs.is_empty(), ParkSchema.describe(errs))

	# 3. Planted low cable landing fails clearance.
	var flat_ground := func(_x: float, _z: float) -> float: return -40.0
	t.check("planted: cable landing 1.0 m over ground fails clearance",
		not _cable_end_clear(Vector3(0.0, -39.0, 0.0), flat_ground))

	# 4. Planted invalid survival form fails ParkSchema.
	var bad_surv := sink.duplicate(true)
	bad_surv["survival_rows"][0]["form"] = "cage"
	errs = ParkSchema.validate(bad_surv)
	t.check("planted: unknown survival form fails ParkSchema [enum]",
		errs.any(func(e): return e["rule"] == "enum"), ParkSchema.describe(errs))

	# 5. Planted destructible near scenic timber_rock_strut & bad tier fail.
	t.check("planted: destructible 5 m from timber_rock_strut fails clearance",
		_min_strut_dist(MOAB_STRUTS[0] + Vector2(5.0, 0.0)) < STRUT_CLEAR_M)
	t.check("planted: destructible tier 6 fails Destructibles.validate_row",
		Destructibles.validate_row({"id": "bad_t6", "tier": 6, "at": [0, 0, 0], "size": [2, 2, 2]}) != "")

	# 6. Planted handover faults: kind, heading, speed, ahead, far_card inside play_rect.
	var atlas := {"origin": Vector2.ZERO, "heading_deg": 0.0}
	var ex := {"kind": "launch", "at": Vector2.ZERO, "heading_deg": 0.0, "speed_cruise": 1.0}
	var clean := {"kind": "land", "at": Vector2(0.0, 100.0), "heading_deg": 0.0, "speed_cruise": 1.0}
	t.check("planted: mismatched handover kind fails", _measure_handover(ex, atlas, clean.merged({"kind": "drop"}, true), atlas)["kind"] < 1.0)
	t.check("planted: 90 deg handover heading fails", _measure_handover(ex, atlas, clean.merged({"heading_deg": 90.0}, true), atlas)["heading"] > RAIL_TURN_MAX_DEG)
	t.check("planted: halved handover speed fails", _measure_handover(ex, atlas, clean.merged({"speed_cruise": 0.4}, true), atlas)["speed"] < SPEED_MIN)
	t.check("planted: arrival behind exit fails ahead check", _measure_handover(ex, atlas, clean.merged({"at": Vector2(0.0, -100.0)}, true), atlas)["ahead"] > AHEAD_MAX_DEG)
	var bad_card := pit.duplicate(true)
	bad_card["approach"]["far_card"]["at"] = [0, 200]
	errs = ParkSchema.validate(bad_card)
	t.check("planted: far_card inside play_rect fails ParkSchema [approach]",
		errs.any(func(e): return e["rule"] == "approach"), ParkSchema.describe(errs))

	# 7. Planted flat contraptions fail verticality translator floor.
	var empty_map := ParkMap.new("")
	t.check("planted: empty map fails >= 5 vertical translators check", _vertical_translators(empty_map, flat_ground) < 5)


static func _cable_end_clear(end: Vector3, ground: Callable) -> bool:
	return end.y - float(ground.call(end.x, end.z)) >= CABLE_CLEAR_M - CABLE_EPS_M


static func _min_strut_dist(p: Vector2) -> float:
	var best := INF
	for s: Vector2 in MOAB_STRUTS:
		best = minf(best, p.distance_to(s))
	return best


static func _nearest_vertical_escape(park: Dictionary, at: Vector2) -> float:
	var best := INF
	for c: Dictionary in park.get("contraption_rows", []):
		var kind := String(c.get("kind", ""))
		if kind in ["lift", "thermal", "launcher"]:
			var p := Vector2(float(c["at"][0]), float(c["at"][1]))
			best = minf(best, at.distance_to(p))
		elif kind == "cable":
			var f := Vector2(float(c["from"][0]), float(c["from"][2]))
			best = minf(best, at.distance_to(f))
	for row: Dictionary in park.get("park_rows", []):
		if String(row.get("element", "")) == "kicker":
			var p := Vector2(float(row["at"][0]), float(row["at"][1]))
			best = minf(best, at.distance_to(p))
	return best


static func _vertical_translators(map: ParkMap, ground: Callable) -> int:
	var count := 0
	for c: Dictionary in map.contraptions:
		match String(c.get("kind", "")):
			"lift":
				if float(c.get("rise", 0.0)) >= 10.0:
					count += 1
			"thermal":
				if float(c.get("height", 0.0)) >= 10.0:
					count += 1
			"launcher":
				var at: Vector2 = c["at"]
				var target: Vector3 = c["target"]
				if absf(target.y - float(ground.call(at.x, at.y))) >= 10.0:
					count += 1
			"cable":
				var from_pt: Vector3 = c["from"]
				var to_pt: Vector3 = c["to"]
				if absf(to_pt.y - from_pt.y) >= 10.0:
					count += 1
	return count


static func _to_atlas(p: Vector2, atlas: Dictionary) -> Vector2:
	var a := deg_to_rad(float(atlas["heading_deg"]))
	return Vector2(atlas["origin"]) + Vector2(p.x * cos(a) + p.y * sin(a), -p.x * sin(a) + p.y * cos(a))


static func _yaw_dir(yaw_deg: float) -> Vector2:
	return Vector2(sin(deg_to_rad(yaw_deg)), cos(deg_to_rad(yaw_deg)))


static func _measure_handover(exit_row: Dictionary, exit_atlas: Dictionary, arrive_row: Dictionary, arrive_atlas: Dictionary) -> Dictionary:
	var exit_at := _to_atlas(exit_row["at"], exit_atlas)
	var arrive_at := _to_atlas(arrive_row["at"], arrive_atlas)
	var exit_yaw := float(exit_row["heading_deg"]) + float(exit_atlas["heading_deg"])
	var arrive_yaw := float(arrive_row["heading_deg"]) + float(arrive_atlas["heading_deg"])
	var exit_dir := _yaw_dir(exit_yaw)
	return {
		"kind": 1.0 if ParkSchema.HANDOVER_PAIRS.get(str(exit_row["kind"]), "") == str(arrive_row["kind"]) else 0.0,
		"heading": absf(rad_to_deg(exit_dir.angle_to(_yaw_dir(arrive_yaw)))),
		"speed": float(arrive_row["speed_cruise"]) / float(exit_row["speed_cruise"]),
		"ahead": absf(rad_to_deg(exit_dir.angle_to(arrive_at - exit_at))),
	}
