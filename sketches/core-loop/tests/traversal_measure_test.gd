extends SceneTree
# smoke: timeout=360s   (2026-10-11 w13 coordinator: the runner reads this marker in the first five lines only and clamps it at 360 s; KB7b put it on line 11, so the file was killed at the 180 s default under load)

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const RunLog := preload("res://src/core/run_log.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

# One short traversal of the Cable Reach on the slice table (design-v3/TRAVERSAL.md): the
# measure's JSON carries every field, flow share lies in 0 to 1, and the human-shaped bot
# keeps its limits (no reaction under 150 ms, no two verbs inside 0.4 s). Then the run log
# counts what the harpoon's bus signals report, on this same real game.
#
# Then the park measure (PARK.md section 8, unit KB7). On the park_test fixture: the six pilot
# keys name real classes, the fixture's line file passes the schema and resolves through every
# waymark, the summary names every band and judges its median, the floor line's hands roll and
# steer only, the fixture rides as the park table's stage 1 and its seed row carries every new
# field, progress_m is a number read through the fixture's stage graph (park_graph.gd's static
# read), and a planted missing graph.bin reads null and is said once. On the park only PARK.md
# section 4's ride facts count toward distinct_ride_facts and end a quiet stretch: the lift,
# the crater ride and a crumbled wall do not (KB7b).
#
# The planted dead stop runs on the fixture: a scratch line file sends Sable from the drop-in
# through the wash into the 6 m west face of the fixture's bench row (park_test.json "bench",
# south of the bench ramp), the run reports the dead stop with its place, and the dead-stop band
# goes red. The control is the same line without the planted point, ridden as long: 0 dead
# stops. (The committed fixture line meets the kicker's face near (0, -112) at about 18.5 s,
# so it is not the window's control.) The planted point inside the Cable Reach's satellite
# tower (TRAVERSAL.md:80) stays as a second control on the slice.

const TICK_LIMIT := 90 * 40
const FIELDS := ["seed", "flow_share", "dead_stops", "max_anchor_gap_m", "time_to_warden_s", "reached_warden", "path_length_m", "rides", "uphill_m", "outcome", "ticks"]
const DOCUMENT_FIELDS := ["pilot", "table", "commit", "bar", "runs", "median_flow_share", "worst_seed", "dead_stops_total", "max_anchor_gap_m", "reached_warden", "median_path_length_m", "median_uphill_m", "median_rides"]
const PARK_FIELDS := ["airborne_share", "peak_speed_mps", "tier3_s", "segment_s", "segments_s", "quiet_max_s", "distinct_verbs", "verbs", "progress_m", "length_ratio", "dead_stop_at"]
const PARK_BANDS := ["reached_warden", "time_to_warden_s", "segment_s", "flow_share", "airborne_share", "dead_stops", "peak_speed_mps", "tier3_s", "quiet_max_s", "max_anchor_gap_m", "distinct_verbs", "length_ratio"]
const PILOT_CLASSES := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster",
	"tarn": "tarn", "tally": "tally", "cannon": "remembered_cannon"}
const FIXTURE_LINES := "res://assets/park/park_test/lines.json"
const FIXTURE_PARK := "res://src/world/park/park_test.json"
const FIXTURE_TICKS := 90 * 2
# A line point inside the Cable Reach's satellite tower (TRAVERSAL.md:80).
const PLANT_POINT := [-72, -16]
const PLANT_TICK_LIMIT := 90 * 30
# The fixture plant: the bench's west face (bench at [300, 200], 160 by 200, 6 m high), met at
# about (196, 123), south of the bench ramp's z 180 to 220.
# 2026-10-11 (w13 KB9 round 3): with the park rows placed, the control's intermediate waypoints move onto the schema
# lanes (park_recipes.gd clear_zones: the waymarks chain and the routes, which the anchor posts keep out of). Old:
# [-150, -400], [-40, 0], [60, 100]; [60, 100] lay 40 m off the wash_camp-to-tube lane, and both runs dead-stopped on a
# grey_c3 post at (38.3, 97.8). New: [-138, -400] on the drop_in-to-wash_camp centreline, [-25, 0] and [25, 120] on the
# wash_camp-to-tube centreline; [25, 120] is north of grey_c3's footprint (z <= 105), so the planted leg to the bench
# runs clear of the field's edge posts. The dead-stop rule, the plant point and the checks are unchanged.
const PARK_ROUTE_HEAD := ["drop_in", [-138, -400], "wash_camp", [-25, 0], [25, 120]]
const PARK_ROUTE_TAIL := ["tube", "landmark"]
const PARK_PLANT_POINT := [300, 140]
const PARK_PLANT_TICK_LIMIT := 90 * 45
const PARK_CONTROL_MARGIN := 45
# PARK.md section 4's "Verb and ride fact" column, and the slice's ride facts, unchanged.
const SECTION4_RIDE_FACTS := ["ride_chute", "ride_grapple_line", "ride_bowl", "ride_drop", "ride_ledge",
	"kicker_launch", "ride_glide_drop", "thermal_ride", "ride_hop"]
