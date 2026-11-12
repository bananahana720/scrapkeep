extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const TerrainEvent := preload("res://src/world/terrain_event.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

# The terrain-changing events (DESIGN-V2 section 9): each is announced before anything
# changes, its telegraph runs the full lead, a ball inside the new geometry's footprint
# holds the change until it leaves, and the change lands as one swap of a pre-built
# collider on the same tick the event starts. Riding the new feature pays a milestone.
#
# Part one holds the pure model to its schedule. Part two runs both events on the real
# gorge: the cave-in held over a ball in the tunnel, the impact landing on open ground,
# then a ride round the crater wall, with the physics world probed where the collider
# should now stand.
#
# Evidence limit: calm and headless; the stinger's beat and the telegraph's look are
# presentation's and Andrew's to judge.

const SWAP_BUDGET_USEC := 2000
const SIM_SCALE := 2.0

# 2026-10-04: the authored gorge route remains on a test double after the alpha repoint.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _phase := "boot"
var _ticks := 0
var _clock := 0.0
var _log: Array = []
var _cave
var _impact
var _held_at := -1.0
var _parked_while_held := true
var _sim := 0.0
var _started_tick := {}
var _announced_tick := {}


func _initialize() -> void:
	_check_model()
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_model() -> void:
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var site := {"lead": 3.0, "footprint": [{"centre": Vector2.ZERO, "radius": 5.0}],
		"ride": {"centre": Vector2.ZERO, "radius": 10.0, "inner": 3.0}}
	var ev := TerrainEvent.new("impact", site, 2.0, 14.0, flat)
	var step := 1.0 / 90.0
	var inside := Vector3(0.0, 1.0, 1.0)
	var t := 0.0
	var order := []
	var swap_t := -1.0
	var announce_t := -1.0
	while t < 12.0:
		t += step
		var ball := inside if t < 8.0 else Vector3(30.0, 1.0, 0.0)
		for f in ev.advance(step, ball, Vector3.ZERO):
			order.append(f["kind"])
			if f["kind"] == "announced":
				announce_t = t
			if f["kind"] == "terrain_swap":
				swap_t = t
	_report("model announces first", order.find("announced") == 0 and order.find("announced") < order.find("terrain_swap"),
		"fact order %s" % [order])
	_report("model holds a covered ball", absf(announce_t - 2.0) < 0.02 and swap_t >= 8.0 and swap_t < 8.03 and ev.held > 2.9,
		"announced at %.2f s with a 3 s lead; ball inside until 8 s; held %.2f s; swapped at %.2f s" % [announce_t, ev.held, swap_t])
	var clear := TerrainEvent.new("cave_in", site, 1.0, 14.0, flat)
	var clear_swap := -1.0
	var started_same_tick := false
	t = 0.0
	while t < 6.0:
		t += step
		var facts: Array = clear.advance(step, Vector3(40.0, 1.0, 0.0), Vector3.ZERO)
		var kinds := facts.map(func(f): return f["kind"])
		if kinds.has("terrain_swap"):
			clear_swap = t
			started_same_tick = kinds.has("started")
	_report("model swaps on the lead", clear_swap >= 4.0 - 0.001 and clear_swap <= 4.0 + 3.0 / 90.0 and started_same_tick,
		"a clear ball: announced at 1 s, swapped at %.3f s, never before the 3 s lead and within 3 ticks of it; started on the swap tick %s"
			% [clear_swap, started_same_tick])
	var won := []
	for k in 90:
		for f in ev.advance(step, Vector3(8.0, 2.4, 0.0), Vector3(0.0, 0.0, 14.0)):
			if f["kind"] == "milestone" or f["kind"] == "ended":
				won.append([f["kind"], f.get("outcome", "")])
	_report("model pays the ride", won.size() == 2 and won[0][0] == "milestone" and won[1][1] == "won",
		"riding the rim 1.4 m above the floor at cruise: %s" % [won])


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	_sim += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			var bus = _game.events
			bus.event_announced.connect(func(id: String, s: float, _at: Vector3): _log.append(["announced", id, _sim, s]); _announced_tick[id] = _sim)
			bus.event_started.connect(func(id: String): _log.append(["started", id, _sim]); _started_tick[id] = _sim)
			bus.milestone_won.connect(func(id: String): _log.append(["milestone", id, _sim]))
			bus.world_fact.connect(func(kind: String, _at: Vector3): _log.append(["fact", kind, _sim]))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "enter"
		"enter":
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_phase = "arm"
		"arm":
			var events = _game.world.events
			_cave = events.terrain_event("cave_in")
			_impact = events.terrain_event("impact")
			_cave.timer = 0.5
			_impact.timer = 1000.0
			_put(_mid("w1"), Vector3.ZERO)
			_game.player.set_frozen(true)
			Engine.time_scale = SIM_SCALE
			_phase = "cave"
			_clock = 0.0
		"cave":
			_clock += delta
			var m = _game.ctx.terrain.map()
			var seal: Node3D = m.swaps["cave_in"]["after"][0]
			var home: Vector3 = seal.get_meta("home")
			if _cave.phase == TerrainEvent.HOLDING:
				if _held_at < 0.0:
					_held_at = _clock
				if seal.position.distance_to(home) < 1.0:
					_parked_while_held = false
				if _clock - _held_at > 1.5 and _game.player.frozen():
					_game.player.set_frozen(false)
					_put(Vector2(-4.0, -20.0), Vector3(0.0, 0.0, 6.0))
			if _cave.changed():
				_check_cave(seal, home)
				_impact.timer = 0.3
				_put(Vector2(0.0, -40.0), Vector3.ZERO)
				_phase = "impact"
				_clock = 0.0
			elif _clock > 20.0:
				_report("cave-in swapped", false, "phase %s after %.1f s" % [_cave.phase_name(), _clock])
				return _finish()
		"impact":
			_clock += delta
			if _impact.changed():
				_check_impact()
				_ride_crater(true)
				_phase = "ride"
				_clock = 0.0
			elif _clock > 20.0:
				_report("impact swapped", false, "phase %s after %.1f s" % [_impact.phase_name(), _clock])
				return _finish()
		"ride":
			_clock += delta
			_ride_crater(false)
			var paid := _log.any(func(e): return e[0] == "milestone" and e[1] == "impact")
			if paid or _clock > 4.0:
				var r := Vector2(_game.player.ball_position().x, _game.player.ball_position().z).distance_to(Gorge.IMPACT)
				_report("riding the crater pays", paid,
					"rolling round the new bowl's wall (%.1f m from its centre) at %.1f m/s: milestone_won(impact) %s after %.2f s"
						% [r, _game.player.planar_velocity().length(), paid, _clock])
				return _finish()
	return false


func _mid(id: String) -> Vector2:
	var ends: Array = Gorge.TUNNELS[id]
	return (ends[0] as Vector2).lerp(ends[1], 0.45)


func _put(xz: Vector2, velocity: Vector3) -> void:
	var at: Vector3 = _game.ctx.terrain.drop_point(xz.x, xz.y, 1.2)
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at


func _probe(xz: Vector2) -> float:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x, 200.0, xz.y), Vector3(xz.x, -100.0, xz.y), 1))
	return hit["position"].y if not hit.is_empty() else -INF


