extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Beacon := preload("res://src/core/beacon.gd")

# The run as one state machine: title, class select, then per stage roam, beacon,
# gates and launch, and a summary after stage 3. Death is its own state with a
# one-key way out. Modules read state; only flow changes it, and every change is
# published as flow_changed so music and HUD follow the same beat.

enum { TITLE, CLASS_SELECT, STAGE, BEACON, GATES, LAUNCH, SUMMARY, DEAD, BOSS, VICTORY }

const NAMES := ["title", "class_select", "stage", "beacon", "gates", "launch", "summary", "dead", "boss", "victory"]
# The beat between Brindle's defeat and the summary: the ball keeps rolling.
const VICTORY_SECONDS := 2.5
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
# The Warden seals every stage in play. ctx.calm leaves stages unsealed so momentum
# tests measure the seams alone; force_warden seals them anyway for the gate tests.
var force_warden := false
var sealed := false
var warden: Node3D = null
# Seam for wave 4: the boss flow sets boss_active when it enters its "boss" state and
# boss_plating to the hull's plating. The death screen then shows the boss gap line and
# offers T, which replays stage 3 from the start the run kept.
var boss_active := false
var boss_plating := 120.0
# True from arena entry until the run leaves the fight, so a death there retries the
# arena, not stage 3.
var in_arena := false
# The plating that stood in the way when the ball died in the arena, for the gap line.
var _death_plating := -1.0
var _victory_left := 0.0
# warden_engaged fires once per stage attempt: on the first sealed ring entry or the
# first strike on the Warden, whichever comes first (the music's cue to bring its theme in).
var _engaged := false
# Where this stage's Warden stands; it is immobile, so a warden kill reported far from
# here belongs to some other warden and does not unseal this beacon.
var _warden_at := Vector3.ZERO
# While sealed the shown charge stops short of full, so 1.0 is published only by the
# unseal itself and a module that opens gates on 1.0 cannot run ahead of the kill.
const SEALED_CAP := 0.99
const WARDEN_MATCH := 6.0
var _warned := {}

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
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.boss_defeated.connect(_on_boss_defeated)


func state_name() -> String:
	return NAMES[state]


func in_play() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH or state == BOSS


# Stage content (director, flood, events, scrap, fabricators, vaults, stage enemies)
# runs only while this is true; it is false in the arena and after the win.
func in_stage() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH


# The boss module (ctx.boss, set by src/boss/boss.gd) runs the arena; without one the
# run ends on the summary after stage 3, as it did before the boss existed.
func _boss_module() -> Node:
	var boss: Node = ctx.boss if "boss" in ctx else null
	return boss if boss != null and boss.has_method("enter_arena") else null


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
	in_arena = false
	boss_active = false
	ctx.run.begin(chosen)
	ctx.events.run_started.emit(chosen.id)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	enter_stage(1, heading * ctx.tuning.f("cruise") * FIRST_DROP_SPEED, false)


# carried is the velocity the ball arrives with: its horizontal speed is kept exactly
# and turned onto the stage's entry heading, its vertical part is kept as it was.
func enter_stage(index: int, carried: Vector3, retry: bool) -> void:
	ctx.run.enter_stage(index)
	_launched = false
	_flight = 0.0
	_last_percent = -1
	# The checkpoint is taken before stage_entered, so nothing a module grants inside
	# its handler is folded into the stage start. The entry pose is filled in after,
	# because world may swap the geometry inside that handler.
	ctx.run.snapshot(Vector3.ZERO, Vector3.ZERO, ctx.camera.yaw)
	ctx.events.stage_entered.emit(index, retry)
	var heading: Vector3 = ctx.terrain.entry_heading(index)
	var flat := Vector2(carried.x, carried.z).length()
	var velocity := heading * flat + Vector3.UP * carried.y
	var at: Vector3 = ctx.terrain.spawn_point(index) + Vector3.UP * ENTRY_LIFT
	_place_ball(at, velocity, heading)
	_place_beacon()
	ctx.run.set_snapshot_entry(at, velocity, ctx.camera.yaw)
	_set_state(STAGE)


# Back to the stage-start checkpoint: run state, ball position and entry speed. It is
# one synchronous call, so it lands well inside a second.
func retry_stage() -> void:
	if not ctx.run.has_snapshot() or state == TITLE or state == CLASS_SELECT or state == SUMMARY or state == VICTORY:
		return
	if in_arena:
		_retry_arena()
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


# Replays a stage from the first start the run kept for it, as the boss death screen's
# T does for stage 3. One synchronous call, like a retry.
func replay_stage(index: int) -> bool:
	if not ctx.run.use_stage_start(index):
		return false
	boss_active = false
	in_arena = false
	retry_stage()
	return true


