extends SceneTree
# F6 2026-10-04: the family step is now _step_guard; the plating fight is gone.
# KF0 2026-10-10: one Warden kind per world, so world one's pair is the Spillway reactor and
# the Reach reactor meltdown; the swarm rack case and its --mutant control moved to stage 3,
# the swarm on the Dig.

const Game := preload("res://src/game.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const BossContract := preload("res://src/boss/boss_contract.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Warden := preload("res://src/combat/warden.gd")

# The two world-one zone Wardens on the alpha table, through the real spawn path
# (flow.enter_stage, then combat.spawn_enemy("warden")): the Spillway reactor and the Cable
# Reach reactor meltdown both fight by posture. Each row builds a Warden that conforms to the
# boss contract's TARGET, takes real contacts to a stagger, cracks then shatters one chunk, and
# four chunks unseal the stage with the plate and the ring mounted for it. Neither has a rack;
# the Reach carries the meltdown's 6 s core window. The Dig's swarm (stage 3, world two) keeps
# the rack case: one fixed quarter bar per scatter on a cruise-or-faster ram, once, until it
# reforms. Contacts are real physics from placed starts, not a player's run; every wait is
# counted in physics frames. Run with --mutant to read the Dig row as a reactor (the rack
# check must then fail).

const OUT := 58.0
const NEAR := 5.0

var _game
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _stage := 1
var _row: Dictionary = {}
var _smashed := 0
var _posture_events := 0
var _opened := 0
var _kills: Array = []
var _unsealed := 0
var _mutant := false


# The alpha table with the Dig row (stage 3) read as a reactor, for the mutant run only.
class MutantTable extends RefCounted:
	const BOSS := AlphaDefs.BOSS
	const COUNT := AlphaDefs.COUNT
	const PICK_ON_CLASS_UP := AlphaDefs.PICK_ON_CLASS_UP
	const DEFS := AlphaDefs.DEFS

	func of(stage: int) -> Dictionary:
		var row: Dictionary = AlphaDefs.of(stage).duplicate(true)
		if stage == 3:
			row["warden_family"] = "reactor"
		return row

	func is_last(stage: int) -> bool:
		return AlphaDefs.is_last(stage)

	func world_of(stage: int) -> int:
		return AlphaDefs.world_of(stage)

	func local(stage: int) -> int:
		return AlphaDefs.local(stage)

	func first_of(world: int) -> int:
		return AlphaDefs.first_of(world)

	func last_of(world: int) -> int:
		return AlphaDefs.last_of(world)

	func worlds() -> Array:
		return AlphaDefs.worlds()

	func is_world_last(stage: int) -> bool:
		return AlphaDefs.is_world_last(stage)

	func is_run_last(stage: int) -> bool:
		return AlphaDefs.is_run_last(stage)

	func synergy_in_play(id: String) -> bool:
		return AlphaDefs.synergy_in_play(id)

	func part_in_play(id: String) -> bool:
		return AlphaDefs.part_in_play(id)

	func parts_listed() -> bool:
		return AlphaDefs.parts_listed()

	func packs() -> Array:
		return AlphaDefs.packs()

	func elite() -> Dictionary:
		return AlphaDefs.elite()

	func elite_arrival() -> int:
		return AlphaDefs.elite_arrival()

	func has_vault() -> bool:
		return AlphaDefs.has_vault()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_mutant = OS.get_cmdline_user_args().has("--mutant")
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _top() -> Vector3:
	return _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT


func _plating() -> float:
	return float(_row["warden_plating"])


func _hp() -> float:
	return float(_row["warden_hp"])


# The ram force whose punch matches the plating at heft 1.
func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < _plating():
		force += 0.05
	return force


func _ram() -> void:
	_combat.strike(_warden, "ram", _matched_force())
	await physics_frame


func _fill() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		await _ram()
		guard += 1


func _smash(at: Vector3) -> void:
	_smashed = 0
	_player.reset_to(at + Vector3(-6.0, 6.0, 0.0))
	_player.grapple_to(at, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _seconds(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}


# A fresh game on the alpha table, entered at the stage, with the real Warden spawned by the flow.
func _start(stage: int) -> bool:
	_stage = stage
	_row = AlphaDefs.of(stage)
	_smashed = 0
	_posture_events = 0
	_opened = 0
	_kills.clear()
	_unsealed = 0
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	if _mutant:
		_game.ctx.stages = MutantTable.new()
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	_game.events.posture_changed.connect(func(_e: Node3D, _p: float, _s: bool): _posture_events += 1)
	_game.events.weak_point_opened.connect(func(_id: String, _at: Vector3, _seconds: float): _opened += 1)
	_game.events.enemy_killed.connect(func(kind: String, _at: Vector3, _v: int): _kills.append(kind))
	_game.events.beacon_unsealed.connect(func(_s: int): _unsealed += 1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		_report("stage %d spawns a Warden" % stage, false, "no Warden on the alpha table")
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	return true


func _run() -> void:
	for stage in [1, 2]:
		await _contract(stage)
		_game.free()
		await _start(stage)
		await _contacts(stage)
		_game.free()
	await _rack_case(3)
	await _no_rack(1)
	await _no_rack(2)
	print("world_one_wardens_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _contract(stage: int) -> void:
	if not await _start(stage):
		return
	var name := "stage %d" % stage
	var family: String = _row["warden_family"]
	var missing: Array = BossContract.conforms(_warden, BossContract.TARGET)
	_report("%s Warden conforms to the boss contract" % name, missing.is_empty(), "missing %s" % [missing])
	_report("%s row is the alpha row" % name, _warden.fight() == "posture" and _warden.family == family and _warden.plating == _plating()
			and _warden.max_hp == _hp() and _warden.chunks_left() == 4 and _warden.posture() == 0.0,
		"fight %s, family %s, plating %.0f, hp %.0f, %d chunks, posture %.1f" % [_warden.fight(), _warden.family, _warden.plating,
			_warden.max_hp, _warden.chunks_left(), _warden.posture()])


# Rams fill the bar to a stagger, a smash on the open core cracks then shatters one chunk, four
# chunks kill it, the stage unseals, and the plate and the ring are mounted for the fight.
func _contacts(stage: int) -> void:
	if not is_instance_valid(_warden):
		return
	var name := "stage %d" % stage
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)
	if is_instance_valid(_warden.guard):
		for drone in _warden.guard.alive():
			drone.set_physics_process(false)
	await _ram()
	var plate: Control = _game.hud.boss_plate
	var ring: Node = _warden.get_node_or_null("WardenRing")
	_report("%s plate and ring mount for the fight" % name, plate != null and plate.get_parent() != null and ring != null,
		"plate %s, ring %s" % [plate, ring])
	for i in 2:
		await _ram()
	_report("%s rams fill the bar" % name, absf(_warden.posture() - 90.0) < 1.0 and not _warden.staggered() and _posture_events >= 3,
		"posture %.1f after three matched rams, %d posture_changed" % [_warden.posture(), _posture_events])
	await _ram()
	_report("%s the fourth ram staggers it" % name, _warden.staggered() and _warden.posture() == 100.0 and _opened == 1 and _warden.hp == _hp(),
		"staggered %s, posture %.1f, openings %d, hp %.1f" % [_warden.staggered(), _warden.posture(), _opened, _warden.hp])
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	for chunk in 4:
		var before: float = _warden.hp
		var left: int = _warden.chunks_left()
		_player.reset_to(_ground(OUT))
		await _seconds(0.3)
		await _fill()
		if chunk == 0:
			await physics_frame
			await _ram()
			_report("%s a ram on the open core cracks it and takes no health" % name, _warden.chunk_cracked() and _warden.staggered()
				and _warden.hp == before and _warden.chunks_left() == left, "cracked %s, hp %.1f, chunks %d" % [_warden.chunk_cracked(), _warden.hp, _warden.chunks_left()])
		_player.reset_to(_ground(OUT))
		await _smash(_top())
		await _frames(2)
		if is_instance_valid(_warden):
			_report("%s smash %d shatters exactly one chunk" % [name, chunk + 1],
				before - _warden.hp == _hp() / 4.0 and _warden.chunks_left() == left - 1 and not _warden.staggered(),
				"hp %.1f to %.1f, chunks %d to %d, staggered %s" % [before, _warden.hp, left, _warden.chunks_left(), _warden.staggered()])
		else:
			_report("%s smash %d kills the last chunk" % [name, chunk + 1], chunk == 3 and left == 1, "the Warden is gone at chunk %d" % (chunk + 1))
		await _seconds(0.4)
	await _seconds(0.5)
	_report("%s four chunks unseal the stage" % name, _kills.has("warden") and _unsealed == 1,
		"kills %s, beacon_unsealed %d" % [_kills, _unsealed])


# One bowled rack pays 25 posture, a second ram before it reforms pays nothing.
func _rack_case(stage: int) -> void:
	if not await _start(stage):
		return
	_warden.set_physics_process(false)
	_warden._step_guard(Warden.GUARD_RESPAWN)
	for drone in _warden.guard.alive() if _warden.guard != null else []:
		drone.set_physics_process(false)
	var has_rack: bool = _warden.guard != null and _warden.guard.alive().size() == 10
	_report("stage %d swarm Warden has a ten-drone rack" % stage, has_rack and _warden.family == "swarm",
		"family %s, rack %s" % [_warden.family, "ten drones" if has_rack else "none"])
	if not has_rack:
		_game.free()
		return
	var cruise: float = _player.tuning.f("cruise")
	var threshold: float = cruise * SpeedTier.MULTIPLES[SpeedTier.CRUISE]
	_rack_hit(threshold)
	_report("one bowled rack pays exactly 25 posture", is_equal_approx(_warden.posture(), 25.0) and is_equal_approx(Warden.GUARD_RACK_POSTURE, 25.0)
		and not _warden.staggered() and _warden.hp == _hp(),
		"posture %.1f, hp %.1f" % [_warden.posture(), _warden.hp])
	_rack_hit(cruise * 3.0)
	_report("a second ram before it reforms pays nothing", is_equal_approx(_warden.posture(), 25.0),
		"posture %.1f" % _warden.posture())
	_game.free()


func _rack_hit(force: float) -> void:
	var drone: Node3D = _warden.guard.alive()[0]
	drone.knock(Vector3.RIGHT, 6.0 * float(drone.weight))
	_combat.strike(drone, "ram", force)


func _no_rack(stage: int) -> void:
	if not await _start(stage):
		return
	_warden.set_physics_process(false)
	_warden._physics_process(Warden.GUARD_RESPAWN)
	_report("stage %d reactor Warden has no rack" % stage, _warden.family == "reactor" and _warden.guard == null,
		"family %s, guard %s" % [_warden.family, _warden.guard])
	var want_variant := String(_row["warden_variant"])
	var window := 6.0 if want_variant == "meltdown" else BossPosture.STAGGER_SECONDS
	_report("stage %d variant '%s'" % [stage, want_variant], _warden.variant == want_variant
			and is_equal_approx(_warden._posture.stagger_seconds, window),
		"variant '%s', stagger_seconds %.1f" % [_warden.variant, _warden._posture.stagger_seconds])
	_warden.on_guard_scattered(null, Vector3.ZERO)
	_report("stage %d posture stays 0 without a rack" % stage, _warden.posture() == 0.0 and not _warden.family_open(),
		"posture %.1f" % _warden.posture())
	_game.free()
