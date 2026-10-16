extends Node3D

const EventGround := preload("res://src/world/events/event_ground.gd")
const WaterSurface := EventGround.Surface
const OverlayMap := EventGround.OverlayMap

const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Flood := preload("res://src/world/flood.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

const KINDS := {
	"flood_fill": {}, "drain": {}, "cave_in": {}, "collapse": {}, "flash_flood": {},
	"impact": {"lift_mps": 8.0}, "lightning": {"lift_mps": 8.0},
}

var world
var active := {}
var _sites := {}
var _prepared := {}
var _original_map
var _overlay_map
var _water_field := WaterField.new()
var _original_flood
var _audio
var _world_sound := Callable()
var _next_checked := false
# Natural plans (plan()) by park stage root, the instance id of terrain's geometry root for the
# stage, so a rebuilt stage plans again: {"task", "out"} while a worker plans the next stage, then
# {"plan"}. Shared across handlers because each stage's handler is freed on the next entry. A
# stage's handler starts the worker for the next stage once that stage's ground is built.
static var _plans := {}


class WaterClock:
	extends FloodCycle
	var metres := 0.0
	func depth(_full: float) -> float:
		return metres
	func klaxon() -> bool:
		return false


class WaterView:
	extends Flood
	var site := {}
	var geometry := {}
	var surface: WaterSurface
	var query_xz := Vector2.ZERO
	func in_basin(point: Vector3) -> bool:
		query_xz = Vector2(point.x, point.z)
		return visible and ParkMap.footprint_contains(geometry.site, query_xz, 0.0, Vector2.INF, geometry.half)
	func surface_y() -> float:
		return surface.height(query_xz) + cycle.metres
	func render() -> void:
		_plane.position = Vector3.UP * cycle.metres
	func external_accel(_point: Vector3, _velocity: Vector3) -> Vector3:
		return Vector3.ZERO



# Terrain's material queries use the same surfaces the Flood nodes draw.
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
	_original_map = world.terrain.map()
	_original_flood = world.terrain.flood
	for site in _original_map.park.park_rows:
		_sites[site.id] = site
	var planned := _planned()
	for row in _original_map.park.event_rows:
		if row.family != "natural" or not KINDS.has(row.kind):
			continue
		var entry: Dictionary = planned[row.id]
		var record := {"site": entry.site, "at": entry.at, "geometry": entry.geometry.duplicate(), "overlay": null}
		if entry.has("water"):
			record.water_surface = entry.water
		if row.kind in ["cave_in", "collapse", "impact"]:
			_prepare_overlay(row, record, entry)
		_prepared[row.id] = record
	world.terrain.flood = _water_field
	# Replace the generic world's sound listener for this stage, preserving its other cues.
	var presentation = world.ctx.root.get("presentation")
	if presentation != null:
		_audio = presentation.audio
		for connection in world.ctx.events.get_signal_connection_list("world_fact"):
			if connection.callable.get_object() == _audio:
				_world_sound = connection.callable
				world.ctx.events.world_fact.disconnect(_world_sound)
				world.ctx.events.world_fact.connect(_on_world_sound)
				break


# Where each natural row stands and the ground surfaces it projects (330 to 1,040 ms a stage for the
# floods and collapses, SWAP-HITCH-2), as plain data: world is the live world or an
# EventGround.Snapshot, park the map's park rows, and neither is written, so a worker can run it.
# Surfaces carry mesh arrays only; _finish builds their meshes on the main thread.
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
			entry.water = EventGround.project_surface(world, geometry, [EventGround._rectangle(-geometry.half, geometry.half)], Callable(), true, null, null, null, true)
		if row.kind == "collapse":
			geometry.crack_foot_x = _bench_face_foot(terrain, geometry)
		if row.kind in ["collapse", "impact"] and not EventGround.kind_of_span(row):
			entry.surface = EventGround.overlay_surface(world, row.kind, geometry, true)
			if row.kind == "collapse":
				entry.target = _collapse_surface(world, row, geometry, entry.surface, true)
		out[row.id] = entry
	return out


static func _finish(planned: Dictionary) -> void:
	for entry in planned.values():
		for key in ["water", "surface", "target"]:
			if entry.has(key):
				entry[key].finish()


# This stage's plan: the one a worker made while the previous stage played, the one the last entry
# made (a retry), or one made here. A stage whose cave roof has dropped, or whose rows changed since
# the plan (a test fixture edits them), plans on its live ground.
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


static func _rows_hash(park: Dictionary) -> int:
	return hash([park.park_rows, park.event_rows])


# The plan key of a built park stage on the game's terrain, or 0 (a test double, an old map).
static func _root_key(terrain, index: int) -> int:
	if not "_cave_roofs" in terrain or index < 1 or index > terrain.maps.size():
		return 0
	var i: int = index - 1
	if not terrain._is_park[i] or terrain._roots[i] == null or terrain._heights[i].is_empty():
		return 0
	return terrain._roots[i].get_instance_id()


static func _settle(key: int) -> void:
	if not _plans.has(key) or not _plans[key].has("task"):
		return
	WorkerThreadPool.wait_for_task_completion(_plans[key].task)
	var planned: Dictionary = _plans[key].out
	_finish(planned)
	_plans[key] = {"plan": planned, "rows": _plans[key].rows, "worker": true}


# Once the next stage's ground is built (world.gd starts it when the Warden wakes), its plan runs on
# a worker from a snapshot of that ground and a copy of its rows.
func _prepare_next() -> void:
	if _next_checked or world == null:
		return
	var terrain = world.terrain
	if not "_cave_roofs" in terrain or terrain.stage >= terrain.maps.size() or not terrain.is_ready(terrain.stage + 1):
		return
	_next_checked = true
	var next: int = terrain.stage + 1
	var key := _root_key(terrain, next)
	var map = terrain.map_for(next)
	if key == 0 or _plans.has(key) or not "park" in map or map.park.is_empty():
		return
	for old in _plans.keys():
		if not is_instance_id_valid(old):
			_settle(old)
			_plans.erase(old)
	var snapshot := EventGround.snapshot(terrain, next)
	var park: Dictionary = map.park.duplicate(true)
	var out := {}
	_plans[key] = {"task": WorkerThreadPool.add_task(func(): out.merge(plan(snapshot, park)), false, "natural plan"), "out": out, "rows": _rows_hash(map.park)}


# A handler leaves on every stage change, so a plan still running is left for the handler that
# enters its stage (_planned) or the next poll; activities.gd waits on what is left at teardown.
static func settle_plans() -> void:
	for key in _plans.keys():
		_settle(key)


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if not KINDS.has(row.kind):
		return
	match action:
		"telegraph":
			var state: Dictionary = _prepared[row.id].duplicate()
			state.merge({"phase": "telegraph", "hit": false, "elapsed_s": 0.0, "depth_m": 0.0,
				"water": null, "mark": _mark(row, state.geometry), "announced_s": ctx.clock_s}, true)
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
				state.water.cycle.metres = state.depth_m
				state.water.render()
			if row.kind in ["collapse", "cave_in"]:
				var fill_s := maxf(0.0, float(row.effect.fill_s))
				_advance_collapse(row, clampf(state.elapsed_s / fill_s, 0.0, 1.0) if fill_s > 0.0 else 1.0)
			_hazard(row, state, ctx)
		"end":
			_end(row)


func _process(_delta: float) -> void:
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
			[_rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), half)],
			func(local, _base): return float(spec.dust_height_m) * progress * clampf((local.x - half.x + float(spec.crack_width_m)) / float(spec.crack_width_m), 0.0, 1.0)).mesh
		var foot: float = state.geometry.crack_foot_x
		var crack = state.mark.get_node("CrawlingCrack")
		crack.mesh = _project_surface(state.geometry,
			[_rectangle(Vector2(foot - float(spec.crack_width_m), -half.y), Vector2(foot, lerpf(-half.y, half.y, progress)))]).mesh


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
	water.setup()
	water.site = state.site
	water.geometry = state.geometry
	water.cycle = WaterClock.new()
	var depth := minf(ParkSchema.MAX_EVENT_WATER_M, maxf(0.0, float(row.effect.get("depth_m", 0.0))))
	state.start_depth_m = depth if row.kind == "drain" else 0.0
	for existing in _water_field.surfaces:
		if existing.site.id == state.site.id and existing.visible:
			state.start_depth_m = existing.cycle.metres
	state.depth_m = state.start_depth_m
	water.cycle.metres = state.depth_m
	var half: Vector2 = state.geometry.half
	var centre := Vector2(state.at.x, state.at.z)
	water.configure({"centre": centre, "radius": half.length(), "plane_centre": centre,
		"plane_size": half * 2.0, "depth": depth}, state.at.y, state.at)
	water.surface = state.water_surface
	water.query_xz = centre
	water._plane.mesh = water.surface.mesh
	water._mast.visible = false
	water._lamp_mesh.visible = false
	water.render()
	state.water = water
	_water_field.surfaces.append(water)
	_water_field.refresh()


