extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventDirector := preload("res://src/world/event_director.gd")

# The event layer wired into the real game. Stage 1: the Scrap Stampede is armed and
# ignored, and the beacon, gate and launch still take the ball to stage 2. Stage 2:
# roll into the Surge Run ring and thread its gates at blazing speed; the bus carries
# the announcement, the start, the win and milestone_won, in that order, the win grants
# an event core, and the codex records Surge Slingshot. Stage 3: hold the relay with a
# combat module that has no miniboss; the world asks for one at a seeded spot near the
# relay, falls back to a chaser there, and nothing breaks.

const BEACON_SECONDS := 0.6
const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const GATE_TICKS := 4
const HOLD_TICKS := 10
const BLAZING_SPEED := 32.0
const TICK_LIMIT := 90 * 70


class FakeSpawner extends Node:
	var calls: Array = []

	func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
		calls.append([kind, at])
		return null

	func strike(_enemy: Node3D, _kind: String, _force: float) -> void:
		pass


# Preserve the legacy three-stage rule on a double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _world
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _started := false
var _done := false
var _phase := "boot"
var _wait := 0
var _bus: Array = []
var _cleared: Array[int] = []
var _launched := false
var _stampede_at_exit := -1
var _fake := FakeSpawner.new()


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if not _started:
		if _game.flow == null:
			return false
		_start()
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_report("timeout", false, "stalled in %s, phase %s" % [_game.flow.state_name(), _phase])
		return _finish()
	_step()
	return false


func _start() -> void:
	_started = true
	_world = _game.world
	var ev = _game.events
	ev.event_announced.connect(func(id: String, s: float, _at: Vector3): _bus.append(["announced", id, s]))
	ev.event_started.connect(func(id: String): _bus.append(["started", id]))
	ev.event_ended.connect(func(id: String, outcome: String): _bus.append(["ended", id, outcome]))
	ev.milestone_won.connect(func(id: String): _bus.append(["milestone", id]))
	ev.core_gained.connect(func(source: String, _at: Vector3, count: int): _bus.append(["core", source, count]))
	ev.synergy_discovered.connect(func(id: String, category: String, _first: bool): _bus.append(["codex", id, category]))
	ev.stage_cleared.connect(func(stage: int): _cleared.append(stage))
	ev.launched.connect(func(_v: Vector3): _launched = true)
	ev.reward_offered.connect(_on_offered)
	ev.reward_chosen.connect(_on_chosen)
	ev.stage_entered.connect(_on_stage_entered)
	_game.ctx.calm = true
	_game.flow.beacon_seconds_override = BEACON_SECONDS
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)


func _offer(id: String) -> Dictionary:
	return _world.events.offer(id)


func _put(at: Vector3) -> void:
	_game.player.reset_to(at)
	_game.player.body().global_position = at


func _step() -> void:
	match _phase:
		"arm_stampede":
			if _offer("scrap_stampede")["phase"] == EventDirector.ARMED:
				_put(_game.flow.beacon.global_position + Vector3.UP * 1.5)
				_phase = "to_gates"
		"arm_surge":
			var offer := _offer("surge_run")
			if offer["phase"] == EventDirector.ARMED:
				var ring: Vector2 = offer["model"].ring
				_put(_game.ctx.terrain.drop_point(ring.x, ring.y, 1.2))
				_phase = "surge"
				_wait = 0
		"surge":
			var offer := _offer("surge_run")
			_wait += 1
			if offer["phase"] == EventDirector.LIVE and _wait % GATE_TICKS == 0:
				var model = offer["model"]
				var n: int = mini(model.next_gate, model.gates.size() - 1)
				var g: Vector2 = model.gates[n]
				var t: Vector2 = model.route.tangent(model.gate_distances[n])
				var at: Vector3 = _game.ctx.terrain.drop_point(g.x, g.y, 1.2)
				_game.player.reset_to(at, Vector3(t.x, 0.0, t.y) * BLAZING_SPEED)
				_game.player.body().global_position = at
			elif offer["phase"] == EventDirector.DONE or offer["phase"] == EventDirector.COOLDOWN:
				_check_surge()
				_begin_relay()
		"arm_relay":
			var offer := _offer("hold_the_relay")
			if offer["phase"] == EventDirector.ARMED:
				_phase = "hold"
				_wait = 0
		"hold":
			_wait += 1
			if _wait % HOLD_TICKS == 1:
				var relay: Vector2 = _offer("hold_the_relay")["model"].relay
				_put(_game.ctx.terrain.drop_point(relay.x, relay.y, 1.2))
			if _fake.calls.any(func(c): return c[0] == "miniboss"):
				_wait = 0
				_phase = "after_miniboss"
		"after_miniboss":
			_wait += 1
			if _wait == 3:
				_check_miniboss()
				_finish()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_source.hold = {}
	if stage == 1:
		_offer("scrap_stampede")["timer"] = 0.0
		_phase = "arm_stampede"
	elif stage == 2 and _phase == "flight":
		_check_skip()
		_offer("surge_run")["timer"] = 0.0
		_phase = "arm_surge"


