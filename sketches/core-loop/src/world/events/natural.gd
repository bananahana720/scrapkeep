extends Node3D

const EventGround := preload("res://src/world/events/event_ground.gd")
const WaterSurface := EventGround.Surface
const OverlayMap := EventGround.OverlayMap

const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const StormSeek := preload("res://src/world/events/storm_seek.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const FOAM_SET := "spill_flood"
const FOAM_PARKS := ["park_dam", "park_flume"]
const FOAM_PIECE_M := 30.0
const FOAM_PIECES := 4
const FOAM_DRY_M := 0.05

const KINDS := {
	"flood_fill": {}, "drain": {}, "cave_in": {}, "collapse": {}, "flash_flood": {},
	"impact": {"lift_mps": 8.0}, "lightning": {"lift_mps": 8.0},
}
const ENEMY_STRIKE_DAMAGE := 40.0
const ENEMY_TOSS := 14.0
const FLOOD_DEEP_M := 0.4
const FLOOD_SWEEP_S := 1.0
const FLOOD_ENEMY_DAMAGE := 8.0
const FLOOD_TOSS := 10.0
const FLOOD_TAX := 2
const FLOOD_TAX_AFTER_S := 3.0
const FLOOD_TAX_EVERY_S := 2.0
const BALL_RADIUS_M := 1.2
const FLOOD_KINDS := ["flood_fill", "flash_flood"]

var world
var active := {}
var _sites := {}
var _prepared := {}
var _original_map
var _overlay_map
var _water_field := WaterField.new()
var _original_flood
var _next_checked := false
var hits_enemies := false
var seek := StormSeek.new()
static var _plans := {}
static var _marks_job := {}


class WaterView:
	extends Node3D
	var site := {}
	var geometry := {}
	var surface: WaterSurface
	var query_xz := Vector2.ZERO
	var depth_m := 0.0
	var _plane: MeshInstance3D
	func setup(projected: WaterSurface) -> void:
		surface = projected
		_plane = MeshInstance3D.new()
		_plane.mesh = projected.mesh
		_plane.material_override = PaletteMaterials.water(Palette.water_tone())
		add_child(_plane)
	func in_basin(point: Vector3) -> bool:
		query_xz = Vector2(point.x, point.z)
		return visible and ParkMap.footprint_contains(geometry.site, query_xz, 0.0, Vector2.INF, geometry.half)
	func surface_y() -> float:
		return surface.height(query_xz) + depth_m
	func render() -> void:
		_plane.position = Vector3.UP * depth_m


class WaterField:
	extends RefCounted
	var surfaces: Array = []
	var _surface_y := -INF
	func refresh() -> void:
		var top := {}
		for water in surfaces:
			water.visible = false
			top[water.site.id] = water
		for water in top.values():
			water.visible = true
			water.render()
	func in_basin(point: Vector3) -> bool:
		_surface_y = -INF
		for water in surfaces:
			if water.in_basin(point):
				_surface_y = maxf(_surface_y, water.surface_y())
		return _surface_y > -INF
	func surface_y() -> float:
		return _surface_y


func setup(world_ref) -> void:
	world = world_ref
	name = "NaturalEvents"
	add_to_group("world_telegraphs")
	_original_map = world.terrain.map()
	_original_flood = world.terrain.flood
	for site in _original_map.park.park_rows:
		_sites[site.id] = site
	var planned := _planned()
	for row in _original_map.park.event_rows:
		if row.family != "natural" or not KINDS.has(row.kind):
			continue
		var entry: Dictionary = planned[row.id]
		var record := {"site": entry.site, "at": entry.at, "geometry": entry.geometry.duplicate(), "overlay": null, "marks": entry.get("marks", {})}
		if entry.has("water"):
			record.water_surface = entry.water
		if row.kind == "cave_in" or row.kind in Kinds.HIDING_NATURAL_KINDS:
			_prepare_overlay(row, record, entry)
		_prepared[row.id] = record
	_plan_marks(planned)
	hits_enemies = HazardHits.applies_to(world.ctx.get("run"))
	world.terrain.flood = _water_field


static func plan(world, park: Dictionary) -> Dictionary:
	var terrain = world.terrain
	var sites := {}
	for site in park.park_rows:
		sites[site.id] = site
	var out := {}
	for row in park.event_rows:
		if row.family != "natural" or not KINDS.has(row.kind):
			continue
		var site: Dictionary = NaturalFootprint.resolve(row, sites[row.site])
		var at := _at(terrain, site)
		var geometry := {"site": site, "at": at, "half": ParkMap.footprint_half_extents(site),
			"yaw": deg_to_rad(float(site.yaw_deg)), "strike_m": maxf(0.0, float(row.effect.get("strike_m", 0.0)))}
		if row.kind == "lightning":
			geometry.half = Vector2.ONE * geometry.strike_m
			geometry.yaw = 0.0
		var entry := {"site": site, "at": at, "geometry": geometry}
		if row.kind in ["flood_fill", "drain", "flash_flood"]:
			entry.water = EventGround.project_surface(world, geometry, [EventGround.rectangle(-geometry.half, geometry.half)], Callable(), true, null, null, null, true)
		if row.kind == "collapse":
			geometry.crack_foot_x = _bench_face_foot(terrain, geometry)
		if row.kind in ["collapse", "impact"] and not EventGround.kind_of_span(row):
			entry.surface = EventGround.overlay_surface(world, row.kind, geometry, true)
			if row.kind == "collapse":
				entry.target = _collapse_surface(world, row, geometry, entry.surface, true)
		elif EventGround.kind_of_span(row):
			var span_site := EventGround.span_site(park, site)
			entry.span = EventGround.span_surface(span_site, 0.0, true)
			entry.target = EventGround.span_surface(span_site, maxf(0.0, float(row.effect.depth_m)), true)
		out[row.id] = entry
	return out


static func plan_marks(world, park: Dictionary, planned: Dictionary) -> Dictionary:
	var out := {}
	for row in park.event_rows:
		if not planned.has(row.id):
			continue
		var geometry: Dictionary = planned[row.id].geometry
		out[row.id] = {"telegraph": _mark_surfaces(world, row, geometry, false, null, true)}
		if row.kind == "collapse" and planned[row.id].has("target"):
			var landed := geometry.duplicate()
			landed.marker_surface = planned[row.id].target
			out[row.id].land = _mark_surfaces(world, row, landed, true, null, true)
		elif row.kind == "impact" and planned[row.id].has("landed") and world is EventGround.Snapshot:
			var profile: Dictionary = planned[row.id].landed
			var landed := geometry.duplicate()
			landed.marker_surface = profile.surface
			out[row.id].land = _mark_surfaces(world.with_profile(profile), row, landed, true, null, true)
		elif row.kind != "impact" and row.kind != "collapse":
			out[row.id].land = _mark_surfaces(world, row, geometry, true, null, true)
	return out


static func _finish(planned: Dictionary) -> void:
	for entry in planned.values():
		for key in ["water", "surface", "target", "span"]:
			if entry.has(key):
				entry[key].finish()
		_finish_marks(entry.get("marks", {}))


static func _finish_marks(marks: Dictionary) -> void:
	for surfaces: Dictionary in marks.values():
		for surface in surfaces.values():
			surface.finish()


func _planned() -> Dictionary:
	var terrain = world.terrain
	var key := _root_key(terrain, terrain.stage)
	var rows := _rows_hash(_original_map.park)
	if key != 0:
		_settle(key)
		if _plans.has(key) and _plans[key].rows == rows and EventGround.pristine(terrain, terrain.stage):
			return _plans[key].plan
	var planned := plan(world, _original_map.park)
	_finish(planned)
	if key != 0 and EventGround.pristine(terrain, terrain.stage):
		_plans[key] = {"plan": planned, "rows": rows}
	return planned


func _plan_marks(planned: Dictionary) -> void:
	var terrain = world.terrain
	var key := _root_key(terrain, terrain.stage)
	if key == 0 or not _plans.has(key) or not EventGround.pristine(terrain, terrain.stage):
		return
	if planned.values().any(func(entry): return entry.has("marks")) or _marks_job.get("key", 0) == key:
		return
	_settle_marks()
	var snapshot: EventGround.Snapshot = _plans[key].get("snapshot")
	_plans[key].erase("snapshot")
	if snapshot == null:
		snapshot = EventGround.snapshot(world.terrain, world.terrain.stage)
	var park: Dictionary = _original_map.park.duplicate(true)
	var geometry := {}
	for id in _prepared:
		geometry[id] = {"geometry": _prepared[id].geometry.duplicate(true)}
		var record: Dictionary = _prepared[id]
		if record.get("overlay_map") != null and record.overlay_map.swaps[record.swap].get("target") != null:
			geometry[id].target = record.overlay_map.swaps[record.swap].target
		if record.get("overlay_map") != null and record.overlay_map.profiles.has(record.swap + "_after") and not record.overlay_map.swaps[record.swap].get("cave", false):
			geometry[id].landed = record.overlay_map.profiles[record.swap + "_after"]
	var out := {}
	_marks_job = {"key": key, "out": out, "task": WorkerThreadPool.add_task(func(): out.merge(plan_marks(snapshot, park, geometry)), false, "natural marks")}


func _take_marks() -> void:
	if _marks_job.is_empty() or not WorkerThreadPool.is_task_completed(_marks_job.task):
		return
	var key: int = _marks_job.key
	var marks := _settle_marks()
	if world == null or key != _root_key(world.terrain, world.terrain.stage):
		return
	for id in marks:
		if _prepared.has(id) and _prepared[id].marks.is_empty():
			_prepared[id].marks = marks[id]


static func _settle_marks() -> Dictionary:
	if _marks_job.is_empty():
		return {}
	WorkerThreadPool.wait_for_task_completion(_marks_job.task)
	var marks: Dictionary = _marks_job.out
	_finish_marks_by_row(marks)
	var cached: Dictionary = _plans.get(_marks_job.key, {}).get("plan", {})
	for id in marks:
		if cached.has(id):
			cached[id].marks = marks[id]
	_marks_job = {}
	return marks


static func _finish_marks_by_row(marks: Dictionary) -> void:
	for row_marks: Dictionary in marks.values():
		_finish_marks(row_marks)


static func _rows_hash(park: Dictionary) -> int:
	return hash([park.park_rows, park.event_rows])


static func _root_key(terrain, index: int) -> int:
	return terrain.stage_root_key(index) if terrain.has_method("stage_root_key") else 0


static func _settle(key: int) -> void:
	if not _plans.has(key) or not _plans[key].has("task"):
		return
	WorkerThreadPool.wait_for_task_completion(_plans[key].task)
	var planned: Dictionary = _plans[key].out
	_finish(planned)
	_plans[key] = {"plan": planned, "rows": _plans[key].rows, "worker": true, "snapshot": _plans[key].get("snapshot")}


func _prepare_next() -> void:
	if _next_checked or world == null:
		return
	var terrain = world.terrain
	if not terrain.has_method("stage_root_key") or terrain.stage >= terrain.maps.size() or not terrain.is_ready(terrain.stage + 1):
		return
	_next_checked = true
	var next: int = terrain.stage + 1
	var key := _root_key(terrain, next)
	var map = terrain.map_for(next)
	if key == 0 or _plans.has(key) or not "park" in map or map.park.is_empty():
		return
	for old in _plans.keys():
		if not is_instance_id_valid(old) and (not _plans[old].has("task") or WorkerThreadPool.is_task_completed(_plans[old].task)):
			_settle(old)
			_plans.erase(old)
	var snapshot := EventGround.snapshot(terrain, next, false)
	var park: Dictionary = map.park.duplicate(true)
	var out := {}
	var work := func() -> void:
		snapshot.copy_roofs()
		out.merge(plan(snapshot, park))
	_plans[key] = {"task": WorkerThreadPool.add_task(work, false, "natural plan"), "out": out, "rows": _rows_hash(map.park), "snapshot": snapshot}


static func prewarm(terrain, next_stage: int) -> Dictionary:
	var key := _root_key(terrain, next_stage)
	var map = terrain.map_for(next_stage) if terrain.has_method("map_for") else null
	if key == 0 or map == null or not ("park" in map) or map.park.is_empty():
		return {"key": key, "status": "non_park"}
	if _plans.has(key):
		var entry: Dictionary = _plans[key]
		if entry.has("task") and WorkerThreadPool.is_task_completed(entry.task):
			_settle(key)
		return {"key": key, "status": "ready" if not _plans[key].has("task") else "worker_running"}
	for old in _plans.keys():
		if not is_instance_id_valid(old) and (not _plans[old].has("task") or WorkerThreadPool.is_task_completed(_plans[old].task)):
			_settle(old)
			_plans.erase(old)
	var snapshot := EventGround.snapshot(terrain, next_stage, false)
	var park: Dictionary = map.park.duplicate(true)
	var out := {}
	var work := func() -> void:
		snapshot.copy_roofs()
		out.merge(plan(snapshot, park))
	_plans[key] = {
		"task": WorkerThreadPool.add_task(work, false, "natural prewarm"),
		"out": out,
		"rows": _rows_hash(map.park),
		"snapshot": snapshot,
	}
	return {"key": key, "status": "worker_started"}


static func settle_plans() -> void:
	for key in _plans.keys():
		_settle(key)
	_settle_marks()


static func release_plans() -> void:
	settle_plans()
	_plans.clear()


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if not KINDS.has(row.kind):
		return
	match action:
		"telegraph":
			var state: Dictionary = _prepared[row.id].duplicate()
			state.merge({"phase": "telegraph", "hit": false, "elapsed_s": 0.0, "depth_m": 0.0,
				"struck": {}, "sweep_s": 0.0, "wet_slow_s": 0.0, "taxes": 0, "water": null, "kind": row.kind, "mark": _mark(row, state.geometry), "announced_s": ctx.clock_s}, true)
			active[row.id] = state
		"land":
			var state: Dictionary = active[row.id]
			state.phase = "land"
			if row.kind in ["flood_fill", "drain", "flash_flood"]:
				_land_water(row, state)
			if state.overlay != null:
				_set_overlay(row, true)
				if row.kind in ["collapse", "cave_in"] and float(row.effect.fill_s) <= 0.0:
					_advance_collapse(row, 1.0)
			_show_landing(row, state)
			_hazard(row, state, ctx)
		"step":
			var state: Dictionary = active[row.id]
			state.phase = "live"
			state.elapsed_s += float(ctx.delta_s)
			if state.water != null:
				var fill_s := maxf(0.0, float(row.effect.get("fill_s", 0.0)))
				var elapsed: float = state.elapsed_s if row.kind == "drain" else float(ctx.rise_s) + float(ctx.delta_s)
				var fraction := clampf(elapsed / fill_s, 0.0, 1.0) if fill_s > 0.0 else 1.0
				var depth := minf(ParkSchema.MAX_EVENT_WATER_M, maxf(0.0, float(row.effect.get("depth_m", 0.0))))
				state.depth_m = lerpf(float(state.start_depth_m), 0.0 if row.kind == "drain" else depth, fraction)
				state.water.depth_m = state.depth_m
				state.water.render()
				_ride_foam(state, 1.0 - fraction if row.kind != "drain" else 0.0)
			if row.kind in ["collapse", "cave_in"]:
				var fill_s := maxf(0.0, float(row.effect.fill_s))
				_advance_collapse(row, clampf(state.elapsed_s / fill_s, 0.0, 1.0) if fill_s > 0.0 else 1.0)
			_hazard(row, state, ctx)
		"end":
			_end(row)


func _physics_process(delta: float) -> void:
	if world == null or not hits_enemies:
		return
	var player = world.ctx.player
	if player == null or not player.has_method("ball_position") or not player.has_method("planar_velocity"):
		return
	var ball: Vector3 = player.ball_position()
	if _seek_exempt(ball):
		seek.stand_down()
		return
	seek.observe(delta, ball, player.planar_velocity(), _cruise())


func _seek_exempt(ball: Vector3) -> bool:
	var flow = world.ctx.get("flow")
	if flow != null and SiltBoil.exempt(flow, ball):
		return true
	var bay = world.get("bay")
	return bay != null and bay.inside


func _cruise() -> float:
	var tuning = world.ctx.player.get("tuning")
	return float(tuning.f("cruise")) if tuning != null else 0.0


func _process(_delta: float) -> void:
	_take_marks()
	_prepare_next()
	for key in _plans:
		if _plans[key].has("task") and WorkerThreadPool.is_task_completed(_plans[key].task):
			_settle(key)
	for state in active.values():
		if state.phase != "telegraph" or not state.mark.has_node("DustCurtain"):
			continue
		var row: Dictionary = _original_map.park.event_rows.filter(func(r): return r.id == state.mark.get_meta("row_id"))[0]
		var progress := clampf((world.events.stage_time - float(state.announced_s)) / float(row.telegraph.lead_s), 0.001, 1.0)
		if int(progress * 30.0) == int(float(state.get("warning_progress", -1.0)) * 30.0):
			continue
		state.warning_progress = progress
		var spec: Dictionary = Kinds.world_row(row.telegraph.form)
		var half: Vector2 = state.geometry.half
		var dust = state.mark.get_node("DustCurtain")
		dust.mesh = _project_surface(state.geometry,
			[EventGround.rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), half)],
			func(local, _base): return float(spec.dust_height_m) * progress * clampf((local.x - half.x + float(spec.crack_width_m)) / float(spec.crack_width_m), 0.0, 1.0)).mesh
		var foot: float = state.geometry.crack_foot_x
		var crack = state.mark.get_node("CrawlingCrack")
		crack.mesh = _project_surface(state.geometry,
			[EventGround.rectangle(Vector2(foot - float(spec.crack_width_m), -half.y), Vector2(foot, lerpf(-half.y, half.y, progress)))]).mesh


