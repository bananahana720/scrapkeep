extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const RunLog := preload("res://src/core/run_log.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

# smoke: timeout=300s
# One short traversal of the Cable Reach on the slice table (design-v3/TRAVERSAL.md): the
# measure's JSON carries every field, flow share lies in 0 to 1, and the human-shaped bot
# keeps its limits (no reaction under 150 ms, no two verbs inside 0.4 s). Then the run log
# counts what the harpoon's bus signals report, on this same real game.
#
# Then the park measure (PARK.md section 8, unit KB7) on the park_test fixture: the six pilot
# keys name real classes, the fixture's line file passes the schema, the summary names every
# band and judges its median, the floor line's hands roll and steer only, and a planted line
# point inside the ledge wall makes the run report a dead stop and the dead-stop band go red.
# Without graph.bin the progress field reads null and the sampler says so once.

const TICK_LIMIT := 90 * 40
const FIELDS := ["seed", "flow_share", "dead_stops", "max_anchor_gap_m", "time_to_warden_s", "reached_warden", "path_length_m", "rides", "uphill_m", "outcome", "ticks"]
const DOCUMENT_FIELDS := ["pilot", "table", "commit", "bar", "runs", "median_flow_share", "worst_seed", "dead_stops_total", "max_anchor_gap_m", "reached_warden", "median_path_length_m", "median_uphill_m", "median_rides"]
const PARK_FIELDS := ["airborne_share", "peak_speed_mps", "tier3_s", "segment_s", "segments_s", "quiet_max_s", "distinct_verbs", "verbs", "progress_m", "length_ratio", "dead_stop_at"]
const PARK_BANDS := ["reached_warden", "time_to_warden_s", "segment_s", "flow_share", "airborne_share", "dead_stops", "peak_speed_mps", "tier3_s", "quiet_max_s", "max_anchor_gap_m", "distinct_verbs", "length_ratio"]
const PILOT_CLASSES := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster",
	"tarn": "tarn", "tally": "tally", "cannon": "remembered_cannon"}
const FIXTURE_LINES := "res://tools/park_lines/park_test.json"
const FIXTURE_PARK := "res://src/world/park/park_test.json"
# A line point inside the fixture's service ledge (park row service_ledge, 100 by 20 by 9 m at
# (-200, 200)): the bot rolls into its face and stops there.
const PLANT_POINT := [-200, 200]
const PARK_TICK_LIMIT := 90 * 75

var _t := T.new("traversal_measure_test")
var _game
var _driver
var _sampler
var _ticks := 0
var _phase := "slice"


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _phase == "slice":
		return _slice_tick(delta)
	if _phase == "park":
		return _park_tick(delta)
	return false


func _slice_tick(delta: float) -> bool:
	if _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "traversal", 1)
		_driver.start()
		_sampler = TraversalLine.Sampler.new(_game)
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	_sampler.sample()
	if over or _sampler.engaged or _ticks > TICK_LIMIT:
		_check_measure()
		_check_limits()
		_check_run_log()
		_game.free()
		_game = null
		_start_park()
	return false


# --- The park measure (PARK.md section 8) ---

var _plant_lines := {}
var _plant_waymarks: Array = []


func _start_park() -> void:
	_phase = "park"
	_driver = null
	_sampler = null
	_ticks = 0
	_check_pilots()
	_check_fixture_lines()
	_check_summary()
	_check_floor_hands()
	_t.check("the fixture replaces the park table's first stage", TraversalLine.use_fixture(), "park_defs stage 1 map now park_test")
	var lines := TraversalLine.load_lines(FIXTURE_LINES)
	var planted: Dictionary = lines.duplicate(true)
	if planted.has("pilots") and planted["pilots"].has("sable"):
		var points: Array = planted["pilots"]["sable"]["waypoints"]
		points.insert(1, PLANT_POINT)
	_plant_lines = planted
	var park: Dictionary = ParkSchema.read_file(FIXTURE_PARK)
	var errors := ParkSchema.validate_lines(planted, park)
	_t.check("the planted line still passes the schema", errors.is_empty(), ParkSchema.describe(errors))
	seed(1)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)


func _park_tick(delta: float) -> bool:
	if _game.flow == null:
		return false
	if _driver == null:
		_t.eq("the fixture loads as the park table's stage 1", String(_game.ctx.terrain.map_for(1).title), "park_test")
		var park: Dictionary = ParkSchema.read_file(FIXTURE_PARK)
		var line := TraversalLine.line_of(_plant_lines, "sable", park)
		_plant_waymarks = line["waymarks"]
		_driver = BotDriver.new(_game, "traversal", 1)
		_driver.class_index = BotDriver.class_index_for(1, PILOT_CLASSES["sable"])
		_driver.route = line["route"]
		_driver.start()
		_sampler = TraversalLine.Sampler.new(_game)
		_sampler.setup_park(_plant_waymarks, TraversalLine.open_graph("park_test"))
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	_sampler.sample()
	if over or _sampler.engaged or _ticks > PARK_TICK_LIMIT or _sampler.traversal.dead_stops > 0 and _ticks > 90 * 3:
		_check_planted()
		_game.free()
		_game = null
		TraversalLine.restore_park_defs()
		_phase = "done"
		quit(_t.verdict())
		return true
	return false


