extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Rockets := preload("res://src/combat/actives/scrap_rockets.gd")
const T := preload("res://tests/support/t.gd")

# The active slot on F and its first active, the Scrap Rocket Rack (design page "Makers and
# Actives", 17 Oct 2026). A real Game with the first pilot. Covers: --actives is on by default;
# off, an F press does nothing; on, a run opens racked empty (0 charges, ruling ek) with a valid
# cooling bar chip on F; a press with a charge fires four homing rockets that strike machines as
# "rocket" and all burst; the charges spend and a dry press is refused "cooling"; a Jam lock
# refuses "jammed"; kills pay charge and, with the ultimate meter full, bank overflow rockets;
# weapon damage mods scale the rockets; a new run clears the rack. Evidence limit: rules in a
# headless run, not the feel.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)


# The rocket rack with a 0.5 s wind-up, standing in for the big actives that wind up.
class WindupRack:
	extends "res://src/combat/actives/active_rack.gd"

	func _row(id: String) -> Dictionary:
		var out: Dictionary = super._row(id).duplicate()
		out["windup"] = 0.5
		return out


var _t := T.new("active_rockets_test")
var _game
var _player
var _combat
var _rack
var _source := Intent.Scripted.new()
var _fired: Array = []
var _fails: Array = []
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


func _ground(dx: float, dz := 0.0) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, 1.0)


func _enemy(dx: float, dz: float) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", _ground(dx, dz))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	return enemy


