extends SceneTree

const Game := preload("res://src/game.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const Intent := preload("res://src/movement/intent.gd")

# The posture fight on the slice table, through combat.strike() and real contacts
# (LEGIBILITY section 4): rams fill the bar and posture_changed goes out; a full bar
# staggers the Warden, opens its core once and stops the pulse; a charge in flight is
# cancelled; health falls only through a shatter, and a harpoon smash on the open core
# removes exactly one chunk; four chunks kill it and the stage unseals.
# Contacts are real physics from placed starts, not a
# player's run; every wait is counted in physics frames.

const OUT := 58.0
const NEAR := 5.0
const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const HP := 800.0

# F6 2026-10-04: the local plating regression is gone; every Warden fights on posture.

var _game
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _smashed := 0
var _posture_events := 0
var _opened: Array = []
var _hits := 0
var _kills: Array = []
var _unsealed := 0
var _offered := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
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


# The ram force whose punch matches the plating at heft 1.
func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING:
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


func _start() -> bool:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	_game.events.posture_changed.connect(func(_e: Node3D, _p: float, _s: bool): _posture_events += 1)
	_game.events.weak_point_opened.connect(func(id: String, _at: Vector3, seconds: float): _opened.append([id, seconds]))
	_game.events.enemy_killed.connect(func(kind: String, _at: Vector3, _v: int): _kills.append(kind))
	_game.events.beacon_unsealed.connect(func(_stage: int): _unsealed += 1)
	_game.events.reward_offered.connect(func(_offers: Array): _offered += 1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		print("warden_posture_test: FAIL (no Warden on the slice table)")
		return false
	_warden.hit_player.connect(func(_amount: float, _push: Vector3): _hits += 1)
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	return true


func _run() -> void:
	if not await _start():
		quit(1)
		return
	await _direct_damage()
	await _charge_lands()
	await _charge_cancelled()
	await _bar_and_stagger()
	await _filling_smash()
	await _chunks()
	_game.free()
	print("warden_posture_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _direct_damage() -> void:
	var removed: float = _warden.take_damage(9999.0)
	_report("a direct take_damage removes nothing", removed == 0.0 and _warden.hp == HP and is_instance_valid(_warden) and _kills.is_empty(),
		"take_damage(9999) removed %.1f, hp %.1f of %.1f, kills %s" % [removed, _warden.hp, HP, _kills])
	_report("the fight is posture", _warden.fight() == "posture" and _warden.chunks_left() == 4 and _warden.posture() == 0.0,
		"fight %s, %d chunks, posture %.1f" % [_warden.fight(), _warden.chunks_left(), _warden.posture()])


# Player within the core ring, pulse clock set so a charge starts on the next tick.
func _prime_charge() -> void:
	_player.reset_to(_ground(NEAR))
	_warden._pulse_clock = _warden.PULSE_CYCLE - _warden.PULSE_TELEGRAPH
	await _frames(3)


func _charge_lands() -> void:
	_hits = 0
	var pulses: int = _warden.pulses
	await _prime_charge()
	var charging: bool = _warden._charging
	await _seconds(2.4)
	_report("control: an undisturbed charge lands", charging and _warden.pulses == pulses + 1 and _hits == 1,
		"charging %s, pulses %d to %d, hit_player %d times" % [charging, pulses, _warden.pulses, _hits])


func _charge_cancelled() -> void:
	_hits = 0
	_posture_events = 0
	var pulses: int = _warden.pulses
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)
	await _prime_charge()
	var ring: Node3D = _warden.telegraph()
	var was_charging: bool = _warden._charging and is_instance_valid(ring)
	_player.reset_to(_ground(NEAR))
	await _fill()
	await _frames(2)
	_report("a stagger cancels the charge", was_charging and _warden.staggered() and not _warden._charging and _warden._charge_time == 0.0 \
			and _warden._pulse_clock == 0.0 and not is_instance_valid(ring) and _warden.telegraph() == null and _warden._core_ring == null,
		"was charging %s, staggered %s, charging now %s, clock %.2f, ring freed %s" % [was_charging, _warden.staggered(), _warden._charging, _warden._pulse_clock, not is_instance_valid(ring)])
	var lift_before: bool = _warden.last_pulse_lifted
	await _seconds(2.6)
	_report("nothing lands from the cancelled charge", _hits == 0 and _warden.pulses == pulses and _warden.last_pulse_lifted == lift_before,
		"hit_player %d times, pulses %d to %d, lifted %s" % [_hits, pulses, _warden.pulses, _warden.last_pulse_lifted])
	await _seconds(2.0)
	_report("the stagger runs out unshattered", not _warden.staggered() and _warden.chunks_left() == 4 and _warden.hp == HP and _warden.posture() == 0.0,
		"staggered %s, %d chunks, hp %.1f, posture %.1f" % [_warden.staggered(), _warden.chunks_left(), _warden.hp, _warden.posture()])
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)


func _bar_and_stagger() -> void:
	_warden._pulse_clock = 1.0
	_posture_events = 0
	_opened.clear()
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)
	for i in 3:
		await _ram()
	_report("rams fill the bar", absf(_warden.posture() - 90.0) < 0.1 and not _warden.staggered() and _posture_events == 3,
		"posture %.1f after three matched rams, %d posture_changed" % [_warden.posture(), _posture_events])
	var before_bolt: float = _warden.posture()
	_combat.strike(_warden, "runner", PLATING)
	_report("a gun bolt adds 1.5", absf(_warden.posture() - before_bolt - 1.5) < 0.01, "a bolt added %.2f" % (_warden.posture() - before_bolt))
	_warden._pulse_clock = 1.5
	_player.reset_to(_ground(NEAR))
	await _frames(2)
	var running: float = _warden._pulse_clock
	await _ram()
	_report("the fourth ram staggers it", _warden.staggered() and _warden.posture() == 100.0 and _warden.stagger_left() > 3.5,
		"staggered %s, posture %.1f, %.2f s left" % [_warden.staggered(), _warden.posture(), _warden.stagger_left()])
	_report("weak_point_opened fires once with the core", _opened.size() == 1 and _opened[0][0] == "core" and is_equal_approx(_opened[0][1], 4.0),
		"opened %s" % [_opened])
	var points: Array = _warden.weak_points()
	_report("the core is the weak point", _warden.family_open() and points.size() == 1 and points[0]["id"] == "core", "points %s" % [points.map(func(p): return p["id"])])
	var posture_events := _posture_events
	await _seconds(1.0)
	_report("the pulse clock stops", running > 1.5 and _warden._pulse_clock == 0.0 and not _warden._charging,
		"clock %.2f before, %.2f after a second in reach" % [running, _warden._pulse_clock])
	var removed: float = _warden.take_damage(9999.0)
	_report("a direct take_damage in a stagger removes nothing", removed == 0.0 and _warden.hp == HP and _warden.chunks_left() == 4,
		"removed %.1f, hp %.1f" % [removed, _warden.hp])
	_combat.strike(_warden, "runner", 9999.0)
	_combat.strike(_warden, "synergy", 9999.0)
	_report("guns and synergies cannot touch the core", _warden.hp == HP and not _warden.chunk_cracked() and _warden.staggered(),
		"hp %.1f, cracked %s" % [_warden.hp, _warden.chunk_cracked()])
	_report("posture_changed went out", posture_events >= 4, "%d posture_changed" % posture_events)
	await _seconds(3.2)
	_report("it closes when the stagger runs out", not _warden.staggered() and _warden.posture() == 0.0, "staggered %s, posture %.1f" % [_warden.staggered(), _warden.posture()])