func _check_pilots() -> void:
	var roster := {}
	for row in ClassDef.all():
		roster[row.id] = true
	_t.eq("six park pilot keys", TraversalLine.PARK_PILOTS.keys(), PILOT_CLASSES.keys())
	var wrong: Array = []
	for key in PILOT_CLASSES:
		if TraversalLine.PARK_PILOTS.get(key) != PILOT_CLASSES[key] or not roster.has(PILOT_CLASSES[key]):
			wrong.append(key)
	_t.check("each pilot key names its class_def id", wrong.is_empty(), "wrong %s" % [wrong])


func _check_fixture_lines() -> void:
	var lines := TraversalLine.load_lines(FIXTURE_LINES)
	var park: Dictionary = ParkSchema.read_file(FIXTURE_PARK)
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


# The summary on made-up rows: each band row is named, and its verdict follows the median.
func _check_summary() -> void:
	var runs: Array = []
	for i in 8:
		runs.append({"seed": i + 1, "flow_share": 0.8, "dead_stops": 0, "max_anchor_gap_m": 20.0, "time_to_warden_s": 90.0,
			"reached_warden": true, "path_length_m": 1500.0, "rides": ["ride_chute"], "uphill_m": 2.0, "outcome": "engaged", "ticks": 8100,
			"airborne_share": 0.05, "peak_speed_mps": 30.0, "tier3_s": 4.0, "segment_s": 30.0, "segments_s": [20.0, 30.0, 25.0],
			"quiet_max_s": 12.0, "distinct_verbs": 4, "verbs": ["jump", "boost", "ride_chute", "kicker_launch"], "progress_m": null,
			"length_ratio": 1.5, "dead_stop_at": []})
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
	var absent: Array = PARK_FIELDS.filter(func(f): return f in ["airborne_share", "peak_speed_mps", "tier3_s", "segment_s", "quiet_max_s", "distinct_verbs"] and not medians.has(f))
	_t.check("the summary carries each new measure's median", absent.is_empty(), "missing %s" % [absent])


# The floor line's hands: only the stick (and the brake) survive the filter.
func _check_floor_hands() -> void:
	var hold := {"move": Vector2(0, 1), "brake_held": true, "fire_held": true, "harpoon_held": true, "boost_held": true, "smash_held": true}
	var press := {"jump_pressed": true, "special_pressed": true, "boost_pressed": true}
	var kept := TraversalLine.floor_hands(hold, press)
	_t.eq("the floor bot keeps only move and brake", [kept["hold"].keys(), kept["press"].keys()], [["move", "brake_held"], []])


func _check_planted() -> void:
	var run: Dictionary = _sampler.result(1, "engaged" if _sampler.engaged else _driver.outcome)
	var gone: Array = PARK_FIELDS.filter(func(f): return not run.has(f))
	_t.check("the park seed row has every new field", gone.is_empty(), "missing %s" % [gone])
	var share := float(run.get("airborne_share", -1.0))
	_t.check("airborne share lies in 0 to 1 and peak speed is a speed", share >= 0.0 and share <= 1.0 and float(run.get("peak_speed_mps", -1.0)) > 0.0,
		"airborne %s, peak %s m/s, tier 3 %s s, quiet max %s s, verbs %s" % [share, run.get("peak_speed_mps"), run.get("tier3_s"), run.get("quiet_max_s"), run.get("verbs")])
	_t.check("the planted wall point makes the run report a dead stop", int(run.get("dead_stops", 0)) >= 1 and (run.get("dead_stop_at", []) as Array).size() >= 1,
		"dead stops %s at %s over %d ticks, outcome %s" % [run.get("dead_stops"), run.get("dead_stop_at"), _ticks, run.get("outcome")])
	var doc := TraversalLine.park_document("sable", "park_test", 0, "test", [run], {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}, {})
	var dead_band := {}
	for row in doc.get("bands", []):
		if row.get("measure") == "dead_stops":
			dead_band = row
	_t.eq("the dead-stop band goes red on the planted line", dead_band.get("inside"), false)
	_t.check("without graph.bin progress reads null and the sampler says so once",
		run.get("progress_m", "absent") == null and _sampler.graph_note != "" and TraversalLine.graph_notes == 1,
		"progress %s, note '%s', notes %s" % [run.get("progress_m", "absent"), _sampler.graph_note, TraversalLine.graph_notes])


func _check_measure() -> void:
	var run: Dictionary = _sampler.result(1, "engaged" if _sampler.engaged else _driver.outcome)
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
