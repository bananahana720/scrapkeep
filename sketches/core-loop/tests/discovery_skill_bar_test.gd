extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const T := preload("res://tests/support/t.gd")

# The skill bar's five discovery rows (design-v3/SKILL-BAR.md section 7), wave P-B unit B6,
# 2026-10-10. Each is staged on a real Game and opens exactly once: a second trigger in the
# same run does not publish synergy_discovered again. loaded_line: the first loaded bite
# fires its flavour. set_piece: the first ultimate lands. set_piece_core: a landing shatters
# an open Warden core. set_piece_cash_in: a landing pays a chain of three or more.
# set_piece_breakout: Q breaks a hostile hold. A cast on a standing line is not a loaded
# bite. Evidence limit: the rules in a headless run, not the feel of the card.

const DT := 1.0 / 60.0
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const IDS := ["loaded_line", "set_piece", "set_piece_core", "set_piece_cash_in", "set_piece_breakout"]

var _t := T.new("discovery_skill_bar_test")
var _game
var _player
var _combat
var _ult
var _source := Intent.Scripted.new()
var _opened: Array = []


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


func _enemy(kind: String, dx: float, dz := 0.0) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, _ground(dx, dz))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	return enemy


func _home() -> void:
	_player.reset_to(_ground(0.0) + Vector3.UP * 1.0)
	await physics_frame
	await physics_frame
	_player.kit.rewind_left = 0.0
	_player.kit.drop_line("reset")
	_player.chain.reset()
	_player.abilities.refill()
	_combat._line_load = {}
	_combat._bite_pending = false


func _count(id: String) -> int:
	return _opened.count(id)


func _fill() -> void:
	_ult.meter.locked = false
	_ult.meter.refund(_ult.meter.CAP)


func _aim_at(point: Vector3) -> Dictionary:
	var origin: Vector3 = _player.ball_position() + Vector3.UP * 2.0
	return {"origin": origin, "forward": (point - origin).normalized(), "harpoon": {"state": Augments.AIM_NONE}}


func _ride_out() -> void:
	for i in 300:
		if _ult.phase() == "idle":
			return
		await physics_frame


func _step(fields := {}) -> void:
	var intent = _player.intent
	intent.clear()
	for k in fields:
		intent.set(k, fields[k])
	_player._route_slots(DT)
	_combat._step_special(intent, DT)
	_combat._step_line(intent, DT)


# Pick slot 3 and click on one tick, release on the next: the line skill's cast.
func _cast_line() -> void:
	_step({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_step({"fire_released": true})


func _chain(enemy: Node3D, links: int) -> void:
	for i in links:
		_player.grapple_to(enemy.global_position, Vector3.UP, enemy)
		_player.release_grapple()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.6)
	_combat.heft_override = 1.0
	_ult = _combat.get("ultimate")
	_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool): _opened.append(id))

	# --- Data: five declared rows ------------------------------------------------------------
	var all_ids: Array = CodexEntries.ids()
	var missing: Array = IDS.filter(func(id): return not all_ids.has(id))
	_t.eq("00 the five framework rows are declared", missing, [])
	var named := {}
	for row in CodexEntries.all():
		named[row["id"]] = row["name"]
	_t.eq("00b the five names", [named.get("loaded_line"), named.get("set_piece"), named.get("set_piece_core"),
		named.get("set_piece_cash_in"), named.get("set_piece_breakout")],
		["Loaded Line", "First Ultimate", "Curtain Call", "Cash In", "Breakout"])

	# --- loaded_line -------------------------------------------------------------------------
	await _home()
	var a := _enemy("chaser", 0.0, 8.0)
	a.max_hp = 5000.0
	a.hp = 5000.0
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_cast_line()
	_t.eq("01 a cast on a standing line is not a loaded bite", _count("loaded_line"), 0)
	await _home()
	_cast_line()
	_t.eq("02 a load still waiting for a bite has opened nothing", [_combat.line_load().is_empty(), _count("loaded_line")], [false, 0])
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_step()
	_t.eq("03 the first loaded bite fires its flavour and opens Loaded Line", _count("loaded_line"), 1)
	await _home()
	_cast_line()
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_step()
	_t.eq("04 a second loaded bite does not reopen it", _count("loaded_line"), 1)

	# --- set_piece ---------------------------------------------------------------------------
	await _home()
	var b := _enemy("chaser", 20.0, 0.5)
	b.max_hp = 5000.0
	b.hp = 5000.0
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	await _ride_out()
	_t.eq("05 the first landing opens First Ultimate and nothing else", [_count("set_piece"), _count("set_piece_cash_in"),
		_count("set_piece_core"), _count("set_piece_breakout")], [1, 0, 0, 0])
	await _home()
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	await _ride_out()
	_t.eq("06 a second landing does not reopen First Ultimate", _count("set_piece"), 1)

	# --- set_piece_cash_in -------------------------------------------------------------------
	await _home()
	_chain(b, 2)
	var short: int = _player.chain.combo
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	await _ride_out()
	_t.eq("07 a landing that pays a chain under three opens no Cash In", [short < 3, _count("set_piece_cash_in")], [true, 0])
	await _home()
	_chain(b, 3)
	var combo: int = _player.chain.combo
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	await _ride_out()
	_t.eq("08 a landing that pays a chain of three opens Cash In", [combo >= 3, _count("set_piece_cash_in")], [true, 1])
	await _home()
	_chain(b, 3)
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	await _ride_out()
	_t.eq("09 a second paid chain does not reopen Cash In", _count("set_piece_cash_in"), 1)

	# --- set_piece_breakout ------------------------------------------------------------------
	await _home()
	var holds = _combat.fleet.holds
	var d := _enemy("chaser", -8.0, -4.0)
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	_t.eq("10 a Q with no hold opens no Breakout", _count("set_piece_breakout"), 0)
	await _ride_out()
	await _home()
	holds.catch(d, "net", ["jump"])
	var held: bool = holds.holding()
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	_t.eq("11 Q breaking a hold opens Breakout", [held, holds.holding(), _count("set_piece_breakout")], [true, false, 1])
	await _ride_out()
	await _home()
	holds.catch(d, "net", ["jump"])
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	_t.eq("12 a second broken hold does not reopen Breakout", _count("set_piece_breakout"), 1)
	await _ride_out()

	# --- set_piece_core ----------------------------------------------------------------------
	await _home()
	var w := _enemy("warden", 18.0, 0.0)
	_fill()
	_ult.press(_aim_at(_ground(18.0)))
	await _ride_out()
	_t.eq("13 a landing on a closed guard opens no Curtain Call", _count("set_piece_core"), 0)
	await _home()
	w._apply_posture({"gain": 100.0, "contact": false})
	var open: bool = w.staggered()
	_fill()
	_ult.press(_aim_at(_ground(18.0)))
	await _ride_out()
	_t.eq("14 a landing that shatters an open core opens Curtain Call", [open, _count("set_piece_core")], [true, 1])
	await _home()
	w._apply_posture({"gain": 100.0, "contact": false})
	_fill()
	_ult.press(_aim_at(_ground(18.0)))
	await _ride_out()
	_t.eq("15 a second shattered core does not reopen it", _count("set_piece_core"), 1)

	for id in IDS:
		_t.eq("16 %s opened exactly once in the run" % id, _count(id), 1)
	quit(_t.verdict())