static func _bench_face_foot(terrain, geometry: Dictionary) -> float:
	var half: Vector2 = geometry.half
	var centre := Vector2(geometry.at.x, geometry.at.z)
	var count := ceili(2.0 * half.x / (ParkTerrain.STEP * 0.5))
	var foot := -half.x
	var steepest := -INF
	var previous := -half.x
	var point := Vector2(previous, 0.0).rotated(-float(geometry.yaw)) + centre
	var previous_y: float = terrain.height(point.x, point.y)
	for i in range(1, count + 1):
		var x := lerpf(-half.x, half.x, float(i) / count)
		point = Vector2(x, 0.0).rotated(-float(geometry.yaw)) + centre
		var y: float = terrain.height(point.x, point.y)
		var slope := (y - previous_y) / (x - previous)
		if slope > steepest:
			steepest = slope
			foot = previous
		previous = x
		previous_y = y
	return foot


static func _at(terrain, site: Dictionary) -> Vector3:
	var x := float(site.at[0])
	var z := float(site.at[1])
	return Vector3(x, float(site.y) if site.y != null else terrain.height(x, z), z)


func _land_water(row: Dictionary, state: Dictionary) -> void:
	var water := WaterView.new()
	add_child(water)
	water.setup(state.water_surface)
	water.site = state.site
	water.geometry = state.geometry
	var depth := minf(ParkSchema.MAX_EVENT_WATER_M, maxf(0.0, float(row.effect.get("depth_m", 0.0))))
	state.start_depth_m = depth if row.kind == "drain" else 0.0
	for existing in _water_field.surfaces:
		if existing.site.id == state.site.id and existing.visible:
			state.start_depth_m = existing.depth_m
	state.depth_m = state.start_depth_m
	water.depth_m = state.depth_m
	water.query_xz = Vector2(state.at.x, state.at.z)
	water.render()
	state.water = water
	if FOAM_PARKS.has(String(_original_map.park.get("map", ""))):
		state.foam = _foam(water, state.geometry)
	_water_field.surfaces.append(water)
	_water_field.refresh()


