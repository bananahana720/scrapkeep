extends Node

# KE4 Ancient machines erupt. Each machine_eruption row telegraphs, lands its swap overlay and
# its miniboss at the site, and ends its swap. The overlay path is natural.gd's (_prepare_overlay
# and _set_overlay), reached through the natural handler the stage already owns, so the swap
# code stays in one place. Follow-up: move that overlay code out of natural.gd into a shared helper.
# The miniboss spawn is the same call the director's ancient packs make (director.gd _ancient and
# world.gd spawn loop), so it is a field spawn, not a Warden-fight spawn.

const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

var world
var _natural
var _landed := {}


func setup(world_ref) -> void:
	world = world_ref
	name = "AncientEvents"


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if str(row.get("kind", "")) != "machine_eruption":
		return
	match action:
		"telegraph":
			_prepare(row)
		"land":
			_land(row, ctx)
		"end":
			_end(row)


func release() -> void:
	for row in _landed.values():
		_end(row)
	_landed.clear()
	_natural = null
	world = null


func _natural_handler():
	if not is_instance_valid(_natural) and world != null:
		_natural = world.event_families.get("natural")
	return _natural


func _site_row(id: String) -> Dictionary:
	for site in world.terrain.map().park.park_rows:
		if site.id == id:
			return site
	return {}


func _prepare(row: Dictionary) -> void:
	var nat = _natural_handler()
	var site_row := _site_row(str(row.site))
	if nat == null or site_row.is_empty():
		push_error("ancient: no natural handler or site for %s; its swap is not prepared" % row.id)
		return
	var site: Dictionary = NaturalFootprint.resolve(row, site_row)
	var at: Vector3 = nat._at(site)
	var geometry := {"site": site, "at": at, "half": ParkMap.footprint_half_extents(site),
		"yaw": deg_to_rad(float(site.yaw_deg)), "strike_m": 0.0}
	var record := {"site": site, "at": at, "geometry": geometry, "overlay": null}
	nat._prepared[row.id] = record
	nat._prepare_overlay(row, record)


func _land(row: Dictionary, ctx: Dictionary) -> void:
	var nat = _natural_handler()
	if nat == null or not nat._prepared.has(row.id):
		push_error("ancient: %s lands before its swap is prepared" % row.id)
		return
	nat._set_overlay(row, true)
	_landed[row.id] = row
	var kind := str(row.effect.get("miniboss", ""))
	var spawner = world.ctx.spawner
	if kind == "" or world.ctx.calm or spawner == null or not spawner.has_method("spawn_enemy"):
		return
	spawner.spawn_enemy(kind, world.terrain.drop_point(ctx.at.x, ctx.at.z, 2.4))


func _end(row: Dictionary) -> void:
	_landed.erase(row.id)
	var nat = _natural
	if not is_instance_valid(nat) or nat._overlay_map == null or not nat._prepared.has(row.id):
		return
	nat._set_overlay(row, false)
