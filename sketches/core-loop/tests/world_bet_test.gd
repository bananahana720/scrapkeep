extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BetCrate := preload("res://src/world/bet_crate.gd")
const Interact := preload("res://src/world/interact.gd")

# The double-or-nothing crate on stage 1's bowl bank (LOOP-REDESIGN section 9), in the
# running game as Rivet in calm. With no core it is not ready: the dial shows, the
# keycap does not, and a held E does nothing. Locked with two cores, the prompt names
# the stake before the hold. A held E stakes them: the drum roll (armed), the clunk
# (fired) and the crack or refusal (bet_resolved) land in that order, the cores end
# doubled or burned, and the crate is spent: a second hold does nothing. A stage
# restart replays the same roll, so restarting cannot re-roll it. Luck is a pure
# function of the run seed, run id, stage and crate: the same inputs land the same way,
# and across run ids both outcomes come up; the burn and the doubling are each played in
# the game on a run id chosen to land them.

const RIVET := 1
const RUN_IDS := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _crate
var _order: Array = []
var _first := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _steps.is_empty():
		_begin()
		return false
	if _index >= _steps.size():
		print("world_bet_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		(step[0] as Callable).call()
		return false
	_ticks += 1
	if _ticks < int(step[1]):
		return false
	(step[2] as Callable).call()
	_index += 1
	_entered = false
	return false


func _begin() -> void:
	_game.player.source = _source
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(RIVET)
	_game.events.interact_armed.connect(func(family: String, _id: String, _at: Vector3):
		if family == "bet":
			_order.append("armed"))
	_game.events.interact_fired.connect(func(family: String, _id: String, _at: Vector3):
		if family == "bet":
			_order.append("fired"))
	_game.events.bet_resolved.connect(func(_id: String, won: bool, _stake: int, _at: Vector3): _order.append("won" if won else "lost"))
	_steps = [
		[_noop, 30, _find_crate],
		[_approach, 8, _hold_e],
		[_noop, 45, _check_not_ready],
		[_stake_two, 4, _check_disclosed],
		[_noop, 1, _hold_e],
		[_noop, 170, _check_bet],
		[_noop, 1, _hold_e],
		[_noop, 60, _check_spent],
		[_restart, 4, _hold_e],
		[_noop, 170, _check_restart],
		[_restart_tails, 4, _hold_e],
		[_noop, 170, _check_tails],
		[_restart_heads, 4, _hold_e],
		[_noop, 170, _check_heads],
		[_noop, 1, _check_luck],
	]


func _noop() -> void:
	pass


func _find_crate() -> void:
	for device in _game.world.interact.devices:
		if device is BetCrate:
			_crate = device
	_report("crate placed", _crate != null, "stage 1 carries a bet crate: %s" % (_crate.id if _crate != null else "none"))


# Four metres in front of the crate, looking at it.
func _approach() -> void:
	var front: Vector3 = _crate.global_position + _crate.global_basis.z * 4.0
	var ball: Vector3 = _game.ctx.terrain.drop_point(front.x, front.z, 1.05)
	_game.player.reset_to(ball, Vector3.ZERO)
	_game.player.body().global_position = ball
	_game.player.set_frozen(true)
	_game.camera.snap(-_crate.global_basis.z)


func _hold_e() -> void:
	_source.press["mount_pressed"] = true
	_source.hold["mount_held"] = true


func _check_not_ready() -> void:
	_source.hold = {}
	var prompt = _crate.prompt
	_report("no core, not ready", _order.is_empty() and not _crate.rolling and prompt.keycap == "" and prompt.gauge == 0.0,
		"%d cores: held E did nothing (%s), keycap \"%s\", dial gauge %.1f" % [_game.run.bonus_cores, _order, prompt.keycap, prompt.gauge])


func _stake_two() -> void:
	_game.run.add_core("test", _crate.global_position)
	_game.run.add_core("test", _crate.global_position)
	_order.clear()


func _check_disclosed() -> void:
	var prompt = _crate.prompt
	var words: String = prompt.parts()["title"]
	_report("the stake shows before the hold", prompt.keycap == "key_e" and words.contains("2 cores") and _order.is_empty(),
		"locked with 2 cores, before any E: keycap \"%s\", prompt \"%s\"" % [prompt.keycap, words])


func _check_bet() -> void:
	_source.hold = {}
	var result: Dictionary = _crate.last
	var won: bool = result.get("won", false)
	var want := 4 if won else 0
	var ordered: bool = _order == ["armed", "fired", "won" if won else "lost"]
	_report("drum roll, clunk, then the result", ordered and result.get("stake", 0) == 2 and _game.run.bonus_cores == want,
		"staked 2 cores: beats %s, cores now %d (want %d)" % [_order, _game.run.bonus_cores, want])
	_report("replay matches", _replay(_game.run.run_id, _crate.id) == won,
		"run %s, stage 1, %s replays as %s; the game rolled %s" % [_game.run.run_id, _crate.id, _replay(_game.run.run_id, _crate.id), won])
	_first = result.duplicate()
	_order.clear()
	if _game.run.bonus_cores == 0:
		_game.run.add_core("test", _crate.global_position)


func _check_spent() -> void:
	_source.hold = {}
	_report("one wager per crate", _order.is_empty() and _crate.spent and not _crate.rolling,
		"a second hold after the bet landed: beats %s, spent %s" % [_order, _crate.spent])


# R: back to the stage start. The crate is fresh, the cores are the stage start's (none),
# so the test hands back two and bets again.
func _restart() -> void:
	_source.hold = {}
	_game.flow.retry_stage()
	_crate = null
	_find_crate()
	_approach()
	_game.run.add_core("test", _crate.global_position)
	_game.run.add_core("test", _crate.global_position)
	_order.clear()


func _check_restart() -> void:
	_source.hold = {}
	var again: bool = _crate.last.get("won", not _first.get("won", false))
	_report("a restart cannot re-roll", _crate.spent and again == bool(_first.get("won", false)) and _game.run.retries == 1,
		"after retry %d the same bet lands %s again (first %s)" % [_game.run.retries, again, _first.get("won", false)])


# The burn and the doubling in the game: a run id whose crate lands that way, then a
# restart.
func _restart_tails() -> void:
	_rig(false)


func _restart_heads() -> void:
	_rig(true)


func _rig(heads: bool) -> void:
	for run_id in RUN_IDS:
		if _replay(run_id, "rim_crate") == heads:
			_game.run.run_id = run_id
			break
	_restart()


func _check_heads() -> void:
	_source.hold = {}
	_report("heads doubles them", _order == ["armed", "fired", "won"] and _crate.last.get("stake", 0) == 2 and _game.run.bonus_cores == 4,
		"run %s staked %d cores: beats %s, cores now %d" % [_game.run.run_id, _crate.last.get("stake", 0), _order, _game.run.bonus_cores])


func _check_tails() -> void:
	_source.hold = {}
	_report("tails burns them", _order == ["armed", "fired", "lost"] and _crate.last.get("stake", 0) == 2 and _game.run.bonus_cores == 0,
		"run %s staked %d cores: beats %s, cores now %d" % [_game.run.run_id, _crate.last.get("stake", 0), _order, _game.run.bonus_cores])


# What a crate's one roll is for a run seed, run id, stage 1 and crate id.
func _replay(run_id: String, crate_id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(_game.ctx.rng.seed, run_id, 1, crate_id)
	return rng.randf() < BetCrate.ODDS


func _check_luck() -> void:
	var same := true
	var heads := 0
	var rolls := PackedStringArray()
	for run_id in RUN_IDS:
		var first := _replay(run_id, "rim_crate")
		same = same and first == _replay(run_id, "rim_crate")
		heads += 1 if first else 0
		rolls.append("%s:%s" % [run_id, "H" if first else "T"])
	_report("deterministic per run", same, "each of %d run ids replayed twice lands the same way: %s" % [RUN_IDS.size(), " ".join(rolls)])
	_report("both outcomes reachable", heads > 0 and heads < RUN_IDS.size(), "%d heads and %d tails across %d runs" % [heads, RUN_IDS.size() - heads, RUN_IDS.size()])