func _rectangle(low: Vector2, high: Vector2) -> Array:
	return [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]


# Clip each shape to the terrain's actual 2 m triangles before projecting. The resulting
# triangles, including their interiors, share terrain.gd's b-c diagonal and interpolation.
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
	return EventGround.project_surface(world, geometry, [EventGround._rectangle(-half, half)], offset, false, baseline, null, null, deferred)


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
	if row.kind not in ["impact", "lightning"] or state.hit:
		return
	var radius: float = state.geometry.strike_m
	var at: Vector3 = state.geometry.at
	if Vector2(ctx.ball.x - at.x, ctx.ball.z - at.z).length() > radius or absf(ctx.ball.y - at.y) > radius:
		return
	state.hit = true
	var amount := maxi(0, ceili(float(row.effect.get("damage", 0.0))))
	var taken: int = world.ctx.run.lose_scrap(amount, ctx.ball, row.kind)
	if taken < amount or amount == 0:
		var velocity: Vector3 = world.ctx.player.state.velocity
		velocity.y = maxf(velocity.y, float(KINDS[row.kind].lift_mps))
		world.ctx.player.set_velocity_now(velocity, "natural_event")


func _mark(row: Dictionary, geometry: Dictionary, landed := false) -> Node3D:
	if landed and row.kind == "collapse":
		geometry = geometry.duplicate()
		geometry.marker_surface = _overlay_map.swaps[_prepared[row.id].swap].target
	var mark := Node3D.new()
	mark.set_meta("row_id", row.id)
	add_child(mark)
	mark.position = Vector3.UP * 0.15
	var form: String = row.telegraph.form
	var spec: Dictionary = Kinds.world_row(world.events.PARK_LAND_FACTS[form] if landed else form)
	var half: Vector2 = geometry.half
	var mesh := MeshInstance3D.new()
	mesh.name = "Style"
	mesh.set_meta("shape", spec.shape)
	var shapes := []
	var offset := Callable()
	if spec.get("pattern", "") == "dust_crack":
		mesh.name = "DustCurtain"
		shapes = [_rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), half)]
		var initial := 1.0 if landed else 0.001
		offset = func(local, _base): return float(spec.dust_height_m) * initial * clampf((local.x - half.x + float(spec.crack_width_m)) / float(spec.crack_width_m), 0.0, 1.0)
		var foot: float = geometry.crack_foot_x
		var crack := MeshInstance3D.new()
		crack.name = "CrawlingCrack"
		crack.mesh = _project_surface(geometry, [_rectangle(Vector2(foot - float(spec.crack_width_m), -half.y), Vector2(foot, lerpf(-half.y, half.y, initial)))]).mesh
		crack.material_override = Palette.unshaded(spec.color)
		mark.add_child(crack)
	elif spec.shape == "cross":
		shapes = [_rectangle(Vector2(-half.x, -0.15), Vector2(half.x, 0.15)),
			_rectangle(Vector2(-0.15, -half.y), Vector2(0.15, half.y))]
	elif spec.shape == "wave":
		shapes = [_rectangle(-half, half)]
		offset = func(local, _base): return 0.2 * (1.0 + sin((local.y / (half.y * 2.0) + 0.5) * TAU * 3.0))
	else:
		var segments := 32
		for k in segments:
			var a := Vector2(cos(TAU * k / segments), sin(TAU * k / segments)) * half
			var b := Vector2(cos(TAU * (k + 1) / segments), sin(TAU * (k + 1) / segments)) * half
			shapes.append([Vector2.ZERO, a, b] if spec.shape == "burst" else [a, b, b * 0.97, a * 0.97])
		if spec.shape == "burst":
			offset = func(local, _base): return 0.3 * maxf(0.0, 1.0 - (local / half).length_squared())
	mesh.mesh = _project_surface(geometry, shapes, offset).mesh
	mesh.material_override = Palette.unshaded(spec.color)
	mark.add_child(mesh)
	if row.kind != "lightning":
		var boundary := Node3D.new()
		boundary.name = "Footprint"
		mark.add_child(boundary)
		var outline := MeshInstance3D.new()
		outline.mesh = _footprint_mesh(geometry)
		outline.material_override = Palette.unshaded(spec.color)
		boundary.add_child(outline)
	return mark


