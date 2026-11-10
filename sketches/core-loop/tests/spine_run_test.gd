extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const T := preload("res://tests/support/t.gd")

# A scripted full run through the real flow: title, class, then for each stage the
# beacon, a reward gate and the launch, ending on the summary. The ball is placed at
# the beacon and aimed at a gate rather than steered across the map, and ctx.calm
# keeps enemies and the flood out, so the speed checks measure the seams alone. All six
# stages run in one pass; the first boss also takes the death, retry and victory checks,
# the other two are defeated on a settle delay.

const BEACON_SECONDS := 0.6
const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const TOLERANCE := 0.15
const SETTLE_TICKS := 9
const TICK_LIMIT := 90 * 150

var _game
var _source := Intent.Scripted.new()
var _t := T.new("spine_run_test")
var _ticks := 0
var _started := false
var _done := false

var _states: Array[String] = []
var _entered: Array[int] = []
var _cleared: Array[int] = []
var _ended := false
var _phase := "boot"
var _offer := {}
var _gate := {}
var _launch := {}
var _gates: Array[Dictionary] = []
var _launches: Array[Dictionary] = []
var _wait := 0
var _boss
var _arena := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if not _started:
		if _game.flow == null:
			return false
		_start()
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_report("timeout", false, "run stalled in flow state %s, phase %s" % [_game.flow.state_name(), _phase])
		return _finish()
	_step()
	return false


func _start() -> void:
	_started = true
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
	_game.flow.victory_lap = false
	var events = _game.events
	events.flow_changed.connect(func(s: String): _states.append(s))
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(stage: int): _cleared.append(stage))
	events.run_ended.connect(func(_won: bool): _ended = true)
	events.reward_offered.connect(_on_offered)
	events.reward_chosen.connect(_on_chosen)
	_boss = BossDouble.new()
	_game.add_child(_boss)
	_boss.setup(_game.ctx)
	events.stage_cleared.connect(func(_stage: int): if not _arena.has("after"): _arena["before"] = _planar())
	_game.ctx.calm = true
	_game.flow.beacon_seconds_override = BEACON_SECONDS
	_game.player.source = _source
	_states.append(_game.flow.state_name())
	_game.flow.press_start()
	_game.flow.choose_class(_class_index())


# The class to run as: 0 by default; char_full_run_test passes "--class=N" to cover the
# others through this same scripted run.
static func _class_index() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			return int(arg.trim_prefix("--class="))
	return 0


func _planar() -> float:
	return _game.player.planar_velocity().length()


func _step() -> void:
	var flow = _game.flow
	match _phase:
		"to_beacon":
			_wait += 1
			if _wait == 2:
				var at: Vector3 = flow.beacon.global_position + Vector3.UP * 1.5
				_game.player.reset_to(at)
				_game.player.body().global_position = at
		"approach":
			var rel: Vector3 = _game.player.ball_position() - _offer["at"]
			var along: float = rel.dot(_offer["facing"])
			if along < -1.5:
				_gate["before"] = _planar()
		"after_gate":
			_wait += 1
			if _wait == SETTLE_TICKS:
				_gate["after"] = _planar()
				_gates.append(_gate)
				_phase = "flight"
				_wait = 0
		"entered":
			_wait += 1
			if _wait == SETTLE_TICKS:
				_launch["after"] = _planar()
				_launches.append(_launch)
				_launch = {}
				_phase = "to_beacon"
				_wait = 0
		"flight":
			if flow.state_name() == "boss" and _arena.has("after_defeat"):
				_wait += 1
				if _wait == SETTLE_TICKS:
					_boss.defeat()
			elif flow.state_name() == "boss" and _boss.entries == 1:
				_wait += 1
				if _wait == SETTLE_TICKS:
					_arena["after"] = _planar()
					_arena["hp"] = _game.run.hp
					_game.run.damage(99999.0, "test")
					_arena["dead_text"] = _game.screens.body_text()
					_arena["dead_state"] = flow.state_name()
					flow.retry_stage()
					_arena["retried_state"] = flow.state_name()
					_arena["retried_hp"] = _game.run.hp
					_boss.defeat()
					_arena["after_defeat"] = flow.state_name()
			if _ended:
				_phase = "summary"
		"summary":
			_finish()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_entered.append(stage)
	_source.hold = {}
	if stage > 1:
		_launch["stage"] = stage
		_launch["before"] = _planar()
		_phase = "entered"
		_wait = 0
	else:
		_phase = "to_beacon"
		_wait = 0