const SLICE_RIDE_FACTS := ["ride_grapple_line", "ride_chute", "ride_skylight", "ride_glide_drop", "wall_crumbled", "thermal_ride"]
# A map id with no assets/park/<id>/graph.bin: the planted missing graph.
const MISSING_GRAPH_MAP := "kb7b_planted_missing_graph"

var _t := T.new("traversal_measure_test")
var _game
var _driver
var _sampler
var _ticks := 0
var _phase := "slice"
# The clean Cable Reach line's dead stops, the control the planted line is read against.
var _clean_dead_stops := -1


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	match _phase:
		"slice":
			_slice_tick(delta)
		"fixture":
			_fixture_tick(delta)
		"plant":
			_plant_tick(delta)
		"park_plant", "park_control":
			_park_plant_tick(delta)
	return false


func _slice_tick(delta: float) -> void:
	if _game.flow == null:
		return
	if _driver == null:
		_driver = BotDriver.new(_game, "traversal", 1)
		_driver.start()
		_sampler = TraversalLine.Sampler.new(_game)
		return
	_ticks += 1
	var over: bool = _driver.tick(delta)
	_sampler.sample()
	if over or _sampler.engaged or _ticks > TICK_LIMIT:
		_clean_dead_stops = _sampler.traversal.dead_stops
		_check_measure()
		_check_limits()
		_check_run_log()
		_game.free()
		_start_fixture()


func _new_game(table: String) -> void:
	seed(1)
	_driver = null
	_sampler = null
	_ticks = 0
	_game = Game.new()
	_game.test_mode = true
	_game.table = table
	root.add_child(_game)


# --- The park measure (PARK.md section 8) on the fixture ---

func _start_fixture() -> void:
	_phase = "fixture"
	_check_pilots()
	_check_fixture_lines()
	_check_summary()
	_check_floor_hands()
	_check_anchor_contacts()
	_t.check("the fixture replaces the park table's first stage", TraversalLine.use_fixture(), "park_defs stage 1 map now park_test")
	_new_game("park")


func _fixture_tick(delta: float) -> void:
	if _game.flow == null:
		return
	if _driver == null:
		_t.eq("the fixture loads as the park table's stage 1", String(_game.ctx.terrain.map_for(1).get("title")), "park_test")
		var park: Dictionary = ParkSchema.read_file(FIXTURE_PARK)["data"]
		var line := TraversalLine.line_of(TraversalLine.load_lines(FIXTURE_LINES), "sable", park)
		_driver = BotDriver.new(_game, "traversal", 1)
		_driver.class_index = BotDriver.class_index_for(1, PILOT_CLASSES["sable"])
		_driver.route = line["route"]
		_driver.start()
		_sampler = TraversalLine.Sampler.new(_game)
		_sampler.setup_park(line["waymarks"], TraversalLine.open_graph("park_test"))
		return
	_ticks += 1
	_driver.tick(delta)
	_sampler.sample()
	if _ticks < FIXTURE_TICKS:
		return
	_check_fixture_ride_facts()
	_check_fixture_graph()
	var run: Dictionary = _sampler.result(1, _driver.outcome)
	var gone: Array = PARK_FIELDS.filter(func(f): return not run.has(f))
	_t.check("the fixture's seed row has every new field", gone.is_empty(), "missing %s" % [gone])
	var share := float(run.get("airborne_share", -1.0))
	_t.check("airborne share lies in 0 to 1, peak speed and tier 3 seconds are numbers",
		share >= 0.0 and share <= 1.0 and float(run.get("peak_speed_mps", -1.0)) >= 0.0 and float(run.get("tier3_s", -1.0)) >= 0.0,
		"airborne %s, peak %s m/s, tier 3 %s s, quiet max %s s, verbs %s" % [share, run.get("peak_speed_mps"), run.get("tier3_s"), run.get("quiet_max_s"), run.get("verbs")])
	_t.eq("the fixture line's waymark clock has one segment per waymark pair", (run.get("segments_s", []) as Array).size(), 3)
	var progress = run.get("progress_m", "absent")
	var start = _sampler._graph_start
	_t.check("progress_m is a number on the fixture, from the ball's real d_landmark",
		progress is float and is_finite(progress) and start != null and float(start) > 100.0 and _sampler.graph_note == "",
		"progress %s m/s, graph start d_landmark %s m, note '%s'" % [progress, start, _sampler.graph_note])
	_check_missing_graph()
	_game.free()
	_start_park_plant()


