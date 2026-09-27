extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# The full run through the real flow with the Warden gate on, on the world's three
# maps: each stage's Warden stands on its bowl's floor, in sight from the entry drop;
# rolling into the bowl spikes the director and threat_rose announces it; breaking the
# Warden unseals the beacon, a gate launches the ball, and the run ends on the summary.
# Uses the spine's spawner double, so it tests the world's side of the seam only, and
# the spine's boss double, whose defeat() ends the arena whether or not the real boss
# module is present.

const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const DROP := 14.0
const WARDEN_EYE := 3.0
const FLOOR_FLAT := 0.35
const TICK_LIMIT := 90 * 90
const RAM := 400.0

var _game
var _double
var _boss
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _started := false
var _done := false
var _phase := "boot"
var _wait := 0
var _entered: Array[int] = []
var _cleared: Array[int] = []
var _unsealed: Array[int] = []
var _rises: Array[int] = []
var _ended := false
var _pressure := 0
var _checked: Array[Dictionary] = []


func _initialize() -> void:
	_game = Game.new()
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
	_double = SpawnerDouble.new()
	_game.add_child(_double)
	_double.setup(_game.ctx)
	_game.ctx.spawner = _double
	_boss = BossDouble.new()
	_game.add_child(_boss)
	_boss.setup(_game.ctx)
	_game.ctx.calm = true
	_game.flow.force_warden = true
	var ev = _game.events
	ev.stage_entered.connect(_on_stage_entered)
	ev.stage_cleared.connect(func(stage: int): _cleared.append(stage))
	ev.beacon_unsealed.connect(func(stage: int): _unsealed.append(stage))
	ev.threat_rose.connect(func(tier: int): _rises.append(tier))
	ev.pressure_changed.connect(func(_p: float): _pressure += 1)
	ev.run_ended.connect(func(_won: bool): _ended = true)
	ev.reward_offered.connect(_on_offered)
	ev.launched.connect(func(_v: Vector3): _phase = "flight")
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)


func _put(at: Vector3) -> void:
	_game.player.reset_to(at)
	_game.player.body().global_position = at


func _step() -> void:
	var flow = _game.flow
	if flow.state_name() == "boss":
		_boss.defeat()
	match _phase:
		"entered":
			_wait += 1
			if _wait == 3:
				_check_warden()
				var b: Vector3 = _game.ctx.terrain.beacon_point(_game.run.stage)
				_put(b + Vector3(12.0, 1.5, 0.0))
				_phase = "in_bowl"
				_wait = 0
		"in_bowl":
			_wait += 1
			if _wait == 20:
				_checked[-1]["state_in_bowl"] = flow.state_name()
				_phase = "break"
		"break":
			if is_instance_valid(flow.warden):
				_double.strike(flow.warden, "ram", RAM)
			else:
				_phase = "to_gates"
		"summary":
			_finish()


func _check_warden() -> void:
	var flow = _game.flow
	var t = _game.ctx.terrain
	var stage: int = _game.run.stage
	var record := {"stage": stage, "sealed": flow.sealed, "valid": is_instance_valid(flow.warden)}
	if record["valid"]:
		var w: Vector3 = flow.warden.global_position
		var b: Vector3 = t.beacon_point(stage)
		record["offset"] = Vector2(w.x - b.x, w.z - b.z).length()
		var spread := 0.0
		for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var p: Vector2 = Vector2(b.x, b.z) + dir * 10.0
			spread = maxf(spread, absf(t.height(p.x, p.y) - b.y))
		record["spread"] = spread
		var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
		var eye: Vector3 = t.spawn_point(stage) + Vector3.UP * DROP
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, b + Vector3.UP * WARDEN_EYE, 1))
		record["seen"] = hit.is_empty()
	_checked.append(record)


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_entered.append(stage)
	_source.hold = {}
	_phase = "entered"
	_wait = 0


func _on_offered(offers: Array) -> void:
	if _phase != "break" and _phase != "to_gates":
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
	if _game.run.stage == 3:
		_game.events.run_ended.connect(func(_won: bool): _phase = "summary")


func _finish() -> bool:
	_done = true
	for r in _checked:
		_report("stage %d warden" % r["stage"], r["sealed"] and r["valid"] and r.get("offset", INF) < 1.0
				and r.get("spread", INF) <= FLOOR_FLAT and r.get("seen", false),
			"sealed %s, Warden %.2f m from the beacon point on a floor that varies %.2f m within 10 m, in sight from the drop %s; state in the bowl %s"
				% [r["sealed"], r.get("offset", INF), r.get("spread", INF), r.get("seen", false), r.get("state_in_bowl", "?")])
	var spiked := _checked.filter(func(r): return r.get("state_in_bowl", "") == "beacon").size()
	_report("threat_rose", spiked == 3 and _rises.size() >= 3,
		"rolling into the bowl entered the beacon state on %d of 3 stages; threat_rose fired %d times %s" % [spiked, _rises.size(), _rises])
	_report("warden run", _entered == [1, 2, 3] and _unsealed == [1, 2, 3] and _cleared == [1, 2, 3] and _ended
			and _game.flow.state_name() == "summary" and _game.world.vault == null and _pressure > 0,
		"entered %s, unsealed %s, cleared %s, run ended %s in %s; no vault in calm %s; %d pressure updates"
			% [_entered, _unsealed, _cleared, _ended, _game.flow.state_name(), _game.world.vault == null, _pressure])
	print("world_warden_flow_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