func _on_offered(offers: Array) -> void:
	if _phase != "to_gates":
		return
	var offer: Dictionary = offers[0]
	var facing: Vector3 = offer["facing"]
	var start: Vector3 = offer["at"] - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_phase = "approach"


func _on_chosen(_part: String) -> void:
	if _phase == "approach":
		_stampede_at_exit = _offer("scrap_stampede")["phase"]
		_phase = "flight"


func _check_skip() -> void:
	var started := _bus.filter(func(e): return e[0] == "started" and e[1] == "scrap_stampede")
	var announced := _bus.filter(func(e): return e[0] == "announced" and e[1] == "scrap_stampede")
	_report("skip keeps the exit", _cleared == [1] and _launched and started.is_empty() and not announced.is_empty()
			and _stampede_at_exit == EventDirector.ARMED,
		"stampede announced %d time(s), armed at the gate (%s), never started; stage 1 cleared %s and launched %s"
			% [announced.size(), EventDirector.PHASE_NAMES[maxi(_stampede_at_exit, 0)], _cleared, _launched])


func _check_surge() -> void:
	var order := []
	for e in _bus:
		if e[1] == "surge_run":
			order.append(e[0] if e[0] != "ended" else "ended " + e[2])
	var milestone := _bus.filter(func(e): return e[0] == "milestone" and e[1] == "surge_run")
	_report("surge run won live", order == ["announced", "started", "ended won", "milestone"] and not milestone.is_empty()
			and "surge_run" in _game.run.events_won,
		"surge_run on the bus: %s; run.events_won %s" % [" > ".join(order), _game.run.events_won])
	var cores := _bus.filter(func(e): return e[0] == "core" and e[1] == "event")
	_report("event core", cores.size() == 1 and _game.run.bonus_cores == 1,
		"the win granted %d event core(s); run.bonus_cores %d" % [cores.size(), _game.run.bonus_cores])
	var codex := _bus.filter(func(e): return e[0] == "codex")
	_report("world codex live", codex == [["codex", "surge_slingshot", "world"]] and "surge_slingshot" in _game.ctx.codex.discovered_this_run()
			and _game.ctx.codex.entries("world").size() >= 5,
		"synergy_discovered %s from the codex; %d world entries declared" % [codex, _game.ctx.codex.entries("world").size()])


func _begin_relay() -> void:
	_game.ctx.spawner = _fake
	_game.ctx.calm = false
	_game.run.set_max_hp(100000.0)
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 18.0), false)
	_offer("hold_the_relay")["timer"] = 0.0
	_phase = "arm_relay"


func _check_miniboss() -> void:
	var calls: Array = _fake.calls
	var idx := -1
	for i in calls.size():
		if calls[i][0] == "miniboss":
			idx = i
	var ok: bool = idx >= 0 and idx + 1 < calls.size() and calls[idx + 1][0] == "chaser" and calls[idx + 1][1] == calls[idx][1]
	var at: Vector3 = calls[idx][1] if idx >= 0 else Vector3.INF
	var relay: Vector2 = _offer("hold_the_relay")["model"].relay
	var d := Vector2(at.x, at.z).distance_to(relay)
	var ground: float = _game.ctx.terrain.height(at.x, at.z)
	var started := _bus.filter(func(e): return e[0] == "started" and e[1] == "hold_the_relay")
	_report("miniboss mid-hold", ok and not started.is_empty() and d >= 30.0 and d <= 48.0 and absf(at.y - ground - 2.4) < 0.01
			and at == _world.last_miniboss_at,
		"relay live %s; spawner asked for a miniboss at (%.0f, %.1f, %.0f), %.0f m from the relay, 2.4 m over the ground; with no miniboss kind it got a %s there"
			% [not started.is_empty(), at.x, at.y, at.z, d, calls[idx + 1][0] if ok else "nothing"])


func _finish() -> bool:
	_done = true
	print("world_flow_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.ctx.spawner = null
	_fake.free()
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
