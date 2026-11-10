extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Launch := preload("res://src/world/launch.gd")

# The stage exit through the real flow, once: roll through a gate, ride the launch
# rail, enter the next stage from above and land on its hill. The ball's horizontal
# speed is measured before the gate, all through the flight, at the stage entry, at
# touchdown and half a second after. It may lose no more than 15% anywhere; a gain is
# a gift (the rail pushing a slow ball up to cruise, the landing hill), but the flight
# never runs faster than the launch it was given. The landing pad must mark where the
# ball actually comes down. The measurement ends at boss entry: a launch into the boss
# is no stage-to-stage launch, and a gun-only ball never ends a posture fight.

const BEACON_SECONDS := 0.6
const APPROACH := 16.0
const APPROACH_SPEED := 21.0
const TOLERANCE := 0.15
const ROLL_ON := 45
const PAD_TOLERANCE := 6.0
const TICK_LIMIT := 90 * 60
# a wide table is sampled twice, a narrow one at every stage-to-stage launch it has
const LAUNCH_SAMPLE := 2

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _started := false
var _done := false
var _phase := "boot"
var _wait := 0
var _offer := {}
var _record := {}
var _records: Array[Dictionary] = []


func _initialize() -> void:
	_check_pure()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check_pure() -> void:
	var fast := Launch.launch_velocity(Vector3(20.0, -3.0, 9.0), 14.0, Vector3.FORWARD)
	var slow := Launch.launch_velocity(Vector3(3.0, 0.0, 4.0), 14.0, Vector3.FORWARD)
	var still := Launch.launch_velocity(Vector3.ZERO, 14.0, Vector3(0.0, 0.0, -1.0))
	var kept := is_equal_approx(Vector2(fast.x, fast.z).length(), Vector2(20.0, 9.0).length()) and fast.y == Launch.LIFT
	var raised := is_equal_approx(Vector2(slow.x, slow.z).length(), 14.0) and Vector2(slow.x, slow.z).normalized().is_equal_approx(Vector2(0.6, 0.8))
	var headed := still.z < -13.9
	_report("launch rule", kept and raised and headed,
		"21.93 m/s kept as %.2f with %.0f m/s lift; 5 m/s raised to %.2f on its own heading; a still ball goes out along the camera at %.2f"
			% [Vector2(fast.x, fast.z).length(), fast.y, Vector2(slow.x, slow.z).length(), -still.z])


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
	var events = _game.events
	events.stage_entered.connect(_on_stage_entered)
	events.reward_offered.connect(_on_offered)
	events.launched.connect(_on_launched)
	events.run_ended.connect(func(_won: bool): _phase = "done")
	_game.ctx.calm = true
	_game.flow.beacon_seconds_override = BEACON_SECONDS
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)


func _planar() -> float:
	return _game.player.planar_velocity().length()


func _step() -> void:
	if _game.flow.state_name() == "boss":
		_finish()
		return
	var player = _game.player
	match _phase:
		"to_beacon":
			_wait += 1
			if _wait == 2:
				var at: Vector3 = _game.flow.beacon.global_position + Vector3.UP * 1.5
				player.reset_to(at)
				player.body().global_position = at
		"approach":
			_record["before"] = _planar()
		"flight":
			_record["flight_min"] = minf(_record.get("flight_min", INF), _planar())
			_record["flight_max"] = maxf(_record.get("flight_max", 0.0), _planar())
		"falling":
			if player.state.grounded:
				_record["touchdown"] = _planar()
				_record["touchdown_at"] = player.ball_position()
				_record["rings_down"] = _game.world.launch.landing_rings()
				_phase = "rolling"
				_wait = 0
		"rolling":
			_wait += 1
			if _wait == ROLL_ON:
				_record["roll_on"] = _planar()
				_records.append(_record)
				_record = {}
				if _records.size() == _launches_wanted():
					_finish()
					return
				_phase = "to_beacon"
				_wait = 0
		"done":
			_finish()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_source.hold = {}
	if stage == 1:
		_phase = "to_beacon"
		_wait = 0
		return
	_record["stage"] = stage
	_record["entry"] = Vector2(_game.player.state.velocity.x, _game.player.state.velocity.z).length()
	_record["pad"] = _game.world.launch.landing_point
	_record["rings_up"] = _game.world.launch.landing_rings()
	_phase = "falling"


func _on_offered(offers: Array) -> void:
	if _phase == "approach" or _phase == "flight":
		return
	_offer = offers[0]
	var facing: Vector3 = _offer["facing"]
	var start: Vector3 = _offer["at"] - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_phase = "approach"


func _on_launched(velocity: Vector3) -> void:
	_record["launch"] = Vector2(velocity.x, velocity.z).length()
	_source.hold = {}
	_phase = "flight"


static func _within(reference: float, value: float) -> bool:
	return reference > 0.1 and absf(value - reference) / reference <= TOLERANCE


static func _no_loss(reference: float, value: float) -> bool:
	return reference > 0.1 and value >= reference * (1.0 - TOLERANCE)


func _finish() -> bool:
	_done = true
	for r in _records:
		var before: float = r.get("before", -1.0)
		var stage: int = r.get("stage", -1)
		var launch: float = r.get("launch", -1.0)
		var kept: bool = _no_loss(before, r.get("flight_min", -1.0)) and _no_loss(before, r.get("entry", -1.0)) \
			and r.get("flight_max", INF) <= maxf(before, launch) * 1.001 and _within(launch, r.get("entry", -1.0))
		_report("launch into stage %d" % stage, kept,
			"%.2f m/s before the gate, %.2f at launch, %.2f to %.2f through the flight, %.2f entering stage %d"
				% [before, r.get("launch", -1.0), r.get("flight_min", -1.0), r.get("flight_max", -1.0), r.get("entry", -1.0), stage])
		_report("landing in stage %d" % stage, _no_loss(before, r.get("touchdown", -1.0)) and _no_loss(before, r.get("roll_on", -1.0)),
			"%.2f m/s at touchdown and %.2f m/s %d ticks later, against %.2f before the gate (no more than %d%% lost)"
				% [r.get("touchdown", -1.0), r.get("roll_on", -1.0), ROLL_ON, before, int(TOLERANCE * 100.0)])
		var pad: Vector3 = r.get("pad", Vector3.INF)
		var down: Vector3 = r.get("touchdown_at", Vector3.ZERO)
		var miss := Vector2(pad.x - down.x, pad.z - down.z).length()
		_report("landing mark in stage %d" % stage, miss <= PAD_TOLERANCE,
			"the pad marked (%.0f, %.0f); the ball touched down %.1f m from it" % [pad.x, pad.z, miss])
		_report("landing rings in stage %d" % stage, int(r.get("rings_up", -1)) == Launch.LANDING_RINGS and int(r.get("rings_down", -1)) == 0,
			"%d rings marked the fall at the entry, %d still stood across the view at touchdown (each goes as the ball threads it)"
				% [r.get("rings_up", -1), r.get("rings_down", -1)])
	_report("launches measured", _records.size() == _launches_wanted(), "%d of %d same-world stage-to-stage launches measured (world one rows minus one)" % [_records.size(), _launches_wanted()])
	print("world_launch_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _launches_wanted() -> int:
	var tbl = _game.ctx.stages
	return mini(LAUNCH_SAMPLE, tbl.last_of(1) - tbl.first_of(1))
