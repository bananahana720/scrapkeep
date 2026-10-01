extends SceneTree

const Game := preload("res://src/game.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")

# The dodge read (v3 W11), on real committed telegraphs in the real game, with a watch
# whose ball is a scripted point so each case is exact. near_miss fires when the ball
# was inside a threat while it warned and is outside when it lands, or leaves within the
# grace unhurt; never when the ball was hit, never when it was never inside, never for a
# threat withdrawn before it landed. The game's own watch is on the bus too, and juice
# answers the fact with the dodge tick.

var _game
var _watch
var _failures := 0
var _point := Vector3.ZERO
var _heard: Array = []
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _done:
		return false
	_done = true
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var watch_on_bus: bool = _game.combat.get("near_miss") != null
	_watch = NearMiss.new()
	_game.add_child(_watch)
	_watch.setup(_game.events, func() -> Vector3: return _point)
	_watch.set_physics_process(false)
	_game.events.near_miss.connect(func(kind: String, at: Vector3): _heard.append([kind, at]))
	var terrain = _game.ctx.spawner.ground
	var far: Vector3 = _game.player.ball_position() + Vector3(180.0, 0.0, 180.0)

	var exits := _ring(terrain, far)
	_at(exits, 0.0)
	_tick()
	_at(exits, 9.0)
	_tick()
	exits.set_progress(1.0)
	_tick()
	_check("exit before it lands", _watch.fired == 1 and _heard.size() == 1 and _heard[0][0] == "threat_instant",
		"inside while it warned, 9 m out when it landed: %d near_miss (%s)" % [_watch.fired, _heard])
	exits.queue_free()

	var hit := _ring(terrain, far + Vector3(30.0, 0.0, 0.0))
	_at(hit, 0.0)
	_tick()
	hit.set_progress(1.0)
	_tick()
	_game.events.player_hit.emit(10.0, "chaser")
	_tick()
	_at(hit, 9.0)
	_tick()
	_check("not when hit", _watch.fired == 1, "inside when it landed and hurt, then out: %d near_miss in total" % _watch.fired)
	hit.queue_free()

	var never := _ring(terrain, far + Vector3(60.0, 0.0, 0.0))
	_at(never, 9.0)
	_tick()
	never.set_progress(1.0)
	_tick()
	_check("never inside", _watch.fired == 1, "outside the whole warning: %d near_miss in total" % _watch.fired)
	never.queue_free()

	var grace := _ring(terrain, far + Vector3(90.0, 0.0, 0.0))
	_at(grace, 0.0)
	_tick()
	grace.set_progress(1.0)
	_tick()
	_at(grace, 9.0)
	_tick(0.1)
	_check("out within the grace", _watch.fired == 2, "inside when it landed, out 0.1 s later unhurt (grace %.2f s): %d near_miss in total" % [_watch.grace, _watch.fired])
	grace.queue_free()

	var late := _ring(terrain, far + Vector3(120.0, 0.0, 0.0))
	_at(late, 0.0)
	_tick()
	late.set_progress(1.0)
	_tick()
	_tick(_watch.grace + 0.1)
	_at(late, 9.0)
	_tick()
	_check("not after the grace", _watch.fired == 2, "out only after the grace ran out: %d near_miss in total" % _watch.fired)
	late.queue_free()

	var withdrawn := _ring(terrain, far + Vector3(150.0, 0.0, 0.0))
	_at(withdrawn, 0.0)
	_tick()
	_at(withdrawn, 9.0)
	_tick()
	withdrawn.free()
	_tick()
	_check("withdrawn threat", _watch.fired == 2, "a threat freed before it landed: %d near_miss in total" % _watch.fired)

	var juice = _game.presentation.juice
	juice.reset_stops()
	_game.events.near_miss.emit("threat_lane", _game.player.ball_position())
	var answered: bool = juice.hook_log.has(["hit_stop", "near_miss"]) and juice.hook_log.has(["punch_fov", "near_miss"])
	_check("juice answers", answered and watch_on_bus and _game.presentation.vfx.spawned.get("near_miss", 0) >= 2,
		"combat runs its own watch %s; a near_miss gets the dodge tick, the zoom-in and the chevron and ring (%d glyphs)" % [watch_on_bus, _game.presentation.vfx.spawned.get("near_miss", 0)])
	print("presentation_near_miss_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _ring(terrain, at: Vector3) -> Node3D:
	return Telegraph.ring(_game, terrain, Threat.Type.INSTANT, at, 3.0)


func _at(ring: Node3D, out: float) -> void:
	var spot: Vector3 = ring.center + Vector3(out, 0.0, 0.0)
	_point = Vector3(spot.x, Telegraph.ground_under(ring.terrain, spot) + 0.9, spot.z)


func _tick(seconds := 1.0 / 60.0) -> void:
	_watch.step(seconds)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
