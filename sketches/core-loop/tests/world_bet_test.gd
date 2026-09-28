extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BetCrate := preload("res://src/world/bet_crate.gd")
const Interact := preload("res://src/world/interact.gd")

# The double-or-nothing crate on stage 1's bowl bank (LOOP-REDESIGN section 9), in the
# running game as Rivet in calm. With no core it is not ready: the dial shows, the
# keycap does not, and a held E does nothing. With two cores a held E stakes them: the
# drum roll (armed), the clunk (fired) and the crack or refusal (bet_resolved) land in
# that order, and the cores end doubled (heads) or burned (tails; it bets again until one
# lands). The outcome is a pure function of the run's seed, the stage, its retries, the
# draw and the stage tick: the same inputs replay the same way, the in-game bet matches
# its replay, and both outcomes come up across seeds and across ticks of one seed.

const RIVET := 1
const SEEDS := [20260926, 1, 2, 3, 5, 8, 13, 21, 34, 55]
const TAILS_TRIES := 8

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _crate
var _order: Array = []
var _seed := 0
var _tries := 0


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
		[_stake_two, 4, _hold_e],
		[_noop, 170, _check_bet],
		[_noop, 4, _hold_e],
		[_noop, 170, _until_tails],
		[_noop, 1, _check_seeds],
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
	_seed = _game.ctx.rng.seed
	_order.clear()


func _check_bet() -> void:
	_source.hold = {}
	var result: Dictionary = _crate.last
	var want := 4 if result.get("won", false) else 0
	var ordered: bool = _order.size() == 3 and _order[0] == "armed" and _order[1] == "fired" and _order[2] == ("won" if result.get("won", false) else "lost")
	_report("drum roll, clunk, then the result", ordered and result.get("stake", 0) == 2 and _game.run.bonus_cores == want,
		"staked 2 cores: beats %s, cores now %d (want %d)" % [_order, _game.run.bonus_cores, want])
	var luck: Dictionary = result.get("luck", {})
	_report("replay matches", not luck.is_empty() and _replay(_seed, luck) == bool(result.get("won", false)),
		"seed %d draw %d at tick %d replays as %s; the game rolled %s" % [_seed, luck.get("draw", -1), luck.get("tick", -1), _replay(_seed, luck), result.get("won", false)])


# Bets again until one lands tails (bounded), so the burn is seen in the game too.
func _until_tails() -> void:
	_source.hold = {}
	var result: Dictionary = _crate.last
	_tries += 1
	if result.get("won", false) and _tries < TAILS_TRIES:
		_order.clear()
		_index -= 2
		return
	_report("tails burns them", not result.get("won", true) and _order.slice(-3) == ["armed", "fired", "lost"] and _game.run.bonus_cores == 0,
		"bet %d staked %d cores: beats %s, cores now %d" % [_tries + 1, result.get("stake", 0), _order.slice(-3), _game.run.bonus_cores])


# What a recorded roll replays as: the run seed, stage 1, no retries, its draw and tick.
func _replay(run_seed: int, luck: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(run_seed, 1, 0, int(luck.get("draw", 0)), int(luck.get("tick", 0)))
	return rng.randf() < BetCrate.ODDS


func _check_seeds() -> void:
	var same := true
	var by_seed := 0
	var by_tick := 0
	var rolls := PackedStringArray()
	for i in SEEDS.size():
		var at_seed := _replay(SEEDS[i], {"draw": 0, "tick": 600})
		var at_tick := _replay(_seed, {"draw": 0, "tick": 600 + i})
		same = same and at_seed == _replay(SEEDS[i], {"draw": 0, "tick": 600})
		by_seed += 1 if at_seed else 0
		by_tick += 1 if at_tick else 0
		rolls.append("%s%s" % ["H" if at_seed else "T", "H" if at_tick else "T"])
	_report("deterministic per seed", same, "each of %d seeds replayed twice lands the same way (seed, tick): %s" % [SEEDS.size(), " ".join(rolls)])
	_report("both outcomes reachable", by_seed > 0 and by_seed < SEEDS.size() and by_tick > 0 and by_tick < SEEDS.size(),
		"heads on %d of %d seeds, and on %d of %d consecutive ticks of this run's seed" % [by_seed, SEEDS.size(), by_tick, SEEDS.size()])
