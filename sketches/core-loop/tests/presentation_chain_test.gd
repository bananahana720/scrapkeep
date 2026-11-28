extends SceneTree

const Game := preload("res://src/game.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

# Kills pop and pickups feel greedy (v3 W11), through the real game. Kills inside the
# chain window climb the kill chain: the pop climbs the pentatonic and a pip per kill
# shows over the ball; a gap longer than the window starts it over and hides the pips.
# Three kills in one frame are a multi-kill with its extra beat. Scrap inside its window
# climbs in pitch piece by piece, and each piece swells the shell. Every kill gets a pop
# and a debris burst from the pools.

# Audio and juice currently pass wall time to Streak. This adapter replaces only
# that input; bump/live and the row's window/cap still use the production rule.
class ClockedStreak extends "res://src/presentation/streak.gd":
	var now: Callable

	func bump(_now_ms: int) -> int:
		return super.bump(int(now.call()))

	func live(_now_ms: int) -> bool:
		return super.live(int(now.call()))


func _clocked_streak(kind: String) -> RefCounted:
	var streak := ClockedStreak.new()
	var row := EventJuice.juice(kind)
	streak.window_ms = int(row.get("chain_ms", 700))
	streak.cap = int(row.get("chain_cap", 9))
	streak.now = func() -> int: return int(_clock_ms)
	return streak


var _game
var _audio
var _juice
var _vfx
var _failures := 0
var _clock_ms := 0.0
var _t0 := 0
var _plan: Array = []
var _marks := {}
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	_clock_ms += 1000.0 / Engine.physics_ticks_per_second
	if _game == null or _game.flow == null:
		return false
	var events = _game.events
	if _audio == null:
		_game.tuning.set_option("music", "synth")
		_audio = _game.presentation.audio
		_audio.bake_now()
		_audio.set_process(false)
		# Keep production streak rules, with every caller reading the same sim tick.
		_audio.kill_streak = _clocked_streak("enemy_killed")
		_audio.scrap_streak = _clocked_streak("scrap_collected")
		_juice = _game.presentation.juice
		_juice.set_process(false)
		_vfx = _game.presentation.vfx
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_t0 = int(_clock_ms)
		var at: Vector3 = _game.player.ball_position() + Vector3(0.0, 0.0, -5.0)
		_marks["rungs"] = []
		for i in 5:
			_plan.append([100 + i * 150, func():
				# Simulated gaps expire the voice gate without waiting for the device.
				_audio.stop("kill_pop")
				_audio._last_start.erase("kill_pop")
				events.enemy_killed.emit("chaser", at, 1)
				_juice.flush()
				_marks["rungs"].append(_audio.kill_streak.rung)])
		_plan.append([850, func(): _marks["pips"] = _vfx.chain_pips()])
		var window := int(EventJuice.juice("enemy_killed")["chain_ms"])
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
				var logged: int = _audio.cue_log_total
				events.scrap_collected.emit(1, _game.player.ball_position(), i + 1)
				# A pickup can also pay off a held part (reward_payoff's bell, or the next card's
				# reveal), logged after the tick, so read this pickup's own tick, not the last cue.
				var ticks: Array = _audio.cues_since(logged).filter(func(e: Array): return e[0] == "scrap_collected")
				_marks["pitches"].append(ticks[0][4] if not ticks.is_empty() else 0.0)
				_marks["shell_v"].append(_juice._shell_velocity - before)])
		_plan.append([850 + window + 1200, func(): pass])
		return false
	_juice._process(1.0 / Engine.physics_ticks_per_second)
	var elapsed := int(_clock_ms) - _t0
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
		"a kill after a %d ms gap is rung %d of a run of %d; %d pips shown" % [EventJuice.juice("enemy_killed")["chain_ms"], _marks["reset"][0], _marks["reset"][1], _marks["reset_pips"]])
	# The chain grows by its tier layer, not by the pop's pitch (SOUND-BIBLE rule 7, PR 947): every pop
	# keeps its own pitch, and each link past the first adds the next, heavier tier.
	var kill_pitches: Array = _audio.cue_log.filter(func(e: Array): return e[0] == "enemy_killed" and e[1] == "kill_pop").map(func(e: Array): return snappedf(e[4], 0.001))
	var tiers: Array = _audio.cue_log.filter(func(e: Array): return e[0] == "enemy_killed" and String(e[1]).begins_with("kill_chain_tier_")).map(func(e: Array): return e[1])
	_check("chain grows", kill_pitches.size() >= 5 and kill_pitches.slice(0, 5).all(func(p): return p == kill_pitches[0])
		and tiers.slice(0, 4) == ["kill_chain_tier_1", "kill_chain_tier_2", "kill_chain_tier_3", "kill_chain_tier_4"],
		"kill pops by pitch %s; tier layers %s" % [kill_pitches.slice(0, 6), tiers.slice(0, 6)])
	var multi: Array = _marks["multi"]
	_check("multi-kill beat", multi.size() == 1 and multi[0][0] == 2,
		"three kills in one frame: extra beats %s" % [multi])
	var scrap: Array = _marks["pitches"]
	# A pickup that logged no tick of its own reads 0.0 and fails the climb.
	var climbing := scrap.size() == 6 and scrap.all(func(p: float): return p > 0.0)
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
	# FX-01: a kill pops as its own mark (Vfx.kill_look counts it as enemy_killed), shards and debris.
	_check("kill bursts", bursts.get("enemy_killed", 0) >= 9 and bursts.get("burst_debris", 0) >= 9,
		"%d kill marks and %d debris bursts for 9 kills" % [bursts.get("enemy_killed", 0), bursts.get("burst_debris", 0)])
	print("presentation_chain_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
