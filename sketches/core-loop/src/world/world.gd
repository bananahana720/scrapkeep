extends Node

const Terrain := preload("res://src/world/terrain.gd")
const Flood := preload("res://src/world/flood.gd")
const Director := preload("res://src/world/director.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const EventView := preload("res://src/world/event_view.gd")
const Launch := preload("res://src/world/launch.gd")

# Writer D's module: the stage geometry, the event director, stage events and the
# launch (see CONTRACTS.md). Each tick it steps the event director and the spawn
# director, publishes what they committed, and applies the world's pushes. The
# rules live in the pure models; this file only wires them to the bus, the run and
# the ball.

const SPAWN_RING := Vector2(34.0, 56.0)
const PRESSURE_STEP := 0.05
const MINIBOSS_KIND := "miniboss"
const MINIBOSS_FALLBACK := "chaser"

var ctx
var terrain
var flood
var director
var events
var view
var launch
# Where the last miniboss was asked for, for tests and the field notes.
var last_miniboss_at := Vector3.INF

var _stage_seed := 0
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
	terrain.flood = flood
	view = EventView.new()
	view.name = "StageEvents"
	ctx.root.add_child(view)
	view.setup(terrain)
	launch = Launch.new()
	launch.name = "Launch"
	ctx.root.add_child(launch)
	launch.setup()
	director = Director.new(ctx.rng.randi())
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.reward_chosen.connect(_on_reward_chosen)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and terrain != null:
		terrain.release()


func _on_stage_entered(stage: int, retry: bool) -> void:
	if events != null:
		_publish(events.end_all())
	launch.stop()
	terrain.use(stage)
	# A retry replays the same stage: same event plan, same miniboss spots. A new
	# entry draws a fresh plan from the run's stream.
	if not retry or _stage_seed == 0:
		_stage_seed = ctx.rng.randi()
	var def: Dictionary = ctx.flow.stage_def()
	var map = terrain.map()
	events = EventDirector.new(_stage_seed, def, map, ctx.tuning.f("cruise"), Callable(terrain, "height"))
	director = Director.new(_stage_seed ^ 0x5eed)
	director.threat = def["threat"]
	flood.cycle = events.flood
	var basin: Dictionary = map.basin
	if not basin.is_empty():
		var centre: Vector2 = basin["centre"]
		var r: float = basin["radius"]
		flood.configure(basin, terrain.height(centre.x, centre.y), terrain.drop_point(centre.x + r * 0.72, centre.y - r * 0.72, 0.0))
	else:
		flood.configure(basin, 0.0, Vector3.ZERO)
	flood.render()
	view.rebuild(events)
	last_miniboss_at = Vector3.INF
	_pressure = -1.0
	_mark_landing(stage, retry)


func _mark_landing(stage: int, retry: bool) -> void:
	launch.clear_landing()
	launch.gravity = ctx.tuning.f("gravity")
	var entry: Vector3
	var velocity: Vector3
	if retry:
		entry = ctx.run.snapshot_value("entry_position")
		velocity = ctx.run.snapshot_value("entry_velocity")
	elif stage > 1:
		var carried: Vector3 = ctx.player.state.velocity
		var flat := Vector2(carried.x, carried.z).length()
		entry = terrain.spawn_point(stage) + Vector3.UP * 14.0
		velocity = terrain.entry_heading(stage) * flat + Vector3.UP * carried.y
	else:
		return
	launch.mark_landing(entry, velocity, Callable(terrain, "height"))


func _physics_process(delta: float) -> void:
	if ctx == null or events == null or not ctx.flow.in_play():
		return
	var player = ctx.player
	if launch.flying():
		var rail = launch.rail(delta)
		if rail != null:
			player.set_velocity_now(rail)
	var ball: Vector3 = player.ball_position()
	var velocity: Vector3 = player.state.velocity
	_publish(events.advance(delta, ball, velocity))
	flood.render()
	if not ctx.calm:
		player.add_external_accel(flood.external_accel(ball, velocity) + events.push(ball, velocity))
	_step_director(delta)


func _publish(facts: Array) -> void:
	var bus = ctx.events
	for fact in facts:
		match fact["kind"]:
			"announced":
				bus.event_announced.emit(fact["id"], fact["seconds"])
			"started":
				bus.event_started.emit(fact["id"])
			"ended":
				bus.event_ended.emit(fact["id"], fact["outcome"])
			"milestone":
				ctx.run.record_milestone(fact["id"])
			"scrap":
				ctx.run.add_scrap(fact["amount"], fact["at"])
			"miniboss":
				_spawn_miniboss(fact["at"])


# The miniboss arrives where the director's seeded stream put it, on the ground and
# inside the playable floor. A combat module without the kind gets a chaser instead.
func _spawn_miniboss(at: Vector2) -> void:
	var rect: Rect2 = terrain.map().play_rect
	var x := clampf(at.x, rect.position.x, rect.end.x)
	var z := clampf(at.y, rect.position.y, rect.end.y)
	last_miniboss_at = terrain.drop_point(x, z, 2.4)
	if ctx.calm or ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
		return
	var enemy = ctx.spawner.spawn_enemy(MINIBOSS_KIND, last_miniboss_at)
	if enemy == null:
		ctx.spawner.spawn_enemy(MINIBOSS_FALLBACK, last_miniboss_at)


func _step_director(delta: float) -> void:
	director.spike = ctx.flow.state_name() == "beacon" or events.spike()
	var alive := get_tree().get_nodes_in_group("enemy").size()
	for kind in director.advance(delta, alive):
		if ctx.calm or ctx.spawner == null:
			continue
		ctx.spawner.spawn_enemy(Director.KIND_NAMES[kind], spawn_point())
	var pressure: float = minf(1.0, director.pressure(alive) + events.pressure_bonus())
	if absf(pressure - _pressure) >= PRESSURE_STEP:
		_pressure = pressure
		ctx.events.pressure_changed.emit(pressure)


# Off-screen and near: the ring is scored against where the camera is looking, so an
# enemy appears beside or behind you rather than popping in ahead.
func spawn_point() -> Vector3:
	var ball: Vector3 = ctx.player.ball_position()
	var forward: Vector3 = -ctx.camera.yaw_basis().z
	var rect: Rect2 = terrain.map().play_rect
	var best := ball + Vector3.UP * 2.0
	var best_score := -99.0
	for i in 12:
		var angle: float = ctx.rng.randf() * TAU
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var spot: Vector3 = ball + dir * ctx.rng.randf_range(SPAWN_RING.x, SPAWN_RING.y)
		var x := clampf(spot.x, rect.position.x, rect.end.x)
		var z := clampf(spot.z, rect.position.y, rect.end.y)
		var ground: float = terrain.height(x, z)
		var score := -dir.dot(forward)
		if absf(ground - terrain.height(x + 3.0, z)) > 6.0:
			score -= 3.0
		if absf(ground - terrain.height(x, z + 3.0)) > 6.0:
			score -= 3.0
		if score > best_score:
			best_score = score
			best = Vector3(x, ground + 2.4, z)
	return best


# The stage exit: the moment a gate is taken the ball is fired up the launch rail
# with its horizontal speed kept, never slower than cruise, which is a gift, not a cost.
func _on_reward_chosen(_part_id: String) -> void:
	var player = ctx.player
	launch.gravity = ctx.tuning.f("gravity")
	var velocity := Launch.launch_velocity(player.state.velocity, ctx.tuning.f("cruise"), -ctx.camera.yaw_basis().z)
	player.set_velocity_now(velocity)
	launch.fire(player.ball_position(), velocity)
	ctx.events.launched.emit(velocity)