func _foam(water: Node3D, geometry: Dictionary) -> Array:
	var half: Vector2 = geometry.half
	var long_x := half.x >= half.y
	var long_half := half.x if long_x else half.y
	var pieces := clampi(ceili(2.0 * long_half / FOAM_PIECE_M), 1, FOAM_PIECES)
	var turn := Basis(Vector3.UP, float(geometry.yaw))
	var centre := Vector2(geometry.at.x, geometry.at.z)
	var out := []
	for k in pieces:
		var u := lerpf(-long_half, long_half, (k + 0.5) / pieces)
		var local := Vector3(u, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, u)
		var at := turn * local
		var a := WorldFxAnchor.make(FOAM_SET)
		a.name = "Foam%d" % k
		water.add_child(a)
		a.transform = Transform3D(turn, Vector3(centre.x + at.x, 0.0, centre.y + at.z))
		var piece := long_half / pieces * 0.9
		a.fit(Vector2(piece, half.y * 0.85) if long_x else Vector2(half.x * 0.85, piece))
		out.append(a)
	_ride_foam({"water": water, "foam": out}, 1.0)
	return out


static func _ride_foam(state: Dictionary, churn: float) -> void:
	var water = state.water
	for a: Node3D in state.get("foam", []):
		var xz := Vector2(a.position.x, a.position.z)
		var floor_y: float = water.surface.height(xz)
		a.visible = floor_y > -INF and float(water.depth_m) > FOAM_DRY_M
		if a.visible:
			a.position.y = floor_y + water.depth_m + 0.05
		a.set_level(lerpf(0.35, 1.0, clampf(churn, 0.0, 1.0)))


