extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# Reach's posture guard rack pays one fixed quarter-bar burst for the ram that
# scatters it at cruise or above. Guns and later hits on following drones pay nothing;
# reform permits another burst. The burst publishes posture and cannot hit the core.
# Scene fixtures use the real rack, knock-before-strike contact order and combat bus.
# Reform advances the formation's simulated clock; no wall-clock waits or player verdict.

var _game
var _combat
var _warden
var _reactor
var _failures := 0
var _posture_events := 0
var _opened := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _rack() -> void:
	_warden._step_guard(Warden.GUARD_RESPAWN)
	for drone in _warden.guard.alive():
		drone.set_physics_process(false)


func _hit(kind: String, force: float) -> void:
	var drone: Node3D = _warden.guard.alive()[0]
	# player_ball._on_enemy_touched and combat.deal_hit both knock before strike.
	drone.knock(Vector3.RIGHT, 6.0 * float(drone.weight))
	_combat.strike(drone, kind, force)


func _reform() -> void:
	await physics_frame
	_warden.guard.step(_warden.guard.FOLLOW, Vector3(999.0, 0.0, 999.0), 0.0)
	_report("rack reforms on its existing clock", not _warden.guard.following(), "state %s" % _warden.guard.state)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_combat = _game.ctx.spawner
	_reactor = _game.flow.warden
	_reactor.set_physics_process(false)
	_game.player.reset_to(_game.ctx.terrain.drop_point(0.0, 0.0, 1.5))
	var row: Dictionary = SliceDefs.of(1).duplicate(true)
	row["warden_family"] = "swarm"
	_warden = Warden.new()
	_game.add_child(_warden)
	_warden.position = _reactor.position + Vector3(80.0, 0.0, 0.0)
	_warden.setup(_game.player, _game.ctx.terrain, _game, Callable(_game.flow, "in_play"), 1.0,
		{"stage": row["stage"], "family": row["warden_family"], "plating": row["warden_plating"], "hp": row["warden_hp"],
		"posture": row["posture"], "fleet": _combat.fleet})
	_warden.set_physics_process(false)
	_game.events.posture_changed.connect(func(enemy: Node3D, _p: float, _s: bool):
		if enemy == _warden:
			_posture_events += 1)
	_game.events.weak_point_opened.connect(func(_id: String, _at: Vector3, _seconds: float): _opened += 1)
	_rack()
	_report("swarm posture rack exists", _warden.fight() == "posture" and _warden.guard.alive().size() == 10,
		"fight %s, drones %d" % [_warden.fight(), _warden.guard.alive().size()])
	_report("burst is a quarter bar", is_equal_approx(Warden.GUARD_RACK_POSTURE, BossPosture.FULL / 4.0),
		"burst %.1f" % Warden.GUARD_RACK_POSTURE)
	var cruise: float = _game.player.tuning.f("cruise")
	var threshold: float = cruise * SpeedTier.MULTIPLES[SpeedTier.CRUISE]
	_hit("ram", threshold - 0.01)
	_report("below cruise earns nothing", _warden.posture() == 0.0, "posture %.1f" % _warden.posture())
	await _reform()
	_hit("ram", threshold)
	_report("bowled rack pays the fixed burst", is_equal_approx(_warden.posture(), Warden.GUARD_RACK_POSTURE)
		and _posture_events == 1 and _opened == 0 and not _warden.family_open(),
		"posture %.1f, events %d, openings %d" % [_warden.posture(), _posture_events, _opened])
	_hit("ram", cruise * 3.0)
	_warden.on_guard_scattered(_warden.guard, Vector3.ZERO)
	_hit("ram", cruise * 3.0)
	_report("same scattered rack pays once", is_equal_approx(_warden.posture(), Warden.GUARD_RACK_POSTURE)
		and _posture_events == 1, "posture %.1f, events %d" % [_warden.posture(), _posture_events])
	await _reform()
	_hit("ram", cruise * 3.0)
	_report("reformed rack pays the same burst at high speed", is_equal_approx(_warden.posture(), 2.0 * Warden.GUARD_RACK_POSTURE),
		"posture %.1f" % _warden.posture())
	await _reform()
	var before: float = _warden.posture()
	_hit("runner", 9999.0)
	_report("gun knock scatter pays nothing", _warden.guard.following() and _warden.posture() == before
		and not _warden.chunk_cracked() and _warden.hp == row["warden_hp"], "posture %.1f, hp %.1f" % [_warden.posture(), _warden.hp])
	await physics_frame
	_hit("ram", cruise)
	_report("later ram on gun-scattered rack pays nothing", _warden.posture() == before, "posture %.1f" % _warden.posture())
	# Replenish a rack whose drones were killed, using the Warden's existing respawn.
	for drone in _warden.guard.alive():
		drone.free()
	_rack()
	_hit("ram", cruise)
	await _reform()
	_hit("ram", cruise)
	_report("rack burst fills the bar through the posture chassis", _warden.posture() == BossPosture.FULL
		and _warden.staggered() and _opened == 1 and _warden.hp == row["warden_hp"],
		"posture %.1f, staggered %s, openings %d, hp %.1f" % [_warden.posture(), _warden.staggered(), _opened, _warden.hp])
	await physics_frame
	var hp_before: float = _warden.hp
	_hit("runner", 9999.0)
	# 2026-10-04: the swarm's open point is "queen" (warden.gd FAMILY_POINTS), so strike family_point().
	_combat.strike(_warden, "runner", 9999.0, _warden.family_point())
	_report("guns cannot crack an open core through the rack", _warden.staggered() and not _warden.chunk_cracked()
		and _warden.hp == hp_before and _warden.chunks_left() == 4, "hp %.1f, chunks %d, cracked %s" % [_warden.hp, _warden.chunks_left(), _warden.chunk_cracked()])
	await _reform()
	_hit("ram", cruise)
	_report("rack burst never cracks or shatters during stagger", _warden.staggered() and not _warden.chunk_cracked()
		and _warden.hp == hp_before and _warden.chunks_left() == 4, "hp %.1f, chunks %d" % [_warden.hp, _warden.chunks_left()])
	_warden._step_posture(BossPosture.STAGGER_SECONDS + 0.1)
	await _reform()
	var contact: Node3D = _warden.guard.alive()[0]
	_game.player.reset_to(contact.global_position - Vector3(2.0, 0.0, 0.0))
	_game.player.set_velocity_now(Vector3(cruise, 0.0, 0.0))
	# The contact handler reads the solver's incoming history, before the bounce.
	_game.player._rigid.recent_velocities.assign([Vector3(cruise, 0.0, 0.0)])
	_game.player._on_enemy_touched(contact, Vector3.LEFT)
	_report("player ram contact earns the burst", _warden.guard.following()
		and is_equal_approx(_warden.posture(), Warden.GUARD_RACK_POSTURE), "posture %.1f" % _warden.posture())
	_reactor._physics_process(Warden.GUARD_RESPAWN)
	_reactor.on_guard_scattered(_warden.guard, Vector3.ZERO)
	_report("reactor is unchanged without a rack", _reactor.guard == null and _reactor.posture() == 0.0
		and not _reactor.family_open() and _reactor.family_opens == 0, "guard %s, posture %.1f" % [_reactor.guard, _reactor.posture()])
	_game.free()
	print("warden_guard_posture_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
