extends SceneTree

const Game := preload("res://src/game.gd")
const Bolts := preload("res://src/combat/bolts.gd")

# perf-lab H2: combat, the winch drone, the swarm follower and the director share one
# valid-checked enemy list per physics tick instead of scanning the "enemy" group at
# every call. Four things must hold:
#   1. the list is built once per tick however often it is asked for;
#   2. it still follows the group inside a tick (a spawn or a free changes the size);
#   3. a freed enemy never shows up in it, and a live game rebuilds it at most once a tick;
#   4. no fenced file scans the group again (the guard that fails if per-call scans return).

const FENCED := [
	"res://src/combat/combat.gd",
	"res://src/combat/bolts.gd",
	"res://src/combat/near_miss.gd",
	"res://src/combat/swarm_remnant.gd",
	"res://src/combat/winch_drone.gd",
	"res://src/world/world.gd",
]
const LIVE_TICKS := 90

# A stand-in enemy: only what the shared list touches.
class Stub extends Node3D:
	func is_dead() -> bool:
		return false

var _failures := 0
var _game
var _phase := "unit"
var _unit_tick := 0
var _base_builds := 0
var _live_ticks := 0
var _live_builds_start := 0
var _live_leaks := 0
var _live_max_size := 0
var _stubs: Array = []


func _initialize() -> void:
	_source_guard()


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _source_guard() -> void:
	for path in FENCED:
		var text := FileAccess.get_file_as_string(path)
		var scans := text.count("get_nodes_in_group(\"enemy\")")
		# bolts.gd holds the one scan that builds the list.
		var allowed := 1 if path.ends_with("bolts.gd") else 0
		_report("scan_" + path.get_file(), scans == allowed,
			"%d direct enemy-group scan(s) in %s (allowed %d)" % [scans, path.get_file(), allowed])


func _physics_process(_delta: float) -> bool:
	if _phase == "unit":
		return _unit_step()
	return _live_step()


func _unit_step() -> bool:
	if _unit_tick == 0:
		for i in 3:
			var stub := Stub.new()
			stub.add_to_group("enemy")
			root.add_child(stub)
			_stubs.append(stub)
		_base_builds = Bolts.snapshot_builds
		for i in 25:
			Bolts.enemy_snapshot(self)
		_report("once_per_tick", Bolts.snapshot_builds - _base_builds == 1,
			"25 asks in one tick built the list %d time(s)" % (Bolts.snapshot_builds - _base_builds))
		var extra := Stub.new()
		extra.add_to_group("enemy")
		root.add_child(extra)
		_stubs.append(extra)
		_report("spawn_mid_tick", Bolts.enemy_snapshot(self).size() == 4 and extra in Bolts.enemy_snapshot(self),
			"an enemy spawned mid-tick is in the list (%d entries)" % Bolts.enemy_snapshot(self).size())
		extra.free()
		_stubs.erase(extra)
		var listed: Array = Bolts.enemy_snapshot(self)
		var clean := listed.size() == 3
		for enemy in listed:
			clean = clean and is_instance_valid(enemy)
		_report("free_mid_tick", clean, "a freed enemy is out of the list at once (%d entries)" % listed.size())
		_base_builds = Bolts.snapshot_builds
	elif _unit_tick == 1:
		Bolts.enemy_snapshot(self)
		_report("rebuilt_next_tick", Bolts.snapshot_builds - _base_builds == 1,
			"the first ask of the next tick rebuilt the list (%d build)" % (Bolts.snapshot_builds - _base_builds))
		for stub in _stubs:
			stub.free()
		_stubs.clear()
		_report("emptied", Bolts.enemy_snapshot(self).is_empty(), "with no enemies the list is empty")
		_phase = "live"
		_game = Game.new()
		_game.test_mode = true
		root.add_child(_game)
	_unit_tick += 1
	return false


func _live_step() -> bool:
	if _game.flow == null:
		return false
	if _live_ticks == 0:
		_game.flow.press_start()
		_game.flow.choose_class(1)
		var ctx = _game.ctx
		var at: Vector3 = ctx.terrain.spawn_point(1)
		var heading: Vector3 = ctx.terrain.entry_heading(1)
		_game.player.reset_to(at)
		_game.player.body().global_position = at
		for i in 4:
			var spot: Vector3 = at + heading * (14.0 + 3.0 * i)
			ctx.spawner.spawn_enemy("chaser", ctx.terrain.drop_point(spot.x, spot.z, 1.6))
		_live_builds_start = Bolts.snapshot_builds
	_live_ticks += 1
	var listed: Array = Bolts.enemy_snapshot(self)
	_live_max_size = maxi(_live_max_size, listed.size())
	for enemy in listed:
		if not is_instance_valid(enemy):
			_live_leaks += 1
	if _live_ticks < LIVE_TICKS:
		return false
	var builds := Bolts.snapshot_builds - _live_builds_start
	_report("live_enemies", _live_max_size >= 4, "the live game listed up to %d enemies" % _live_max_size)
	_report("live_no_leak", _live_leaks == 0, "%d invalid entries seen across %d ticks" % [_live_leaks, _live_ticks])
	_report("live_once_per_tick", builds >= 1 and builds <= _live_ticks + 4,
		"%d builds across %d ticks (combat, world and enemies all share it)" % [builds, _live_ticks])
	var ok := _failures == 0
	print("combat_enemy_snapshot_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