# After stage 3's launch the run enters the arena instead of the summary. The boss
# module places the ball; flow then keeps the arena-entry checkpoint (the stage-3-end
# snapshot), which R restores on the boss death screen.
func enter_boss(carried: Vector3) -> void:
	var boss := _boss_module()
	in_arena = true
	ctx.run.snapshot(Vector3.ZERO, Vector3.ZERO, ctx.camera.yaw)
	_set_state(BOSS)
	ctx.events.stage_content_cleared.emit("arena")
	ctx.player.set_frozen(false)
	boss.enter_arena(carried)
	ctx.run.set_snapshot_entry(ctx.player.ball_position(), ctx.player.state.velocity, ctx.camera.yaw)


# The retry's reason is its own, so anything that keeps per-attempt memory (the codex,
# the music) can tell a fresh arena from a retried one.
func _retry_arena() -> void:
	ctx.run.restore()
	ctx.player.set_frozen(false)
	_set_state(BOSS)
	ctx.events.stage_content_cleared.emit("arena_retry")
	_boss_module().enter_arena(ctx.run.snapshot_value("entry_velocity"))


# The boss's live read of the fight (CONTRACTS, Flow seams): the plating that stands in
# the way right now and the objective for the current phase. A boss module without
# them falls back to the entry plating and the standing arena objective.
func boss_plating_now() -> float:
	var boss := _boss_module()
	if boss != null and boss.has_method("live_plating"):
		return float(boss.live_plating())
	return boss_plating


func _boss_objective() -> String:
	var boss := _boss_module()
	if boss != null and boss.has_method("objective_text"):
		var text := String(boss.objective_text())
		if text != "":
			return text
	return EventKinds.objective("boss_arena_entered", {"punch": int(punch_now()), "plating": int(boss_plating_now())})


# The arena's own fall rescue. The boss module (E) owns the arena, so it names the
# floor and the landing spot; without them flow uses the arena-entry checkpoint.
# Like the stage rescue it costs nothing and keeps the horizontal speed.
const ARENA_FALL := 40.0


func _rescue_in_arena(ball: Vector3) -> void:
	var boss := _boss_module()
	var floor_y: float
	var landing: Vector3
	if boss != null and boss.has_method("floor_y") and boss.has_method("rescue_point"):
		floor_y = boss.floor_y()
		if ball.y >= floor_y:
			return
		landing = boss.rescue_point()
	else:
		var entry: Vector3 = ctx.run.snapshot_value("entry_position")
		if ball.y >= entry.y - ARENA_FALL:
			return
		warn_once("arena_rescue", "flow: boss module has no floor_y()/rescue_point(); rescuing to the arena entry")
		landing = entry
	var v: Vector3 = ctx.player.state.velocity
	ctx.player.reset_to(landing, Vector3(v.x, 0.0, v.z))
	ctx.player.body().global_position = landing


# The treasure burst for a first discovery in a run: scrap at the spot, which feeds
# heft, so exploring feeds growth (DEMO-SPEC). The codex calls it once per entry per run.
const BURST_PER_STAGE := 20


func discovery_burst(at: Vector3) -> void:
	ctx.run.add_scrap(BURST_PER_STAGE * ctx.run.stage, at)


func can_replay_final_stage() -> bool:
	return boss_active and ctx.run.has_stage_start(StageDefs.COUNT)


# What the death screen says about the fight that killed you: your punch against the
# plating that stood in the way, and your heft. Empty when no plated lock was live.
func gap_line() -> String:
	var plating := -1.0
	if boss_active:
		plating = _death_plating if state == DEAD and _death_plating >= 0.0 else boss_plating_now()
	elif sealed and is_instance_valid(warden):
		plating = warden_plating()
	if plating < 0.0:
		return ""
	return "Punch %d / plating %d · Heft %s" % [int(punch_now()), int(plating), ctx.run.roman(ctx.run.heft_class())]


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
	if is_instance_valid(warden):
		warden.queue_free()
	_engaged = false
	sealed = (not ctx.calm) or force_warden
	warden = _spawn_warden() if sealed else null
	_warden_at = warden.global_position if warden != null else Vector3.ZERO
	# No Warden to break (a spawner without the kind): the stage stays on the
	# presence path rather than locking the exit.
	if warden == null:
		sealed = false


func _spawn_warden() -> Node3D:
	if ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
		return null
	var spawned = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(ctx.run.stage))
	return spawned if spawned is Node3D else null


# Spawner reads, each with the fallback the contract names for a spawner without it.
# A fallback that fires says so once, so a missing seam shows up in the log.
func warden_integrity() -> float:
	if not is_instance_valid(warden):
		return 1.0
	if not ctx.spawner.has_method("integrity_of"):
		warn_once("integrity_of", "flow: spawner has no integrity_of(); the Warden charge reads 0")
		return 1.0
	return ctx.spawner.integrity_of(warden)


