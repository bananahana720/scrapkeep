extends Node3D

const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Flood := preload("res://src/world/flood.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const TerrainEvent := preload("res://src/world/terrain_event.gd")
const LocalMesh := preload("res://src/world/local_mesh.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

const KINDS := {
	"flood_fill": {"form": "flood_rising", "land": "flood_landed"},
	"drain": {"form": "flood_rising", "land": "flood_landed"},
	"cave_in": {"form": "cave_in_crumble", "land": "cave_in_swap"},
	"collapse": {"form": "cave_in_crumble", "land": "cave_in_swap"},
	"impact": {"form": "impact_incoming", "land": "impact_swap", "lift_mps": 8.0},
	"flash_flood": {"form": "flood_rising", "land": "flood_landed"},
	"lightning": {"form": "lightning_charge", "land": "lightning_landed", "lift_mps": 8.0},
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
	func in_basin(point: Vector3) -> bool:
		return visible and ParkMap.footprint_contains(site, Vector2(point.x, point.z))
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


# The existing terrain overlay API, with finished colliders parked between swaps.
class OverlayMap:
	extends ParkMap
	var swaps := {}
	var profiles := {}
	var source
	func apply_swap(id: String, changed: bool) -> void:
		if not swaps.has(id):
			return
		var entry: Dictionary = swaps[id]
		entry.body.position = entry.home if changed else entry.home + Vector3.DOWN * Gorge.SWAP_PARK
		entry.body.visible = changed
		if is_instance_valid(entry.before):
			entry.before.position = entry.before_home + Vector3.DOWN * Gorge.SWAP_PARK if changed else entry.before_home
			entry.before.visible = not changed
	func overlay_height(id: String, x: float, z: float, ground: float) -> float:
		if not profiles.has(id):
			return source.overlay_height(id, x, z, ground)
		var p: Dictionary = profiles[id]
		if not ParkMap.footprint_contains(p.site, Vector2(x, z)):
			return -INF
		var local := (Vector2(x, z) - Vector2(float(p.site.at[0]), float(p.site.at[1]))).rotated(deg_to_rad(float(p.site.yaw_deg)))
		return float(p.height.call(local.x, local.y))


class Surface:
	extends RefCounted
	var size := Vector2.ZERO
	var nx := 0
	var nz := 0
	var heights := PackedFloat64Array()
	func height(x: float, z: float) -> float:
		var gx := clampf((x / size.x + 0.5) * nx, 0.0, float(nx))
		var gz := clampf((z / size.y + 0.5) * nz, 0.0, float(nz))
		var i := mini(int(gx), nx - 1)
		var j := mini(int(gz), nz - 1)
		var fx := gx - i
		var fz := gz - j
		var a := heights[j * (nx + 1) + i]
		var b := heights[j * (nx + 1) + i + 1]
		var c := heights[(j + 1) * (nx + 1) + i]
		var d := heights[(j + 1) * (nx + 1) + i + 1]
		return a + (b - a) * fx + (c - a) * fz if fx + fz <= 1.0 else d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


func setup(world_ref) -> void:
	world = world_ref
	name = "NaturalEvents"
	_original_map = world.terrain.map()
	_original_flood = world.terrain.flood
	for site in _original_map.park.park_rows:
		_sites[site.id] = site
	for row in _original_map.park.event_rows:
		if row.family != "natural" or not KINDS.has(row.kind):
			continue
		var site: Dictionary = _sites[row.site]
		var at := _at(site)
		var record := {"site": site, "at": at, "overlay": null, "model": null}
		if row.kind in ["cave_in", "collapse", "impact"]:
			_prepare_overlay(row, record)
			var half := ParkMap.footprint_half_extents(site)
			var footprint := {"centre": Vector2(at.x, at.z), "radius": minf(half.x, half.y)}
			var model = TerrainEvent.new("impact" if row.kind == "impact" else "cave_in",
				{"footprint": [footprint], "lead": maxf(float(row.telegraph.lead_s), ParkSchema._lead_floor(row))},
				0.0, 14.0, Callable(world.terrain, "height"))
			world.events.terrain.append(model)
			record.model = model
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


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if not KINDS.has(row.kind):
		return
	match action:
		"telegraph":
			var state: Dictionary = _prepared[row.id].duplicate()
			state.merge({"phase": "telegraph", "hit": false, "elapsed_s": 0.0, "depth_m": 0.0,
				"water": null, "mark": _mark(row, ctx.at), "announced_s": ctx.clock_s}, true)
			active[row.id] = state
			if state.model != null:
				state.model.phase = TerrainEvent.ANNOUNCED
				state.model.timer = state.model.lead
		"land":
			var state: Dictionary = active[row.id]
			state.phase = "land"
			_show_landing(row, state)
			if row.kind in ["flood_fill", "drain", "flash_flood"]:
				_land_water(row, state)
			if state.overlay != null:
				_set_overlay(row, true)
			if state.model != null:
				state.model.phase = TerrainEvent.CHANGED
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
			_hazard(row, state, ctx)
		"end":
			_end(row)


func _at(site: Dictionary) -> Vector3:
	var x := float(site.at[0])
	var z := float(site.at[1])
	return Vector3(x, float(site.y) if site.y != null else world.terrain.height(x, z), z)


func _land_water(row: Dictionary, state: Dictionary) -> void:
	var water := WaterView.new()
	add_child(water)
	water.setup()
	water.site = state.site
	water.cycle = WaterClock.new()
	var depth := minf(ParkSchema.MAX_EVENT_WATER_M, maxf(0.0, float(row.effect.get("depth_m", 0.0))))
	state.start_depth_m = depth if row.kind == "drain" else 0.0
	for existing in _water_field.surfaces:
		if existing.site.id == state.site.id and existing.visible:
			state.start_depth_m = clampf(existing.surface_y() - state.at.y, 0.0, ParkSchema.MAX_EVENT_WATER_M)
	state.depth_m = state.start_depth_m
	water.cycle.metres = state.depth_m
	var half := ParkMap.footprint_half_extents(state.site)
	var centre := Vector2(state.at.x, state.at.z)
	water.configure({"centre": centre, "radius": half.length(), "plane_centre": centre,
		"plane_size": half * 2.0, "depth": depth}, state.at.y, state.at)
	water._plane.rotation.y = deg_to_rad(float(state.site.yaw_deg))
	water._mast.visible = false
	water._lamp_mesh.visible = false
	water.render()
	state.water = water
	_water_field.surfaces.append(water)
	_water_field.refresh()


func _prepare_overlay(row: Dictionary, record: Dictionary) -> void:
	if _overlay_map == null:
		_overlay_map = OverlayMap.new(_original_map.path)
		for property in _original_map.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
				_overlay_map.set(property.name, _original_map.get(property.name))
		_overlay_map.source = _original_map
		world.terrain.maps[world.terrain.stage - 1] = _overlay_map
	var site: Dictionary = record.site
	var half := ParkMap.footprint_half_extents(site)
	var radius := minf(half.x, half.y)
	var at: Vector3 = record.at
	var yaw := deg_to_rad(float(site.yaw_deg))
	var terrain = world.terrain
	var kind: String = row.kind
	# Collider vertices and terrain.height use this identical surface function.
	var height := func(x: float, z: float) -> float:
		var world_xz := Vector2(x, z).rotated(-yaw) + Vector2(at.x, at.z)
		var base: float = terrain.height(world_xz.x, world_xz.y)
		if kind == "impact":
			return base + maxf(0.0, Gorge.crater_profile(Vector2(x, z).length() * Gorge.CRATER_OUT / radius))
		if kind == "collapse":
			return base + 2.0 * clampf((z + half.y) / (2.0 * half.y), 0.0, 1.0)
		return base + Gorge.rubble_profile(Vector2(x, z).length() * Gorge.RUBBLE_RADIUS / radius)
	var step := maxf(0.5, minf(half.x, half.y) / 8.0)
	var surface := Surface.new()
	surface.size = half * 2.0
	surface.nx = ceili(surface.size.x / step)
	surface.nz = ceili(surface.size.y / step)
	for j in surface.nz + 1:
		for i in surface.nx + 1:
			var x := -half.x + i * surface.size.x / surface.nx
			var z := -half.y + j * surface.size.y / surface.nz
			surface.heights.append(float(height.call(x, z)))
	var sampled := Callable(surface, "height")
	var body := LocalMesh.grid(self, "Natural_" + row.id, half * 2.0, step, sampled,
		func(_x, _z): return Palette.SANDSTONE)
	body.position = Vector3(at.x, 0.0, at.z)
	body.rotation.y = yaw
	var before: Node3D = null
	if world.terrain.has_method("geometry_root"):
		before = world.terrain.geometry_root(world.terrain.stage).find_child("Park_" + str(row.site), true, false) as Node3D
	var id: String = str(row.effect.get("swap", row.id))
	if id == "":
		id = row.id
	_overlay_map.swaps[id] = {"body": body, "home": body.position, "before": before,
		"before_home": before.position if is_instance_valid(before) else Vector3.ZERO}
	_overlay_map.profiles[id + "_after"] = {"site": site, "height": sampled, "surface": surface}
	_overlay_map.apply_swap(id, false)
	record.overlay = body
	record.swap = id


func _set_overlay(row: Dictionary, changed: bool) -> void:
	var id: String = _prepared[row.id].swap
	_overlay_map.apply_swap(id, changed)
	if changed:
		world.terrain.overlays.erase(id + "_before")
		if not world.terrain.overlays.has(id + "_after"):
			world.terrain.overlays.append(id + "_after")
	else:
		world.terrain.overlays.erase(id + "_after")


func _hazard(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	if row.kind not in ["impact", "lightning"] or state.hit:
		return
	var radius := maxf(0.0, float(row.effect.get("strike_m", 0.0)))
	if Vector2(ctx.ball.x - state.at.x, ctx.ball.z - state.at.z).length() > radius or absf(ctx.ball.y - state.at.y) > radius:
		return
	state.hit = true
	var amount := maxi(0, ceili(float(row.effect.get("damage", 0.0))))
	var taken: int = world.ctx.run.lose_scrap(amount, ctx.ball, row.kind)
	if taken < amount or amount == 0:
		var velocity: Vector3 = world.ctx.player.state.velocity
		velocity.y = maxf(velocity.y, float(KINDS[row.kind].lift_mps))
		world.ctx.player.set_velocity_now(velocity, "natural_event")


func _mark(row: Dictionary, at: Vector3, landed := false) -> Node3D:
	var mark := Node3D.new()
	add_child(mark)
	mark.position = at + Vector3.UP * 0.15
	var spec: Dictionary = Kinds.world_row(KINDS[row.kind].land if landed else KINDS[row.kind].form)
	var half := ParkMap.footprint_half_extents(_sites[row.site])
	var mesh := MeshInstance3D.new()
	if spec.shape == "burst":
		var shape := SphereMesh.new()
		shape.radius = minf(half.x, half.y) * 0.25
		shape.height = shape.radius * 2.0
		mesh.mesh = shape
	elif spec.shape == "cross":
		var shape := BoxMesh.new()
		shape.size = Vector3(half.x * 2.0, 0.1, 0.3)
		mesh.mesh = shape
		var other := MeshInstance3D.new()
		other.mesh = shape
		other.rotation.y = PI * 0.5
		other.material_override = Palette.unshaded(spec.color)
		mark.add_child(other)
	else:
		var shape := TorusMesh.new()
		shape.inner_radius = maxf(0.1, minf(half.x, half.y) - 0.3)
		shape.outer_radius = minf(half.x, half.y)
		mesh.mesh = shape
		mesh.scale.y = 0.05
	mesh.material_override = Palette.unshaded(spec.color)
	mark.add_child(mesh)
	return mark


func _show_landing(row: Dictionary, state: Dictionary) -> void:
	state.mark.free()
	state.mark = _mark(row, state.at, true)


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


func _process(_delta: float) -> void:
	if world == null:
		return
	for state in active.values():
		if state.phase == "telegraph" and state.model != null:
			state.model.timer = maxf(0.0, state.model.lead - (world.events.stage_time - float(state.announced_s)))


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
	if state.model != null:
		state.model.phase = TerrainEvent.DONE
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