func _press() -> void:
	_source.press = {"active_pressed": true}
	await physics_frame
	await physics_frame


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
	_t.check("00 combat carries the active rack", _rack != null)
	if _rack == null:
		quit(_t.verdict())
		return
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	ev.verb_failed.connect(func(verb: String, reason: String, _at: Vector3):
		if verb == "active":
			_fails.append(reason))
	ev.enemy_struck.connect(func(_enemy_node: Node3D, kind: String, _force: float):
		if kind == Rockets.KIND:
			_struck.append(kind))

	# --- Off by default ----------------------------------------------------------------
	await _press()
	_t.check("02 off: nothing is racked, F fires nothing and plays no refusal",
		_rack.active_id == "" and _fired.is_empty() and _fails.is_empty() and _rack.slot_record().is_empty(),
		"racked '%s' fired %s fails %s" % [_rack.active_id, _fired, _fails])

	# --- On: the starter is racked empty (ruling ek) -------------------------------------
	_game.tuning.set_option("actives", "on")
	await _sim(0.1)
	var cap := int(ActiveDefs.row(ActiveDefs.SCRAP_ROCKET)["max_charges"])
	_t.check("03 on: the run racks the Scrap Rocket Rack empty and charging",
		_rack.active_id == ActiveDefs.SCRAP_ROCKET and _rack.charges == 0 and _rack.progress > 0.0,
		"racked '%s' charges %d progress %.3f" % [_rack.active_id, _rack.charges, _rack.progress])
	var record: Dictionary = _rack.slot_record()
	_t.check("04 the bar chip is a valid cooling slot on F",
		AbilitySlots.valid_slot(record) and record["key"] == "key_f" and record["group"] == "chip" and record["state"] == "cooling",
		str(record))
	var bar: Array = AbilitySlots.new().slots(_game)
	_t.check("05 the HUD's slot list carries the active chip", bar.any(func(e): return e["id"] == "active_scrap_rocket"), str(bar.map(func(e): return e["id"])))
	await _press()
	_t.check("05b an opening press with zero charges is refused cooling",
		_fails == ["cooling"] and _fired.is_empty(), "fails %s fired %s" % [_fails, _fired])
	_fails.clear()
	_fired.clear()

	# --- A press: four homing rockets strike and burst ----------------------------------
	_rack.charges = cap
	_rack.progress = 0.0
	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.1)
	var ball: Vector3 = _player.ball_position()
	var targets := [_enemy(12.0, 4.0), _enemy(14.0, -5.0), _enemy(-10.0, 9.0)]
	for target in targets:
		target.max_hp = 9999.0
		target.hp = 9999.0
	await _sim(0.05)
	await _press()
	_t.eq("06 the press fires the rack once with four rockets", _fired, [[ActiveDefs.SCRAP_ROCKET, Rockets.ROCKETS]])
	_t.eq("07 one charge is spent", _rack.charges, cap - 1)
	await _sim(3.0)
	var kind = _rack._kinds[ActiveDefs.SCRAP_ROCKET]
	_t.check("08 every rocket burst and none is left flying", kind.rockets.is_empty() and kind.bursts == Rockets.ROCKETS,
		"flying %d bursts %d" % [kind.rockets.size(), kind.bursts])
	_t.check("09 the rockets homed onto machines (at least one strike each)", _struck.size() >= Rockets.ROCKETS,
		"rocket strikes %d, ball %s" % [_struck.size(), ball])
	var hurt := targets.filter(func(t): return t.hp < 9999.0)
	_t.check("10 rockets spread over the locked machines", hurt.size() >= 2, "hurt %d of %d" % [hurt.size(), targets.size()])

	# --- Charges, the dry press and Jam -------------------------------------------------
	_rack.charges = 0
	_rack.progress = 0.0
	_fails.clear()
	_fired.clear()
	await _press()
	_t.check("11 a press with no charge is refused cooling", _fails == ["cooling"] and _fired.is_empty(), "fails %s" % [_fails])
	_rack.charges = 1
	_rack.lock(0.5)
	_fails.clear()
	await _press()
	_t.check("12 a Jam lock refuses jammed and keeps the charge", _fails == ["jammed"] and _rack.charges == 1, "fails %s charges %d" % [_fails, _rack.charges])
	_t.eq("13 the chip reads unavailable while jammed", _rack.slot_record()["state"], "unavailable")
	await _sim(0.6)
	_t.check("14 the lock runs out", not _rack.locked())

	# --- Kills feed the rack; a full meter banks overflow rockets -----------------------
	kind.clear()
	_rack.charges = 0
	_rack.progress = 0.0
	var meter = _player.abilities.meter
	meter.reset()
	ev.enemy_killed.emit("chaser", ball, 1)
	var paid: float = _rack.progress
	_t.check("15 a kill pays a share of a charge", paid >= float(ActiveDefs.row(ActiveDefs.SCRAP_ROCKET)["kill_charge"]) - 0.001 and _rack.bonus == 0,
		"progress %.3f bonus %d" % [paid, _rack.bonus])
	meter.locked = false
	meter.refund(meter.CAP)
	ev.enemy_killed.emit("chaser", ball, 1)
	ev.enemy_killed.emit("chaser", ball, 1)
	_t.eq("16 with the meter full, two kills bank two overflow rockets", _rack.bonus, 2)
	_t.eq("17 the next volley carries them", kind.count_for(_rack.bonus), Rockets.ROCKETS + 2)
	for i in 10:
		ev.enemy_killed.emit("chaser", ball, 1)
	_t.eq("18 overflow holds at the cap", _rack.bonus, int(ActiveDefs.row(ActiveDefs.SCRAP_ROCKET)["bonus_cap"]))

	# --- A strong build makes stronger rockets ------------------------------------------
	var base: float = kind.damage()
	_game.tuning.set_mod("weapon_damage", 2.0)
	_t.near("19 weapon damage mods scale every rocket", kind.damage(), base * 2.0, 0.01)

	# --- A big active winds up; a Jam during the wind-up cancels it and refunds -------
	_game.tuning.clear_mods()
	var slow := WindupRack.new()
	_combat.add_child(slow)
	slow.setup(_game.ctx, _combat)
	slow._granted = true
	slow.rack(ActiveDefs.SCRAP_ROCKET)
	_fired.clear()
	_t.eq("21 a wind-up press fires nothing yet and spends the charge", [slow.press(), _fired.size(), slow.charges], ["", 0, cap - 1])
	_t.eq("22 the chip reads active while it winds up", slow.slot_record()["state"], "active")
	await _sim(0.3)
	_t.eq("23 still nothing before the wind-up ends", _fired.size(), 0)
	await _sim(0.3)
	_t.eq("24 it fires once when the wind-up ends", _fired.size(), 1)
	_fired.clear()
	slow.press()
	slow.lock(0.5)
	await _sim(0.7)
	_t.check("25 a Jam mid wind-up cancels the fire and refunds the charge", _fired.is_empty() and slow.charges == cap - 1 and slow.winding == 0.0,
		"fired %s charges %d" % [_fired, slow.charges])
	slow.press()
	slow.charges = cap
	slow.lock(0.5)
	_t.eq("26 a Jam refund never lifts charges past the cap", slow.charges, cap)
	slow.queue_free()

	# --- A new run clears the rack -------------------------------------------------------
	ev.run_started.emit("pylon_engineer")
	_t.check("20 a new run empties the rack until play racks the starter", _rack.active_id == "" and _rack.bonus == 0 and _rack.fires == 0)
	quit(_t.verdict())