# On the park, lift_fired is a contraption, not a ride fact: it neither ends the quiet stretch
# nor counts toward distinct_ride_facts. A section 4 ride fact (ride_bowl) does both.
func _check_fixture_ride_facts() -> void:
	var now: float = _game.run.stage_time
	var began: bool = _sampler._start != Vector3.INF
	_game.events.world_fact.emit("lift_fired", _game.player.ball_position())
	var after_lift: float = _sampler._last_event
	_t.check("on the park lift_fired alone does not reset the quiet clock or count as a ride fact",
		began and after_lift < now and not "lift_fired" in _sampler._ride_facts(),
		"began %s, last event %s s, now %s s, ride facts %s, verbs %s" % [began, after_lift, now, _sampler._ride_facts(), _sampler._verbs])
	_game.events.world_fact.emit("ride_bowl", _game.player.ball_position())
	_t.check("a section 4 ride fact (ride_bowl) resets the quiet clock and counts",
		_sampler._last_event == now and "ride_bowl" in _sampler._ride_facts(),
		"last event %s s, now %s s, ride facts %s" % [_sampler._last_event, now, _sampler._ride_facts()])


# The fixture's graph.bin loads through park_graph.gd's static read: every node has its
# d_landmark, so no query indexes an empty array.
func _check_fixture_graph() -> void:
	var graph = TraversalLine.open_graph("park_test")
	var nodes: int = graph.node_count() if graph != null else -1
	var lands: int = (graph.d_land as PackedFloat32Array).size() if graph != null else -1
	_t.check("the fixture's stage graph loads with a d_landmark for every node", graph != null and nodes > 0 and lands == nodes,
		"%d nodes, %d d_landmark values" % [nodes, lands])
	_t.check("the sampler reads the same graph", _sampler.graph == graph, "sampler graph %s" % [_sampler.graph])


# A planted missing graph (a map id with no graph.bin, never the fixture): null, said once.
func _check_missing_graph() -> void:
	var file: String = TraversalLine.GRAPH_FILE % MISSING_GRAPH_MAP
	_t.check("the planted map has no graph.bin", not FileAccess.file_exists(file), file)
	var notes_before: int = TraversalLine.graph_notes
	var absent = TraversalLine.open_graph(MISSING_GRAPH_MAP)
	var stand_in = TraversalLine.Sampler.new(_game)
	stand_in.setup_park([], absent)
	_t.check("without graph.bin progress reads null and the sampler says so once",
		absent == null and notes_before == 0 and TraversalLine.graph_notes == 1 and stand_in.graph_note != "" and stand_in._progress() == null,
		"graph %s, notes %d then %d, note '%s', progress %s" % [absent, notes_before, TraversalLine.graph_notes, stand_in.graph_note, stand_in._progress()])
	TraversalLine.open_graph(MISSING_GRAPH_MAP)
	_t.eq("a second missing graph is not said again", TraversalLine.graph_notes, 1)


# --- The planted dead stop on the fixture, and its control ---

var _park_plant_ticks := -1


func _start_park_plant() -> void:
	_phase = "park_plant"
	_new_game("park")


