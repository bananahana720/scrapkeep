extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Silo := preload("res://src/combat/actives/silo_battery.gd")
const RunState := preload("res://src/core/run_state.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# The Silo Battery (Fleet Surplus, relic; design page "Makers and Actives", 17 Oct 2026). A real
# Game with the first pilot and --actives on. Covers: the row is a relic with a 0.5 s wind-up;
# the press commits amber target rings on the nearest machines and nothing lands before the
# wind-up and the fall end; the strikes land only inside those rings (a machine moved out of its
# ring and one with no ring take nothing) and the rings clear; heft class adds one ring each and
# overflow adds rings (banked before the press) or shells (banked during it); a Jam mid wind-up
# drops the rings and refunds; weapon damage mods scale the strike; the sound has its recipe.
# Evidence limit: rules in a headless run, not the feel.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const ID := "silo_battery"

var _t := T.new("active_silo_test")
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


func _ground(dx: float, dz := 0.0) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, 1.0)


func _enemy(dx: float, dz: float) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", _ground(dx, dz))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	return enemy


func _clear_enemies() -> void:
	for enemy in _combat.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_game.tuning.set_option("actives", "on")
	await _sim(0.4)
	_rack = _combat.get("actives")
	_t.check("00 combat carries the active rack", _rack != null)
	if _rack == null:
		quit(_t.verdict())
		return
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	ev.enemy_struck.connect(func(enemy_node: Node3D, kind: String, _force: float):
		if kind == Silo.KIND:
			_struck.append(enemy_node))

	# --- The row ------------------------------------------------------------------------
	var row := ActiveDefs.row(ID)
	_t.check("01 the Silo Battery is a Fleet Surplus relic with a 0.5 s wind-up",
		row.get("rarity") == "relic" and row.get("maker") == "fleet_surplus" and is_equal_approx(float(row.get("windup", 0.0)), 0.5), str(row))
	_t.check("02 its launch sound has a trim row and a recipe",
		SfxBank.has_recipe("active_" + ID) and SfxBank.samples("active_" + ID).size() > 0)

	# --- A press commits the rings; nothing lands before the wind-up and the fall -------
	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.1)
	_combat.heft_override = RunState.HEFT_CLASS_AT[0]
	var ringed := [_enemy(10.0, 4.0), _enemy(12.0, -6.0)]
	var walker := _enemy(-9.0, 8.0)
	var far := _enemy(-38.0, -24.0)
	await _sim(0.05)
	_t.check("03 the rack takes the Silo Battery", _rack.rack(ID) and _rack.charges == int(row["max_charges"]))
	var kind = _rack._kinds[ID]
	_t.eq("04 heft class 1 shows the base rings", kind.count_for(0), Silo.RINGS)
	_t.eq("05 the press winds up and spends the charge", [_rack.press(), _rack.charges, _fired.size()], ["", int(row["max_charges"]) - 1, 0])
	var rings: Array = kind.rings.map(func(e): return e["ring"])
	_t.check("06 begin committed one amber telegraph ring per strike",
		rings.size() == Silo.RINGS and rings.all(func(r): return is_instance_valid(r) and r.is_in_group("telegraph") and r.color == Palette.AMBER and not r.is_hostile()),
		"rings %d" % rings.size())
	var marked := func(enemy: Node3D) -> bool: return rings.any(func(r): return r.contains(enemy.global_position))
	_t.check("07 the three nearest machines are ringed; the far one is not",
		ringed.all(marked) and marked.call(walker) and not marked.call(far))
	# The walker steps out of its ring after it was shown.
	walker.global_position = _ground(-30.0, 26.0)
	await _sim(0.4)
	_t.check("08 nothing is struck during the wind-up", _struck.is_empty() and _fired.is_empty(), "struck %d fired %s" % [_struck.size(), _fired])
	await _sim(0.15)
	_t.eq("09 the hatch opens once at the wind-up's end, one shell per ring", _fired, [[ID, Silo.RINGS]])
	_t.check("10 the shells are still falling", _struck.is_empty() and kind.falling > 0.0, "struck %d" % _struck.size())
	await _sim(Silo.FALL + 0.05)
	_t.check("11 every ringed machine is struck", ringed.all(func(e): return e in _struck and e.hp < 9999.0), "struck %d" % _struck.size())
	_t.check("12 nothing outside a shown ring is struck",
		not (walker in _struck) and not (far in _struck) and is_equal_approx(walker.hp, 9999.0) and is_equal_approx(far.hp, 9999.0))
	_t.check("13 the rings clear after the landing", kind.rings.is_empty() and rings.all(func(r): return not is_instance_valid(r) or r.is_queued_for_deletion()))

	# --- Heft class and overflow ---------------------------------------------------------
	_combat.heft_override = RunState.HEFT_CLASS_AT[2]
	_t.eq("14 heft class 3 adds two rings", kind.count_for(0), Silo.RINGS + 2)
	await _clear_enemies()
	_fired.clear()
	_rack.charges = 1
	_rack.bonus = 2
	_rack.press()
	_t.eq("15 overflow banked before the press adds rings, rings with no machine fill the aim",
		kind.rings.size(), Silo.RINGS + 2 + 2)
	_rack.bonus = 3
	await _sim(0.55)
	_t.eq("16 overflow banked during the wind-up drops extra shells into the shown rings", _fired, [[ID, Silo.RINGS + 2 + 3]])
	await _sim(Silo.FALL + 0.05)
	_t.eq("17 every shell landed", kind.strikes, Silo.RINGS + Silo.RINGS + 2 + 3)

	# --- A Jam mid wind-up drops the rings and refunds ------------------------------------
	_combat.heft_override = RunState.HEFT_CLASS_AT[0]
	_fired.clear()
	_rack.charges = 1
	_rack.bonus = 0
	_rack.press()
	var jammed: Array = kind.rings.map(func(e): return e["ring"])
	_rack.lock(0.5)
	_t.check("18 a Jam mid wind-up drops every ring and refunds the charge",
		kind.rings.is_empty() and _rack.charges == 1 and jammed.all(func(r): return not is_instance_valid(r) or r.is_queued_for_deletion()))
	await _sim(1.2)
	_t.eq("19 the jammed strike never fires", _fired.size(), 0)

	# --- A strong build hits harder -------------------------------------------------------
	var base: float = kind.damage()
	_game.tuning.set_mod("weapon_damage", 2.0)
	_t.near("20 weapon damage mods scale every strike", kind.damage(), base * 2.0, 0.01)
	_game.tuning.clear_mods()

	# --- A press during the fall lands the falling strike first; a stage clear drops it ---
	var target := _enemy(8.0, 0.0)
	await _sim(0.05)
	_struck.clear()
	_rack.charges = 2
	_rack.press()
	await _sim(0.55)
	_t.check("21 the shells are falling", kind.falling > 0.0 and _struck.is_empty())
	_rack.press()
	_t.check("22 a second press mid-fall lands the falling strike instead of dropping it",
		target in _struck and kind.rings.size() == Silo.RINGS, "struck %d rings %d" % [_struck.size(), kind.rings.size()])
	var held: Array = kind.rings.map(func(e): return e["ring"])
	_struck.clear()
	_game.events.stage_content_cleared.emit("test")
	await _sim(1.2)
	_t.check("23 a stage clear mid wind-up drops the rings and strikes nothing",
		kind.rings.is_empty() and _struck.is_empty() and held.all(func(r): return not is_instance_valid(r) or r.is_queued_for_deletion()))
	_combat.heft_override = -1.0
	quit(_t.verdict())
