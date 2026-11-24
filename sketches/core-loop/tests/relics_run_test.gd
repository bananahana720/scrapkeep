extends SceneTree

const Game := preload("res://src/game.gd")
const RunState := preload("res://src/core/run_state.gd")
const Relics := preload("res://src/build/relics.gd")
const Parts := preload("res://src/build/parts.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")

# RL2: a relic found in a cracked cache is held in the run's part list on the relic rung, one
# per slot, rewrites its kit slot, is announced once as a relic-rarity part_gained, survives a
# retry and the entrance document, and an old save's relics move into the part list. Sable in the running game; the cache is forced to offer one.

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


# The relics the run holds, slot to relic id: they live in the part list (relics.gd).
func _held() -> Dictionary:
	return Relics.held(_game.ctx.run.parts)


func _run() -> void:
	var run = _game.ctx.run
	var abilities = _game.player.abilities
	for device in _game.world.interact.devices:
		if device is CrackedCache:
			_cache = device
	_report("cache placed", _cache != null, "stage 1 carries a cracked cache")
	_report("no relic held at the start", _held().is_empty(), "relics %s" % [_held()])

	# A zero chance leaves the cache a parts cache; a forced one puts a relic on the last pedestal.
	_cache.relic_chance = 0.0
	_report("chance zero offers none", _cache._relic_offer() == "", "no relic at chance 0")
	_cache.relic_chance = 1.0
	_cache.crumble()
	var before_fire := _gained.size()
	_cache.fire()
	var offered := String(_cache.offers[-1])
	_relic = Relics.relic_of(offered)
	_report("cache yields a relic part", _relic != "" and _cache.offers.size() == CrackedCache.PICKS
		and Relics.fits(_relic, run.class_id()) and Parts.rung_of(offered) == 2, "offers %s" % [_cache.offers])
	_slot = Relics.slot_of(_relic)
	_cd_before = abilities.cooldown_of(_slot)
	_id_before = abilities.id_of(_slot)
	_cache.take(_cache.offers.size() - 1)

	_report("run holds it as a part in its slot", offered in run.parts and _held() == {_slot: _relic}, "parts %s" % [run.parts])
	var row := Relics.row(_relic)
	var swapped: bool = Relics.swap_of(_relic) != "" and abilities.id_of(_slot) == Relics.swap_of(_relic) and _id_before != abilities.id_of(_slot)
	var cooled: bool = row.has("cooldown") and _cd_before > 0.0 and is_equal_approx(abilities.cooldown_of(_slot), maxf(AbilityState.COOLDOWN_FLOOR, _cd_before * float(row["cooldown"])))
	_report("the kit row applies", swapped or cooled, "%s slot %s: id %s -> %s, cooldown %.2f -> %.2f"
		% [_relic, _slot, _id_before, abilities.id_of(_slot), _cd_before, abilities.cooldown_of(_slot)])
	var fired := _gained.slice(before_fire)
	_report("part_gained once, relic rarity", fired.size() == 1 and fired[0][1] == "cache" and fired[0][0] == offered
		and Parts.def(fired[0][0]).rarity == "relic" and RewardCeremony.rarity_of(fired[0][0]) == "relic",
		"gained %s" % [fired])

	var card: Dictionary = _game.presentation.ceremony.card_state(_game.presentation.ceremony.find_of(fired[0][0], "cache"), 0, false)
	_report("the card names the relic", card["name"] == Relics.name_of(_relic) and card["verb"] == String(row["text"]),
		"card '%s' / '%s' for %s" % [card["name"], card["verb"], _relic])

	# The one-per-slot rule: a held slot's relics are no longer offered.
	var still := Relics.eligible(run.class_id(), _held())
	_report("a held slot is not offered again", still.all(func(id): return Relics.slot_of(id) != _slot) and not still.is_empty(),
		"eligible %s" % [still])

	# A retry puts back the relic held at the checkpoint, and takes back one found after it.
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var other := ""
	for id in still:
		other = id
	var other_slot := Relics.slot_of(other)
	var other_id_before: String = abilities.id_of(other_slot)
	run.add_part(Relics.part_of(other), "cache")
	_report("second slot filled", _held().size() == 2 and _game.ctx.build._relic_fx.has(other_slot), "relics %s" % [_held()])
	_game.flow.retry_stage()
	_report("retry restores the checkpoint set", _held() == {_slot: _relic}, "relics %s" % [_held()])
	_report("retry kit matches the set", abilities.id_of(_slot) == (Relics.swap_of(_relic) if swapped else _id_before)
		and (not cooled or is_equal_approx(abilities.cooldown_of(_slot), maxf(AbilityState.COOLDOWN_FLOOR, _cd_before * float(row["cooldown"]))))
		and not _game.ctx.build._relic_fx.has(other_slot) and (other_slot == _slot or abilities.id_of(other_slot) == other_id_before), "slot %s id %s cooldown %.2f, other slot row undone" % [_slot, abilities.id_of(_slot), abilities.cooldown_of(_slot)])

	# The entrance document carries it in the part list.
	var doc: Dictionary = JSON.parse_string(JSON.stringify(run.to_entrance_doc()))
	var loaded := RunState.new(null)
	var ok_load: bool = loaded.from_entrance_doc(doc)
	_report("entrance doc round-trips", ok_load and Relics.held(loaded.parts) == {_slot: _relic} and RunState.validate_entrance_doc(doc) == "",
		"doc parts %s, loaded %s" % [doc.get("parts"), loaded.parts])
	_saved_relics_migrate(run, abilities)
	_tree_pick_survives_undo(run, abilities)