func _park_line(waypoints: Array, file: String) -> Dictionary:
	var lines := {"map": "park_test", "stage": 1, "pilots": {"sable": {"waypoints": waypoints,
		"bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}}, "floor": {"waypoints": ["drop_in", "landmark"]}}
	var path: String = _game.storage_dir.path_join(file)
	TraversalLine.write_document(path, lines)
	var park: Dictionary = ParkSchema.read_file(FIXTURE_PARK)["data"]
	return TraversalLine.line_of(TraversalLine.load_lines(path), "sable", park)


func _park_plant_tick(delta: float) -> void:
	if _game.flow == null:
		return
	var planted := _phase == "park_plant"
	if _driver == null:
		var waypoints: Array = PARK_ROUTE_HEAD.duplicate()
		if planted:
			waypoints.append(PARK_PLANT_POINT)
		waypoints.append_array(PARK_ROUTE_TAIL)
		var line := _park_line(waypoints, "planted_park_line.json" if planted else "control_park_line.json")
		_driver = BotDriver.new(_game, "traversal", 1)
		_driver.class_index = BotDriver.class_index_for(1, PILOT_CLASSES["sable"])
		_driver.route = line["route"]
		_driver.start()
		_sampler = TraversalLine.Sampler.new(_game)
		_sampler.setup_park(line["waymarks"], TraversalLine.open_graph("park_test"))
		return
	_ticks += 1
	var over: bool = _driver.tick(delta)
	_sampler.sample()
	if planted:
		if not over and not _sampler.engaged and _ticks <= PARK_PLANT_TICK_LIMIT and _sampler.traversal.dead_stops == 0:
			return
	elif not over and not _sampler.engaged and _ticks < _park_plant_ticks + PARK_CONTROL_MARGIN:
		return
	var run: Dictionary = _sampler.result(1, "engaged" if _sampler.engaged else _driver.outcome)
	var stops: Array = run.get("dead_stop_at", [])
	var detail := "%s at %s after %d ticks (%.1f s), path %s m, outcome %s" % [run.get("dead_stops"), stops, _ticks, float(_ticks) / 90.0, run.get("path_length_m"), run.get("outcome")]
	if planted:
		_park_plant_ticks = _ticks
		var at_face := false
		for stop in stops:
			var at: Array = stop.get("at", [])
			if at.size() == 2 and absf(float(at[0]) - 196.0) <= 10.0 and float(at[1]) >= 100.0 and float(at[1]) < 180.0:
				at_face = true
		_t.check("the planted bench point makes the fixture run report a dead stop at the bench face",
			int(run.get("dead_stops", 0)) >= 1 and at_face, "planted %s" % detail)
		var doc := TraversalLine.park_document("sable", "park_test", 0, "test", [run], {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}, {})
		_t.eq("the dead-stop band goes red on the planted fixture line", _band_of(doc, "dead_stops").get("inside"), false)
		_game.free()
		_phase = "park_control"
		_new_game("park")
		return
	_t.check("the same fixture line without the planted point has 0 dead stops over as long",
		int(run.get("dead_stops", -1)) == 0 and _ticks >= _park_plant_ticks, "control %s" % detail)
	_game.free()
	TraversalLine.restore_park_defs()
	_start_plant()


func _check_pilots() -> void:
	var roster := {}
	for row in ClassDef.all():
		roster[row.id] = true
	_t.eq("six park pilot keys", TraversalLine.PARK_PILOTS.keys(), PILOT_CLASSES.keys())
	var wrong: Array = []
	for key in PILOT_CLASSES:
		if TraversalLine.PARK_PILOTS.get(key) != PILOT_CLASSES[key] or not roster.has(PILOT_CLASSES[key]) \
				or BotDriver.class_index_for(1, PILOT_CLASSES[key]) < 0:
			wrong.append(key)
	_t.check("each pilot key names a class_def id the bot can choose", wrong.is_empty(), "wrong %s" % [wrong])


func _check_fixture_lines() -> void:
	var lines := TraversalLine.load_lines(FIXTURE_LINES)
	var park: Dictionary = ParkSchema.read_file(FIXTURE_PARK)["data"]
	var errors := ParkSchema.validate_lines(lines, park)
	_t.check("the fixture's line file loads with zero schema errors", not lines.is_empty() and errors.is_empty(), ParkSchema.describe(errors))
	var routes := 0
	for key in PILOT_CLASSES:
		var line := TraversalLine.line_of(lines, key, park)
		if (line["route"] as Array).size() >= 2 and (line["waymarks"] as Array).size() == (park.get("waymarks", []) as Array).size():
			routes += 1
	var floor_line := TraversalLine.line_of(lines, TraversalLine.FLOOR, park)
	_t.check("every pilot and the floor resolve to a route through every waymark", routes == 6 and (floor_line["route"] as Array).size() >= 2,
		"%d of 6 pilot routes, floor route %d points" % [routes, (floor_line["route"] as Array).size()])
	var landmark: Vector2 = floor_line["route"][-1] if (floor_line["route"] as Array).size() > 0 else Vector2.INF
	_t.eq("the landmark waymark resolves to the engage centre", landmark, Vector2(0, 575))


# The summary on made-up rows: each band row is named, and its verdict follows the median.
func _check_summary() -> void:
	var runs: Array = []
	for i in 8:
		runs.append({"seed": i + 1, "flow_share": 0.8, "dead_stops": 0, "max_anchor_gap_m": 20.0, "time_to_warden_s": 90.0,
			"reached_warden": true, "path_length_m": 1500.0, "rides": ["ride_chute"], "uphill_m": 2.0, "outcome": "engaged", "ticks": 8100,
			"airborne_share": 0.05, "peak_speed_mps": 30.0, "tier3_s": 4.0, "segment_s": 30.0, "segments_s": [20.0, 30.0, 25.0],
			"quiet_max_s": 12.0, "distinct_verbs": 4, "verbs": ["jump", "boost", "ride_chute", "kicker_launch"], "progress_m": null,
			"distinct_ride_facts": 2, "blazing_mps": 26.6, "length_ratio": 1.5, "dead_stop_at": []})
	var doc := TraversalLine.park_document("sable", "park_test", 0, "test", runs, {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}, {})
	var named: Array = []
	var verdicts := {}
	for row in doc.get("bands", []):
		named.append(row.get("measure"))
		verdicts[row.get("measure")] = row.get("inside")
	var missing: Array = PARK_BANDS.filter(func(m): return not m in named)
	_t.check("the summary names every PARK.md section 8 band", missing.is_empty(), "missing %s" % [missing])
	_t.eq("the summary judges each median against its band", [verdicts.get("flow_share"), verdicts.get("airborne_share"), verdicts.get("dead_stops"), verdicts.get("segment_s")],
		[true, false, true, true])
	var medians: Dictionary = doc.get("medians", {})
	var absent: Array = ["airborne_share", "peak_speed_mps", "tier3_s", "segment_s", "quiet_max_s", "distinct_verbs"].filter(func(f): return not medians.has(f))
	_t.check("the summary carries each new measure's median", absent.is_empty(), "missing %s" % [absent])
	var floor_doc := TraversalLine.park_document("floor", "park_test", 0, "test", runs, {}, {"pilot": "rivet", "median_time_to_warden_s": 40.0})
	var floor_band := {}
	for row in floor_doc.get("bands", []):
		if row.get("measure") == "floor":
			floor_band = row
	_t.eq("the floor band judges 2.0 times the pilot line's median time", [floor_band.get("worst"), floor_band.get("inside")], [80.0, false])
	_check_summary_edges(runs)


# Each row's band reads PARK.md section 8's definition, not a nearby measure.
func _check_summary_edges(base: Array) -> void:
	var skills := _rows(base, {"distinct_verbs": 3, "verbs": ["jump", "boost", "special"], "distinct_ride_facts": 1})
	_t.eq("three verbs with one ride fact miss the distinct-verbs band (ride facts only)",
		_band_of(skills, "distinct_verbs").get("inside"), false)
	var rides := _rows(base, {"distinct_verbs": 3, "verbs": ["ride_chute", "kicker_launch", "ride_bowl"], "distinct_ride_facts": 3})
	_t.eq("three ride facts make the distinct-verbs band", _band_of(rides, "distinct_verbs").get("inside"), true)
	# A row the merged tool wrote (distinct_ride_facts 3) from three world facts PARK.md section 4 does not list.
	var not_rides := _rows(base, {"distinct_verbs": 3, "verbs": ["lift_fired", "crater_ride", "wall_crumbled"], "distinct_ride_facts": 3})
	_t.eq("lift_fired, crater_ride and wall_crumbled give 0 distinct ride facts and miss the band",
		[not_rides.get("medians", {}).get("distinct_ride_facts"), _band_of(not_rides, "distinct_verbs").get("inside")], [0.0, false])
	var park_facts: Array = TraversalLine.PARK_RIDE_FACTS.duplicate()
	park_facts.sort()
	var section4: Array = SECTION4_RIDE_FACTS.duplicate()
	section4.sort()
	_t.eq("the park's ride facts are PARK.md section 4's list", park_facts, section4)
	_t.eq("the slice's ride facts are unchanged", TraversalLine.RIDE_FACTS, SLICE_RIDE_FACTS)
	_t.eq("the reached band names the run's own seed count",
		[_band_of(_rows(base, {}), "reached_warden").get("band"), _band_of(_rows(base.slice(0, 2), {}), "reached_warden").get("band")],
		["8 of 8 seeds", "2 of 2 seeds"])
	var fast_cruise := _rows(base, {"peak_speed_mps": 30.0, "blazing_mps": 32.3})
	_t.eq("the peak band reads the blazing tier the run was tuned to", _band_of(fast_cruise, "peak_speed_mps").get("inside"), false)
	var slow_cruise := _rows(base, {"peak_speed_mps": 25.0, "blazing_mps": 22.8})
	_t.eq("a lower tuned cruise lowers the peak band with it", _band_of(slow_cruise, "peak_speed_mps").get("inside"), true)
	var stalled := _rows(base, {"dead_stops": 0, "path_length_m": 0.0})
	_t.eq("a ball that never rolled cannot read the dead-stop band green", _band_of(stalled, "dead_stops").get("inside"), null)


func _rows(base: Array, change: Dictionary) -> Dictionary:
	var runs: Array = []
	for row in base:
		var copy: Dictionary = (row as Dictionary).duplicate(true)
		copy.merge(change, true)
		runs.append(copy)
	return TraversalLine.park_document("sable", "park_test", 0, "test", runs, {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}, {})


func _band_of(doc: Dictionary, measure: String) -> Dictionary:
	for row in doc.get("bands", []):
		if row.get("measure") == measure:
			return row
	return {}


# The floor line's hands: only the stick and the brake survive the filter.
# --anchor-contacts on planted geometry: a fitted box turned 90 degrees, a ball a known distance from its vertical-edge corner.
func _check_anchor_contacts() -> void:
	var AC = TraversalLine.AnchorContacts
	var fitted := {"row": "plant", "key": "anchor_basalt_a", "size_y": 2.0, "fitted": true, "over_limit": true}
	var grey := {"row": "grey", "key": "greybox:anchor_field", "size_y": 14.0, "fitted": false, "over_limit": false}
	# Size (4, 6, 2) turned a quarter about Y at (10, 3, 20): x 9 to 11, z 16 to 24, one corner at (11, 18).
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(10.0, 3.0, 20.0))
	var list: Array = [AC.box_record(xf, Vector3(4.0, 6.0, 2.0), fitted), AC.box_record(Transform3D(Basis.IDENTITY, Vector3(13.5, 3.0, 18.0)), Vector3(1.0, 6.0, 1.0), grey)]
	var ball := Vector3(12.2, 3.0, 18.0)
	var corner: Dictionary = AC.corner_distance(ball, list)
	_t.check("anchor contacts: the planted ball is 1.2 m from the turned fitted box's corner", int(corner["box"]) == 0 and absf(float(corner["dist"]) - 1.2) < 0.0001, str(corner))
	_t.check("anchor contacts: a ball above the box's span has no corner, and an 8 m box has none", not is_finite(float(AC.corner_distance(Vector3(12.2, 11.0, 18.0), list)["dist"]))
		and not is_finite(float(AC.corner_distance(ball, [list[1]])["dist"])))
	var hit: Dictionary = AC.nearest_surface(ball, list)
	_t.check("anchor contacts: the nearest surface is the grey box 0.8 m away, with a normal facing the ball", int(hit["box"]) == 1 and absf(float(hit["dist"]) - 0.8) < 0.0001 and (hit["normal"] as Vector3).x < -0.99, str(hit))
	var mask := {"side": 4, "step": 8.0, "half": 16.0, "cells": PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])}
	_t.check("anchor contacts: the lane mask marks the planted cell only", AC.on_lane(mask, ball.x, ball.z) and not AC.on_lane(mask, -12.0, -12.0) and not AC.on_lane({}, ball.x, ball.z))
	var hit_fit: Dictionary = AC.nearest_surface(ball, [list[0]])
	var event: Dictionary = AC.describe("stop", "park_plant", 7, 3.5, ball, list, hit_fit, mask)
	_t.check("anchor contacts: the event row carries park, seed, row, size, fitted, over_limit, distance and ride line",
		event["park"] == "park_plant" and event["seed"] == 7 and event["row"] == "plant" and event["size_y"] == 2.0 and event["fitted"] and event["over_limit"]
		and event["corner_dist_m"] == 1.2 and event["corner_row"] == "plant" and event["on_ride_line"] and event["kind"] == "stop", str(event))
	var far: Dictionary = AC.describe("bounce", "park_plant", 7, 4.0, Vector3(-12.0, 3.0, -12.0), list, AC.nearest_surface(Vector3(-12.0, 3.0, -12.0), list), mask)
	var summary: Dictionary = AC.summarise([event, far])
	_t.check("anchor contacts: the summary counts the planted corner stop, on the ride line, and the over_limit one",
		summary["events"] == 2 and summary["near_corner"] == 1 and summary["near_corner_on_ride_line"] == 1 and summary["events_on_ride_line"] == 1
		and (summary["over_limit_events"] as Dictionary).size() == 1 and not far["on_ride_line"], str(summary))
	var near_limit: Dictionary = AC.describe("stop", "park_plant", 7, 3.6, Vector3(11.8, 3.0, 20.0), list, AC.nearest_surface(Vector3(11.8, 3.0, 20.0), list), mask)
	_t.check("anchor contacts: a stop 0.8 m from an over_limit box's face is counted under over_limit",
		(AC.summarise([near_limit])["over_limit_events"] as Dictionary).size() == 1, str(AC.summarise([near_limit])))
	# The recorder on a real fitted row placed by place_row: one record per BoxShape3D, all fitted, and a ball planted 0.9 m from a corner.
	var row := {"id": "corner_t", "element": "anchor_field", "at": [0, 0], "y": null, "size": [60, 10, 60], "yaw_deg": 30, "ride_fact": "",
		"recipe": "anchor_hoodoo", "stamp": "", "budget": "detail"}
	var parent := Node3D.new()
	root.add_child(parent)
	var node: Node3D = ParkRecipes.place_row(row, parent, func(_x: float, _z: float) -> float: return 0.0)
	var recorded: Array = AC.collect(root, [row])
	var shapes := node.find_children("*", "CollisionShape3D", true, false)
	var all_fitted := recorded.all(func(b: Dictionary) -> bool: return b["fitted"] and b["row"] == "corner_t")
	_t.check("anchor contacts: collect finds every box of a placed fitted row (%d of %d)" % [recorded.size(), shapes.size()], recorded.size() == shapes.size() and shapes.size() > 0 and all_fitted)
	if not recorded.is_empty():
		var c: Vector2 = recorded[0]["corners"][0]
		var planted := Vector3(c.x + 0.9, (float(recorded[0]["y0"]) + float(recorded[0]["y1"])) * 0.5, c.y)
		var found: Dictionary = AC.corner_distance(planted, recorded)
		_t.check("anchor contacts: a ball planted 0.9 m from a placed box's corner reads at most 0.9 m", float(found["dist"]) <= 0.9001, str(found))
	parent.free()


