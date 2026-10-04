extends SceneTree

const Game := preload("res://src/game.gd")
const RunState := preload("res://src/core/run_state.gd")
const Relics := preload("res://src/build/relics.gd")
const Parts := preload("res://src/build/parts.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")

# RL2: a relic found in a cracked cache is held in the run, one per slot, rewrites its
# kit slot, is announced once as a relic-rarity part_gained, and survives a retry and
# the entrance document. Sable in the running game; the cache is forced to offer one.

const SABLE := 0

var _game
var _failures := 0
var _ticks := 0
var _stage := 0
var _gained: Array = []
var _cache
var _relic := ""
var _slot := ""
var _cd_before := 0.0
var _id_before := ""


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
	_ticks += 1
	if _stage == 0:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(SABLE)
		_game.events.part_gained.connect(func(part: String, source: String): _gained.append([part, source]))
		_stage = 1
		_ticks = 0
	elif _stage == 1 and _ticks >= 20:
		_run()
		_stage = 2
	elif _stage == 2:
		print("relics_run_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _run() -> void:
	var run = _game.ctx.run
	var abilities = _game.player.abilities
	for device in _game.world.interact.devices:
		if device is CrackedCache:
			_cache = device
	_report("cache placed", _cache != null, "stage 1 carries a cracked cache")
	_report("no relic held at the start", run.relics.is_empty(), "relics %s" % [run.relics])

	# A zero chance leaves the cache a parts cache; a forced one puts a relic on the last pedestal.
	_cache.relic_chance = 0.0
	_report("chance zero offers none", _cache._relic_offer() == "", "no relic at chance 0")
	_cache.relic_chance = 1.0
	_cache.crumble()
	var before_fire := _gained.size()
	_cache.fire()
	_relic = String(_cache.offers[-1])
	_report("cache yields a relic", Relics.has(_relic) and _cache.offers.size() == CrackedCache.PICKS
		and Relics.fits(_relic, run.class_id()), "offers %s" % [_cache.offers])
	_slot = Relics.slot_of(_relic)
	_cd_before = abilities.cooldown_of(_slot)
	_id_before = abilities.id_of(_slot)
	_cache.take(_cache.offers.size() - 1)

	_report("run holds it in its slot", run.relics.get(_slot, "") == _relic and run.relics.size() == 1, "relics %s" % [run.relics])
	var row := Relics.row(_relic)
	var swapped: bool = Relics.swap_of(_relic) != "" and abilities.id_of(_slot) == Relics.swap_of(_relic) and _id_before != abilities.id_of(_slot)
	var cooled: bool = row.has("cooldown") and _cd_before > 0.0 and is_equal_approx(abilities.cooldown_of(_slot), maxf(AbilityState.COOLDOWN_FLOOR, _cd_before * float(row["cooldown"])))
	_report("the kit row applies", swapped or cooled, "%s slot %s: id %s -> %s, cooldown %.2f -> %.2f"
		% [_relic, _slot, _id_before, abilities.id_of(_slot), _cd_before, abilities.cooldown_of(_slot)])
	var fired := _gained.slice(before_fire)
	_report("part_gained once, relic rarity", fired.size() == 1 and fired[0][1] == "cache"
		and Parts.def(fired[0][0]).rarity == "relic" and RewardCeremony.rarity_of(fired[0][0]) == "relic",
		"gained %s" % [fired])

	# The one-per-slot rule: the same slot is refused, nothing changes, nothing is announced.
	var count := _gained.size()
	var refused: bool = not run.add_relic(_relic, "cache")
	_report("a second relic for the slot is refused", refused and _gained.size() == count and run.relics.size() == 1,
		"relics %s, gained %d" % [run.relics, _gained.size() - count])

	# A retry puts back the relic held at the checkpoint, and takes back one found after it.
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var other := ""
	for id in Relics.eligible(run.class_id(), run.relics):
		other = id
	_report("another slot's relic exists", other != "", "second relic %s" % other)
	var other_slot := Relics.slot_of(other)
	var other_id_before: String = abilities.id_of(other_slot)
	run.add_relic(other, "cache")
	_report("second slot filled", run.relics.size() == 2 and _game.ctx.build._relic_fx.has(other_slot), "relics %s" % [run.relics])
	_game.flow.retry_stage()
	_report("retry restores the checkpoint set", run.relics == {_slot: _relic}, "relics %s" % [run.relics])
	_report("retry kit matches the set", abilities.id_of(_slot) == (Relics.swap_of(_relic) if swapped else _id_before)
		and (not cooled or is_equal_approx(abilities.cooldown_of(_slot), maxf(AbilityState.COOLDOWN_FLOOR, _cd_before * float(row["cooldown"]))))
		and not _game.ctx.build._relic_fx.has(other_slot) and (other_slot == _slot or abilities.id_of(other_slot) == other_id_before), "slot %s id %s cooldown %.2f, other slot row undone" % [_slot, abilities.id_of(_slot), abilities.cooldown_of(_slot)])

	# The entrance document carries it.
	var doc: Dictionary = JSON.parse_string(JSON.stringify(run.to_entrance_doc()))
	var loaded := RunState.new(null)
	var ok_load: bool = loaded.from_entrance_doc(doc)
	_report("entrance doc round-trips", ok_load and loaded.relics == {_slot: _relic} and RunState.validate_entrance_doc(doc) == ""
		and not loaded.extra.has("relics"), "doc relics %s, loaded %s" % [doc.get("relics"), loaded.relics])
	var old_doc := doc.duplicate()
	old_doc.erase("relics")
	var old := RunState.new(null)
	_report("a doc without relics loads empty", old.from_entrance_doc(old_doc) and old.relics.is_empty(), "older save")