func _project_surface(geometry: Dictionary, shapes: Array, offset := Callable(), water := false, baseline: WaterSurface = null) -> WaterSurface:
	return EventGround.project_surface(world, geometry, shapes, offset, water, baseline, _overlay_map, ArrayMesh.new())


func _prepare_overlay(row: Dictionary, record: Dictionary, entry: Dictionary) -> void:
	_overlay_map = EventGround.prepare_overlay(world, self, row, record, Callable(self, "_collapse_target"), entry)


func _collapse_target(row: Dictionary, geometry: Dictionary, baseline: WaterSurface) -> WaterSurface:
	return _collapse_surface(world, row, geometry, baseline)


static func _collapse_surface(world, row: Dictionary, geometry: Dictionary, baseline: WaterSurface, deferred := false) -> WaterSurface:
	var half: Vector2 = geometry.half
	var centre := Vector2(geometry.at.x, geometry.at.z)
	var yaw: float = geometry.yaw
	var depth_m := maxf(0.0, float(row.effect.depth_m))
	if geometry.get("span", false):
		return EventGround.span_surface(geometry.site, depth_m)
	var offset := func(local: Vector2, base: float) -> float:
		var top := Vector2(half.x, local.y).rotated(-yaw) + centre
		var upper: float = baseline.height(top)
		var ramp := upper - depth_m * (half.x - local.x) / (2.0 * half.x)
		return maxf(0.0, ramp - base)
	return EventGround.project_surface(world, geometry, [EventGround.rectangle(-half, half)], offset, false, baseline, null, null, deferred)