func _check_floor_hands() -> void:
	var hold := {"move": Vector2(0, 1), "brake_held": true, "fire_held": true, "line_held": true, "boost_held": true, "special_held": true}
	var press := {"jump_pressed": true, "special_pressed": true, "boost_pressed": true}
	var kept := TraversalLine.floor_hands(hold, press)
	_t.eq("the floor bot keeps only move and brake", [kept["hold"].keys(), kept["press"].keys()], [["move", "brake_held"], []])


# --- The planted dead stop, on the stage that rolls ---

var _plant_path := ""


func _start_plant() -> void:
	_phase = "plant"
	_new_game("slice")


func _plant_tick(delta: float) -> void:
	if _game.flow == null:
		return
	if _driver == null:
		var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
		var beacon: Vector3 = _game.ctx.terrain.beacon_point(1)
		# A scratch line file in the park line format; drop_in and landmark resolve through a park
		# stand-in carrying the slice stage's spawn and engage centre.
		var lines := {"map": "slice_reach", "stage": 1, "pilots": {"sable": {"waypoints": ["drop_in", PLANT_POINT, "landmark"],
			"bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}}, "floor": {"waypoints": ["drop_in", "landmark"]}}
		_plant_path = _game.storage_dir.path_join("planted_line.json")
		TraversalLine.write_document(_plant_path, lines)
		var stand_in := {"spawn": {"at": [spawn.x, spawn.z]}, "landmark": {"beacon": [beacon.x, beacon.z]}}
		var line := TraversalLine.line_of(TraversalLine.load_lines(_plant_path), "sable", stand_in)
		_driver = BotDriver.new(_game, "traversal", 1)
		_driver.class_index = BotDriver.class_index_for(1, PILOT_CLASSES["sable"])
		_driver.route = line["route"]
		_driver.start()
		_sampler = TraversalLine.Sampler.new(_game)
		_sampler.setup_park(line["waymarks"], null)
		return
	_ticks += 1
	var over: bool = _driver.tick(delta)
	_sampler.sample()
	if not over and not _sampler.engaged and _ticks <= PLANT_TICK_LIMIT and _sampler.traversal.dead_stops == 0:
		return
	var run: Dictionary = _sampler.result(1, "engaged" if _sampler.engaged else _driver.outcome)
	_t.check("the planted wall point makes the run report a dead stop the clean line does not have",
		_clean_dead_stops == 0 and int(run.get("dead_stops", 0)) >= 1 and (run.get("dead_stop_at", []) as Array).size() >= 1,
		"clean line %d; planted %s at %s after %d ticks, path %s m, outcome %s" % [_clean_dead_stops, run.get("dead_stops"), run.get("dead_stop_at"), _ticks, run.get("path_length_m"), run.get("outcome")])
	var doc := TraversalLine.park_document("sable", "slice_reach", 1, "test", [run], {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}, {})
	var dead_band := {}
	for row in doc.get("bands", []):
		if row.get("measure") == "dead_stops":
			dead_band = row
	_t.eq("the dead-stop band goes red on the planted line", dead_band.get("inside"), false)
	_game.free()
	_phase = "done"
	quit(_t.verdict())


func _check_measure() -> void:
	var run: Dictionary = _sampler.result(1, "engaged" if _sampler.engaged else _driver.outcome)
	_t.check("--anchor-contacts off: the sampler holds no contact recorder and the run row carries no anchor_contacts", _sampler.contacts == null and not run.has("anchor_contacts"))
	var doc := TraversalLine.document("sable", "slice", "test", [run], {})
	var path: String = _game.storage_dir.path_join("traversal_measure.json")
	_t.check("document written", TraversalLine.write_document(path, doc), path)
	var back = JSON.parse_string(FileAccess.get_file_as_string(path))
	_t.check("document parses", back is Dictionary, "read back from %s" % path)
	if not back is Dictionary:
		return
	var missing: Array = []
	for field in DOCUMENT_FIELDS:
		if not back.has(field):
			missing.append(field)
	_t.check("document has every field", missing.is_empty(), "missing %s" % [missing])
	var seed_row: Dictionary = back["runs"][0] if back["runs"] is Array and (back["runs"] as Array).size() == 1 else {}
	var gone: Array = []
	for field in FIELDS:
		if not seed_row.has(field):
			gone.append(field)
	_t.check("seed row has every field", gone.is_empty(), "missing %s" % [gone])
	var share := float(seed_row.get("flow_share", -1.0))
	_t.check("flow share lies in 0 to 1", share >= 0.0 and share <= 1.0 and int(seed_row.get("ticks", 0)) > 0,
		"flow share %s over %s ticks, dead stops %s, anchor gap %s m" % [share, seed_row.get("ticks"), seed_row.get("dead_stops"), seed_row.get("max_anchor_gap_m")])
	_t.eq("pilot and table are recorded", [back.get("pilot"), back.get("table")], ["sable", "slice"])


func _check_limits() -> void:
	var tps := Engine.physics_ticks_per_second
	_t.check("reaction constant is at least 150 ms", BotDriver.TRAVERSE_REACTION >= 0.15, "%s s" % BotDriver.TRAVERSE_REACTION)
	_t.check("press constant is at least 0.4 s", BotDriver.TRAVERSE_PRESS_GAP >= 0.4, "%s s" % BotDriver.TRAVERSE_PRESS_GAP)
	_check_reaction()
	# The gate under a press on every tick: whatever the bot's own pace, the gaps hold.
	var before: int = _driver.press_ticks.size()
	for i in tps * 4:
		_driver.ticks += 1
		_driver.source.press = {"jump_pressed": true, "boost_pressed": true}
		_driver._gate_presses()
	var presses: Array = _driver.press_ticks
	var smallest := 1000000
	for i in range(1, presses.size()):
		smallest = mini(smallest, int(presses[i]) - int(presses[i - 1]))
	_t.check("presses are at least 0.4 s apart", presses.size() - before >= 2 and float(smallest) / float(tps) >= 0.4,
		"%d presses, smallest gap %d ticks (%.3f s)" % [presses.size(), smallest, float(smallest) / float(tps)])
	_t.check("one verb per press", _driver.source.press.size() <= 1, "%s" % [_driver.source.press])


# What the bot sends, with the route's point changed on one tick: for 13 ticks neither the
# camera nor the world direction the stick pushes in answers, and both are out by tick 16.
# The ball does not move between calls, so only the bot's own delay can separate the two.
func _check_reaction() -> void:
	var tps := Engine.physics_ticks_per_second
	var ball: Vector3 = _game.player.ball_position()
	_driver.route.clear()
	_driver.route.append(Vector2(ball.x + 80.0, ball.z))
	_driver._leg = 0
	_driver._out.clear()
	var fired := 0
	var last := Vector3.ZERO
	for i in 150:
		_driver.ticks += 1
		_driver._traverse(1.0 / tps)
		last = _driver._stick_to_world(_driver.source.hold.get("move", Vector2.ZERO))
		if _driver.source.hold.get("fire_held", false):
			fired += 1
	var yaw_before: float = _game.camera.yaw
	_driver.route[0] = Vector2(ball.x - 80.0, ball.z)
	_driver._leg = 0
	var answered := -1
	var turned := -1
	for i in range(1, 31):
		_driver.ticks += 1
		_driver._traverse(1.0 / tps)
		var wish: Vector3 = _driver._stick_to_world(_driver.source.hold.get("move", Vector2.ZERO))
		if _driver.source.hold.get("fire_held", false):
			fired += 1
		if answered < 0 and wish.distance_to(last) > 0.3:
			answered = i
		if turned < 0 and absf(wrapf(_game.camera.yaw - yaw_before, -PI, PI)) > 0.001:
			turned = i
	_t.check("the push answers a changed target no sooner than 150 ms and by tick 16", answered >= 14 and answered <= 16,
		"the world direction of the stick first answered %d ticks after the change (before it %s)" % [answered, last])
	_t.check("the camera answers a changed target no sooner than 150 ms and by tick 16", turned >= 14 and turned <= 16,
		"the camera first turned %d ticks after the change" % turned)
	_t.eq("the traversal bot never holds fire", fired, 0)


func _check_run_log() -> void:
	var events = _game.events
	events.event_started.emit("flood")
	events.event_started.emit("surge_run")
	for i in 2:
		events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	events.line_state_changed.emit("smash_lands", null, Vector3.ZERO, "")
	events.line_state_changed.emit("broke", null, Vector3.ZERO, "wall")
	events.line_state_changed.emit("broke", null, Vector3.ZERO, "wall")
	events.line_state_changed.emit("broke", null, Vector3.ZERO, "slack")
	for i in 3:
		events.verb_failed.emit("harpoon", "no_aim", Vector3.ZERO)
	events.verb_failed.emit("haul", "no_line", Vector3.ZERO)
	_game.run.damage(9999.0, "test")
	var lines := FileAccess.get_file_as_string(_game.storage_dir.path_join(RunLog.LOG_FILE)).strip_edges().split("\n", false)
	var record = JSON.parse_string(lines[lines.size() - 1]) if lines.size() > 0 else null
	_t.check("the run log wrote a record", record is Dictionary, "%d line(s)" % lines.size())
	if not record is Dictionary:
		return
	_t.eq("bites", int(record.get("bites", -1)), 2)
	_t.eq("smashes", int(record.get("smashes", -1)), 1)
	var breaks: Dictionary = record.get("breaks", {})
	_t.eq("breaks by cause", [int(breaks.get("wall", 0)), int(breaks.get("slack", 0)), breaks.size()], [2, 1, 2])
	var fails: Dictionary = record.get("verb_fails", {})
	_t.eq("verb fails by verb", [int(fails.get("harpoon", 0)), int(fails.get("haul", 0)), fails.size()], [3, 1, 2])
	_t.check("prompts shown", float(record.get("prompts_shown", -1)) >= 0.0 and float(record.get("prompts_shown", -1)) == floorf(float(record.get("prompts_shown", -1))), "prompts_shown %s" % record.get("prompts_shown"))
	var share = record.get("flow_share")
	_t.check("flow share and dead stops ride the record", share is float and share >= 0.0 and share <= 1.0 and record.has("dead_stops"),
		"flow share %s, dead stops %s" % [share, record.get("dead_stops")])
	var stage: Dictionary = record["stages"][0] if record.get("stages") is Array and (record["stages"] as Array).size() > 0 else {}
	_t.eq("only the opt-in event was joined", stage.get("events_joined"), ["surge_run"])
