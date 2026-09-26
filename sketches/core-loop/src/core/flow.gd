extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Beacon := preload("res://src/core/beacon.gd")

# The run as one state machine: title, class select, then per stage roam, beacon,
# gates and launch, and a summary after stage 3. Death is its own state with a
# one-key way out. Modules read state; only flow changes it, and every change is
# published as flow_changed so music and HUD follow the same beat.

enum { TITLE, CLASS_SELECT, STAGE, BEACON, GATES, LAUNCH, SUMMARY, DEAD }

const NAMES := ["title", "class_select", "stage", "beacon", "gates", "launch", "summary", "dead"]
# How long the ball flies after the launch before the next stage takes it; the
# velocity at that moment is what the next stage receives.
const LAUNCH_FLIGHT := 0.6
# The next stage is entered from above, so a launch lands rather than appears.
const ENTRY_LIFT := 14.0
# Stage 1 has no launch behind it; it drops you in rolling at this share of cruise.
const FIRST_DROP_SPEED := 0.8
const RESCUE_DEPTH := 14.0

var ctx
var beacon
var state := TITLE
var classes: Array[Resource] = []
# Tests shorten the beacon; anything below zero means use the stage's own seconds.
var beacon_seconds_override := -1.0

var _launched := false
var _flight := 0.0
var _last_percent := -1


func setup(ctx_ref, beacon_ref) -> void:
	ctx = ctx_ref
	beacon = beacon_ref
	classes = ClassDef.all()
	ctx.events.player_died.connect(_on_player_died)
	ctx.events.reward_chosen.connect(_on_reward_chosen)
	ctx.events.launched.connect(_on_launched)


func state_name() -> String:
	return NAMES[state]


func in_play() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH


func stage() -> int:
	return ctx.run.stage


func stage_def() -> Dictionary:
	return StageDefs.of(ctx.run.stage)


func show_title() -> void:
	ctx.player.set_frozen(true)
	state = TITLE
	ctx.events.flow_changed.emit(NAMES[TITLE])


func open_class_select() -> void:
	if not in_play():
		ctx.player.set_frozen(true)
		_set_state(CLASS_SELECT)


# Space or Enter on the title, or on the summary, goes to class select.
func press_start() -> void:
	if state == TITLE or state == SUMMARY:
		_set_state(CLASS_SELECT)


func choose_class(index: int) -> void:
	if state != CLASS_SELECT or index < 0 or index >= classes.size():
		return
	_begin_run(classes[index])


# The death screen's second key: a fresh run with the same class, straight in.
func new_run() -> void:
	if ctx.run.class_def == null:
		_set_state(CLASS_SELECT)
		return
	_begin_run(ctx.run.class_def)


func _begin_run(chosen: Resource) -> void:
	ctx.run.begin(chosen)
	ctx.events.run_started.emit(chosen.id)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	enter_stage(1, heading * ctx.tuning.f("cruise") * FIRST_DROP_SPEED, false)


# carried is the velocity the ball arrives with: its horizontal speed is kept exactly
# and turned onto the stage's entry heading, its vertical part is kept as it was.
func enter_stage(index: int, carried: Vector3, retry: bool) -> void:
	ctx.run.stage = index
	_launched = false
	_flight = 0.0
	_last_percent = -1
	ctx.events.stage_entered.emit(index, retry)
	var heading: Vector3 = ctx.terrain.entry_heading(index)
	var flat := Vector2(carried.x, carried.z).length()
	var velocity := heading * flat + Vector3.UP * carried.y
	var at: Vector3 = ctx.terrain.spawn_point(index) + Vector3.UP * ENTRY_LIFT
	_place_ball(at, velocity, heading)
	_place_beacon()
	ctx.run.snapshot(at, velocity, ctx.camera.yaw)
	_set_state(STAGE)


# Back to the stage-start checkpoint: run state, ball position and entry speed. It is
# one synchronous call, so it lands well inside a second.
func retry_stage() -> void:
	if not ctx.run.has_snapshot() or state == TITLE or state == CLASS_SELECT or state == SUMMARY:
		return
	ctx.run.restore()
	_launched = false
	_flight = 0.0
	_last_percent = -1
	ctx.events.stage_entered.emit(ctx.run.stage, true)
	var velocity: Vector3 = ctx.run.snapshot_value("entry_velocity")
	_place_ball(ctx.run.snapshot_value("entry_position"), velocity, velocity)
	ctx.camera.yaw = ctx.run.snapshot_value("camera_yaw")
	_place_beacon()
	_set_state(STAGE)


