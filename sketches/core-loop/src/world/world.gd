extends Node

const Terrain := preload("res://src/world/terrain.gd")
const Groups := preload("res://src/core/groups.gd")
const Flood := preload("res://src/world/flood.gd")
const Director := preload("res://src/world/director.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const CinderHeat := preload("res://src/world/cinder_heat.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const EventView := preload("res://src/world/event_view.gd")
const Launch := preload("res://src/world/launch.gd")
const CodexWorld := preload("res://src/world/codex_world.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const TerrainEventView := preload("res://src/world/terrain_event_view.gd")
const Bay := preload("res://src/world/bay.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Interact := preload("res://src/world/interact.gd")
const Activities := preload("res://src/world/activities.gd")
const SurveyPosts := preload("res://src/world/survey_posts.gd")
const BowlApproach := preload("res://src/world/bowl_approach.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Breach := preload("res://src/world/breach.gd")
const EventFamilies := preload("res://src/world/events/families.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const WARDEN_FIGHT := "warden"


const PRESSURE_STEP := 0.05
const MINIBOSS_KIND := "miniboss"
const MINIBOSS_FALLBACK := "chaser"
const ROGUE_CLEARANCE := 4.8
const VAULT_KIND := "vault"
const TAILWIND := 0.7
const SAIL_WIND := 0.5

var ctx
var terrain
var flood
var director
var events
var event_families := {}
var _park_warden_staggered := false
var _park_warden_chunks := 4
var _warden_phase := 0
var view
var launch
var last_miniboss_at := Vector3.INF
var rogue_plan := {}
var rogue: Node3D
var vault: Node3D
var codex_world := CodexWorld.new()
var discoveries: Array = []

var contraptions := {}
var _building := {}
var terrain_view
var bay
var ride
var interact
var locks
var activities
var survey_posts: Node3D
var bowl_approach: Node3D
var rescue
var bay_bark := {}
var layer := ""
var swap_log: Array[Dictionary] = []
var breach

var _stage_seed := 0
var _chute_clock := 0.0
var _skylight_clock := 0.0
var _glide_clock := 0.0
var _air_clock := 0.0
var _bay_calm := false
var _picks_opened := {}
var _picks_waiting: Array[int] = []
var _class_picks_owed := 0
var _pressure := -1.0
const BUILD_REFRESH := 1.0
var _build_clock := BUILD_REFRESH
var _vault_pending := false
var _was_grounded := true
var _on_barge := false
var cinder_heat := CinderHeat.new()
var _on_cinder := false


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "World"
	terrain = Terrain.new(ctx.stages)
	terrain.publish = ctx.events.world_fact.emit
	terrain.build(ctx.root, ctx.root.get("ground_behind_menu") == true)
	ctx.terrain = terrain
	_wire_terrain()
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
	_setup_gorge()
	interact = Interact.new()
	ctx.root.add_child(interact)
	interact.setup(ctx)
	ctx.player.interact_claim = interact.claims
	director = Director.new(ctx.rng.randi())
	_author_director()
	Threat.follow_row(ctx.tuning)
	Threat.Painter.warm_up(ctx.root)
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(_on_stage_content_cleared)
	ctx.events.reward_chosen.connect(_on_reward_chosen)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.enemy_struck.connect(func(_enemy, _kind, _force): cinder_heat.struck())
	ctx.events.slammed.connect(_on_slammed)
	ctx.events.jumped.connect(_on_jumped)
	ctx.events.element_resolved.connect(_on_element_resolved)
	ctx.events.reward_offered.connect(_on_reward_offered)
	ctx.events.flow_changed.connect(_on_flow_changed)
	ctx.events.run_started.connect(func(_class_id: String):
		_picks_opened.clear()
		_picks_waiting.clear()
		_class_picks_owed = 0)
	ctx.events.heft_class_changed.connect(_on_class_rise)
	ctx.events.stage_cleared.connect(_open_pick)
	ctx.events.warden_engaged.connect(_on_park_warden_engaged)
	ctx.events.posture_changed.connect(_on_park_warden_posture)
	ctx.events.beacon_unsealed.connect(_on_park_warden_broken)
	for entry in CodexWorld.ENTRIES:
		ctx.codex.declare(entry)
	activities = Activities.new()
	ctx.root.add_child(activities)
	activities.setup(ctx)
	survey_posts = SurveyPosts.new()
	ctx.root.add_child(survey_posts)
	survey_posts.setup(ctx)
	bowl_approach = BowlApproach.new()
	ctx.root.add_child(bowl_approach)
	bowl_approach.setup(ctx)
	activities.sluice_opened.connect(func(row_id: String):
		if events != null:
			events.notify_activity(row_id))
	activities.sluice_closed.connect(func(row_id: String):
		if events != null:
			_publish(events.finish_activity(row_id)))
	rescue = RescueSites.new()
	ctx.root.add_child(rescue)
	rescue.setup(ctx, interact)
	locks = StageLocks.new()
	ctx.root.add_child(locks)
	locks.setup(ctx)


func _setup_gorge() -> void:
	var g: float = ctx.tuning.f("gravity")
	var cruise: float = ctx.tuning.f("cruise")
	_add_contraptions()
	terrain_view = TerrainEventView.new()
	terrain_view.name = "TerrainEvents"
	ctx.root.add_child(terrain_view)
	terrain_view.setup(Callable(terrain, "height"))
	bay = Bay.new()
	ctx.root.add_child(bay)
	bay.setup(g, cruise)
	terrain.bay = bay


func _wire_terrain() -> void:
	terrain.stage_freed.connect(_on_stage_freed)
	terrain.stage_built.connect(_on_stage_built)
	ctx.events.warden_engaged.connect(_prepare_after)
	ctx.events.flow_changed.connect(func(state: String):
		if state == "gates":
			_prepare_after(ctx.run.stage))


func _prepare_after(stage: int) -> void:
	if stage >= 1 and stage < terrain.maps.size():
		terrain.prepare(stage + 1)


func _on_stage_freed(stage: int) -> void:
	contraptions.erase(stage)
	_building.erase(stage)


func _on_stage_built(stage: int) -> void:
	if not terrain.built_threaded(stage) or contraptions.has(stage) or _building.has(stage):
		return
	if terrain.geometry_root(stage).visible:
		return
	var m = terrain.maps[stage - 1]
	if not "contraptions" in m or m.contraptions.is_empty():
		return
	var c := Contraptions.new()
	terrain.geometry_root(stage).add_child(c)
	c.begin(m, terrain.ground_callable(stage), ctx.tuning.f("cruise"), ctx.tuning.f("gravity"))
	_building[stage] = c


func _process(_delta: float) -> void:
	if ctx == null or (ctx.flow != null and not ctx.flow.calm()):
		return
	for stage in _building:
		var c = _building[stage]
		if not is_instance_valid(c):
			_building.erase(stage)
		elif c.unbuilt():
			c.build_next()
		else:
			_building.erase(stage)
			c.finish()
			contraptions[stage] = c
		return


func _add_contraptions() -> void:
	var g: float = ctx.tuning.f("gravity")
	var cruise: float = ctx.tuning.f("cruise")
	for i in terrain.maps.size():
		var m = terrain.maps[i]
		if _building.has(i + 1):
			contraptions[i + 1] = _building[i + 1]
			_building.erase(i + 1)
			contraptions[i + 1].finish()
		if contraptions.has(i + 1) or not terrain.is_built(i + 1):
			continue
		if not "contraptions" in m or m.contraptions.is_empty():
			continue
		var c := Contraptions.new()
		terrain.geometry_root(i + 1).add_child(c)
		c.setup(m, terrain.ground_callable(i + 1), cruise, g)
		contraptions[i + 1] = c


func _on_stage_entered(stage: int, retry: bool) -> void:
	cinder_heat.reset()
	if retry:
		_class_picks_owed = 0
	Threat.follow_row(ctx.tuning)
	Threat.Painter.warm_up(ctx.root)
	if events != null:
		_publish(events.end_all())
	EventFamilies.release(events, event_families)
	_park_warden_staggered = false
	_park_warden_chunks = 4
	_warden_phase = 0
	launch.stop()
	ride = null
	_show_ride()
	bay.undock()
	_bay_calm = false
	terrain.use(stage)
	_add_contraptions()
	var m = terrain.map()
	_host_destructibles(m)
	if "swaps" in m:
		for id in m.swaps:
			m.apply_swap(id, false)
	breach = Breach.new(m.breach_plates) if "breach_plates" in m else null
	if contraptions.has(stage):
		contraptions[stage].reset()
	layer = ""
	var drawn: int = ctx.rng.randi()
	if not retry or _stage_seed == 0:
		_stage_seed = drawn
	var def: Dictionary = RunTier.stage_row(ctx.flow.stage_def(), ctx.run.selected_run_tier())
	var map = terrain.map()
	events = EventDirector.new(_stage_seed, def, map, ctx.tuning.f("cruise"), Callable(terrain, "height"))
	event_families = EventFamilies.build(self, events)
	director = Director.new(_stage_seed ^ 0x5eed)
	var map_id := String(map.park.get("map", "")) if "park" in map else ""
	rogue_plan = RogueDirector.plan(_stage_seed ^ 0x706e, ctx.stages.world_of(stage), RogueDirector.read_sites(map_id))
	rogue = null
	_author_director(def)
	director.use_row(def, ctx.tuning.option(Director.Tuning.BREATH_KEY) if ctx.tuning != null else "", Callable(ctx.run, "selected_run_tier"))
	director.threat = def["threat"]
	director.play_rect = map.play_rect
	director.terrain = terrain
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
	terrain_view.rebuild(events)
	last_miniboss_at = Vector3.INF
	_pressure = -1.0
	vault = null
	_vault_pending = ctx.stages.has_vault()
	codex_world = CodexWorld.new()
	view.set_vault(terrain.vault_point(stage), false)
	_mark_landing(stage, retry)
	if ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("cruise_launch_air_reset") and ctx.player != null:
		var fwd: Vector3 = terrain.entry_heading(stage)
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
		ctx.player.set_velocity_now(fwd * ctx.tuning.f("cruise"))
	_cut_gov_air_refilled = false


func _on_stage_content_cleared(_reason: String) -> void:
	_release_destructibles()
	if events != null:
		_publish(events.end_all())
	EventFamilies.release(events, event_families)
	events = null
	rogue_plan = {}
	flood.cycle = null
	flood.configure({}, 0.0, Vector3.ZERO)
	launch.stop()
	launch.clear_landing()
	ride = null
	_show_ride()
	bay.undock()
	_bay_calm = false
	terrain_view.clear()
	director.arrivals.clear()
	view.clear()
	vault = null
	_vault_pending = false
	terrain.park_all()
	if _pressure > 0.0:
		ctx.events.pressure_changed.emit(0.0)
	_pressure = -1.0


func _host_destructibles(map) -> void:
	_release_destructibles()
	var rows := _destructible_rows(map)
	if rows.is_empty():
		return
	var pieces := Destructibles.new()
	pieces.name = "Destructibles"
	pieces.build({"destructible_rows": rows}, {"ctx": ctx, "root": ctx.root, "owned_ids": _contraption_ids(map),
		"no_visuals": not ParkTerrain.draw_regions})
	ctx.destructibles = pieces
	ctx.player.bind_destructibles(pieces, Callable(ctx.run, "heft_class"))


func _release_destructibles() -> void:
	if ctx == null or ctx.destructibles == null:
		return
	var pieces: Node = ctx.destructibles
	ctx.destructibles = null
	ctx.player.bind_destructibles(null)
	if is_instance_valid(pieces):
		pieces.teardown()
		pieces.queue_free()


static func _destructible_rows(map) -> Array:
	if "park" in map and (map.park as Dictionary).has("destructible_rows"):
		return map.park["destructible_rows"]
	if "destructible_rows" in map:
		return map.destructible_rows
	return []


static func _contraption_ids(map) -> Array:
	var ids: Array = []
	if "contraptions" in map:
		for spec in map.contraptions:
			ids.append(String(spec.get("id", "")))
	return ids


func _mark_landing(stage: int, retry: bool) -> void:
	launch.clear_landing()
	launch.gravity = ctx.tuning.f("gravity")
	var next: Vector3 = ctx.flow.arrival_heading_after(stage) if ctx.flow != null and ctx.flow.has_method("arrival_heading_after") else Vector3.ZERO
	launch.aim(next, ctx.camera)
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


func mark_arrival(entry: Vector3, velocity: Vector3, height: Callable) -> void:
	launch.clear_landing()
	launch.gravity = ctx.tuning.f("gravity")
	launch.mark_landing(entry, velocity, height)


func _physics_process(delta: float) -> void:
	if ctx == null or events == null or not ctx.flow.in_stage():
		return
	var player = ctx.player
	_deliver_waiting_picks()
	_deliver_class_picks()
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
	elif ride != null:
		_hold_ride(delta)
	var ball: Vector3 = player.ball_position()
	var velocity: Vector3 = player.state.velocity
	if is_instance_valid(ctx.destructibles):
		ctx.destructibles.on_ball(ball, velocity, ctx.run.heft_class(), delta)
	var riding: bool = ride != null or launch.flying()
	for fact in bay.step(delta, ball, velocity, riding):
		_bay_fact(fact)
	var calm_bay: bool = bay.inside
	if calm_bay != _bay_calm:
		_bay_calm = calm_bay
		if calm_bay:
			_pressure = 0.0
			ctx.events.pressure_changed.emit(0.0)
	if not calm_bay:
		events.set_clock_tier(director.effective_tier())
		_publish(events.advance(delta, ball, velocity, {
			"grounded": player.state.grounded, "ball_radius_m": player.Tuning.RADIUS,
		}.merged(ctx.root.presentation.audio.park_transport(events.stage_time + delta)
			if ctx.root.get("presentation") != null else {})))
	if contraptions.has(ctx.flow.stage()) and contraptions[ctx.flow.stage()].live:
		var steering: bool = player.intent.move.length() > 0.1 or player.intent.jump_pressed
		_on_cinder = false
		for fact in contraptions[ctx.flow.stage()].step(delta, ball, velocity, player.kit, ride != null or launch.flying(), steering):
			_contraption_fact(fact)
		_step_cinder(delta, ball)
	_show_ride()
	if bay.in_yard(ball):
		_free_cooldowns()
	_watch_ground(delta, ball)
	if not calm_bay and not riding:
		_watch_rogue(ball)
	_watch_layer(delta, ball)
	flood.render()
	if not ctx.calm and not calm_bay:
		player.add_external_accel(flood.external_accel(ball, velocity) + events.push(ball, velocity))
	if not calm_bay:
		_step_director(delta)
	_step_cut_governor(delta, ball, velocity, calm_bay)


var _cut_gov_air_refilled := false


func _step_cut_governor(delta: float, _ball: Vector3, velocity: Vector3, calm_bay: bool) -> void:
	if ctx == null or ctx.run == null or not ctx.run.has_method("override_on"):
		return
	if ctx.player == null or ctx.player.frozen() or calm_bay:
		return
	var cruise: float = ctx.tuning.f("cruise")
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if ctx.player.state.grounded:
		_cut_gov_air_refilled = false
	elif ctx.run.override_on("cruise_launch_air_reset") and not _cut_gov_air_refilled and flat_speed >= cruise:
		if ctx.player.state.air_actions < 1:
			ctx.player.state.air_actions = 1
			_cut_gov_air_refilled = true
	if ctx.run.override_on("stall_drains_hull") and ctx.player.state.grounded and flat_speed < cruise * 0.25:
		if ctx.flow == null or not ctx.flow.start_pick_open():
			ctx.run.damage(6.0 * delta, "cut_governor")


func _on_park_warden_engaged(_stage: int) -> void:
	_warden_phase_to(1)
	if events != null:
		events.notify_warden_phase("engaged")


func _on_park_warden_posture(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if enemy != ctx.flow.warden:
		return
	if events != null and staggered and not _park_warden_staggered:
		events.notify_warden_phase("stagger")
	_park_warden_staggered = staggered
	var phase_left: int = enemy.phase_chunks_left() if enemy.has_method("phase_chunks_left") else enemy.chunks_left()
	var left: int = mini(_park_warden_chunks, phase_left)
	for lost in range(4 - _park_warden_chunks + 1, 4 - left + 1):
		if lost <= 3 and events != null:
			events.notify_warden_phase("chunk_%d" % lost)
	_park_warden_chunks = left
	if left < BossPosture.CHUNKS:
		_warden_phase_to(BossPosture.CHUNKS - maxi(left, 1) + 1)


func _warden_phase_to(phase: int) -> void:
	while _warden_phase < mini(phase, BossPosture.CHUNKS):
		_warden_phase += 1
		assert(_warden_phase <= BossPosture.CHUNKS)
		ctx.events.fight_phase_changed.emit(WARDEN_FIGHT, _warden_phase, BossPosture.CHUNKS)


func _on_park_warden_broken(_stage: int) -> void:
	if events != null:
		events.notify_warden_phase("broken")


func _publish(facts: Array) -> void:
	var bus = ctx.events
	for fact in facts:
		match fact["kind"]:
			"announced":
				bus.event_announced.emit(fact["id"], fact["seconds"], _announced_at(fact))
			"started":
				bus.event_started.emit(fact["id"])
			"ended":
				bus.event_ended.emit(fact["id"], fact["outcome"])
			"milestone":
				ctx.run.record_milestone(fact["id"])
				var at: Vector2 = fact["at"]
				ctx.run.add_event_core(terrain.drop_point(at.x, at.y, 1.0))
			"scrap":
				ctx.run.add_scrap(fact["amount"], fact["at"])
				ctx.run.add_cogs(int(fact["amount"]))
			"progress":
				bus.event_progress.emit(fact["id"], fact["fraction"])
			"miniboss":
				_spawn_miniboss(fact["at"])
			"gate":
				var g: Vector2 = fact["at"]
				_discover(codex_world.note("gate", {"id": fact["id"], "at": terrain.drop_point(g.x, g.y, 1.0),
					"tier": ctx.player.speed_tier()}))
			"terrain_swap":
				_swap(fact["id"])
			"world":
				bus.world_fact.emit(fact["fact"], fact["at"])


func _announced_at(fact: Dictionary) -> Vector3:
	if not fact.has("at") or fact.get("family", "") == "weather":
		return Vector3.INF
	var at = fact["at"]
	if at is Vector2:
		return terrain.drop_point(at.x, at.y, 0.0)
	return at


func _spawn_miniboss(at: Vector2) -> void:
	var rect: Rect2 = terrain.map().play_rect
	var x := clampf(at.x, rect.position.x, rect.end.x)
	var z := clampf(at.y, rect.position.y, rect.end.y)
	last_miniboss_at = terrain.drop_point(x, z, 2.4)
	if ctx.calm or not ctx.can_spawn():
		return
	var enemy = ctx.spawner.spawn_enemy(MINIBOSS_KIND, last_miniboss_at)
	if enemy == null:
		ctx.spawner.spawn_enemy(MINIBOSS_FALLBACK, last_miniboss_at)


func _watch_rogue(ball: Vector3) -> void:
	if not RogueDirector.wakes(rogue_plan, ball):
		return
	var plan: Dictionary = rogue_plan
	rogue_plan = {}
	if ctx.calm or not ctx.can_spawn():
		return
	var rect: Rect2 = terrain.map().play_rect
	var x := clampf(float(plan.at.x), rect.position.x, rect.end.x)
	var z := clampf(float(plan.at.y), rect.position.y, rect.end.y)
	rogue = ctx.spawner.spawn_enemy(String(plan.kind), terrain.drop_point(x, z, ROGUE_CLEARANCE))
	if rogue != null and rogue.has_method("fit_site"):
		rogue.fit_site(float(plan.radius_m))


func _watch_ground(delta: float, ball: Vector3) -> void:
	codex_world.advance(delta)
	var grounded: bool = ctx.player.state.grounded
	if _was_grounded and not grounded:
		_discover(codex_world.note("airborne", {"at": ball, "off_kicker": terrain.map().near_kicker_lip(Vector2(ball.x, ball.z))}))
	elif grounded and flood.in_basin(ball) and flood.surface_y() > terrain.height(ball.x, ball.z):
		_discover(codex_world.note("grounded", {"at": ball, "over_water": true}))
	var map = terrain.map()
	if grounded and map.has_method("net_deck_height"):
		var on := "barge" if _on_barge else ("deck" if map.material_at(ball.x, ball.z) == "net" else "island")
		_discover(codex_world.note("footing", {"at": ball, "on": on}))
	_on_barge = false
	_was_grounded = grounded


func _step_cinder(delta: float, ball: Vector3) -> void:
	var heat := cinder_heat.step(delta, _on_cinder and not ctx.calm, ctx.run.hp)
	contraptions[ctx.flow.stage()].set_cinder_glow(float(heat["glow"]))
	if String(heat["fact"]) != "":
		ctx.events.world_fact.emit(String(heat["fact"]), ball)
		if heat["fact"] == CinderHeat.COOL_FACT:
			contraptions[ctx.flow.stage()].steam(ball)
	if float(heat["damage"]) > 0.0:
		ctx.run.damage(float(heat["damage"]), CinderHeat.SOURCE)


func _on_enemy_killed(_kind: String, at: Vector3, _scrap: int) -> void:
	if ctx.flow.in_stage():
		_discover(codex_world.note("kill", {"at": at, "in_water": flood.submersion(at) > 0.0}))


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if contraptions.has(ctx.flow.stage()):
		contraptions[ctx.flow.stage()].note_slam(at)
	if ctx.flow.in_stage():
		_discover(codex_world.note("slam", {"at": at}))
	if breach != null and ctx.flow.in_stage():
		var opened: Array[String] = breach.slam(at)
		for id in opened:
			_swap(id)
			_mark("breach_plate", at)
			ctx.events.world_fact.emit(Breach.FACT, at)
		if not opened.is_empty():
			_breach_strike(opened, at, strength)


func _breach_strike(opened: Array[String], at: Vector3, strength: float) -> void:
	const Augments := preload("res://src/movement/augments.gd")
	var enemies := get_tree().get_nodes_in_group(Groups.ENEMY).filter(func(e):
		return is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()) and e.global_position.y < at.y - 2.0)
	var force := Augments.SLAM_KNOCK * strength
	for i in breach.under(opened, enemies.map(func(e): return e.global_position)):
		var enemy: Node3D = enemies[i]
		var flat := Vector3(enemy.global_position.x - at.x, 0.0, enemy.global_position.z - at.z)
		ctx.spawner.deal_proc_hit(enemy, "slam", force, flat, force, "", "drop_or_slam", "slam")


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


func _discover(fired: Array) -> void:
	for entry in fired:
		discoveries.append(entry)
		ctx.codex.mark_discovered(entry["id"], entry["at"])


func _spawn_vault() -> void:
	if not ctx.stages.has_vault() or ctx.calm or not ctx.can_spawn():
		return
	var at: Vector3 = terrain.vault_point(ctx.flow.stage()) + Vector3.UP * 2.4
	var node = ctx.spawner.spawn_enemy(VAULT_KIND, at)
	if node is Node3D:
		vault = node
		view.set_vault(at, true, ctx.spawner.plating_of(node) if ctx.spawner.has_method("plating_of") else -1.0)


func _author_director(def := {}) -> void:
	director.author(def, ctx.stages)


func director_alive() -> int:
	return maxi(0, get_tree().get_nodes_in_group(Groups.ENEMY).size() - activities.standing())


func _dismiss_left_packs() -> void:
	var at: Vector3 = ctx.player.ball_position()
	var ball := Vector2(at.x, at.z)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not enemy is Node3D or not enemy.has_meta("pack_seq") or enemy.has_meta("elite_pack") or enemy.has_meta("yard_crew"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if Director.leaves(Vector2(enemy.global_position.x, enemy.global_position.z), ball):
			enemy.remove_from_group(Groups.ENEMY)
			enemy.remove_from_group(Groups.ENEMY_SHOT)
			enemy.queue_free()


func director_held() -> int:
	var at: Vector3 = ctx.player.ball_position()
	var ball := Vector2(at.x, at.z)
	var held := 0
	var total := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not enemy is Node3D or activities.keeps(enemy):
			continue
		total += 1
		var kind = enemy.get("kind")
		if Director.holds(String(kind) if kind != null else "", Vector2(enemy.global_position.x, enemy.global_position.z), ball):
			held += 1
	return Director.held_count(held, total)


func _step_director(delta: float) -> void:
	director.spike = ctx.flow.state_name() == "beacon" or events.spike()
	director.heft_class = ctx.run.heft_class()
	_build_clock += delta
	if _build_clock >= BUILD_REFRESH and ctx.spawner != null and ctx.spawner.has_method("build_read"):
		_build_clock = 0.0
		director.build = ctx.spawner.build_read()
	_dismiss_left_packs()
	var alive := director_held()
	var ball: Vector3 = ctx.player.ball_position()
	var v: Vector3 = ctx.player.state.velocity
	var forward: Vector3 = ctx.heading()
	var due: Array = director.advance(delta, alive, Vector2(ball.x, ball.z), Vector2(v.x, v.z), Vector2(forward.x, forward.z))
	for tier in director.take_threat_rises():
		ctx.events.threat_rose.emit(tier)
	view.show_arrivals(director.arrivals if not ctx.calm else [])
	for arrival in director.arrivals:
		if Director.KIND_NAMES[arrival["kind"]] == "dispatcher":
			terrain.prepare_perches()
			break
	var all_elite: bool = ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("all_packs_elite")
	var double_shift: bool = ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("half_guard_double_count")
	var hp_mult := 0.5 if double_shift else 1.0
	for spawn in due:
		if ctx.calm or ctx.spawner == null:
			continue
		var at: Vector2 = spawn["at"]
		var kind_name: String = Director.KIND_NAMES[spawn["kind"]]
		var affix := String(spawn.get("affix", ""))
		if all_elite and affix == "":
			affix = "plated"
		var copies := 2 if double_shift and kind_name != "dispatcher" else 1
		for copy_idx in copies:
			var offset := Vector2(2.6, 0.0) if copy_idx == 1 else Vector2.ZERO
			var enemy: Node3D
			if kind_name == "dispatcher":
				var perch: Vector3 = terrain.perch_near(Vector3(at.x, 0.0, at.y), ctx.flow.stage())
				enemy = ctx.spawner.spawn_enemy(kind_name, terrain.drop_point(at.x, at.y, 2.4), affix, perch, hp_mult)
			else:
				enemy = ctx.spawner.spawn_enemy(kind_name, terrain.drop_point(at.x + offset.x, at.y + offset.y, 2.4), affix, Vector3.INF, hp_mult)
			if enemy != null:
				enemy.set_meta("pack_seq", int(spawn.get("pack", -1)))
				locks.note_member(enemy, int(spawn.get("pack", -1)), spawn.get("rider", false))
			if (spawn.get("elite", false) or all_elite) and enemy != null:
				enemy.set_meta("elite_pack", true)
	var pressure: float = minf(1.0, director.pressure(alive) + events.pressure_bonus())
	if absf(pressure - _pressure) >= PRESSURE_STEP:
		_pressure = pressure
		ctx.events.pressure_changed.emit(pressure)


func _on_reward_chosen(_part_id: String) -> void:
	var player = ctx.player
	launch.gravity = ctx.tuning.f("gravity")
	var velocity := Launch.launch_velocity(player.state.velocity, ctx.tuning.f("cruise"), ctx.heading())
	var start := Launch.rail_start(player.state.velocity)
	if Vector2(start.x, start.z).length() < 0.5:
		start = velocity
	player.set_velocity_now(start)
	launch.fire(player.ball_position(), velocity, start)
	ctx.events.launched.emit(velocity)


func _hold_ride(delta: float) -> void:
	var v = ride.step(delta)
	if v != null:
		ctx.player.set_velocity_now(v)
		return
	ctx.player.set_velocity_now(ride.release_velocity())
	ride = null


func _show_ride() -> void:
	var presentation = ctx.root.get("presentation") if ctx.root != null else null
	if presentation != null and presentation.get("line_view") != null:
		presentation.line_view.set_ride(ride)


func _contraption_fact(fact: Dictionary) -> void:
	match fact["kind"]:
		"ride":
			ride = fact["ride"]
			ctx.player.set_velocity_now(ride.velocity_at(0.0))
		"fact":
			ctx.events.world_fact.emit(fact["fact"], fact["at"])
		"codex":
			_mark(fact["id"], fact["at"])
		"accel":
			if not ctx.calm:
				ctx.player.add_external_accel(fact["accel"])
			_discover(codex_world.note("thermal", {"at": ctx.player.ball_position()}))
		"drag":
			ctx.player.add_external_accel(fact["accel"])
			_on_cinder = FloorRule.on_floor(ctx.player.state)
		"carry":
			ctx.player.add_external_accel(fact["accel"])
			_on_barge = true


func _bay_fact(fact: Dictionary) -> void:
	var shop = _shop()
	match fact["kind"]:
		"entered":
			if shop != null:
				bay_bark = shop.enter()
			ctx.events.bay_entered.emit(fact["banked"])
			_open_pick(ctx.flow.stage())
		"left":
			if shop != null:
				bay_bark = shop.leave()
			ctx.events.bay_left.emit(fact["velocity"])
		"ride":
			ride = fact["ride"]
			ctx.player.set_velocity_now(ride.velocity_at(0.0))
		"fact":
			ctx.events.world_fact.emit(fact["fact"], fact["at"])
		"codex":
			_mark(fact["id"], fact["at"])


func _shop():
	var b = ctx.build_module() if ctx.has_method("build_module") else ctx.get("build")
	if b == null or not "shop" in b:
		return null
	return b.shop


func _free_cooldowns() -> void:
	var abilities = ctx.player.abilities
	for name in AbilityState.SLOTS:
		var s = abilities.slot(name)
		if s.charges < s.max_charges:
			abilities.grant(name, s.max_charges)


func _swap(id: String) -> void:
	var m = terrain.map()
	var began := Time.get_ticks_usec()
	m.apply_swap(id, true)
	terrain.overlays.erase(id + "_before")
	if not terrain.overlays.has(id + "_after"):
		terrain.overlays.append(id + "_after")
	swap_log.append({"id": id, "usec": Time.get_ticks_usec() - began, "stage_time": events.stage_time})


func _mark(id: String, at: Vector3) -> void:
	discoveries.append({"id": id, "at": at})
	ctx.codex.mark_discovered(id, at)


func _watch_layer(delta: float, ball: Vector3) -> void:
	var m = terrain.map()
	if not m.has_method("layer_at"):
		return
	_chute_clock = maxf(0.0, _chute_clock - delta)
	_skylight_clock = maxf(0.0, _skylight_clock - delta)
	_glide_clock = maxf(0.0, _glide_clock - delta)
	if "marble_path" in m and m.in_marble_chute(ball.x, ball.z):
		_chute_clock = 3.0
	if absf(ball.x - m.SKYLIGHT_X) < m.SKYLIGHT_DEPTH and ball.z > m.SKYLIGHT_Z.x and ball.z < m.SKYLIGHT_Z.y:
		_skylight_clock = 3.0
	if ctx.player.kit.gliding:
		_glide_clock = 4.0
	var grounded: bool = ctx.player.state.grounded
	if ride != null or launch.flying():
		_air_clock = 0.0
		_glide_clock = 0.0
		return
	_air_clock = 0.0 if grounded else _air_clock + delta
	if not grounded:
		if _air_clock > 1.0:
			_glide_clock = maxf(_glide_clock, 2.0)
		return
	var now: String = m.layer_at(ball)
	if now == layer:
		return
	var was := layer
	layer = now
	if was == "" or bay.inside:
		return
	ctx.events.world_fact.emit("layer_" + now, ball)
	var via := ""
	if _chute_clock > 0.0:
		via = "chute"
	elif _skylight_clock > 0.0:
		via = "skylight"
	elif _glide_clock > 0.0:
		via = "glide_drop"
	if via != "":
		ctx.events.world_fact.emit("ride_" + via, ball)


func _on_reward_offered(offers: Array) -> void:
	if ctx.flow.in_stage() and ctx.flow.state_name() == "gates" and ShiftVariants.dam_shop_open(ctx.get("run")):
		bay.dock(offers, Callable(terrain, "height"), ctx.root.get_world_3d().direct_space_state if ctx.root.is_inside_tree() else null, terrain.map())


func _on_flow_changed(state: String) -> void:
	if state != "gates" and not bay.inside:
		bay.undock()


func _open_pick(stage: int) -> void:
	var tree = ctx.player.tree if "tree" in ctx.player else null
	if tree == null:
		return
	tree.max_depth = UpgradeTree.depth_cap(ctx.stages.world_of(ctx.run.stage)) if ctx.tuning.world_one() else UpgradeTree.DEPTHS
	tree.world_one = ctx.tuning.world_one() and ctx.stages.world_of(ctx.run.stage) == 1
	if _picks_opened.has(stage) or (ctx.run.pick_opened and stage == ctx.run.stage):
		return
	if ctx.tuning.world_one():
		if not _first_of_world(stage):
			return
	elif stage >= tree.max_depth:
		return
	_picks_opened[stage] = true
	if ctx.tuning.world_one() and not _pick_calm():
		_picks_waiting.append(stage)
		return
	tree.open_checkpoint()
	ctx.run.pick_opened = ctx.run.pick_opened or stage == ctx.run.stage


func _first_of_world(stage: int) -> bool:
	return stage <= 1 or ctx.stages.world_of(stage - 1) != ctx.stages.world_of(stage)


func _on_class_rise(heft_class: int, _heft: float) -> void:
	if not ctx.stages.PICK_ON_CLASS_UP or heft_class <= ctx.run.class_rewarded:
		return
	_class_picks_owed += heft_class - ctx.run.class_rewarded
	ctx.run.class_rewarded = heft_class
	_deliver_class_picks()


func _deliver_class_picks() -> void:
	if _class_picks_owed <= 0 or not _pick_calm() or (ctx.flow != null and ctx.flow.warden_fight_live()):
		return
	var tree = ctx.player.tree if "tree" in ctx.player else null
	if tree == null:
		return
	tree.max_depth = UpgradeTree.depth_cap(ctx.stages.world_of(ctx.run.stage)) if ctx.tuning.world_one() else UpgradeTree.DEPTHS
	tree.world_one = ctx.tuning.world_one() and ctx.stages.world_of(ctx.run.stage) == 1
	var owed := _class_picks_owed
	_class_picks_owed = 0
	for _i in owed:
		tree.open_checkpoint()


func _pick_calm() -> bool:
	return ctx.player.state.grounded or bay.inside


func _deliver_waiting_picks() -> void:
	if _picks_waiting.is_empty() or not _pick_calm():
		return
	var tree = ctx.player.tree
	for stage in _picks_waiting:
		tree.open_checkpoint()
		ctx.run.pick_opened = ctx.run.pick_opened or stage == ctx.run.stage
	_picks_waiting.clear()
