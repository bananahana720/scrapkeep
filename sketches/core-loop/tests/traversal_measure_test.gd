extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const RunLog := preload("res://src/core/run_log.gd")
const T := preload("res://tests/support/t.gd")

# One short traversal of the Cable Reach on the slice table (design-v3/TRAVERSAL.md): the
# measure's JSON carries every field, flow share lies in 0 to 1, and the human-shaped bot
# keeps its limits (no reaction under 150 ms, no two verbs inside 0.4 s). Then the run log
# counts what the harpoon's bus signals report, on this same real game.

const TICK_LIMIT := 90 * 40
const FIELDS := ["seed", "flow_share", "dead_stops", "max_anchor_gap_m", "time_to_warden_s", "reached_warden", "path_length_m", "rides", "uphill_m", "outcome", "ticks"]
const DOCUMENT_FIELDS := ["pilot", "table", "commit", "bar", "runs", "median_flow_share", "worst_seed", "dead_stops_total", "max_anchor_gap_m", "reached_warden", "median_path_length_m", "median_uphill_m", "median_rides"]

var _t := T.new("traversal_measure_test")
var _game
var _driver
var _sampler
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
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
		quit(_t.verdict())
		return true
	return false


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
	_t.eq("prompts shown", int(record.get("prompts_shown", -1)), 0)
	var share = record.get("flow_share")
	_t.check("flow share and dead stops ride the record", share is float and share >= 0.0 and share <= 1.0 and record.has("dead_stops"),
		"flow share %s, dead stops %s" % [share, record.get("dead_stops")])
	var stage: Dictionary = record["stages"][0] if record.get("stages") is Array and (record["stages"] as Array).size() > 0 else {}
	_t.eq("only the opt-in event was joined", stage.get("events_joined"), ["surge_run"])
