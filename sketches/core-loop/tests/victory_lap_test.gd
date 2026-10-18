# smoke: solo (plays the Mind's arena, the 60 s victory lap and the credits in simulated time)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Combat := preload("res://src/combat/combat.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const VictoryLap := preload("res://src/world/victory_lap.gd")
const T := preload("res://tests/support/t.gd")

# Rule (src/world/victory_lap.gd, src/core/flow.gd _begin_ending; Andrew's design answer Q16 "60 s free roll"): after
# the Mind falls and the crew's fly-over hands over (the bot skips it, as screens.gd lets a bot), a bot-driven ball
# rolls Meteor Crater with no damage source anywhere (no fight group node, no arena,
# hit points never fall) and the credits roll over the bowl within 60 s of the lap starting. The run is won and the
# save cleared before the fly-over; any key skips the credits to the summary.
#
# Evidence limit: one seed and one pilot (Rivet, the skipper's seed 1), the bot driver's lap policy, simulated time.
# It says nothing about feel or frame time on Andrew's 4080.

const SEED := 1
const FIGHT_SECONDS := 4.0
const TICK_LIMIT := 120 * 60

var _game
var _driver
var _t := T.new("victory_lap_test")
var _ticks := 0
var _phase := "boot"
var _clock := 0.0
var _hazards_before := 0
var _hp := 0.0
var _lap_ticks := 0
var _credits_at := -1.0
var _worst_fight := 0
var _hp_low := INF
var _arena_seen := false
var _lap
var _stats := {}
var _prelude_seen := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _phase == "done" or _game.flow == null:
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_t.check("finished inside the tick limit", false, "phase %s" % _phase)
		return _finish()
	match _phase:
		"boot":
			_driver = BotDriver.new(_game, "skipper", SEED)
			_driver.start()
			_phase = "start"
		"start":
			if _game.flow.state_name() == "stage" and _game.run.stage == 1:
				_game.flow.enter_stage(StageDefs.COUNT, Vector3(0.0, 0.0, 14.0), false)
				_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
				_phase = "fight"
				_clock = 0.0
			else:
				_driver.tick(delta)
		"fight":
			_clock += delta
			_driver.tick(delta)
			if _clock >= FIGHT_SECONDS:
				_t.eq("the Mind's arena runs before the win", _game.flow.state_name(), "boss")
				_t.eq("the final boss is the Mind", String(_game.flow.boss_row(_game.ctx.stages.world_of(_game.run.stage)).get("music", "")), "mind")
				_arena_seen = _arena_live()
				_hazards_before = _fight_nodes()
				_game.events.boss_defeated.emit()
				_phase = "victory"
		"victory":
			var seq = _game.screens.ending_sequence
			if is_instance_valid(seq) and seq.active and seq.prelude and not _prelude_seen:
				_prelude_seen = true
				_t.eq("the crew's fly-over opens the ending", seq.phase, "flyover")
				_t.check("the win is recorded before the fly-over", _game.flow.run_won and _game.run.over)
				_t.check("the ball waits frozen through the fly-over", _game.player.frozen())
			if _game.flow.state_name() == "lap":
				_lap_begins()
				_phase = "lap"
		"lap":
			_lap_tick()
		"credits":
			_credits_tick()
	return false


func _lap_begins() -> void:
	_lap = _game.flow.lap
	_hp = float(_game.run.hp)
	_t.check("fixture: the Mind's arena was built", _arena_seen)
	_t.check("the fly-over played before the lap", _prelude_seen)
	_t.check("the fly-over is gone", not is_instance_valid(_game.screens.ending_sequence))
	print("victory_lap_test: %d fight nodes before the win" % _hazards_before)
	_t.check("the lap has its bowl", is_instance_valid(_lap) and _lap.crater != null)
	_t.check("the arena and its Warden are gone", not _arena_live())
	_t.check("the run is won when the lap starts", _game.flow.run_won and _game.run.over)
	_t.check("no Continue survives the win", _game.flow.saved_run().is_empty())
	_t.check("the ball is live", not _game.player.frozen())
	_t.check("the ball starts over the rim", _game.player.ball_position().distance_to(_lap.entry_point()) < 4.0,
		"%s vs %s" % [_game.player.ball_position(), _lap.entry_point()])


func _lap_tick() -> void:
	_lap_ticks += 1
	_worst_fight = maxi(_worst_fight, _fight_nodes())
	_hp_low = minf(_hp_low, float(_game.run.hp))
	if _game.flow.state_name() == "lap":
		_driver._lap_roll()
		if is_instance_valid(_lap):
			_stats = _lap.stats()
		return
	var seq = _game.screens.ending_sequence
	_credits_at = float(_lap_ticks) / float(Engine.physics_ticks_per_second)
	_t.eq("the lap closes on the summary", _game.flow.state_name(), "summary")
	_t.check("the credits roll", is_instance_valid(seq) and seq.active and seq.phase == "credits",
		"sequence %s" % (seq.phase if is_instance_valid(seq) else "missing"))
	_t.check("credits within 60 s of the lap starting", _credits_at <= VictoryLap.SECONDS + 0.05, "%.2f s" % _credits_at)
	_t.check("no fight node during the lap (Mind's arena had %d)" % _hazards_before, _worst_fight == 0, "%d" % _worst_fight)
	_t.check("hit points never fell during the lap", _hp_low >= _hp, "%.1f from %.1f" % [_hp_low, _hp])
	_t.check("the lap is freed", not is_instance_valid(_lap))
	_t.check("the bot carried speed in the bowl", float(_stats.get("top_speed", 0.0)) >= 20.0, "%s" % [_stats])
	_t.check("the vent threw the bot into the air", int(_stats.get("vent_shots", 0)) >= 1 and float(_stats.get("best_air", 0.0)) >= VictoryLap.AIR_WORD,
		"%s" % [_stats])
	_t.check("the credits carry the lap", is_instance_valid(seq) and seq._credits.text.contains("Victory lap"))
	print("victory_lap_test: credits at %.2f s; lap stats %s" % [_credits_at, _stats])
	_clock = 0.0
	_phase = "credits"


func _credits_tick() -> void:
	var seq = _game.screens.ending_sequence
	_clock += 1.0 / Engine.physics_ticks_per_second
	if _clock < 1.0:
		return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	_game.screens._input(key)
	_t.check("any key skips the credits", not is_instance_valid(seq) or not seq.active)
	_t.eq("the summary stays", _game.flow.state_name(), "summary")
	_finish()


# The Mind fights on the stub's pad with a choir Warden (stub_boss.gd); a ship boss keeps an arena.
func _arena_live() -> bool:
	var boss = _game.ctx.boss
	return is_instance_valid(boss.get("pad")) or is_instance_valid(boss.get("arena")) or is_instance_valid(boss.get("warden"))


func _fight_nodes() -> int:
	var count := 0
	for group in Combat.FIGHT_GROUPS:
		count += get_nodes_in_group(group).size()
	return count


func _finish() -> bool:
	_phase = "done"
	_game.free()
	quit(_t.verdict())
	return true