func _check_cave(seal: Node3D, home: Vector3) -> void:
	var m = _game.ctx.terrain.map()
	var plug: Node3D = m.swaps["cave_in"]["before"][0]
	var ann: float = _announced_tick.get("cave_in", -1.0)
	var st: float = _started_tick.get("cave_in", -1.0)
	_report("cave-in announced before it changed", ann > 0.0 and st > ann and st - ann >= 3.0 - 0.02,
		"event_announced at %.2f s, event_started at %.2f s: %.2f s apart, lead 3 s, held while the ball sat inside" % [ann, st, st - ann])
	_report("cave-in held over the ball", _held_at >= 0.0 and _parked_while_held and _cave.held >= 1.4,
		"the ball sat in the tunnel under the rubble's footprint; the change held %.2f s with the seal still parked (%s)"
			% [_cave.held, _parked_while_held])
	var swap: Dictionary = _game.world.swap_log[0] if not _game.world.swap_log.is_empty() else {}
	# 1.5 m off the mound's axis: its polar mesh leaves a 0.4 m eye at the centre (too
	# small for the ball), which a ray would slip through.
	var centre := _mid("w1") + Vector2(1.5, 0.0)
	var ground: float = _game.ctx.terrain.height(centre.x, centre.y)
	var hit := _probe(centre)
	_report("cave-in swapped a finished collider", seal.position.distance_to(home) < 0.01 and plug.position.y < -300.0
		and int(swap.get("usec", 999999)) < SWAP_BUDGET_USEC and absf(hit - ground) < 0.6,
		"seal at home, plug parked %.0f m down; swap took %d us (budget %d; a stage trimesh re-add is about 34 ms); ray hits the rubble at %.2f m, height() says %.2f m"
			% [-plug.position.y, int(swap.get("usec", -1)), SWAP_BUDGET_USEC, hit, ground])
	var opened := _mid("w2")
	_report("cave-in opened the other tunnel", _game.ctx.terrain.height(opened.x, opened.y) < ground - 4.0,
		"the w2 tunnel floor is back at %.1f m; the sealed w1 now stands %.1f m" % [_game.ctx.terrain.height(opened.x, opened.y), ground])


func _check_impact() -> void:
	var ann: float = _announced_tick.get("impact", -1.0)
	var st: float = _started_tick.get("impact", -1.0)
	var r := 10.0
	var at := Gorge.IMPACT + Vector2(r, 0.0)
	var want: float = _game.ctx.terrain.height(at.x, at.y)
	var hit := _probe(at)
	var swap: Dictionary = _game.world.swap_log[-1]
	_report("impact announced, then landed on the lead", ann > 0.0 and absf(st - ann - 4.0) < 0.05,
		"announced at %.2f s, landed at %.2f s with the ball clear: %.3f s, lead 4 s" % [ann, st, st - ann])
	_report("impact left a rideable bowl", absf(hit - want) < 0.6 and want - _game.ctx.terrain.height(Gorge.IMPACT.x, Gorge.IMPACT.y) > 1.5
		and int(swap["usec"]) < SWAP_BUDGET_USEC,
		"10 m from the centre the collider stands at %.2f m and height() at %.2f m, above the floor at %.2f m; swap %d us"
			% [hit, want, _game.ctx.terrain.height(Gorge.IMPACT.x, Gorge.IMPACT.y), int(swap["usec"])])


# Holds a tangential line round the crater wall, as a player carving the bowl would.
func _ride_crater(place: bool) -> void:
	var r := 11.0
	var ball: Vector3 = _game.player.ball_position()
	var rel := Vector2(ball.x, ball.z) - Gorge.IMPACT
	if place:
		var at := Gorge.IMPACT + Vector2(r, 0.0)
		_put(at, Vector3(0.0, 0.0, 16.0))
		return
	var tangent := Vector2(-rel.y, rel.x).normalized()
	var want := Vector3(tangent.x, 0.0, tangent.y) * 16.0
	var v: Vector3 = _game.player.state.velocity
	_game.player.set_velocity_now(Vector3(want.x, v.y, want.z))


func _finish() -> bool:
	Engine.time_scale = 1.0
	print("stage_terrain_events_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
