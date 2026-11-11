extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunLog := preload("res://src/core/run_log.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")

# What the sitting leaves in the run log (LEGIBILITY): on a live slice game a posture
# Warden is staggered twice by real rams, loses one chunk to a real harpoon smash, a real
# reinforcement spawn arrives as a pack and a held synergy fires on a real ram. The line
# the run leaves carries the table and the stage row's posture, packs and causes, with the
# numbers the bus itself announced. A local fixture carries the default table id and a
# posture block on its Warden's row. Contacts are real physics from placed starts;
# every wait is counted in physics frames.

const OUT := 58.0
const NEAR := 5.0
const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const SYNERGY := "wrecking_ball"

# F6 2026-10-04: the default-table fixture now fights on posture, so its row carries a posture block.
class PlatingGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _smashed := 0
var _staggers_seen := 0
var _packs_seen: Array = []
var _fired := 0


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


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING:
		force += 0.05
	return force


# One ram whose punch sits under the glance line, so the rule counts a glance: a light
# ball (the heft override), then the usual one back.
func _glance() -> void:
	_combat.heft_override = 0.05
	var punch: float = _combat.punch_of("ram", 1.0)
	_combat.strike(_warden, "ram", 1.0)
	await physics_frame
	_combat.heft_override = 1.0
	_report("the glancing ram is under the line", punch <= PLATING * BossPosture.MULT_MIN, "punch %.2f of %.1f" % [punch, PLATING])


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


func _start(table: String) -> bool:
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
	_game.events.posture_changed.connect(_on_posture)
	_game.events.pack_arrived.connect(func(faction: String, _at: Vector3, kinds: Array): _packs_seen.append({"faction": faction, "kinds": kinds.duplicate()}))
	_game.events.cause_fired.connect(func(id: String, _t: Node3D, _at: Vector3): _fired += 1 if id == SYNERGY else 0)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		_report("%s Warden" % table, false, "no Warden on the %s table" % table)
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden:
			enemy.queue_free()
	return true


func _hold_synergy() -> void:
	var call := Synergies.callout(SYNERGY)
	_game.run.parts.clear()
	_game.run.parts.append(call["a"])
	_game.run.parts.append(call["b"])
	_game.ctx.get_meta("build").recompute()


var _was_staggered := false


func _on_posture(_enemy: Node3D, _posture: float, staggered: bool) -> void:
	if staggered and not _was_staggered:
		_staggers_seen += 1
	_was_staggered = staggered


func _last_line() -> Dictionary:
	var path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	if lines.is_empty():
		return {}
	return JSON.parse_string(lines[lines.size() - 1])


func _run() -> void:
	if not await _start("slice"):
		quit(1)
		return
	_combat.spawn_enemy("mag_trapper", _ground(30.0))
	await _frames(6)
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)
	_hold_synergy()
	_combat.spawn_enemy("chaser", _warden.global_position + Vector3(0.0, 0.0, 3.0))
	await _frames(2)
	await _glance()
	await _fill()
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	_player.reset_to(_ground(OUT))
	await _seconds(0.3)
	await _fill()
	await _frames(2)
	var left: int = _warden.chunks_left()
	await _smash(_top())
	await _frames(2)
	var lost: int = left - _warden.chunks_left()
	# The wrecking ball's own strikes sit under the glance line of a plating of 110 as well, so the
	# Warden counts more than the one glancing ram; the record must carry the Warden's own count.
	var glanced: int = _warden.glances()
	_game.flow.new_run()
	var line := _last_line()
	var row: Dictionary = {}
	for one in line.get("stages", []):
		row = one
		break
	var posture: Dictionary = row.get("posture", {})
	_report("the record names the table", line.get("table") == "slice", "table %s" % line.get("table"))
	_report("two staggers", _staggers_seen == 2 and posture.get("staggers") == 2, "bus %d, record %s" % [_staggers_seen, posture.get("staggers")])
	_report("one chunk lost", lost == 1 and posture.get("chunks_lost") == 1, "Warden lost %d, record %s" % [lost, posture.get("chunks_lost")])
	_report("the glances are recorded", glanced >= 1 and posture.get("glances") == glanced, "record %s, Warden counted %d" % [posture.get("glances"), glanced])
	_report("fight ticks", int(posture.get("fight_ticks", 0)) > 0, "posture %s" % [posture])
	_report("a first try is attempt 1", row.get("attempts") == 1, "attempts %s" % [row.get("attempts")])
	_report("the pack is in the row", not _packs_seen.is_empty() and row.get("packs") == _packs_seen, "bus %s, record %s" % [_packs_seen, row.get("packs")])
	_report("the synergy count matches the bus", _fired > 0 and int(row.get("causes", {}).get(SYNERGY, 0)) == _fired, "bus %d, record %s" % [_fired, row.get("causes")])
	await _retry_row()
	_game.free()
	await _default_table()
	print("run_log_sitting_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# A row describes its last attempt: a retry clears the packs and causes with the posture
# block and counts the attempt, and what fires in the boss arena is not the stage's.
func _retry_row() -> void:
	var events = _game.events
	events.pack_arrived.emit("fleet", Vector3.ZERO, [])
	events.cause_fired.emit("old_cause", null, Vector3.ZERO)
	_game.flow.retry_stage()
	await _frames(2)
	events.pack_arrived.emit("raid", Vector3.ZERO, [])
	events.cause_fired.emit("new_cause", null, Vector3.ZERO)
	events.stage_content_cleared.emit("arena")
	events.pack_arrived.emit("arena_pack", Vector3.ZERO, [])
	events.cause_fired.emit("arena_cause", null, Vector3.ZERO)
	_game.flow.new_run()
	var line := _last_line()
	var row: Dictionary = {}
	for one in line.get("stages", []):
		row = one
		break
	_report("a retry clears the old packs and causes", row.get("packs") == [{"faction": "raid", "kinds": []}] and row.get("causes", {}).size() == 1 and int(row.get("causes", {}).get("new_cause", 0)) == 1,
		"packs %s, causes %s" % [row.get("packs"), row.get("causes")])
	_report("a retry is attempt 2", row.get("attempts") == 2, "attempts %s" % [row.get("attempts")])
	_report("arena packs and causes stay out of the stage row", not JSON.stringify(row.get("packs", [])).contains("arena_pack") and not row.get("causes", {}).has("arena_cause"),
		"packs %s, causes %s" % [row.get("packs"), row.get("causes")])


func _default_table() -> void:
	_game = PlatingGame.new()
	_game.test_mode = true
	root.add_child(_game)
	if not await _start("default"):
		_failures += 1
		return
	for i in 4:
		await _ram()
	_game.flow.new_run()
	var line := _last_line()
	var row: Dictionary = {}
	for one in line.get("stages", []):
		row = one
		break
	_report("the default table is named", line.get("table") == "default", "table %s" % line.get("table"))
	_report("a default-table Warden's row carries its posture", _warden.fight() == "posture" and row.has("posture") and row.has("packs") and row.has("causes"),
		"fight %s, row keys %s" % [_warden.fight(), row.keys()])
	_game.free()
