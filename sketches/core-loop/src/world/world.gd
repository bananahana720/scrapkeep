extends Node

const Terrain := preload("res://src/world/terrain.gd")
const Flood := preload("res://src/world/flood.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const Director := preload("res://src/world/director.gd")

# Writer D's module: the stage geometry, the event director, stage events and the
# launch. This is the spine's minimal stub. One ambient event (the Spillway flood,
# announced by its klaxon before the water rises), enemy scheduling through the
# spawner, pressure for the music, and a straight launch that keeps the ball's
# horizontal speed. D replaces this folder wholesale; see CONTRACTS.md.

const FLOOD_ID := "flood"
const LAUNCH_UP := 20.0
const SPAWN_RING := Vector2(34.0, 56.0)
const PRESSURE_STEP := 0.05

var ctx
var terrain
var flood
var director

var _flood_phase := -1
var _pressure := -1.0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "World"
	terrain = Terrain.new()
	terrain.build(ctx.root)
	ctx.terrain = terrain
	flood = Flood.new()
	flood.name = "Flood"
	ctx.root.add_child(flood)
	flood.setup()
	director = Director.new(ctx.rng.randi())
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.reward_chosen.connect(_on_reward_chosen)


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	director = Director.new(ctx.rng.randi())
	director.threat = ctx.flow.stage_def()["threat"]
	flood.cycle = FloodCycle.new()
	flood.step(0.0)
	_flood_phase = flood.cycle.phase
	_pressure = -1.0


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.flow.in_play():
		return
	_step_flood(delta)
	_step_director(delta)


func _step_flood(delta: float) -> void:
	flood.step(delta)
	var phase: int = flood.cycle.phase
	if phase != _flood_phase:
		_flood_phase = phase
		match phase:
			FloodCycle.WARNING:
				ctx.events.event_announced.emit(FLOOD_ID, flood.cycle.seconds_to_flood())
			FloodCycle.RISING:
				ctx.events.event_started.emit(FLOOD_ID)
			FloodCycle.FALLING:
				ctx.events.event_ended.emit(FLOOD_ID, "passed")
	if ctx.calm:
		return
	var player = ctx.player
	player.add_external_accel(flood.external_accel(player.ball_position(), player.state.velocity))


func _step_director(delta: float) -> void:
	director.spike = ctx.flow.state_name() == "beacon"
	var alive := get_tree().get_nodes_in_group("enemy").size()
	for kind in director.advance(delta, alive):
		if ctx.calm or ctx.spawner == null:
			continue
		ctx.spawner.spawn_enemy(Director.KIND_NAMES[kind], spawn_point())
	var pressure: float = director.pressure(alive)
	if absf(pressure - _pressure) >= PRESSURE_STEP:
		_pressure = pressure
		ctx.events.pressure_changed.emit(pressure)


# Off-screen and near: the ring is scored against where the camera is looking, so an
# enemy appears beside or behind you rather than popping in ahead.
func spawn_point() -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var forward: Vector3 = -ctx.camera.yaw_basis().z
	var best := ball + Vector3.UP * 2.0
	var best_score := -99.0
	for i in 12:
		var angle: float = ctx.rng.randf() * TAU
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var spot: Vector3 = ball + dir * ctx.rng.randf_range(SPAWN_RING.x, SPAWN_RING.y)
		var x := clampf(spot.x, -108.0, 155.0)
		var z := clampf(spot.z, -178.0, 178.0)
		var ground := Terrain.ground(x, z)
		var score := -dir.dot(forward)
		if absf(ground - Terrain.ground(x + 3.0, z)) > 6.0:
			score -= 3.0
		if absf(ground - Terrain.ground(x, z + 3.0)) > 6.0:
			score -= 3.0
		if score > best_score:
			best_score = score
			best = Vector3(x, ground + 2.4, z)
	return best


# The stub launch: the moment a gate is taken, the ball is thrown up with its
# horizontal speed kept, and never slower than cruise, which is a gift, not a cost.
func _on_reward_chosen(_part_id: String) -> void:
	var player = ctx.player
	var v: Vector3 = player.state.velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var floor_speed: float = ctx.tuning.f("cruise")
	if flat.length() < floor_speed:
		var heading := flat.normalized() if flat.length() > 0.5 else -ctx.camera.yaw_basis().z
		flat = heading * floor_speed
	var launch := flat + Vector3.UP * LAUNCH_UP
	player.set_velocity_now(launch)
	ctx.events.launched.emit(launch)