func _place_ball(at: Vector3, velocity: Vector3, heading: Vector3) -> void:
	ctx.player.set_frozen(false)
	ctx.player.reset_to(at, velocity)
	# The body takes its new transform on the next physics step; the camera is snapped
	# to the target now so the first drawn frame already looks down the run.
	ctx.player.body().global_position = at
	ctx.camera.snap(heading)


func _place_beacon() -> void:
	var def := stage_def()
	var seconds: float = beacon_seconds_override if beacon_seconds_override >= 0.0 else def["beacon_seconds"]
	beacon.place(ctx.terrain.beacon_point(ctx.run.stage), seconds, def["beacon_radius"])


func physics_step(delta: float) -> void:
	if not in_play():
		return
	ctx.run.advance(delta)
	var ball: Vector3 = ctx.player.ball_position()
	match state:
		STAGE, BEACON:
			var done: bool = beacon.advance(delta, ball)
			if state == STAGE and beacon.phase != Beacon.IDLE:
				_set_state(BEACON)
			var percent := int(beacon.fraction() * 100.0)
			if percent != _last_percent and not done:
				_last_percent = percent
				ctx.events.beacon_charge_changed.emit(beacon.fraction())
			if done:
				_set_state(GATES)
				ctx.events.beacon_charge_changed.emit(1.0)
		LAUNCH:
			if _launched:
				_flight += delta
				if _flight >= LAUNCH_FLIGHT:
					_finish_stage()
	_rescue_if_fallen(ball)


func _finish_stage() -> void:
	var cleared: int = ctx.run.stage
	ctx.events.stage_cleared.emit(cleared)
	if StageDefs.is_last(cleared):
		ctx.run.over = true
		ctx.player.set_frozen(true)
		_set_state(SUMMARY)
		ctx.events.run_ended.emit(true)
		return
	enter_stage(cleared + 1, ctx.player.state.velocity, false)


func _on_reward_chosen(_part_id: String) -> void:
	if state == GATES:
		_set_state(LAUNCH)


# World may launch from inside its own reward_chosen handler, before flow has heard
# reward_chosen, so a launch during GATES counts as the gate being taken too.
func _on_launched(_velocity: Vector3) -> void:
	if state == GATES or state == LAUNCH:
		_set_state(LAUNCH)
		_launched = true
		_flight = 0.0


func _on_player_died() -> void:
	if not in_play():
		return
	ctx.player.set_frozen(true)
	_set_state(DEAD)


# A fall through the geometry is the map's fault, not the player's, so the rescue
# costs nothing and keeps the horizontal speed.
func _rescue_if_fallen(ball: Vector3) -> void:
	if ctx.terrain.contains(ball) and ball.y > ctx.terrain.height(ball.x, ball.z) - RESCUE_DEPTH:
		return
	var v: Vector3 = ctx.player.state.velocity
	ctx.player.reset_to(ctx.terrain.rescue_point(ball), Vector3(v.x, 0.0, v.z))


func objective_text() -> String:
	var ball: Vector3 = ctx.player.ball_position()
	var to_beacon: float = Vector2(ball.x - beacon.global_position.x, ball.z - beacon.global_position.z).length()
	match state:
		STAGE:
			return EventKinds.objective("stage_entered", {"distance": int(to_beacon)})
		BEACON:
			var text := EventKinds.objective("beacon_charge_changed", {"percent": int(beacon.fraction() * 100.0)})
			if not beacon.in_ring(ball):
				text += "  Outside the ring: %d m back." % int(to_beacon - beacon.radius)
			return text
		GATES:
			return EventKinds.objective("reward_offered")
		LAUNCH:
			return EventKinds.objective("launched" if _launched else "reward_chosen")
	return ""


func _set_state(next: int) -> void:
	if state == next:
		return
	state = next
	ctx.events.flow_changed.emit(NAMES[next])
