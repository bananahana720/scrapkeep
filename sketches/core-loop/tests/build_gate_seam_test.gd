extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# The reward gates' seams, over a scripted run of all three stages:
#   - Build opens the gates on flow's "gates" state, never on the charge reading
#     (spine review finding B1). A beacon_charge_changed(1.0) arriving while flow is
#     still in "beacon" opens nothing.
#   - Gates stand downhill of the ball (writer D's integration finding: gates up the
#     beacon bowl's bank cost 20 -> 13 m/s). On every stage, each gate spot is at or
#     below the ground under the ball when the gates appear, within 0.75 m.
#   - Rolling through a gate at 20 m/s loses at most 15% of horizontal speed (a gain
#     is fine).
# ctx.calm keeps enemies out, so the speed check measures the gates alone. The spine's
# boss double stands in for the arena after stage 3, and its defeat() ends the run
# whether or not the real boss module is present.

const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const TOLERANCE := 0.15
const CLIMB_TOLERANCE := 0.75
const SETTLE_TICKS := 9

# Preserve the legacy three-stage rule on a double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _build
var _boss
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _phase := "boot"
var _wait := 0
var _offered := 0
var _early := {}
var _offer := {}
var _gate := {}
var _gates: Array[Dictionary] = []
var _ended := false


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks > 90 * 90:
		_report("timeout", false, "stalled in phase %s, flow %s" % [_phase, _game.flow.state_name()])
		return _finish()
	_wait += 1
	match _phase:
		"boot":
			_boss = BossDouble.new()
			_game.add_child(_boss)
			_boss.setup(_game.ctx)
			_game.ctx.calm = true
			_game.player.source = _source
			_game.flow.beacon_seconds_override = 30.0
			var events = _game.events
			events.reward_offered.connect(_on_offered)
			events.reward_chosen.connect(func(_id: String): _next("after_gate"))
			events.stage_entered.connect(func(_stage: int, _retry: bool):
				_source.hold = {}
				_next("to_beacon"))
			events.run_ended.connect(func(_won: bool): _ended = true)
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_build = _game.ctx.build
		"to_beacon":
			if _wait == 2:
				var at: Vector3 = _game.flow.beacon.global_position + Vector3.UP * 1.5
				_game.player.reset_to(at)
				_game.player.body().global_position = at
			if _early.is_empty() and _game.flow.state_name() == "beacon":
				_game.events.beacon_charge_changed.emit(1.0)
				_early = {"state": _game.flow.state_name(), "open": _build.gates.is_open(), "offered": _offered}
				_game.flow.beacon.duration = 0.3
				_game.flow.beacon_seconds_override = 0.6
		"approach":
			var rel: Vector3 = _game.player.ball_position() - _offer["at"]
			if rel.dot(_offer["facing"]) < -1.5:
				_gate["before"] = _game.player.planar_velocity().length()
		"after_gate":
			if _wait == SETTLE_TICKS:
				_gate["after"] = _game.player.planar_velocity().length()
				_gates.append(_gate)
				_next("flight")
		"flight":
			if _game.flow.state_name() == "boss":
				_boss.defeat()
			if _ended:
				return _finish()
	return false


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0


func _on_offered(offers: Array) -> void:
	_offered += 1
	if _phase != "to_beacon":
		return
	var ball: Vector3 = _game.player.ball_position()
	var ground: float = _game.ctx.terrain.height(ball.x, ball.z)
	var worst := -INF
	for offer in offers:
		worst = maxf(worst, (offer["at"] as Vector3).y - ground)
	_gate = {"stage": _game.run.stage, "climb": worst, "ball_y": ball.y, "ground": ground,
		"below_ball": offers.all(func(o): return (o["at"] as Vector3).y <= ball.y), "before": APPROACH_SPEED}
	_offer = offers[0]
	var facing: Vector3 = _offer["facing"]
	var start: Vector3 = (_offer["at"] as Vector3) - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_next("approach")


func _finish() -> bool:
	_report("no gates on the charge reading", _early.get("state", "") == "beacon" and not _early.get("open", true) and _early.get("offered", 1) == 0,
		"beacon_charge_changed(1.0) while flow was in %s: gates open %s, %d offer(s) published"
			% [_early.get("state", "?"), _early.get("open", "?"), _early.get("offered", -1)])
	_report("gates open on the gates state", _gates.size() == 3,
		"flow's gates state opened gates on %d of 3 stages" % _gates.size())
	for g in _gates:
		_report("gates downhill stage %d" % g["stage"], g["climb"] <= CLIMB_TOLERANCE and g["below_ball"],
			"highest gate spot %.2f m against the ground under the ball (needs <= %.2f), and below the ball at %.2f m"
				% [g["climb"], CLIMB_TOLERANCE, g["ball_y"]])
		var loss: float = (g["before"] - g.get("after", 0.0)) / g["before"]
		_report("gate speed stage %d" % g["stage"], g.has("after") and loss <= TOLERANCE,
			"%.2f m/s before the gate, %.2f m/s after (loss %.1f%%, needs <= %d%%)"
				% [g["before"], g.get("after", -1.0), loss * 100.0, int(TOLERANCE * 100.0)])
	print("build_gate_seam_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