# A save from before the fold holds relics in RunState.relics, not in the part list. On stage
# entry the build moves them into the part list once, with no second reveal, and the kit row
# applies as before.
func _saved_relics_migrate(run, abilities) -> void:
	var build = _game.ctx.build
	var part_id := Relics.part_of(_relic)
	run.parts.erase(part_id)
	build.sync_relics()
	_report("kit undone without the part", not build._relic_fx.has(_slot), "fx %s" % [build._relic_fx])
	var doc: Dictionary = JSON.parse_string(JSON.stringify(run.to_entrance_doc()))
	doc["relics"] = {_slot: _relic}
	var loaded := RunState.new(null)
	_report("an old doc with relics still loads", loaded.from_entrance_doc(doc) and loaded.relics == {_slot: _relic}
		and RunState.validate_entrance_doc(doc) == "", "loaded relics %s" % [loaded.relics])
	var count := _gained.size()
	run.relics = loaded.relics.duplicate()
	build.sync_relics()
	_report("old relics move into the part list", part_id in run.parts and run.relics.is_empty() and run.parts.count(part_id) == 1
		and build._relic_fx.has(_slot) and _gained.size() == count, "parts %s, relics %s, gained %d" % [run.parts, run.relics, _gained.size() - count])
	build.sync_relics()
	_report("adopting twice changes nothing", run.parts.count(part_id) == 1, "copies %d" % run.parts.count(part_id))


# Crater Heart and Crater Slam (tree node s_crater) swap the smash slot to the same row. With
# both gained in one stage a retry undoes the relic and must leave the pick's swap in place,
# and a relic the tree already gave is not offered.
func _tree_pick_survives_undo(run, abilities) -> void:
	var build = _game.ctx.build
	var tree = _game.player.tree
	for part_id in run.parts.duplicate():
		if Relics.is_relic(part_id):
			run.parts.erase(part_id)
	build.sync_relics()
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var smash_before: String = abilities.id_of(AbilityState.SMASH)
	run.add_part(Relics.part_of("crater_heart"), "cache")
	var path := UpgradeTree.path_to(run.class_id(), "s_crater", tree.world_one)
	var picked_all := not path.is_empty()
	for depth in range(1, path.size() + 1):
		while tree.picks.size() < depth and not tree.pending():
			tree.open_checkpoint()
		picked_all = tree.pick(path[depth - 1]) and picked_all
	_report("relic and tree pick both land", picked_all and tree.gives_swap(AbilityState.SMASH, "crater_slam") and abilities.id_of(AbilityState.SMASH) == "crater_slam",
		"path %s picks %s smash %s" % [path, tree.picks, abilities.id_of(AbilityState.SMASH)])
	_report("a relic the tree gave is not offered", not "crater_heart" in Relics.eligible(run.class_id(), {}, tree) and "crater_heart" in Relics.eligible(run.class_id(), {}),
		"eligible with the tree %s" % [Relics.eligible(run.class_id(), {}, tree)])
	_game.flow.retry_stage()
	_report("retry took the relic back", _held().is_empty() and not build._relic_fx.has(AbilityState.SMASH), "relics %s" % [_held()])
	_report("retry keeps the tree pick's swap", abilities.id_of(AbilityState.SMASH) == "crater_slam" and smash_before != "crater_slam",
		"smash %s (was %s), picks %s" % [abilities.id_of(AbilityState.SMASH), smash_before, tree.picks])
