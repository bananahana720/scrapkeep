extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const RunLog := preload("res://src/core/run_log.gd")
const T := preload("res://tests/support/t.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# loop_bot_test for another class (v2 W3). The feedback loop's bot, end to end
# (DEMO-SPEC, "Bot runs"): one seeded skipper run
# through the real game, in play (not calm), breaks stage 1's Warden, takes a gate and
# launches into stage 2. The run log writes only at a death or a run end, so once stage
# 2 is entered the test ends the run the way spine_run_log_test does, with a lethal
# run.damage, and reads back the one line it wrote. The line must carry stage 1 whole.
#
# Evidence limit: this proves the bot drives the real flow and the log is readable; it
# says nothing about feel. Test mode keeps the logs in its per-process folder.

# Seed 2 plays Kest (the bot picks the class by seed modulo the three rows); seed 0,
# in char_bot_sable_test, plays Sable; loop_bot_test's seed 1 plays Rivet.
const SEED := 2
const TICK_LIMIT := 90 * 100

var _game
var _driver
var _t: RefCounted
var _ticks := 0
var _cleared: Array[int] = []
var _done := false


func _initialize() -> void:
	_t = T.new(get_script().resource_path.get_file().get_basename())
	# A seeded run replays only on the tick clock with the run named by its seed, as tools/bot_run.gd sets both.
	# Until 15 Nov 2026 this run kept the wall clock and a clock-made run id, and one seed broke stage 1's
	# Warden at 4050 to 6438 ticks across five launches of one commit.
	SimClock.ticks = true
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _seed() -> int:
	return SEED


# Subclasses set the driver up before it starts (tree_bot_run picks a random branch)
# and add their own checks before the verdict.
func _configure(_driver_ref) -> void:
	pass


func _extra_checks() -> void:
	pass


func _report(label: String, ok: bool, detail: String) -> void:
	_t.check(label, ok, detail)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_game.run.run_seed_override = _seed()
		_driver = BotDriver.new(_game, "skipper", _seed())
		_game.events.stage_cleared.connect(func(stage: int): _cleared.append(stage))
		_configure(_driver)
		_driver.start()
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	# stage 2 means "the second stage", whatever the table size, so the literal stays
	var in_stage_two: bool = _game.run.stage == 2 and _game.flow.state_name() == "stage"
	if in_stage_two or over or _ticks > TICK_LIMIT:
		return _finish(in_stage_two)
	return false


func _finish(reached: bool) -> bool:
	_done = true
	var seconds := float(_ticks) / float(Engine.physics_ticks_per_second)
	_report("stage 1 cleared", reached and _cleared == [1],
		"skipper seed %d as %s: cleared %s, now stage %d in %s after %.1f s (bot outcome '%s', limit %d s)"
			% [_seed(), _driver.class_id(), _cleared, _game.run.stage, _game.flow.state_name(), seconds, _driver.outcome, TICK_LIMIT / 90])
	if reached:
		_game.run.damage(9999.0, "test")
	var path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	var record = JSON.parse_string(lines[0]) if lines.size() == 1 else null
	var ok: bool = record is Dictionary
	_report("one line", ok, "%d line(s) in the run log" % lines.size())
	var stages: Array = record.get("stages", []) if ok else []
	var first: Dictionary = stages[0] if stages.size() > 0 and stages[0] is Dictionary else {}
	var header: bool = ok and record.get("run_id") == _game.run.run_id and record.get("class") == _driver.class_id() \
		and record.get("outcome") == "died" and record.get("codex") is Array and record.has("brindle_phase_reached") \
		and record["brindle_phase_reached"] == null
	_report("record header", header, "run_id %s, class %s, outcome %s, codex %s"
		% [record.get("run_id", "?") if ok else "?", record.get("class", "?") if ok else "?",
			record.get("outcome", "?") if ok else "?", record.get("codex", "?") if ok else "?"])
	var parts: Array = first.get("part_ids_at_exit", []) if first.get("part_ids_at_exit") is Array else []
	var ticks_to_break = first.get("ticks_to_warden_break")
	var heft = first.get("heft_at_exit")
	var stage_one: bool = int(first.get("stage", 0)) == 1 and ticks_to_break != null and float(ticks_to_break) > 0.0 \
		and heft != null and float(heft) >= 1.0 and parts.size() >= 1 and first.get("deaths") is Array \
		and (first["deaths"] as Array).is_empty() and first.get("events_joined") is Array and first.get("events_won") is Array \
		and first.has("bonus_cores")
	_report("stage 1 record", stage_one, "Warden broken at %s ticks (%.1f s), heft %s at exit, parts %s, bonus cores %s, events %s"
		% [ticks_to_break, float(ticks_to_break if ticks_to_break != null else 0) / 90.0, heft, parts,
			first.get("bonus_cores", "?"), first.get("events_joined", "?")])
	var second: Dictionary = stages[1] if stages.size() > 1 and stages[1] is Dictionary else {}
	# the bot ends in the second stage, so the record holds stage 1 and stage 2 whatever the table size; 2 is a count of visited stages, not the table size
	var death_logged: bool = stages.size() == 2 and int(second.get("stage", 0)) == 2 and second.get("deaths") is Array \
		and (second["deaths"] as Array).size() == 1
	_report("death carried", death_logged, "%d stage record(s); stage 2 deaths %s" % [stages.size(), second.get("deaths", "none")])
	_extra_checks()
	print("%s: seed %d" % [_t.suite, _seed()])
	_game.free()
	quit(_t.verdict())
	return true