func punch_now() -> float:
	if ctx.spawner == null or not ctx.spawner.has_method("punch_now"):
		warn_once("punch_now", "flow: spawner has no punch_now(); punch reads 0")
		return 0.0
	return ctx.spawner.punch_now()


func warden_plating() -> float:
	if is_instance_valid(warden) and ctx.spawner.has_method("plating_of"):
		return ctx.spawner.plating_of(warden)
	if is_instance_valid(warden):
		warn_once("plating_of", "flow: spawner has no plating_of(); showing the stage's warden_plating")
	return stage_def()["warden_plating"]


func warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


func physics_step(delta: float) -> void:
	if state == VICTORY:
		_victory_left -= delta
		if _victory_left <= 0.0:
			_end_run_won()
		return
	if not in_play():
		return
	ctx.run.advance(delta)
	var ball: Vector3 = ctx.player.ball_position()
	match state:
		STAGE, BEACON:
			if sealed and not is_instance_valid(warden):
				_warden_vanished()
				return
			var done: bool = beacon.advance(delta, ball, sealed)
			if sealed:
				beacon.show_progress(beacon.duration * minf(SEALED_CAP, 1.0 - warden_integrity()))
				if beacon.phase != Beacon.IDLE:
					_engage()
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
		BOSS:
			# The arena is the boss module's geometry, not the world's terrain.
			_rescue_in_arena(ball)
			return
	_rescue_if_fallen(ball)


func _finish_stage() -> void:
	var cleared: int = ctx.run.stage
	ctx.events.stage_cleared.emit(cleared)
	if StageDefs.is_last(cleared):
		if _boss_module() != null:
			enter_boss(ctx.player.state.velocity)
			return
		_end_run_won()
		return
	enter_stage(cleared + 1, ctx.player.state.velocity, false)


func _on_boss_defeated() -> void:
	if state != BOSS:
		return
	boss_active = false
	in_arena = false
	_victory_left = VICTORY_SECONDS
	_set_state(VICTORY)


func _end_run_won() -> void:
	ctx.run.over = true
	ctx.player.set_frozen(true)
	_set_state(SUMMARY)
	ctx.events.run_ended.emit(true)


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


# Breaking the Warden opens the gates wherever the ball is: the stage's MUST is done
# and nothing asks you to roll back to the ring.
func _on_enemy_killed(kind: String, at: Vector3, _scrap_value: int) -> void:
	if kind != "warden" or not sealed or not (state == STAGE or state == BEACON):
		return
	if not _is_this_warden(at):
		return
	_unseal()


# The kill is this stage's Warden when the spawner reads it as broken, or, for a
# spawner that cannot say, when it died where this Warden stands.
func _is_this_warden(at: Vector3) -> bool:
	if is_instance_valid(warden) and ctx.spawner.has_method("integrity_of"):
		return ctx.spawner.integrity_of(warden) <= 0.0
	return at.distance_to(_warden_at) <= WARDEN_MATCH


# A Warden that left the tree with no kill recorded is a seam fault, not the player's:
# the stage opens the same way a break does, and the run log keeps a note of it.
func _warden_vanished() -> void:
	warn_once("warden_vanished", "flow: the Warden left without a recorded kill; unsealing stage %d" % ctx.run.stage)
	ctx.run.note_anomaly("warden_vanished")
	_unseal()


func _unseal() -> void:
	sealed = false
	warden = null
	beacon.open()
	ctx.events.beacon_unsealed.emit(ctx.run.stage)
	_set_state(GATES)
	ctx.events.beacon_charge_changed.emit(1.0)


func _on_enemy_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if sealed and enemy == warden:
		_engage()


func _engage() -> void:
	if _engaged:
		return
	_engaged = true
	ctx.events.warden_engaged.emit(ctx.run.stage)


func _on_player_died() -> void:
	if not in_play():
		return
	_death_plating = boss_plating_now() if state == BOSS else -1.0
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
	var percent := int(beacon.fraction() * 100.0)
	var fight := {
		"distance": int(to_beacon),
		"percent": percent,
		"punch": int(punch_now()),
		"plating": int(warden_plating()),
		"hint": stage_def()["warden_hint"],
	}
	match state:
		STAGE, BEACON:
			if sealed:
				return EventKinds.objective("stage_entered" if state == STAGE else "beacon_charge_changed", fight)
			var text := EventKinds.objective("beacon_unsealed", fight)
			if not beacon.in_ring(ball):
				text += "  The ring is %d m away." % int(maxf(0.0, to_beacon - beacon.radius))
			return text
		GATES:
			return EventKinds.objective("reward_offered")
		LAUNCH:
			return EventKinds.objective("launched" if _launched else "reward_chosen")
		BOSS:
			return _boss_objective()
	return ""


func _set_state(next: int) -> void:
	if state == next:
		return
	state = next
	ctx.events.flow_changed.emit(NAMES[next])
