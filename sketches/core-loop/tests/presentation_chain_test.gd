extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

# Kills pop and pickups feel greedy (v3 W11), through the real game. Kills inside the
# chain window climb the kill chain: the pop climbs the pentatonic and a pip per kill
# shows over the ball; a gap longer than the window starts it over and hides the pips.
# Three kills in one frame are a multi-kill with its extra beat. Scrap inside its window
# climbs in pitch piece by piece, and each piece swells the shell. Every kill gets a pop
# and a debris burst from the pools.

var _game
var _audio
var _juice
var _vfx
var _failures := 0
var _t0 := 0
var _plan: Array = []
var _marks := {}
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var events = _game.events
	if _audio == null:
		_audio = _game.presentation.audio
		_juice = _game.presentation.juice
		_vfx = _game.presentation.vfx
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_t0 = Time.get_ticks_msec()
		var at: Vector3 = _game.player.ball_position() + Vector3(0.0, 0.0, -5.0)
		_marks["rungs"] = []
		for i in 5:
			_plan.append([100 + i * 150, func():
				events.enemy_killed.emit("chaser", at, 1)
				_juice.flush()
				_marks["rungs"].append(_audio.kill_streak.rung)])
		_plan.append([850, func(): _marks["pips"] = _vfx.chain_pips()])
		var window := int(EventKinds.juice("enemy_killed")["chain_ms"])
		_plan.append([850 + window + 150, func():
			events.enemy_killed.emit("chaser", at, 1)
			_juice.flush()
			_marks["reset"] = [_audio.kill_streak.rung, _audio.kill_streak.length]])
		_plan.append([850 + window + 250, func(): _marks["reset_pips"] = _vfx.chain_pips()])
		_plan.append([850 + window + 450, func():
			var before: int = _juice.multi_log.size()
			for i in 3:
				events.enemy_killed.emit("chaser", at, 1)
			_juice.flush()
			_marks["multi"] = _juice.multi_log.slice(before)])
		# The field's own scrap is cleared so the rolling ball cannot join the streak.
		_plan.append([850 + window + 700, func():
			_game.build.scrap.clear()
			_audio.scrap_streak.reset()
			_marks["pitches"] = []
			_marks["shell_v"] = []])
		for i in 6:
			_plan.append([850 + window + 750 + i * 60, func():
				_audio._last_start.clear()
				var before: float = _juice._shell_velocity
				events.scrap_collected.emit(1, _game.player.ball_position(), i + 1)
				_marks["pitches"].append(_audio.cue_log.back()[4])
				_marks["shell_v"].append(_juice._shell_velocity - before)])
		_plan.append([850 + window + 1200, func(): pass])
		return false
	var elapsed := Time.get_ticks_msec() - _t0
	while not _plan.is_empty() and elapsed >= _plan[0][0]:
		var item: Array = _plan.pop_front()
		(item[1] as Callable).call()
	if not _plan.is_empty() or _done:
		return false
	_done = true
	var rungs: Array = _marks["rungs"]
	_check("chain climbs", rungs == [0, 1, 2, 3, 4] and _marks["pips"] == 5,
		"five kills 150 ms apart climb rungs %s; %d pips over the ball" % [rungs, _marks["pips"]])
	_check("chain resets", _marks["reset"] == [0, 1] and _marks["reset_pips"] == 0,
		"a kill after a %d ms gap is rung %d of a run of %d; %d pips shown" % [EventKinds.juice("enemy_killed")["chain_ms"], _marks["reset"][0], _marks["reset"][1], _marks["reset_pips"]])
	var kill_pitches: Array = _audio.cue_log.filter(func(e: Array): return e[0] == "enemy_killed" and e[1] == "kill_pop").map(func(e: Array): return snappedf(e[4], 0.001))
	_check("chain sings", kill_pitches.size() >= 5 and kill_pitches[1] > kill_pitches[0] and kill_pitches[4] > kill_pitches[3],
		"kill pops by pitch %s" % [kill_pitches.slice(0, 6)])
	var multi: Array = _marks["multi"]
	_check("multi-kill beat", multi.size() == 1 and multi[0][0] == 2,
		"three kills in one frame: extra beats %s" % [multi])
	var scrap: Array = _marks["pitches"]
	var climbing := scrap.size() == 6
	for i in range(1, scrap.size()):
		climbing = climbing and scrap[i] > scrap[i - 1]
	var steps: Array = []
	for pitch in scrap:
		steps.append(snappedf(12.0 * log(pitch) / log(2.0), 0.1))
	var swells: Array = _marks["shell_v"]
	var swelling: bool = swells.size() == 6 and swells.all(func(v: float): return v > 0.0) and swells[5] >= swells[0]
	_check("pickup streak climbs", climbing and swelling,
		"six pieces 60 ms apart tick at %s semitones; each swells the shell by %s" % [steps, swells.map(func(v: float): return snappedf(v, 0.01))])
	var bursts: Dictionary = _vfx.spawned
	_check("kill bursts", bursts.get("burst_pop", 0) >= 9 and bursts.get("burst_debris", 0) >= 9,
		"%d pops and %d debris bursts for 9 kills" % [bursts.get("burst_pop", 0), bursts.get("burst_debris", 0)])
	print("presentation_chain_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
