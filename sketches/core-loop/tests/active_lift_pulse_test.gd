extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Pulse := preload("res://src/combat/actives/lift_pulse.gd")
const T := preload("res://tests/support/t.gd")

# The Lift Pulse active (Highdraft Roosts; design page "Makers and Actives", 17 Oct 2026). A real
# Game with the first pilot. Covers: --actives on by default; on, the pulse racks with a valid
# chip on F and its own launch sound; a press fires on the press (no wind-up) and shoves only the
# machines inside the committed cone, straight away from the ball, while machines behind, to the
# side or past its reach take nothing; the knock grows per heft class, so a heavy flies further
# off a heavy ball; overflow pieces add knock; weapon damage mods scale the hit; Spiral Wave
# widens the cone, Cross Split adds an echo through the same cone, Chain Arc jumps only inside it;
# a new run clears it.
# Evidence limit: rules in a headless run, not the feel, and not the ring-out kill itself (that
# rule belongs to the island edges and the enemies).

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

var _t := T.new("active_lift_pulse_test")
var _game
var _player
var _combat
var _rack
var _source := Intent.Scripted.new()
var _fired: Array = []
var _struck: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _ground_at(at: Vector3) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.0)


func _enemy(at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", _ground_at(at))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	return enemy


func _press() -> void:
	_source.press = {"active_pressed": true}
	await physics_frame
	await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _clear_enemies() -> void:
	for enemy in _combat.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	await physics_frame


# Shoves one heavy (weight 3) standing `ahead` metres down the aim and returns how far it went.
func _heavy_shove(ahead: float) -> float:
	await _clear_enemies()
	_player.reset_to(_ground_at(FLAT_SHELF) + Vector3.UP)
	await _sim(0.1)
	var ball: Vector3 = _player.ball_position()
	var heavy := _enemy(ball + _forward() * ahead)
	heavy.weight = 3.0
	await _sim(0.05)
	var before: float = _flat(heavy.global_position, ball)
	_rack.charges = 1
	await _press()
	await _sim(1.0)
	return _flat(heavy.global_position, ball) - before


func _forward() -> Vector3:
	var forward: Vector3 = _game.ctx.aim_forward()
	forward.y = 0.0
	return forward.normalized()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	# Actives are on by default (24 Oct); the off checks below run with --actives=off.
	_t.eq("01 --actives defaults on", _game.tuning.option("actives"), "on")
	_game.tuning.set_option("actives", "off")
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.4)
	_rack = _combat.get("actives")
	_t.check("00 combat carries the active rack and the lift pulse row", _rack != null and not ActiveDefs.row("lift_pulse").is_empty())
	if _rack == null or ActiveDefs.row("lift_pulse").is_empty():
		quit(_t.verdict())
		return
	var row := ActiveDefs.row("lift_pulse")
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	ev.enemy_struck.connect(func(enemy_node: Node3D, kind: String, _force: float):
		if kind == Pulse.KIND:
			_struck.append(enemy_node))

	# --- Off by default; on, it racks -----------------------------------------------------
	_game.tuning.set_option("actives", "on")
	await _sim(0.1)
	_t.check("02 the pulse racks full", _rack.rack("lift_pulse") and _rack.charges == int(row["max_charges"]))
	var record: Dictionary = _rack.slot_record()
	_t.check("03 the bar chip is a valid slot on F", AbilitySlots.valid_slot(record) and record["id"] == "active_lift_pulse" and record["key"] == "key_f", str(record))
	_t.check("04 a rare Highdraft Roosts active that fires on the press",
		row["rarity"] == "rare" and row["maker"] == "highdraft_roosts" and float(row["windup"]) == 0.0, str(row))
	_t.check("05 its launch sound has a trim row and a recipe", SfxBank.has_recipe("active_lift_pulse") and SfxBank.new()._bake("active_lift_pulse").size() > 0)

	# --- The cone: in front is shoved away; behind, beside and past reach are untouched ------
	_player.reset_to(_ground_at(FLAT_SHELF) + Vector3.UP)
	await _sim(0.1)
	var ball: Vector3 = _player.ball_position()
	var forward := _forward()
	var side := forward.cross(Vector3.UP).normalized()
	var ahead := _enemy(ball + forward * 5.0)
	var ahead_wide := _enemy(ball + forward * 6.0 + side * 2.5)
	var behind := _enemy(ball - forward * 5.0)
	var beside := _enemy(ball + side * 5.0)
	var past := _enemy(ball + forward * (Pulse.RANGE + 4.0))
	await _sim(0.05)
	var start := {}
	for enemy in [ahead, ahead_wide, behind, beside, past]:
		start[enemy] = [_flat(enemy.global_position, ball), enemy.knocks, enemy.hp]
	await _press()
	_t.eq("06 the press fires one pulse at once", _fired, [["lift_pulse", 1]])
	_t.eq("07 one charge is spent", _rack.charges, int(row["max_charges"]) - 1)
	var cone: Dictionary = _rack._kinds["lift_pulse"].last_cone
	_t.check("08 both machines in front stood inside the committed cone",
		Pulse.inside(cone, ball + forward * 5.0) and Pulse.inside(cone, ball + forward * 6.0 + side * 2.5))
	# Read the outside machines on the press itself: later, a machine the pulse threw can roll into one.
	var untouched := [behind, beside, past].map(func(e): return not e in _struck and e.hp == 9999.0 and e.knocks == int(start[e][1]))
	await _sim(0.6)
	for enemy in [ahead, ahead_wide]:
		_t.check("09 a machine inside the cone is struck and shoved away from the ball",
			enemy in _struck and enemy.hp < 9999.0 and _flat(enemy.global_position, ball) > float(start[enemy][0]) + 2.0,
			"from %.2f to %.2f hp %.1f" % [start[enemy][0], _flat(enemy.global_position, ball), enemy.hp])
	_t.eq("10 machines behind, beside and past reach take nothing from the pulse", untouched, [true, true, true])
	_t.check("10b and the pulse never strikes them later", [behind, beside, past].all(func(e): return not e in _struck))
	_t.check("11 the cone test agrees with the hits", not Pulse.inside(cone, ball - forward * 5.0) and not Pulse.inside(cone, ball + side * 5.0)
		and not Pulse.inside(cone, ball + forward * (Pulse.RANGE + 0.5)) and Pulse.inside(cone, ball + forward * 5.0)
		and not Pulse.inside(cone, ball + forward * 5.0 + Vector3.UP * (Pulse.HEIGHT_BAND + 1.0)))

	# --- Heft class: a heavy ball throws a heavy machine much further -----------------------
	var kind = _rack._kinds["lift_pulse"]
	var run = _game.ctx.run
	_t.eq("12 a light ball sits in heft class 1", run.heft_class(), 1)
	var light_knock: float = kind.knock_for(0)
	var light_push: float = await _heavy_shove(4.0)
	var mass_before: float = run.mass
	run.mass = 2000.0
	_t.eq("13 a heavy ball reaches heft class 5", run.heft_class(), 5)
	_t.near("14 the knock climbs by a step per heft class", kind.knock_for(0), Pulse.KNOCK + Pulse.KNOCK_PER_CLASS * 4.0, 0.01)
	var heavy_push: float = await _heavy_shove(4.0)
	_t.check("15 a class-5 pulse throws a heavy at least three times as far", heavy_push > light_push * 3.0 and heavy_push > 8.0,
		"class 1 %.2f m, class 5 %.2f m (knock %.1f to %.1f)" % [light_push, heavy_push, light_knock, kind.knock_for(0)])
	run.mass = mass_before

	# --- Overflow and weapon damage scale it -------------------------------------------------
	_t.near("16 each banked overflow piece adds knock", kind.knock_for(2), kind.knock_for(0) * (1.0 + 2.0 * Pulse.BONUS_KNOCK), 0.01)
	var base: float = kind.damage()
	_game.tuning.set_mod("weapon_damage", 2.0)
	_t.near("17 weapon damage mods scale the hit", kind.damage(), base * 2.0, 0.01)
	_game.tuning.clear_mods()

	# --- Patterns: Spiral Wave widens, Cross Split echoes through the same cone ------------
	var narrow: float = kind.half_angle()
	run.add_part("spiral_wave", "test")
	await physics_frame
	_t.check("18 Spiral Wave widens the cone", kind.half_angle() > narrow, "%.1f to %.1f" % [narrow, kind.half_angle()])
	run.add_part("cross_split", "test")
	await physics_frame
	await _clear_enemies()
	_player.reset_to(_ground_at(FLAT_SHELF) + Vector3.UP)
	await _sim(0.1)
	ball = _player.ball_position()
	var echo_target := _enemy(ball + _forward() * 3.0)
	_fired.clear()
	_struck.clear()
	var pulses_before: int = kind.pulses
	_rack.charges = 1
	await _press()
	_t.eq("19 with Cross Split the fire counts a pulse and an echo", _fired, [["lift_pulse", 2]])
	var first_cone: Dictionary = kind.last_cone
	var echo_cone: Dictionary = kind.echoes[0]["cone"] if not kind.echoes.is_empty() else {}
	_t.check("20 the echo is queued on the very cone the first pulse drew", echo_cone == first_cone and _struck.count(echo_target) == 1,
		"same %s strikes %d" % [echo_cone == first_cone, _struck.count(echo_target)])
	await _sim(Pulse.ECHO_GAP + 0.1)
	_t.check("20b the echo lands and strikes the machine again", kind.pulses == pulses_before + 2 and kind.echoes.is_empty()
		and _struck.count(echo_target) == 2, "pulses %d echoes %d strikes %d" % [kind.pulses - pulses_before, kind.echoes.size(), _struck.count(echo_target)])

	# --- Chain Arc jumps only to machines inside the cone ---------------------------------
	run.add_part("chain_arc", "test")
	await physics_frame
	await _clear_enemies()
	_player.reset_to(_ground_at(FLAT_SHELF) + Vector3.UP)
	await _sim(0.1)
	ball = _player.ball_position()
	forward = _forward()
	side = forward.cross(Vector3.UP).normalized()
	var front := _enemy(ball + forward * 3.0)
	var behind_close := _enemy(ball - forward * 2.0)
	await _sim(0.05)
	_struck.clear()
	var chains_before: int = kind.chain_hits
	_rack.charges = 1
	await _press()
	_t.check("20c Chain Arc never jumps to a machine outside the cone", front in _struck and not behind_close in _struck
		and kind.chain_hits == chains_before, "front %s behind %s chains %d" % [front in _struck, behind_close in _struck, kind.chain_hits - chains_before])
	await _clear_enemies()
	_player.reset_to(_ground_at(FLAT_SHELF) + Vector3.UP)
	await _sim(0.1)
	ball = _player.ball_position()
	_enemy(ball + forward * 3.0)
	_enemy(ball + forward * 6.0 + side * 1.0)
	await _sim(0.05)
	_rack.charges = 1
	chains_before = kind.chain_hits
	await _press()
	_t.check("20d Chain Arc jumps between machines inside the cone", kind.chain_hits > chains_before,
		"chains %d" % [kind.chain_hits - chains_before])
	var punch_base: float = kind.damage()
	_t.check("20e punch is part of the hit", is_equal_approx(punch_base, (Pulse.BASE_DAMAGE + float(_game.ctx.build.punch_bonus())) * _game.tuning.mod("weapon_damage")))

	# --- A new run clears it ------------------------------------------------------------------
	_rack.charges = 1
	_rack.press()
	ev.run_started.emit("pylon_engineer")
	_t.check("21 a new run empties the rack and drops pending echoes", _rack.active_id == "" and kind.echoes.is_empty())
	quit(_t.verdict())
