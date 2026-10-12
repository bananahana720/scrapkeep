extends SceneTree

const Bay := preload("res://src/world/bay.gd")
const World := preload("res://src/world/world.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

class GateFlow extends RefCounted:
	func in_stage() -> bool:
		return true

	func state_name() -> String:
		return "gates"

class FlatTerrain extends RefCounted:
	var active_map: RefCounted

	func map() -> RefCounted:
		return active_map

	func height(_x: float, _z: float) -> float:
		return 0.0

var _failures := 0
var _world
var _terrain := FlatTerrain.new()
var _scene: Node3D
var _space_root: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] -> %s" % [label, "PASS" if ok else "FAIL"])


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	# The real reward callback, with flat ground and no obstacle query, isolates map bounds.
	_space_root = Node3D.new()
	_world = World.new()
	_world.ctx = {"flow": GateFlow.new(), "root": _space_root}
	_world.terrain = _terrain
	_world.bay = Bay.new()
	_scene.add_child(_world.bay)
	_world.bay.setup(26.0, 14.0)
	_check("legacy point at 184 m passes", Bay._on_map(Vector3(184.0, 0.0, 0.0)))
	_check("legacy point at 186 m fails", not Bay._on_map(Vector3(186.0, 0.0, 0.0)))
	_check("legacy boundary stays strict", not Bay._on_map(Vector3(0.0, 0.0, -185.0)))
	for id in Terrain.MAPS:
		_terrain.active_map = Terrain.map_named(id, 1)
		_check("%s keeps the legacy dock limit" % id, not _dock(Vector3(300.0, 0.0, 0.0)))
	var park := ParkMap.new()
	_check("real park fixture loads", park.ok)
	_terrain.active_map = park
	_check("park dock at x 300 m passes through reward callback", _dock(Vector3(300.0, 0.0, 0.0)))
	var rect: Rect2 = park.play_rect
	for x in [rect.position.x + Bay.DECK_V + 1.0, rect.end.x - Bay.DECK_V - 1.0]:
		_check("park deck fits inside x edge %s" % x, _dock(Vector3(x, 0.0, 0.0)))
	for x in [rect.position.x + Bay.DECK_V - 1.0, rect.end.x - Bay.DECK_V + 1.0, rect.end.x - Bay.DECK_V]:
		_check("park deck crossing or touching x edge %s fails" % x, not _dock(Vector3(x, 0.0, 0.0)))
	for z in [rect.position.y + Bay.DECK_V + 1.0, rect.end.y - Bay.DECK_V - 1.0]:
		_check("park deck fits inside z edge %s" % z, _dock(Vector3(0.0, 0.0, z), Vector3.RIGHT))
	for z in [rect.position.y + Bay.DECK_V - 1.0, rect.end.y - Bay.DECK_V + 1.0]:
		_check("park deck crossing z edge %s fails" % z, not _dock(Vector3(0.0, 0.0, z), Vector3.RIGHT))
	var failed_park := ParkMap.new("user://bay_map_limit_missing.json")
	_check("failed park load retains inherited rectangle", not failed_park.ok and failed_park.play_rect == Rect2(-150.0, -150.0, 300.0, 300.0))
	_check_fallback("failed park load", failed_park)
	var undeclared_park := ParkMap.new()
	undeclared_park.park.erase("play_rect")
	_check_fallback("park without declared play_rect", undeclared_park)
	for invalid_rect in [Rect2(), Rect2(-800.0, -800.0, 0.0, 1600.0), Rect2(-800.0, -800.0, 1600.0, 0.0), Rect2(-800.0, -800.0, -1.0, 1600.0)]:
		var empty_park := ParkMap.new()
		empty_park.play_rect = invalid_rect
		_check_fallback("empty or nonpositive rectangle %s" % invalid_rect, empty_park)
	for invalid_rect in [Rect2(-INF, -800.0, INF, 1600.0), Rect2(-800.0, -800.0, INF, 1600.0), Rect2(-800.0, NAN, 1600.0, 1600.0), Rect2(-800.0, -800.0, 1600.0, NAN)]:
		var nonfinite_park := ParkMap.new()
		nonfinite_park.play_rect = invalid_rect
		_check_fallback("non-finite rectangle %s" % invalid_rect, nonfinite_park)
	_terrain.active_map = Terrain.map_named("spillway", 1)
	_check("returning to legacy resets the limit", not _dock(Vector3(300.0, 0.0, 0.0)))
	_world.bay.undock()
	_check("caller with no map keeps legacy fallback", not _world.bay.dock(
		[{"at": Vector3(300.0, 0.0, 0.0), "facing": Vector3.FORWARD}], Callable(_terrain, "height"), null))
	_space_root.free()
	_world.free()
	_scene.free()
	print("bay_map_limit_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _dock(at: Vector3, facing := Vector3.FORWARD) -> bool:
	_world.bay.undock()
	_world._on_reward_offered([{"at": at, "facing": facing}])
	return _world.bay.docked


func _check_fallback(label: String, park: RefCounted) -> void:
	for axis in [Vector3.RIGHT, Vector3.BACK]:
		for sign_value in [-1.0, 1.0]:
			_check("%s: 184 m passes on %s" % [label, axis * sign_value], Bay._on_map(axis * sign_value * 184.0, park))
			_check("%s: 185 m stays strict on %s" % [label, axis * sign_value], not Bay._on_map(axis * sign_value * 185.0, park))
			_check("%s: 186 m fails on %s" % [label, axis * sign_value], not Bay._on_map(axis * sign_value * 186.0, park))
	_terrain.active_map = park
	_check("%s: fallback dock at x 160 m passes through reward callback" % label, _dock(Vector3(160.0, 0.0, 0.0)))
