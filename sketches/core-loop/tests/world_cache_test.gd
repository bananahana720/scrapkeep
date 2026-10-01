extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")

# The cracked wall behind stage 1's vault plinth and the cache in its pocket
# (LOOP-REDESIGN section 9), in the running game as Kest in calm. Rolled into at
# 10 m/s the wall holds; at 24 m/s it crumbles the tick before contact and the ball keeps
# its speed. While sealed its gauge reads the approach speed and E cannot reach the
# chest. Inside, E opens the chest, three parts rise, and rolling onto one takes it as a
# cache part.

const KEST := 2
const SLOW := 10.0
const FAST := 24.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _cache
var _crumbled: Array = []
var _gained: Array = []
var _gauge_seen := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _steps.is_empty():
		_begin()
		return false
	if _index >= _steps.size():
		print("world_cache_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	if _cache != null and _cache.state == CrackedCache.SEALED:
		_gauge_seen = maxf(_gauge_seen, _cache.gauge())
	var step: Array = _steps[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		(step[0] as Callable).call()
		return false
	_ticks += 1
	if _ticks < int(step[1]):
		return false
	(step[2] as Callable).call()
	_index += 1
	_entered = false
	return false


func _begin() -> void:
	_game.player.source = _source
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(KEST)
	_game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "wall_crumbled":
			_crumbled.append(_game.player.planar_velocity().length()))
	_game.events.part_gained.connect(func(part: String, source: String): _gained.append([part, source]))
	_steps = [
		[_noop, 30, _find_cache],
		[_run_at_wall.bind(SLOW), 90, _check_holds],
		[_press_at_wall, 4, _check_sealed_press],
		[_run_at_wall.bind(FAST), 60, _check_breaks],
		[_inside_pocket, 6, _press_e],
		[_noop, 4, _check_open],
		[_onto_pedestal, 4, _check_taken],
	]


func _noop() -> void:
	pass


func _find_cache() -> void:
	for device in _game.world.interact.devices:
		if device is CrackedCache:
			_cache = device
	_report("cache placed", _cache != null, "stage 1 carries a cracked cache: %s" % (_cache.id if _cache != null else "none"))


func _local_ground(local: Vector3) -> Vector3:
	var at: Vector3 = _cache.to_global(local)
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.05)


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at
	_source.hold = {}
	_source.press = {}


# Five metres out from the wall's face, rolling straight at it.
func _run_at_wall(speed: float) -> void:
	_gauge_seen = 0.0
	var into: Vector3 = -_cache.global_basis.z
	_place(_local_ground(Vector3(0.0, 0.0, CrackedCache.HALF_D + 6.0)), into * speed)
	_game.camera.snap(into)


func _check_holds() -> void:
	var local: Vector3 = _cache.to_local(_game.player.ball_position())
	_report("a slow ball meets a wall", not _cache.broken() and _crumbled.is_empty() and local.z > CrackedCache.HALF_D,
		"rolled at the wall at %.0f m/s: broken %s, ball still outside it (%.1f m from the pocket's middle), gauge peaked %.2f"
			% [SLOW, _cache.broken(), local.z, _gauge_seen])


func _press_at_wall() -> void:
	_place(_local_ground(Vector3(0.0, 0.0, CrackedCache.HALF_D + 2.5)))
	_game.camera.snap(-_cache.global_basis.z)
	_source.press["mount_pressed"] = true


func _check_sealed_press() -> void:
	_report("sealed, E cannot reach it", _cache.state == CrackedCache.SEALED and _cache.prompt.keycap == "",
		"E at the sealed wall: state %d, keycap \"%s\"" % [_cache.state, _cache.prompt.keycap])


func _check_breaks() -> void:
	var at_break: float = _crumbled[0] if not _crumbled.is_empty() else 0.0
	_report("a fast ball breaks it", _cache.broken() and _crumbled.size() == 1 and at_break >= FAST * 0.9 and _gauge_seen >= 1.0,
		"rolled at the wall at %.0f m/s: crumbled %d time(s) with the ball at %.1f m/s, gauge reached %.2f"
			% [FAST, _crumbled.size(), at_break, _gauge_seen])


# Inside the pocket, five metres from the chest, facing it.
func _inside_pocket() -> void:
	_place(_local_ground(Vector3(0.0, 0.0, 1.2)))
	_game.camera.snap(-_cache.global_basis.z)


func _press_e() -> void:
	_source.press["mount_pressed"] = true


func _check_open() -> void:
	var shown := 0
	for p in _cache._pedestals:
		if p["node"].visible:
			shown += 1
	_report("E opens the chest", _cache.state == CrackedCache.PICKING and _cache.offers.size() == CrackedCache.PICKS and shown == CrackedCache.PICKS,
		"E inside the pocket: state %d, %d parts offered %s, %d pedestals up" % [_cache.state, _cache.offers.size(), _cache.offers, shown])


func _onto_pedestal() -> void:
	var p: Dictionary = _cache._pedestals[1]
	_place(_local_ground(p["at"]))


func _check_taken() -> void:
	var want: String = _cache.offers[1] if _cache.offers.size() > 1 else ""
	_report("roll onto one to take it", _gained == [[want, "cache"]] and _cache.state == CrackedCache.TAKEN and _cache.spent,
		"rolled onto the middle pedestal: gained %s, state %d, spent %s" % [_gained, _cache.state, _cache.spent])