# A real smash that fills the bar opens the Warden and removes nothing: the landing's own
# shockwave arrives on the stagger's frame and is not a core hit.
func _filling_smash() -> void:
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)
	for i in 3:
		await _ram()
	var parts: Array = []
	var record := func(enemy: Node3D, kind: String, force: float):
		if enemy == _warden:
			parts.append([kind, String(_combat.resolve(enemy, kind, force)["part"])])
	_game.events.enemy_struck.connect(record)
	await _smash(_top())
	var landing := parts.duplicate()
	_combat.strike(_warden, "runner", 10.0, "core")
	_game.events.enemy_struck.disconnect(record)
	var slams := landing.filter(func(entry): return entry[0] == "slam")
	_report("a smash that fills the bar opens it and removes nothing", _smashed == 1 and _warden.staggered() and _warden.chunks_left() == 4 and _warden.hp == HP,
		"smashes %d, staggered %s, %d chunks, hp %.1f; landing %s" % [_smashed, _warden.staggered(), _warden.chunks_left(), _warden.hp, landing])
	_report("the stagger frame's shockwave is not a core hit", not slams.is_empty() and slams.all(func(entry): return entry[1] == ""),
		"landing strikes %s" % [landing])
	_report("a bolt on the open core is not a core hit", parts.back() == ["runner", ""], "the bolt resolved as %s" % [parts.back()])
	_player.reset_to(_ground(OUT))
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)


func _chunks() -> void:
	for chunk in 4:
		var before: float = _warden.hp
		var left: int = _warden.chunks_left()
		_player.reset_to(_ground(OUT))
		await _seconds(0.3)
		await _fill()
		_player.reset_to(_ground(OUT))
		await _smash(_top())
		await _frames(2)
		if is_instance_valid(_warden):
			_report("smash %d removes exactly one chunk" % (chunk + 1), before - _warden.hp == HP / 4.0 and _warden.chunks_left() == left - 1 and not _warden.staggered(),
				"hp %.1f to %.1f, chunks %d to %d, staggered %s" % [before, _warden.hp, left, _warden.chunks_left(), _warden.staggered()])
		else:
			_report("smash %d kills the last chunk" % (chunk + 1), chunk == 3 and left == 1, "the Warden is gone at chunk %d" % (chunk + 1))
		await _seconds(0.4)
	await _seconds(0.5)
	_report("four chunks kill it and the stage unseals", _kills.has("warden") and _unsealed == 1 and _offered >= 1,
		"kills %s, beacon_unsealed %d, reward_offered %d" % [_kills, _unsealed, _offered])