func _footprint_mesh(geometry: Dictionary) -> ArrayMesh:
	var half: Vector2 = geometry.half
	var inset := (half - Vector2.ONE * 0.3).max(Vector2.ZERO)
	return _project_surface(geometry, [
		_rectangle(-half, Vector2(half.x, -inset.y)),
		_rectangle(Vector2(-half.x, inset.y), half),
		_rectangle(Vector2(-half.x, -inset.y), Vector2(-inset.x, inset.y)),
		_rectangle(Vector2(inset.x, -inset.y), Vector2(half.x, inset.y))]).mesh


func _show_landing(row: Dictionary, state: Dictionary) -> void:
	state.mark.free()
	state.mark = _mark(row, state.geometry, true)
	if row.kind == "cave_in":
		state.mark.position.y -= float(row.effect.depth_m) * float(_overlay_map.swaps[_prepared[row.id].swap].progress)


func _on_world_sound(kind: String, at: Vector3) -> void:
	var cues: Dictionary = world.events.PARK_LAND_FACTS
	if not cues.has(kind) and not cues.values().has(kind):
		_world_sound.call(kind, at)
		return
	var entry: Dictionary = Kinds.world_row(kind)
	var sound := Rows.heard(entry, _audio.cue_context())
	var pitch := Harmony.ratio(_audio.live_key())
	if _audio._admit("world_fact", sound, pitch):
		_audio._start("world_fact", sound, Bank.stream(sound),
			Bank.trim_db(sound) + Audio.PRIORITY_DB[Rows.priority("world_fact")], pitch, "SFX")


func _end(row: Dictionary) -> void:
	if not active.has(row.id):
		return
	var state: Dictionary = active[row.id]
	if state.water != null:
		_water_field.surfaces.erase(state.water)
		state.water.free()
		_water_field.refresh()
	if state.overlay != null:
		_set_overlay(row, false)
	state.mark.free()
	active.erase(row.id)


func release() -> void:
	for id in active.keys():
		_end({"id": id})
	if world != null:
		if _world_sound.is_valid():
			world.ctx.events.world_fact.disconnect(_on_world_sound)
			world.ctx.events.world_fact.connect(_world_sound)
		world.terrain.flood = _original_flood
		if _overlay_map != null:
			world.terrain.maps[world.terrain.stage - 1] = _original_map
	_water_field.surfaces.clear()
	_prepared.clear()
	_overlay_map = null
	_original_map = null
	_audio = null
	_world_sound = Callable()
	world = null
