# 2026-10-12 FIXTURE-ADAPT: 50e4a6a added codex profile reads; the scene-free flow has no saved profile.
extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Codex := preload("res://src/core/codex.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Intent := preload("res://src/movement/intent.gd")

# Field notes unlock one per lore moment (the seven below), exchange rows on zone entry.
# The codex half runs without a scene; the HUD half boots the game for the pulse.

const DIR := "user://lore_unlock_test/"
const ZONES := ["1-1", "1-2", "2-1", "2-2", "3-1", "3-2"]

class Table:
	func world_of(stage: int) -> int:
		return AlphaDefs.world_of(stage)

	func local(stage: int) -> int:
		return AlphaDefs.local(stage)

class Ctx:
	var stages := Table.new()
	var profile = null

class FakeFlow:
	var ctx := Ctx.new()

var _t
var _events
var _codex
var _found: Array[String] = []


func _initialize() -> void:
	_t = T.new("lore_unlock_test")
	_check_codex()
	_events.free()
	_codex.free()
	await _check_hud()
	quit(_t.verdict())


func _fresh(dir: String):
	if _codex != null:
		_codex.free()
		_events.free()
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute(dir.path_join(Codex.STATE_FILE))
	_events = GameEvents.new()
	_codex = Codex.new()
	_codex.setup(_events, null, FakeFlow.new(), dir)
	_found = []
	_codex.lore_found.connect(func(id: String): _found.append(id))


func _moment(i: int) -> void:
	match i:
		0: _events.activity_done.emit("enemy_camp", Vector3.ZERO)
		1: _events.world_fact.emit("wall_crumbled", Vector3.ZERO)
		2: _events.rescue_completed.emit("rivet")
		3: _events.part_gained.emit(_relic_part(), "chest")
		4:
			_events.posture_changed.emit(null, 100.0, true)
			_events.posture_changed.emit(null, 0.0, false)
		5: _events.beacon_unsealed.emit(1)
		6: _events.stage_cleared.emit(1)


func _relic_part() -> String:
	var Relics := load("res://src/build/relics.gd")
	return Relics.part_of(Relics.ids()[0])


func _ids(kind: String, zone := "") -> Array:
	return LoreRows.ROWS.filter(func(r): return r["kind"] == kind and (zone == "" or r["zone"] == zone)).map(func(r): return r["id"])


func _zone_known(zone: String) -> int:
	return _ids("field_note", zone).filter(func(id): return _codex.known(id)).size()


func _check_codex() -> void:
	_fresh(DIR)
	for z in ZONES.size():
		_events.stage_entered.emit(z + 1, false)
		for m in 7:
			_moment(m)
	var notes := _ids("field_note")
	var exchanges := _ids("exchange")
	_t.eq("42 field notes in the table", notes.size(), 42)
	_t.eq("all 42 field notes known", notes.filter(func(id): return _codex.known(id)).size(), 42)
	_t.eq("all 18 exchange rows known", exchanges.filter(func(id): return _codex.known(id)).size(), 18)
	_t.eq("lore_found fired once per note, in row order", _found, notes)
	var before: Array = _codex.discovered().duplicate()
	_moment(0)
	_t.eq("a moment with nothing unknown changes nothing", _codex.discovered().size(), before.size())
	_t.eq("no intro row was touched", _ids("intro").filter(func(id): return _codex.known(id)).size(), 0)

	_fresh(DIR)
	_events.stage_entered.emit(1, false)
	for m in 7:
		_moment(m)
	_t.eq("zone 1-1 full after seven moments", _zone_known("1-1"), 7)
	_events.stage_entered.emit(2, false)
	_moment(0)
	_t.eq("a 1-2 moment unlocks a 1-2 note while 1-1 is full", [_zone_known("1-1"), _zone_known("1-2")], [7, 1])
	for m in range(1, 7):
		_moment(m)
	_t.eq("1-2 full", _zone_known("1-2"), 7)

	_fresh(DIR)
	_events.stage_entered.emit(2, false)
	for m in 7:
		_moment(m)
	_t.eq("1-2 full, 1-1 empty", [_zone_known("1-1"), _zone_known("1-2")], [0, 7])
	_moment(0)
	_t.eq("a moment in full 1-2 unlocks the earliest 1-1 note", [_zone_known("1-1"), _found[-1]], [1, _ids("field_note", "1-1")[0]])

	var reload = Codex.new()
	reload.setup(_events, null, FakeFlow.new(), DIR)
	_t.eq("known notes survive a reload", _ids("field_note").filter(func(id): return reload.known(id)), _ids("field_note").filter(func(id): return _codex.known(id)))
	_t.check("reload kept the exchange rows", reload.known(_ids("exchange", "1-2")[0]))
	reload.free()


func _check_hud() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = Intent.Scripted.new()
	await physics_frame
	var hud = game.hud
	_t.check("no pulse before a note", not hud.lore_pulse_visible())
	game.codex.lore_found.emit("lore.spillway.note.shift")
	_t.check("the pulse shows on lore_found", hud.lore_pulse_visible())
	hud._process(1.5)
	_t.check("the pulse holds at 1.5 s", hud.lore_pulse_visible())
	hud._process(1.6)
	_t.check("the pulse clears after 3 s of sim time", not hud.lore_pulse_visible())
	root.remove_child(game)
	game.free()
	await process_frame
