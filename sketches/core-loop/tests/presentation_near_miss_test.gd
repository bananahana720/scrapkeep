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
# answers the fact with the dodge tick. Before the landing, standing_in() is the run of the
# furthest warning the ball stands in, and the HUD's danger mark (ui/danger_mark.gd) shows it
# over the ball.

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

	# BUGFIX-COMBAT-A F003 (2026-10-09): a WAVE hurts only on its running front, so its
	# watch reads the front: inside the ring ahead of the front is in, the front running
	# past the ball (or the wave spent) is the landing. 6 m ring, 6 m/s front, 1 s warn.
	var waved: int = _watch.fired
	var dodge := _wave(terrain, far + Vector3(0.0, 0.0, 30.0))
	_at(dodge, 3.0)
	_wave_run(dodge, 0.5)
	_at(dodge, 9.0)
	_wave_run(dodge, 2.0)
	_check("wave: out before the front", _watch.fired == waved + 1 and _heard.size() == waved + 1 and _heard[waved][0] == "threat_wave",
		"3 m in while it warned, 9 m out before the front reached 3 m: %d near_miss (%s)" % [_watch.fired - waved, _heard.slice(waved)])
	dodge.queue_free()

	waved = _watch.fired
	var hopped := _wave(terrain, far + Vector3(30.0, 0.0, 30.0))
	_at(hopped, 3.0)
	_wave_run(hopped, 1.2)
	_point.y += 6.0
	_wave_run(hopped, 0.7)
	_point.y -= 6.0
	_wave_run(hopped, 1.0)
	_check("wave: jumped over the front", _watch.fired == waved + 1,
		"3 m in, up 6 m while the front passed under: %d near_miss" % (_watch.fired - waved))
	hopped.queue_free()

	waved = _watch.fired
	var caught := _wave(terrain, far + Vector3(60.0, 0.0, 30.0))
	_at(caught, 3.0)
	_wave_run(caught, 1.5)
	_game.events.player_hit.emit(10.0, "lamp_swarm")
	_wave_run(caught, 1.5)
	_check("wave: not when the front hit", _watch.fired == waved,
		"3 m in, hit as the front crossed, front ran on: %d near_miss" % (_watch.fired - waved))
	caught.queue_free()

	waved = _watch.fired
	var outside := _wave(terrain, far + Vector3(90.0, 0.0, 30.0))
	_at(outside, 9.0)
	_wave_run(outside, 3.0)
	_check("wave: never inside", _watch.fired == waved, "9 m out the whole wave: %d near_miss" % (_watch.fired - waved))
	outside.queue_free()

	# Before the landing the same watch says how far the warning the ball stands in has run,
	# and the HUD's mark over the ball shows it.
	var stood := _ring(terrain, far + Vector3(0.0, 0.0, 60.0))
	_at(stood, 9.0)
	stood.set_progress(0.4)
	_tick()
	_check("standing in none", _watch.standing_in() < 0.0, "9 m out of a 3 m ring at 0.4: %.2f" % _watch.standing_in())
	_at(stood, 0.0)
	_tick()
	_check("standing in a warning", is_equal_approx(_watch.standing_in(), 0.4), "at its centre at 0.4: %.2f" % _watch.standing_in())
	var second := _ring(terrain, stood.center)
	second.set_progress(0.7)
	_tick()
	_check("the furthest along wins", is_equal_approx(_watch.standing_in(), 0.7), "a second ring at 0.7 over the first: %.2f" % _watch.standing_in())
	_point.y += 6.0
	_tick()
	_check("a jump over the band is out", _watch.standing_in() < 0.0, "6 m up: %.2f" % _watch.standing_in())
	_point.y -= 6.0
	stood.set_progress(1.0)
	second.set_progress(1.0)
	_tick()
	_check("a landed threat is no warning", _watch.standing_in() < 0.0, "both landed: %.2f" % _watch.standing_in())
	stood.queue_free()
	second.queue_free()
	var net := _ring(terrain, far + Vector3(60.0, 0.0, 60.0))
	net.air_only = true
	net.set_progress(0.5)
	_at(net, 0.0)
	_tick()
	_check("an air-only mark raises none", _watch.standing_in() < 0.0, "under a net that catches only a ball in the air: %.2f" % _watch.standing_in())
	net.queue_free()
	var wave_in := _wave(terrain, far + Vector3(30.0, 0.0, 60.0))
	_at(wave_in, 3.0)
	_wave_run(wave_in, 0.5)
	var arming: float = _watch.standing_in()
	_wave_run(wave_in, 0.75)
	var running: float = _watch.standing_in()
	_check("a wave counts its arming, then its front's run to the ball", arming > 0.0 and arming < 0.5 and running > 0.5 and running < 1.0,
		"3 m in a 6 m wave: %.2f while it armed, %.2f with the front half way to the ball" % [arming, running])
	wave_in.queue_free()

	var hud = _game.hud
	var ball: Vector3 = _game.player.ball_position()
	# The ball is still on its drop this frame, so the warning is hung in the air around it.
	var over := Telegraph.aerial_ring(_game, terrain, Threat.Type.INSTANT, ball - Vector3(0.0, 1.0, 0.0), 3.0, 3.0)
	over.set_progress(0.5)
	_game.combat.near_miss.step(1.0 / 60.0)
	hud._process(0.0)
	var cam: Camera3D = _game.camera.cam
	var ball_top: float = cam.unproject_position(_game.player.shown_position() + cam.global_basis.y).y
	var mark: Rect2 = hud.danger_mark.rect()
	_check("the HUD marks the ball inside a warning", hud.danger_mark.visible and is_equal_approx(hud.danger_mark.run, 0.5)
		and mark.end.y <= ball_top and not mark.intersects(hud.danger_mark.avoid),
		"in play %s, ball in the ring %s, visible %s, run %.2f, mark %s over the ball's top y %.0f, reticle box %s" % [_game.flow.in_play(), over.contains(ball), hud.danger_mark.visible, hud.danger_mark.run, mark, ball_top, hud.danger_mark.avoid])
	hud.part_name.show_part("rivet_plating")
	hud._process(0.0)
	_check("a part's name stands on the mark", hud.part_name.rect().size.x > 0.0 and hud.part_name.rect().end.y <= mark.position.y,
		"name %s, mark %s" % [hud.part_name.rect(), mark])
	over.free()
	_game.combat.near_miss.step(1.0 / 60.0)
	hud._process(0.0)
	_check("and takes it down when the warning is gone", not hud.danger_mark.visible and not hud.danger_mark.shown(),
		"visible %s, run %.2f" % [hud.danger_mark.visible, hud.danger_mark.run])

	var juice = _game.presentation.juice
	juice.hit_stops.reset()
	_game.events.near_miss.emit("threat_lane", _game.player.ball_position())
	# A dodge never freezes time (hit_stop_budget.gd STRIKE_STOP_FACTS; BIBLE: momentum is sacred): the near
	# miss asks for its stop, and the budget logs it at zero and sends nothing.
	var refused: bool = juice.hit_stops.entries.any(func(s: Array): return s[2] == "near_miss" and float(s[1]) == 0.0)
	var froze: bool = juice.hook_log.has(["hit_stop", "near_miss"])
	var answered: bool = refused and not froze and juice.hook_log.has(["punch_fov", "near_miss"])
	_check("juice answers", answered and watch_on_bus and _game.presentation.vfx.spawned.get("near_miss", 0) >= 2,
		"combat runs its own watch %s; a near_miss asks for no time freeze (refused %s, froze %s), gets the zoom-in and the chevron and ring (%d glyphs)" % [watch_on_bus, refused, froze, _game.presentation.vfx.spawned.get("near_miss", 0)])
	print("presentation_near_miss_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _ring(terrain, at: Vector3) -> Node3D:
	return Telegraph.ring(_game, terrain, Threat.Type.INSTANT, at, 3.0)


func _wave(terrain, at: Vector3) -> Node3D:
	return Telegraph.wave(_game, terrain, at, 6.0, 6.0, 1.0)


# The wave and the watch step together, 60 ticks a second.
func _wave_run(wave: Node3D, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		wave.step(1.0 / 60.0)
		_tick()


func _at(ring: Node3D, out: float) -> void:
	var spot: Vector3 = ring.center + Vector3(out, 0.0, 0.0)
	_point = Vector3(spot.x, Telegraph.ground_under(ring.terrain, spot) + 0.9, spot.z)


func _tick(seconds := 1.0 / 60.0) -> void:
	_watch.step(seconds)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
