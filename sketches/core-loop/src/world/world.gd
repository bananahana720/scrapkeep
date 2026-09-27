extends Node

const Terrain := preload("res://src/world/terrain.gd")
const Flood := preload("res://src/world/flood.gd")
const Director := preload("res://src/world/director.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const EventView := preload("res://src/world/event_view.gd")
const Launch := preload("res://src/world/launch.gd")
const CodexWorld := preload("res://src/world/codex_world.gd")

# Writer D's module: the stage geometry, the event director, stage events and the
# launch (see CONTRACTS.md). Each tick it steps the event director and the spawn
# director, publishes what they committed, and applies the world's pushes. The
# rules live in the pure models; this file only wires them to the bus, the run and
# the ball.

const PRESSURE_STEP := 0.05
const MINIBOSS_KIND := "miniboss"
const MINIBOSS_FALLBACK := "chaser"
const VAULT_KIND := "vault"
const TAILWIND := 0.7
const SAIL_WIND := 0.5

var ctx
var terrain
var flood
var director
var events
var view
var launch
# Where the last miniboss was asked for, for tests and the field notes.
var last_miniboss_at := Vector3.INF
# The stage's plated vault while it stands, else null.
var vault: Node3D
var codex_world := CodexWorld.new()
# Every world codex entry fired this session, in order: {"id", "at"}.
var discoveries: Array = []

var _stage_seed := 0
var _pressure := -1.0
var _vault_pending := false
var _was_grounded := true


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
	view.setup(terrain, ctx.player)
	launch = Launch.new()
	launch.name = "Launch"
	ctx.root.add_child(launch)
	launch.setup()
	director = Director.new(ctx.rng.randi())
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.reward_chosen.connect(_on_reward_chosen)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.jumped.connect(_on_jumped)
	ctx.events.element_resolved.connect(_on_element_resolved)
	for entry in CodexWorld.ENTRIES:
		ctx.codex.declare(entry)


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
	director.play_rect = map.play_rect
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
	# Combat clears the stage's enemies in its own stage_entered handler, after this
	# one, so the vault goes in on the first tick of play instead.
	vault = null
	_vault_pending = true
	codex_world = CodexWorld.new()
	view.set_vault(terrain.vault_point(stage), false)
	_mark_landing(stage, retry)


# The arena is not a stage (DESIGN-NOTES spine call 34). The live events close, the
# director, the flood and the launch rail stop, and every stage map is parked until
# the next stage_entered rebuilds the stage. Flow publishes this on arena entry and on
# every arena retry.
func _on_stage_content_cleared(_reason: String) -> void:
	if events != null:
		_publish(events.end_all())
	events = null
	flood.cycle = null
	flood.configure({}, 0.0, Vector3.ZERO)
	launch.stop()
	launch.clear_landing()
	director.arrivals.clear()
	view.clear()
	vault = null
	_vault_pending = false
	terrain.park_all()
	if _pressure > 0.0:
		ctx.events.pressure_changed.emit(0.0)
	_pressure = -1.0


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
	if ctx == null or events == null or not ctx.flow.in_stage():
		return
	var player = ctx.player
	if _vault_pending:
		_vault_pending = false
		_spawn_vault()
	if vault != null and not is_instance_valid(vault):
		vault = null
		view.set_vault(Vector3.ZERO, false)
	if launch.flying():
		var rail = launch.rail(delta)
		if rail != null:
			player.set_velocity_now(rail)
	var ball: Vector3 = player.ball_position()
	var velocity: Vector3 = player.state.velocity
	_publish(events.advance(delta, ball, velocity))
	_watch_ground(delta, ball)
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
				var at: Vector2 = fact["at"]
				ctx.run.add_core("event", terrain.drop_point(at.x, at.y, 1.0))
			"scrap":
				ctx.run.add_scrap(fact["amount"], fact["at"])
			"miniboss":
				_spawn_miniboss(fact["at"])
			"gate":
				var g: Vector2 = fact["at"]
				_discover(codex_world.note("gate", {"id": fact["id"], "at": terrain.drop_point(g.x, g.y, 1.0),
					"tier": ctx.player.speed_tier()}))


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


# The world codex: read what just happened against the ground and the ball, hand it
# to the detector, and pass anything that fired to the codex.
func _watch_ground(delta: float, ball: Vector3) -> void:
	codex_world.advance(delta)
	var grounded: bool = ctx.player.state.grounded
	if _was_grounded and not grounded:
		_discover(codex_world.note("airborne", {"at": ball, "off_kicker": terrain.map().near_kicker_lip(Vector2(ball.x, ball.z))}))
	elif grounded and flood.in_basin(ball) and flood.surface_y() > terrain.height(ball.x, ball.z):
		_discover(codex_world.note("grounded", {"at": ball, "over_water": true}))
	_was_grounded = grounded


func _on_enemy_killed(_kind: String, at: Vector3, _scrap: int) -> void:
	if ctx.flow.in_stage():
		_discover(codex_world.note("kill", {"at": at, "in_water": flood.submersion(at) > 0.0}))


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if ctx.flow.in_stage():
		_discover(codex_world.note("slam", {"at": at}))


func _on_jumped(_air: bool) -> void:
	if not ctx.flow.in_stage() or events == null or events.squall == null:
		return
	var squall = events.squall
	var v: Vector3 = ctx.player.state.velocity
	var flat := Vector2(v.x, v.z)
	var tailwind: bool = squall.intensity() >= SAIL_WIND and flat.length() >= ctx.tuning.f("cruise") \
		and flat.normalized().dot(squall.wind) >= TAILWIND
	_discover(codex_world.note("jump", {"at": ctx.player.ball_position(), "tailwind": tailwind}))


func _on_element_resolved(_element: String, material: String, behaviour: String, at: Vector3) -> void:
	if ctx.flow.in_stage():
		_discover(codex_world.note("element", {"material": material, "behaviour": behaviour, "at": at}))


# The codex publishes synergy_discovered and grants the burst; the world only reports.
func _discover(fired: Array) -> void:
	for entry in fired:
		discoveries.append(entry)
		ctx.codex.mark_discovered(entry["id"], entry["at"])


# The plated vault off the fall line. Never in calm, and a combat module without the
# kind (a null return) simply leaves the spot empty.
func _spawn_vault() -> void:
	if ctx.calm or ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
		return
	var at: Vector3 = terrain.vault_point(ctx.flow.stage()) + Vector3.UP * 2.4
	var node = ctx.spawner.spawn_enemy(VAULT_KIND, at)
	if node is Node3D:
		vault = node
		view.set_vault(at, true, ctx.spawner.plating_of(node) if ctx.spawner.has_method("plating_of") else -1.0)


func _step_director(delta: float) -> void:
	director.spike = ctx.flow.state_name() == "beacon" or events.spike()
	director.heft_class = ctx.run.heft_class()
	var alive := get_tree().get_nodes_in_group("enemy").size()
	var ball: Vector3 = ctx.player.ball_position()
	var v: Vector3 = ctx.player.state.velocity
	var forward: Vector3 = -ctx.camera.yaw_basis().z
	var due: Array = director.advance(delta, alive, Vector2(ball.x, ball.z), Vector2(v.x, v.z), Vector2(forward.x, forward.z))
	for tier in director.take_threat_rises():
		ctx.events.threat_rose.emit(tier)
	view.show_arrivals(director.arrivals if not ctx.calm else [])
	for spawn in due:
		if ctx.calm or ctx.spawner == null:
			continue
		var at: Vector2 = spawn["at"]
		ctx.spawner.spawn_enemy(Director.KIND_NAMES[spawn["kind"]], terrain.drop_point(at.x, at.y, 2.4))
	var pressure: float = minf(1.0, director.pressure(alive) + events.pressure_bonus())
	if absf(pressure - _pressure) >= PRESSURE_STEP:
		_pressure = pressure
		ctx.events.pressure_changed.emit(pressure)


# The stage exit: the moment a gate is taken the ball is fired up the launch rail
# with its horizontal speed kept, and a slow ball is pushed up to cruise along the rail,
# which is a gift, not a cost.
func _on_reward_chosen(_part_id: String) -> void:
	var player = ctx.player
	launch.gravity = ctx.tuning.f("gravity")
	var velocity := Launch.launch_velocity(player.state.velocity, ctx.tuning.f("cruise"), -ctx.camera.yaw_basis().z)
	var start := Launch.rail_start(player.state.velocity)
	if Vector2(start.x, start.z).length() < 0.5:
		start = velocity
	player.set_velocity_now(start)
	launch.fire(player.ball_position(), velocity, start)
	ctx.events.launched.emit(velocity)