func _on_offered(offers: Array) -> void:
	if _phase == "approach":
		return
	_offer = offers[0]
	var facing: Vector3 = _offer["facing"]
	var start: Vector3 = _offer["at"] - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_gate = {"stage": _game.run.stage, "part": _offer["part_id"], "before": APPROACH_SPEED}
	_phase = "approach"


func _on_chosen(part_id: String) -> void:
	_gate["chosen"] = part_id
	_phase = "after_gate"
	_wait = 0


func _report(label: String, ok: bool, detail: String) -> void:
	_t.check(label, ok, detail)


# Only a loss counts against momentum: a gain, such as the launch rail easing a slow
# ball up to cruise, is a gift.
static func _kept(before: float, after: float) -> bool:
	return before > 0.1 and (before - after) / before <= TOLERANCE


func _finish() -> bool:
	_done = true
	var wanted := ["title", "class_select", "stage", "beacon", "gates", "launch", "boss", "dead", "victory", "summary"]
	var missing: Array[String] = []
	for s in wanted:
		if not s in _states:
			missing.append(s)
	_report("flow states", missing.is_empty() and _states[0] == "title" and _states[-1] == "summary",
		"reached %s in order %s; missing %s" % [wanted, " > ".join(_states), missing])
	var every: Array[int] = []
	for i in StageDefs.COUNT:
		every.append(i + 1)
	_report("stages", _entered == every and _cleared == every and _ended,
		"entered %s, cleared %s, run_ended %s" % [_entered, _cleared, _ended])
	_report("summary", _game.flow.state_name() == "summary" and _game.run.parts.size() >= StageDefs.COUNT,
		"flow ends in %s with %d parts (one per gate, plus any evolution) %s" % [_game.flow.state_name(), _game.run.parts.size(), _game.run.parts])
	for g in _gates:
		_report("gate momentum stage %d" % g["stage"], g.has("after") and _kept(g["before"], g["after"]),
			"rolled through the %s gate at %.2f m/s horizontal, %.2f m/s after (within %d%%)"
				% [g.get("chosen", "?"), g["before"], g.get("after", -1.0), int(TOLERANCE * 100.0)])
	_report("gates taken", _gates.size() == StageDefs.COUNT, "%d of %d gates taken" % [_gates.size(), StageDefs.COUNT])
	for l in _launches:
		_report("launch momentum into stage %d" % l["stage"], _kept(l["before"], l["after"]),
			"left at %.2f m/s horizontal, %.2f m/s after entering (within %d%%)"
				% [l["before"], l["after"], int(TOLERANCE * 100.0)])
	_report("launches", _launches.size() == StageDefs.COUNT - 1, "%d stage-to-stage launches measured" % _launches.size())
	var text: String = _arena.get("dead_text", "")
	_report("arena entry momentum", _kept(_arena.get("before", 0.0), _arena.get("after", 0.0)) and _boss.entry_speeds.size() >= 1,
		"left stage 2 at %.2f m/s horizontal, %.2f m/s in the arena" % [_arena.get("before", -1.0), _arena.get("after", -1.0)])
	_report("boss death screen", _arena.get("dead_state", "") == "dead" and text.contains("N   new run") and text.contains("T   replay stage 2")
			and not text.contains("R   ") and text.begins_with("Scrapped by "),
		"death in the arena reads \"%s\"" % text.replace("\n", " | "))
	_report("arena retry and victory", _arena.get("retried_state", "") == "boss" and _boss.entries == 2 and _arena.get("retried_hp", 0.0) == _arena.get("hp", -1.0)
			and _arena.get("after_defeat", "") == "victory",
		"R put flow back in %s (arena entry %d) at hp %.0f; boss_defeated led to %s, then summary"
			% [_arena.get("retried_state", "?"), _boss.entries, _arena.get("retried_hp", -1.0), _arena.get("after_defeat", "?")])
	print("spine_run_test class: %s, %d checks" % [_game.run.class_id(), _t.checks])
	_game.free()
	if _t.failures == 0:
		print("spine_run_test: PASS")
		quit(0)
	else:
		quit(_t.verdict())
	return true
