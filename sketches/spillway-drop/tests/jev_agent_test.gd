extends SceneTree

# JL-27: every route the state offers can be driven to its end by the agent. From
# mid-climb's spawn, holding push_objective must reach the mid-shelf objective by the
# bypass ramp and holding hit_kicker must reach it by a chute; from flood-hatch's spawn,
# on the scenario's own flood clock (the water starts to rise at 17 s), holding
# evade_hazard must bring the ball out of the full flood's reach, within 15 m of its
# refuge, before the water rises. Each case re-holds its intent every 90 ticks, as the runner does for a repeated
# answer, so re-planning from mid-route is exercised too. Both physics modes; the
# director is paused so the cases measure steering, not fights. The tick budgets are
# regression guards set from the first measured runs, not reach criteria.

const Stage := preload("res://src/stage.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const JevState := preload("res://src/jev/jev_state.gd")
const JevAgent := preload("res://src/jev/jev_agent.gd")
const Scenarios := preload("res://src/jev/scenarios.gd")
const Geo := preload("res://src/jev/geo.gd")

const HOLD_EVERY := 90
const REFUGE_REACH := 15.0
const CASES := [
	{"intent": "push_objective", "scenario": "mid-climb", "mode": "kinematic", "budget": 4500, "route": "bypass"},
	{"intent": "push_objective", "scenario": "mid-climb", "mode": "rigid", "budget": 4500, "route": "bypass"},
	{"intent": "hit_kicker", "scenario": "mid-climb", "mode": "kinematic", "budget": 2700, "route": "chute"},
	{"intent": "hit_kicker", "scenario": "mid-climb", "mode": "rigid", "budget": 2700, "route": "chute"},
	{"intent": "evade_hazard", "scenario": "flood-hatch", "mode": "kinematic", "budget": 1530, "route": ""},
	{"intent": "evade_hazard", "scenario": "flood-hatch", "mode": "rigid", "budget": 1530, "route": ""},
]

var _cases := []
var _started := false
var _failures := 0


func _initialize() -> void:
	for spec in CASES:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var stage = Stage.new()
		stage.test_mode = true
		viewport.add_child(stage)
		var c: Dictionary = spec.duplicate()
		c["stage"] = stage
		c["tick"] = -1
		c["done"] = false
		_cases.append(c)


func _check(ok: bool, text: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if not _started:
		for c in _cases:
			if c["stage"].player == null:
				return false
		for c in _cases:
			_begin(c)
		_started = true
		return false
	var running := false
	for c in _cases:
		if c["done"]:
			continue
		running = true
		_step(c)
	if not running:
		print("jev_agent_test: %s" % ("PASS" if _failures == 0 else "FAILED %d" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _begin(c: Dictionary) -> void:
	var stage = c["stage"]
	stage.director.paused = true
	stage.player.set_mode(PlayerBall.MODE_NAMES.find(c["mode"]))
	var scenario: Dictionary = Scenarios.make(c["scenario"])
	Scenarios.place(stage, scenario)
	# From the nominal spawn: a rigid teleport has not landed yet on this frame.
	c["refuge"] = Geo.nearest_refuge(scenario["spawn"])
	var run := Scenarios.Run.new(scenario)
	var view := JevState.new(stage, run)
	view.attach()
	var agent := JevAgent.new(stage, view)
	agent.install()
	c["run"] = run
	c["view"] = view
	c["agent"] = agent


func _step(c: Dictionary) -> void:
	var stage = c["stage"]
	c["tick"] += 1
	var t: int = c["tick"]
	if t > 0:
		c["view"].advance()
	if t >= 1 and (t - 1) % HOLD_EVERY == 0:
		var point: Vector3 = c["run"].objective()["point"]
		c["agent"].hold(c["intent"], {"point": point})
	var label := "%s %s" % [c["intent"], c["mode"]]
	var at: Vector3 = stage.player.ball_position()
	if c["intent"] == "evade_hazard":
		var refuge: Vector3 = c["refuge"]
		if t > 1 and not Geo.wet_at_full(at) and Vector2(at.x, at.z).distance_to(Vector2(refuge.x, refuge.z)) <= REFUGE_REACH:
			_check(t <= c["budget"], "%s: at the refuge (%.0f, %.0f) out of the flood's reach at tick %d (budget %d)" % [
				label, refuge.x, refuge.z, t, c["budget"]])
			_finish(c)
			return
	elif c["run"].success_tick >= 0:
		var route: String = c["run"].progress["route"]
		_check(t <= c["budget"] and route == c["route"], "%s: reached the mid shelf at tick %d (budget %d) by %s (want %s)" % [
			label, t, c["budget"], route, c["route"]])
		_finish(c)
		return
	if t >= c["budget"]:
		_check(false, "%s: not done within %d ticks; at (%.0f, %.1f, %.0f), corridors %s" % [
			label, c["budget"], at.x, at.y, at.z, c["run"].progress["corridors"]])
		_finish(c)


func _finish(c: Dictionary) -> void:
	c["done"] = true
	c["view"].detach()
	c["stage"].player.source = load("res://src/intent.gd").Source.new()
