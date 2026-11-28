extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Triggers := preload("res://src/build/triggers.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Icons := preload("res://src/core/icons.gd")

# v2 W4 loot, the trigger vocabulary and the stockpile (DESIGN-V2 sections 5 and 7):
#   - the vocabulary is twelve kinds, each with its trg_ icon;
#   - a kind cannot re-post itself inside its own pass, every pass ends within twelve
#     resolutions, and each root pass draws exactly once from the loot stream;
#   - on_hit, on_charge_release and timed items fire through the real bus and strike
#     through the spawner, and build's own strikes never proc another item;
#   - charge items raise AbilityState.max_charges, a raised cap arrives stocked, the
#     slot ceiling holds, and no stack of cooldown items goes under the 0.4 s floor;
#   - a retry puts the charges back with the part list.

var _game
var _build
var _failures := 0
var _ticks := 0
var _phase := 0
var _wait := 0
var _struck := {}
var _enemies: Array = []


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
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_build = _game.ctx.build
		_game.events.enemy_struck.connect(func(_e: Node3D, kind: String, _f: float): _struck[kind] = _struck.get(kind, 0) + 1)
		return false
	if _ticks < 12:
		return false
	match _phase:
		0:
			_check_vocabulary()
			_check_guard()
			_check_chain_ends()
			_check_one_draw()
			_check_charges()
			_check_floor()
			_setup_hit()
			_phase = 1
		1:
			_wait += 1
			if _wait >= 4:
				_check_hit()
				_setup_release()
				_phase = 2
				_wait = 0
		2:
			_wait += 1
			if _wait >= 3:
				_check_release()
				_check_timed()
				_setup_retry()
				_phase = 3
				_wait = 0
		3:
			_wait += 1
			if _wait >= 3:
				_check_retry()
				return _finish()
	return false


func _check_vocabulary() -> void:
	var names: Array = Triggers.NAMES
	var unique := {}
	var icons_missing: Array = []
	for n in names:
		unique[n] = true
		if not Triggers.icon(n) in Icons.ids():
			icons_missing.append(n)
	_report("vocabulary", names.size() == 12 and unique.size() == 12 and icons_missing.is_empty()
			and Triggers.is_trigger("") and not Triggers.is_trigger("on_sneeze"),
		"%d kinds %s; missing icons %s; passive allowed, an unknown kind refused" % [names.size(), names, icons_missing])


# A resolver that re-posts its own kind and one other: the same kind is refused, the
# other resolves once, and the pass ends with its guard cleared.
func _check_guard() -> void:
	var bus := Triggers.Bus.new()
	var seen: Array = []
	var resolver := func(c, _draw: float):
		seen.append(c.kind)
		bus.post(Triggers.Commitment.new(c.kind, "again"))
		if c.kind == Triggers.Kind.ON_HIT:
			bus.post(Triggers.Commitment.new(Triggers.Kind.ON_KILL, "kill"))
	bus.post(Triggers.Commitment.new(Triggers.Kind.ON_HIT, "root"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	bus.run(resolver, rng)
	_report("same-kind re-entry refused", seen == [Triggers.Kind.ON_HIT, Triggers.Kind.ON_KILL] and bus.refused == 2
			and not bus.leaked() and bus.pending.is_empty(),
		"resolved %s, refused %d re-posts, guard leaked %s" % [seen, bus.refused, bus.leaked()])


# Every consumer posts all twelve kinds: the pass still ends, each kind at most once.
func _check_chain_ends() -> void:
	var bus := Triggers.Bus.new()
	var count := [0]
	var resolver := func(_c, _draw: float):
		count[0] += 1
		for k in 12:
			bus.post(Triggers.Commitment.new(k, "storm"))
	bus.post(Triggers.Commitment.new(Triggers.Kind.ON_SMASH, "root"))
	var rng := RandomNumberGenerator.new()
	bus.run(resolver, rng)
	_report("chains end by construction", count[0] == 12 and bus.max_same_kind == 1 and not bus.leaked(),
		"a pass where every consumer posts all twelve kinds resolved %d commitments, at most %d of a kind" % [count[0], bus.max_same_kind])


func _check_one_draw() -> void:
	var bus := Triggers.Bus.new()
	var draws: Array = []
	var resolver := func(_c, draw: float): draws.append(draw)
	for i in 3:
		bus.post(Triggers.Commitment.new(Triggers.Kind.ON_LAND, "root"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	bus.run(resolver, rng)
	var twin := RandomNumberGenerator.new()
	twin.seed = 77
	var expect := [twin.randf(), twin.randf(), twin.randf()]
	_report("one draw per pass", draws == expect and rng.randf() == twin.randf(),
		"three root passes drew %s, the stream's first three values, and nothing else" % [draws])


func _slot(name: String):
	return _game.player.abilities.slot(name)


func _check_charges() -> void:
	var run = _game.run
	run.add_part("cap_relay", "test")
	var one: int = _slot("special").max_charges
	var stocked: int = _slot("special").charges
	for i in 4:
		run.add_part("cap_relay", "test")
	var capped: int = _slot("special").max_charges
	run.add_part("cell_special", "test")
	run.add_part("cell_special", "test")
	var ceiling: int = _slot("special").max_charges
	var records: Array = _game.player.abilities.slots()
	var special: Dictionary = records.filter(func(r): return r["slot"] == "special")[0]
	_report("charges stockpile", one == 2 and stocked == 2 and capped == 4 and ceiling == ItemEffects.MAX_CHARGES
			and special["max_charges"] == ceiling,
		"one Cap Relay: max %d, %d stocked at once; five: %d (capped at 3 copies); two Special Cells more: %d (ceiling %d); the slot record shows %d pips"
			% [one, stocked, capped, ceiling, ItemEffects.MAX_CHARGES, special["max_charges"]])


func _check_floor() -> void:
	for i in 12:
		_game.run.add_part("quick_spool", "test")
	var cd: float = _game.player.abilities.cooldown_of("special")
	var scale: float = _slot("special").cooldown_scale
	_report("cooldown floor", cd >= AbilityState.COOLDOWN_FLOOR and scale >= 0.6 - 0.0001,
		"twelve Quick Spools: special cooldown %.2f s (floor %.1f), scale %.2f (hyperbolic, capped at 40%% off)"
			% [cd, AbilityState.COOLDOWN_FLOOR, scale])


func _spawn(offset: Vector3) -> Node3D:
	var at: Vector3 = _game.player.ball_position() + offset
	return _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x, at.z, 2.4))


# Ring Wave answers every hit with a pulse ring: strike one of two close chasers.
func _setup_hit() -> void:
	var at: Vector3 = _game.ctx.terrain.drop_point(-62.0, -80.0, 1.05)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	_game.run.add_part("ring_wave", "test")
	_enemies = [_spawn(Vector3(18.0, 0.0, 0.0)), _spawn(Vector3(19.5, 0.0, 0.0))]
	_struck.clear()
	_game.ctx.spawner.strike(_enemies[0], "ram", 20.0)


func _check_hit() -> void:
	var procs: Dictionary = _build.item_procs()
	var stats: Dictionary = _build.trigger_stats()
	_report("on_hit through the bus", procs.get("ring_wave", 0) == 1 and _struck.get("synergy", 0) >= 1
			and stats["fired"].get(Triggers.Kind.ON_HIT, 0) >= 1 and not stats["leaked"],
		"one ram strike: Ring Wave fired %d time(s), %d synergy strikes, and none of them proc'd it again; stats %s"
			% [procs.get("ring_wave", 0), _struck.get("synergy", 0), stats])


func _setup_release() -> void:
	_game.run.add_part("overcharge_coil", "test")
	_enemies.append(_spawn(Vector3(4.0, 0.0, 3.0)))
	_struck.clear()
	_game.events.gauge_released.emit("detonation_gauge", 1.0)


func _check_release() -> void:
	var procs: Dictionary = _build.item_procs()
	var gap: float = _enemies[-1].global_position.distance_to(_game.player.ball_position()) if is_instance_valid(_enemies[-1]) else -1.0
	_report("on_charge_release", procs.get("overcharge_coil", 0) == 1 and _struck.get("synergy", 0) >= 1,
		"a full gauge release: Overcharge Coil fired %d time(s) and struck %d (a chaser %.1f m away)"
			% [procs.get("overcharge_coil", 0), _struck.get("synergy", 0), gap])


# Overpressure arms the next hit every 8 s; its commitment is timed, not rolled.
func _check_timed() -> void:
	_game.run.add_part("overpressure", "test")
	var effects = _build.effects
	effects.tick(8.05, _build.bus)
	var queued: int = _build.bus.pending.size()
	_build.bus.run(effects.resolve, _build.loot_rng)
	var armed: float = effects._armed_hit
	_report("timed", queued == 1 and absf(armed - 0.6) < 0.001 and effects.procs.get("overpressure", 0) == 1,
		"8 s on the item clock queued %d timed commitment; the next hit is armed +%d%%" % [queued, roundi(armed * 100.0)])


func _setup_retry() -> void:
	_game.flow.retry_stage()


func _check_retry() -> void:
	var max_special: int = _slot("special").max_charges
	_report("retry restores the stockpile", max_special == 1 and _game.run.parts.is_empty(),
		"after a retry to the stage start the part list is %s and the special holds %d charge" % [_game.run.parts, max_special])


func _finish() -> bool:
	print("item_trigger_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