func _advance_collapse(row: Dictionary, progress: float) -> void:
	var id: String = _prepared[row.id].swap
	var entry: Dictionary = _overlay_map.swaps[id]
	if progress <= float(entry.progress):
		return
	entry.progress = progress
	if row.kind == "cave_in":
		var drop_m := float(row.effect.depth_m) * progress
		EventGround.lower_roof(entry.roof, drop_m)
		active[row.id].mark.position.y = 0.15 - drop_m
		return
	var geometry: Dictionary = entry.geometry.duplicate()
	geometry.source_surface = entry.baseline
	geometry.target_surface = entry.target
	geometry.progress = progress
	_install_surface(id, _project_surface(geometry, []))


func _install_surface(id: String, surface: WaterSurface) -> void:
	EventGround.install_surface(_overlay_map, id, surface)


func _set_overlay(row: Dictionary, changed: bool) -> void:
	EventGround.set_overlay(world, row, _prepared[row.id], changed)


func _hazard(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	if row.kind in FLOOD_KINDS:
		_flood(row, state, ctx)
		return
	if row.kind not in ["impact", "lightning"]:
		return
	if hits_enemies:
		HazardHits.strike(get_tree(), func(point: Vector3) -> bool: return _in_strike(state, point), row.kind,
			ENEMY_STRIKE_DAMAGE, ENEMY_TOSS, state.struck)
		if row.kind == "lightning" and state.phase == "live" and not _seek_exempt(ctx.ball):
			_seek(row, state, ctx)
	if state.hit or not _in_strike(state, ctx.ball):
		return
	state.hit = true
	_strike_ball(row, ctx.ball)


static func _in_strike(state: Dictionary, point: Vector3) -> bool:
	var radius: float = state.geometry.strike_m
	var at: Vector3 = state.geometry.at
	return Vector2(point.x - at.x, point.z - at.z).length() <= radius and absf(point.y - at.y) <= radius


func _strike_ball(row: Dictionary, ball: Vector3) -> void:
	var amount := maxi(0, ceili(float(row.effect.get("damage", 0.0))))
	var taken: int = world.ctx.run.lose_scrap(amount, ball, row.kind)
	if taken < amount or amount == 0:
		var velocity: Vector3 = world.ctx.player.state.velocity
		velocity.y = maxf(velocity.y, float(KINDS[row.kind].lift_mps))
		world.ctx.player.set_velocity_now(velocity, "natural_event")


func _seek(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	var told := seek.tells
	var ball: Vector3 = ctx.ball
	var terrain = world.terrain
	seek.step(float(ctx.delta_s), self, func(point: Vector3) -> float: return terrain.height(point.x, point.z), ball,
		float(state.geometry.strike_m), float(row.live_s) - float(state.elapsed_s), func(hazard) -> void:
			_publish("lightning_mark_landed", hazard.centre)
			if hazard.contains(ball):
				_strike_ball(row, ball)
			HazardHits.strike(get_tree(), hazard.contains, row.kind, ENEMY_STRIKE_DAMAGE, ENEMY_TOSS, {}))
	if seek.tells > told:
		_publish("lightning_mark", seek.pending().centre)


func telegraphs(ball: Vector3) -> Array:
	var out: Array = []
	for id in active:
		var state: Dictionary = active[id]
		var kind := String(state.get("kind", ""))
		if kind in ["impact", "lightning"]:
			out.append({"id": ("natural:%s:%s" % [id, state.announced_s]).hash(), "cause": kind, "covers": _in_strike(state, ball)})
		elif kind in FLOOD_KINDS and state.water != null:
			out.append({"id": ("natural:%s:%s" % [id, state.announced_s]).hash(), "cause": "flood", "covers": state.water.in_basin(ball)})
	var ring = seek.pending()
	if ring != null and is_instance_valid(ring):
		out.append({"id": ring.get_instance_id(), "cause": "lightning", "covers": ring.contains(ball)})
	return out


func _publish(kind: String, at: Vector3) -> void:
	if world.ctx.events != null:
		world.ctx.events.world_fact.emit(kind, at)


func _flood(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	var water = state.water
	if not hits_enemies or water == null:
		return
	var delta := float(ctx.get("delta_s", 0.0))
	var deep := func(point: Vector3) -> bool: return water.in_basin(point) and water.surface_y() - point.y >= FLOOD_DEEP_M
	state.sweep_s = float(state.sweep_s) - delta
	if state.sweep_s <= 0.0:
		state.sweep_s = FLOOD_SWEEP_S
		var at: Vector3 = state.at
		HazardHits.strike(get_tree(), deep, row.kind, FLOOD_ENEMY_DAMAGE, FLOOD_TOSS, {},
			func(point: Vector3) -> Vector3: return Vector3(point.x - at.x, 0.5, point.z - at.z))
	var ball: Vector3 = ctx.ball
	var velocity: Vector3 = ctx.get("velocity", Vector3.ZERO)
	var slow := SpeedTier.of(Vector2(velocity.x, velocity.z).length(), _cruise()) < SpeedTier.CRUISE
	if not slow or not deep.call(ball - Vector3.UP * float(ctx.get("ball_radius_m", BALL_RADIUS_M))):
		state.wet_slow_s = 0.0
		state.taxes = 0
		return
	state.wet_slow_s = float(state.wet_slow_s) + delta
	if state.wet_slow_s >= FLOOD_TAX_AFTER_S + FLOOD_TAX_EVERY_S * int(state.taxes):
		state.taxes = int(state.taxes) + 1
		world.ctx.run.lose_scrap(FLOOD_TAX, ball, "flood")


func _mark(row: Dictionary, geometry: Dictionary, landed := false) -> Node3D:
	var surfaces: Dictionary = _prepared[row.id].marks.get("land" if landed else "telegraph", {}) if _prepared.has(row.id) else {}
	var own: String = _prepared[row.id].get("swap", "") + "_after" if landed and row.kind in ["collapse", "impact"] and _prepared.has(row.id) else ""
	if surfaces.is_empty() or not _ground_as_planned(surfaces, own):
		if landed and row.kind == "collapse":
			geometry = geometry.duplicate()
			geometry.marker_surface = _overlay_map.swaps[_prepared[row.id].swap].target
		surfaces = _mark_surfaces(world, row, geometry, landed, _overlay_map)
	var mark := Node3D.new()
	mark.set_meta("row_id", row.id)
	add_child(mark)
	mark.position = Vector3.UP * 0.15
	var spec: Dictionary = Kinds.world_row(EventDirector.PARK_LAND_FACTS[row.telegraph.form] if landed else row.telegraph.form)
	var mesh := MeshInstance3D.new()
	mesh.name = "DustCurtain" if surfaces.has("CrawlingCrack") else "Style"
	mesh.set_meta("shape", spec.shape)
	if surfaces.has("CrawlingCrack"):
		var crack := MeshInstance3D.new()
		crack.name = "CrawlingCrack"
		crack.mesh = surfaces.CrawlingCrack.mesh
		crack.material_override = PaletteMaterials.unshaded(spec.color)
		mark.add_child(crack)
	mesh.mesh = surfaces.Style.mesh
	mesh.material_override = PaletteMaterials.unshaded(spec.color)
	mark.add_child(mesh)
	if surfaces.has("Footprint"):
		var boundary := Node3D.new()
		boundary.name = "Footprint"
		mark.add_child(boundary)
		var outline := MeshInstance3D.new()
		outline.mesh = surfaces.Footprint.mesh
		outline.material_override = PaletteMaterials.unshaded(spec.color)
		boundary.add_child(outline)
	return mark


func _ground_as_planned(surfaces: Dictionary, own := "") -> bool:
	var changed := []
	var terrain = world.terrain
	if terrain.has_method("cave_roofs"):
		for roof in terrain.cave_roofs(terrain.stage).values():
			if roof.surface != roof.baseline:
				changed.append(roof.baseline)
	var m = terrain.map()
	if m is OverlayMap:
		for id in terrain.overlays:
			if m.profiles.has(id) and id != own:
				changed.append(m.profiles[id].surface)
	if changed.is_empty():
		return true
	var reach := Rect2i()
	for surface in surfaces.values():
		reach = _merge_cells(reach, surface)
	if reach.size == Vector2i.ZERO:
		return false
	reach = reach.grow(MARK_GROUND_CELLS)
	for surface in changed:
		var cells := _merge_cells(Rect2i(), surface)
		if cells.size == Vector2i.ZERO or cells.intersects(reach):
			return false
	return true


const MARK_GROUND_CELLS := 2


static func _merge_cells(rect: Rect2i, surface) -> Rect2i:
	if surface == null:
		return rect
	for cell: Vector2i in surface.cells:
		var one := Rect2i(cell, Vector2i.ONE)
		rect = one if rect.size == Vector2i.ZERO else rect.merge(one)
	return rect


static func _mark_surfaces(world, row: Dictionary, geometry: Dictionary, landed: bool, overlay_map: OverlayMap, deferred := false) -> Dictionary:
	var spec: Dictionary = Kinds.world_row(EventDirector.PARK_LAND_FACTS[row.telegraph.form] if landed else row.telegraph.form)
	var half: Vector2 = geometry.half
	var out := {}
	var shapes := []
	var offset := Callable()
	var project := func(shape_list: Array, shape_offset: Callable) -> WaterSurface:
		return EventGround.project_surface(world, geometry, shape_list, shape_offset, false, null, overlay_map, null, deferred)
	if spec.get("pattern", "") == "dust_crack":
		shapes = [EventGround.rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), half)]
		var initial := 1.0 if landed else 0.001
		offset = func(local, _base): return float(spec.dust_height_m) * initial * clampf((local.x - half.x + float(spec.crack_width_m)) / float(spec.crack_width_m), 0.0, 1.0)
		var foot: float = geometry.crack_foot_x
		out.CrawlingCrack = project.call([EventGround.rectangle(Vector2(foot - float(spec.crack_width_m), -half.y), Vector2(foot, lerpf(-half.y, half.y, initial)))], Callable())
	elif spec.shape == "cross":
		shapes = [EventGround.rectangle(Vector2(-half.x, -0.15), Vector2(half.x, 0.15)),
			EventGround.rectangle(Vector2(-0.15, -half.y), Vector2(0.15, half.y))]
	elif spec.shape == "wave":
		shapes = [EventGround.rectangle(-half, half)]
		offset = func(local, _base): return 0.2 * (1.0 + sin((local.y / (half.y * 2.0) + 0.5) * TAU * 3.0))
	else:
		var segments := 32
		for k in segments:
			var a := Vector2(cos(TAU * k / segments), sin(TAU * k / segments)) * half
			var b := Vector2(cos(TAU * (k + 1) / segments), sin(TAU * (k + 1) / segments)) * half
			shapes.append([Vector2.ZERO, a, b] if spec.shape == "burst" else [a, b, b * 0.97, a * 0.97])
		if spec.shape == "burst":
			offset = func(local, _base): return 0.3 * maxf(0.0, 1.0 - (local / half).length_squared())
	out.Style = project.call(shapes, offset)
	if row.kind != "lightning":
		var inset := (half - Vector2.ONE * 0.3).max(Vector2.ZERO)
		out.Footprint = project.call([
			EventGround.rectangle(-half, Vector2(half.x, -inset.y)),
			EventGround.rectangle(Vector2(-half.x, inset.y), half),
			EventGround.rectangle(Vector2(-half.x, -inset.y), Vector2(-inset.x, inset.y)),
			EventGround.rectangle(Vector2(inset.x, -inset.y), Vector2(half.x, inset.y))], Callable())
	return out


func _show_landing(row: Dictionary, state: Dictionary) -> void:
	state.mark.free()
	state.mark = _mark(row, state.geometry, true)
	if row.kind == "cave_in":
		state.mark.position.y -= float(row.effect.depth_m) * float(_overlay_map.swaps[_prepared[row.id].swap].progress)


func _end(row: Dictionary) -> void:
	if not active.has(row.id):
		return
	var state: Dictionary = active[row.id]
	if row.get("kind", "") == "lightning":
		seek.clear()
	if state.water != null:
		_water_field.surfaces.erase(state.water)
		state.water.free()
		_water_field.refresh()
	if state.overlay != null:
		_set_overlay(row, false)
	state.mark.free()
	active.erase(row.id)


func release() -> void:
	seek.clear()
	for id in active.keys():
		_end({"id": id})
	if world != null:
		world.terrain.flood = _original_flood
		if _overlay_map != null:
			world.terrain.maps[world.terrain.stage - 1] = _original_map
	_water_field.surfaces.clear()
	_prepared.clear()
	_overlay_map = null
	_original_map = null
	world = null
