# 2026-10-11 (PC-SABLE): later-world Sable caches offer Bank Shot relics independently of world-one slots.
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const Relics := preload("res://src/build/relics.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const Dig := preload("res://src/world/map_dig.gd")
const DigDeep := preload("res://src/world/map_dig_deep.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const Crown := preload("res://src/world/map_highdraft_crown.gd")

# Each world has its own six relics, two per kit, and each world-2 and world-3 zone holds
# one cache on its map's relic_spot that always offers a relic of that world. On the
# default table, as Kest in calm: entering stages 3 to 6 puts that cache on the stage's own
# ground (stage 3's, not stage 2's), with its chest and pedestals built on it.

const KEST := 2
const PILOT := "demolitions_caster"
# 2026-10-05 (alpha wave 14 tarn-tree): Tarn's own two rows per world
# 2026-10-05 (alpha wave 15 tally-tree): Tally's own two rows per world
# 2026-10-05 (alpha wave 15 cannon-tree): the remembered cannon's own two rows per world
const KITS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const WORLD_ONE := ["crater_heart", "quick_fuse", "muzzle_heart", "redline_spring", "rain_heart", "long_fuse", "taut_cable", "vice_heart",
	"gutter_heart", "rake_heart", "oiled_flywheel", "return_spring", "kick_spring", "brace_pin", "walking_lane", "rush_wake"]
# W45-B2 U3: Tarn's kit swaps (Gutter Heart, Rake Heart) join World 1; Tally and the cannon follow
# in U4 and U5, which add their own two each here (the cannon's are in).
const WORLD_ONE_EXTRA := {"tarn": 2, "remembered_cannon": 2}
# Different luck keys for the one cache, so its relic draw is checked over many picks.
const DRAWS := 12
const SETTLE_TICKS := 4

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _checks := 0
var _stages := [2, 3, 4, 5, 6]
var _index := 0
var _ticks := 0
var _entered := false
var _began := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_check_table()
	_check_maps()


# How many relics one pilot is offered in a world: two, plus that world's kit swaps.
func _want(pilot: String, world: int) -> int:
	return 2 + (int(WORLD_ONE_EXTRA.get(pilot, 0)) if world == 1 else 0)


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_table() -> void:
	_report("validator", Relics.validate().is_empty(), "table problems: %s" % [Relics.validate()])
	_report("world 2 Bank Shot recharge", Relics.row("pit_coil")["world"] == 2 and Relics.slot_of("pit_coil") == AbilityState.LINE, "Pit Coil")
	_report("world 3 Bank Shot stock", Relics.row("storm_crater")["world"] == 3 and Relics.slot_of("storm_crater") == AbilityState.LINE, "Storm Crater")
	var parts := {}
	for id in Relics.ids():
		parts[Relics.part_of(id)] = true
	_report("one part per relic", parts.size() == Relics.ids().size(), "%d parts for %d relics" % [parts.size(), Relics.ids().size()])
	for world in [1, 2, 3]:
		var rows: Array = Relics.ids().filter(func(i): return int(Relics.row(i)["world"]) == world)
		var per_kit := {}
		for id in rows:
			for kit in KITS:
				if Relics.fits(id, kit):
					per_kit[kit] = int(per_kit.get(kit, 0)) + 1
		var total := 0
		for kit in KITS:
			total += _want(kit, world)
		_report("world %d rows" % world, rows.size() == total and KITS.all(func(k): return per_kit.get(k, 0) == _want(k, world)) and per_kit.size() == KITS.size(),
			"%d rows, per kit %s" % [rows.size(), per_kit])
		for pilot in Relics.PILOTS:
			var pool := Relics.eligible(pilot, {}, null, world)
			var own: bool = pool.size() == _want(pilot, world) and pool.all(func(i): return int(Relics.row(i)["world"]) == world)
			_report("world %d pool for %s" % [world, pilot], own, "%s" % [pool])
	for pilot in Relics.PILOTS:
		_report("world 0 is every world for " + pilot, Relics.eligible(pilot, {}, null, 0) == Relics.eligible(pilot, {})
			and Relics.eligible(pilot, {}).size() == 6 + int(WORLD_ONE_EXTRA.get(pilot, 0)), "%s" % [Relics.eligible(pilot, {})])
	var first := []
	for pilot in Relics.PILOTS:
		for id in Relics.eligible(pilot, {}, null, 1):
			if not id in first:
				first.append(id)
	first.sort()
	var want := WORLD_ONE.duplicate()
	want.sort()
	_report("world 1 is the old six plus each new pilot's two", first == want, "%s" % [first])


func _check_maps() -> void:
	for map in [Dig.new(), DigDeep.new(), Highdraft.new(), Crown.new()]:
		var issues := ZoneSchema.validate(map)
		_report(map.title + " schema", issues.is_empty() and ZoneSchema.slots(map).get("relic_spot") is Vector2,
			"issues %s, relic_spot %s" % [issues, ZoneSchema.slots(map).get("relic_spot")])


# The relic cache is placed by a deferred call that can land after the game is gone, which the
# engine logs as an ERROR from a lambda on a freed instance. The deferral is a bound method that
# returns early on a stale stage or a node outside the tree, so neither adds a device.
func _check_deferred_guards() -> void:
	var interact = _game.world.interact
	_report("the deferred placement is a bound method", interact.has_method("_place_relic_cache"), "has _place_relic_cache %s" % interact.has_method("_place_relic_cache"))
	if not interact.has_method("_place_relic_cache"):
		return
	var stage: int = _game.ctx.run.stage
	var before: int = interact.devices.size()
	interact._place_relic_cache(stage + 90)
	_report("a stale stage places nothing", interact.devices.size() == before, "devices %d -> %d" % [before, interact.devices.size()])
	var cache = _relic_cache()
	if cache != null:
		interact.devices.erase(cache)
		interact._owned.erase(cache)
	before = interact.devices.size()
	var parent: Node = interact.get_parent()
	parent.remove_child(interact)
	interact._place_relic_cache(stage)
	parent.add_child(interact)
	_report("a node outside the tree places nothing", interact.devices.size() == before, "devices %d -> %d" % [before, interact.devices.size()])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _began:
		_began = true
		_game.player.source = _source
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(KEST)
		return false
	if _index >= _stages.size():
		_check_deferred_guards()
		print("relics_per_world_test: %s" % ("PASS (%d checks)" % _checks if _failures == 0 else "FAIL (%d of %d checks)" % [_failures, _checks]))
		quit(0 if _failures == 0 else 1)
		return true
	var stage: int = _stages[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		return false
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return false
	_check_stage(stage)
	if stage >= 3:
		_check_sable(stage)
	_index += 1
	_entered = false
	return false


func _relic_cache():
	for device in _game.world.interact.devices:
		if device is CrackedCache and device.id == "relic_cache":
			return device
	return null


func _check_stage(stage: int) -> void:
	var terrain = _game.ctx.terrain
	var map = terrain.map_for(stage)
	var cache = _relic_cache()
	if not "relic_spot" in map:
		_report("stage %d has no relic cache" % stage, cache == null, "map %s" % map.title)
		return
	if cache == null:
		_report("stage %d relic cache" % stage, false, "no relic cache placed on %s" % map.title)
		return
	var spot: Vector2 = map.relic_spot
	var at: Vector3 = cache.global_position
	var ground: Vector3 = terrain.ground_callable(stage).call(spot.x, spot.y, 0.0)
	var on_spot: bool = Vector2(at.x, at.z).distance_to(spot) < 0.01 and absf(at.y - ground.y) < 0.01
	var detail := "cache at %s, spot %s, stage ground %.2f" % [at, spot, ground.y]
	if stage == 3:
		var before: Vector3 = terrain.ground_callable(2).call(spot.x, spot.y, 0.0)
		on_spot = on_spot and absf(before.y - ground.y) > 0.5
		detail += ", stage 2 ground there %.2f" % before.y
	_report("stage %d cache on its own ground" % stage, on_spot and cache.relic_guaranteed, detail)
	_check_footing(stage, cache, map, spot, ground.y)
	_check_relic(stage, cache)


# The spot stands on the map with finite, level ground under the whole pocket, and the
# chest's pedestals were built on this stage's ground.
func _check_footing(stage: int, cache, map, spot: Vector2, y: float) -> void:
	var terrain = _game.ctx.terrain
	var finite: bool = is_finite(y) and terrain.contains(Vector3(spot.x, y, spot.y)) and (map.play_rect as Rect2).has_point(spot)
	var worst := 0.0
	for corner in [Vector3(-7.0, 0.0, -6.0), Vector3(7.0, 0.0, -6.0), Vector3(-7.0, 0.0, 6.0), Vector3(7.0, 0.0, 6.0)]:
		var p: Vector3 = cache.to_global(corner)
		worst = maxf(worst, absf(terrain.height(p.x, p.z) - y))
	_report("stage %d spot on the map and level" % stage, finite and worst < 0.6,
		"ground %.2f at %s, worst corner off by %.2f m" % [y, spot, worst])
	var off := 0.0
	for p in cache._pedestals:
		var g: Vector3 = (p["node"] as Node3D).global_position
		off = maxf(off, absf(g.y - terrain.height(g.x, g.z)))
	_report("stage %d pedestals on the ground" % stage, off < 0.1, "worst pedestal off by %.2f m" % off)


func _check_relic(stage: int, cache) -> void:
	var world: int = _game.ctx.stages.world_of(stage)
	var pool := Relics.eligible(_game.ctx.run.class_id(), Relics.held(_game.ctx.run.parts), _game.player.tree, world)
	_report("stage %d pool is world %d's" % [stage, world], pool.size() == 2 and pool.all(func(i): return int(Relics.row(i)["world"]) == world),
		"pool %s" % [pool])
	var id: String = cache.id
	var picks := []
	for k in DRAWS:
		cache.id = "%s_%d" % [id, k]
		picks.append(Relics.relic_of(cache._relic_offer()))
	cache.id = id
	var ok: bool = picks.all(func(r): return Relics.has(r) and int(Relics.row(r)["world"]) == world and Relics.fits(r, PILOT))
	_report("stage %d cache relic is world %d's" % [stage, world], ok, "%d draws %s" % [DRAWS, picks])


# Sable's later worlds keep an offer whichever world-1 relic Sable holds: Quick Fuse holds the
# special slot, Crater Heart the smash slot.
func _check_sable(stage: int) -> void:
	var world: int = _game.ctx.stages.world_of(stage)
	for held in [{AbilityState.SPECIAL: "quick_fuse"}, {AbilityState.SMASH: "crater_heart"}]:
		var pool := Relics.eligible("pylon_engineer", held, null, world)
		var ok := not pool.is_empty()
		for id in pool:
			ok = ok and int(Relics.row(id)["world"]) == world and Relics.fits(id, "pylon_engineer") and not held.has(Relics.slot_of(id))
		if held.has(AbilityState.SMASH):
			ok = ok and pool.any(func(i): return Relics.slot_of(i) == AbilityState.SPECIAL)
		_report("stage %d Sable holding %s finds a world %d relic" % [stage, held.values()[0], world], ok, "pool %s" % [pool])
