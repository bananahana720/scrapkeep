extends Node3D

const EventGround := preload("res://src/world/events/event_ground.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

var world
var _prepared := {}
var _overlay_map: EventGround.OverlayMap
var _plan := {}


func setup(world_ref) -> void:
	world = world_ref
	name = "AncientEvents"
	var items := []
	for row in world.terrain.map().park.event_rows:
		if row.kind == "machine_eruption":
			var site := _site(row)
			if not site.is_empty():
				items.append({"id": str(row.id), "kind": row.kind, "geometry": _geometry(site, Vector3(float(site.at[0]), 0.0, float(site.at[1])))})
	_plan = EventGround.plan_overlays(world, items)


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if row.kind != "machine_eruption":
		return
	match action:
		"telegraph":
			_prepare(row)
		"land":
			_land(row, ctx)
		"end":
			_end(row)


func _prepare(row: Dictionary) -> void:
	var site := _site(row)
	var x := float(site.at[0])
	var z := float(site.at[1])
	var at := Vector3(x, world.terrain.height(x, z), z)
	var record := {"site": site, "at": at, "overlay": null, "geometry": _geometry(site, at)}
	_overlay_map = EventGround.prepare_overlay(world, self, row, record, Callable(), EventGround.planned_overlay(world, _plan, str(row.id)))
	_prepared[row.id] = record


func _site(row: Dictionary) -> Dictionary:
	for site in world.terrain.map().park.park_rows:
		if site.id == row.site:
			return NaturalFootprint.resolve(row, site)
	return NaturalFootprint.resolve(row, {})


static func _geometry(site: Dictionary, at: Vector3) -> Dictionary:
	return {"site": site, "at": at, "half": ParkMap.footprint_half_extents(site), "yaw": deg_to_rad(float(site.yaw_deg)), "strike_m": 0.0}


func _land(row: Dictionary, ctx: Dictionary) -> void:
	var record: Dictionary = _prepared[row.id]
	EventGround.set_overlay(world, row, record, true)
	var kind := str(row.effect.get("miniboss", ""))
	var spawner = world.ctx.spawner
	if kind == "" or world.ctx.calm or spawner == null or not spawner.has_method("spawn_enemy"):
		return
	spawner.spawn_enemy(kind, world.terrain.drop_point(ctx.at.x, ctx.at.z, 2.4))


func _end(row: Dictionary) -> void:
	if _prepared.has(row.id):
		EventGround.set_overlay(world, row, _prepared[row.id], false)


func release() -> void:
	EventGround.settle_overlays(_plan)
	_plan = {}
	for id in _prepared:
		_end({"id": id})
	EventGround.restore_map(world, _overlay_map)
	_prepared.clear()
	_overlay_map = null
	world = null


func _exit_tree() -> void:
	EventGround.settle_overlays(_plan)
