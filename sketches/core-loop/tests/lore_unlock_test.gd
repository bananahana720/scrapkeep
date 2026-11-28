# 2026-10-12 FIXTURE-ADAPT: 50e4a6a added codex profile reads; the scene-free flow has no saved profile.
# 2026-10-12 R4: exercise status/open_entry through a non-null flow.ctx.profile, retaining null-profile lore cases.
extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Codex := preload("res://src/core/codex.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Parts := preload("res://src/build/parts.gd")
const Intent := preload("res://src/movement/intent.gd")

# Field notes unlock one per lore moment (the seven below), exchange rows on zone entry.
# A zone can hold more notes than one run's seven moments; later runs find the rest.
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

class FakeProfile:
	var can_save := false
	var seen: Array[String] = []
	var marked: Array[String] = []

	func is_seen(id: String) -> bool:
		return id in seen

	func mark_seen(id: String) -> bool:
		marked.append(id)
		seen.append(id)
		return true

	func save_if_allowed() -> bool:
		return true

var _t
var _events
var _codex
var _found: Array[String] = []


func _initialize() -> void:
	_t = T.new("lore_unlock_test")
	_check_codex()
	_check_profile()
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
	_codex.setup(_events, null, FakeFlow.new(), dir, func(id: String) -> bool: var d: Resource = Parts.def(id); return d != null and d.rarity == "relic")
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
		for m in _ids("field_note", ZONES[z]).size():
			_moment(m % 7)
	var notes := _ids("field_note")
	var exchanges := _ids("exchange")
	_t.check("at least seven field notes per zone", ZONES.all(func(zone): return _ids("field_note", zone).size() >= 7))
	_t.eq("all field notes known", notes.filter(func(id): return _codex.known(id)).size(), notes.size())
	_t.eq("all 18 exchange rows known", exchanges.filter(func(id): return _codex.known(id)).size(), 18)
	_t.eq("lore_found fired once per note, in row order", _found, notes)
	var before: Array = _codex.discovered().duplicate()
	_moment(0)
	_t.eq("a moment with nothing unknown changes nothing", _codex.discovered().size(), before.size())
	_t.eq("no intro row was touched", _ids("intro").filter(func(id): return _codex.known(id)).size(), 0)

	var first := _ids("field_note", "1-1").size()
	var second := _ids("field_note", "1-2").size()
	_fresh(DIR)
	_events.stage_entered.emit(1, false)
	for m in 7:
		_moment(m)
	_t.eq("seven moments find the first seven 1-1 notes", _found, _ids("field_note", "1-1").slice(0, 7))
	for m in range(7, first):
		_moment(m % 7)
	_t.eq("zone 1-1 full after one moment per note", _zone_known("1-1"), first)
	_events.stage_entered.emit(2, false)
	_moment(0)
	_t.eq("a 1-2 moment unlocks a 1-2 note while 1-1 is full", [_zone_known("1-1"), _zone_known("1-2")], [first, 1])
	for m in range(1, second):
		_moment(m % 7)
	_t.eq("1-2 full", _zone_known("1-2"), second)

	_fresh(DIR)
	_events.stage_entered.emit(2, false)
	for m in second:
		_moment(m % 7)
	_t.eq("1-2 full, 1-1 empty", [_zone_known("1-1"), _zone_known("1-2")], [0, second])
	_moment(0)
	_t.eq("a moment in full 1-2 unlocks the earliest 1-1 note", [_zone_known("1-1"), _found[-1]], [1, _ids("field_note", "1-1")[0]])

	var reload = Codex.new()
	reload.setup(_events, null, FakeFlow.new(), DIR)
	_t.eq("known notes survive a reload", _ids("field_note").filter(func(id): return reload.known(id)), _ids("field_note").filter(func(id): return _codex.known(id)))
	_t.check("reload kept the exchange rows", reload.known(_ids("exchange", "1-2")[0]))
	reload.free()


func _check_profile() -> void:
	_fresh(DIR.path_join("profile"))
	var profile := FakeProfile.new()
	_codex.flow.ctx.profile = profile
	var id := "fixture.lore.profile"
	_codex.declare({"id": id, "category": "world", "name": "Profile note"})
	_t.check("profile fixture entry discovered", _codex.mark_discovered(id))
	_t.eq("unread flow profile entry is new", _codex.status(id), "new")
	_t.check("open_entry consumes flow profile", _codex.open_entry(id))
	_t.eq("flow profile mark_seen receives the entry id", profile.marked, [id])
	_t.eq("read flow profile entry becomes available", _codex.status(id), "available")


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
	# The cold open has the floor first (the pill waits for a flourish's reading matter); this is about the pill.
	game.presentation.flourish.stop_all()
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
