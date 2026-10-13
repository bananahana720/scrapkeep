extends Node3D

# Fleet landings (KE3). A telegraph raises a greybox vessel of the row's footprint over its
# site; the vessel's footprint is projected onto the terrain the same way natural.gd projects
# its marks. Land sets the vessel down and wakes the row's dormant home through the world's
# director. End removes the vessel.

const Palette := preload("res://src/core/palette.gd")
const NaturalEvents := preload("res://src/world/events/natural.gd")

var world
var active := {}
var _sites := {}
var _projector


func setup(world_ref) -> void:
	world = world_ref
	name = "FleetEvents"
	_projector = NaturalEvents.new()
	_projector.world = world_ref
	for site in world.terrain.map().park.park_rows:
		_sites[site.id] = site


func handle(action: String, row: Dictionary, _ctx: Dictionary) -> void:
	if row.kind != "fleet_landing":
		return
	match action:
		"telegraph":
			active[row.id] = {"mark": _vessel(row, false)}
		"land":
			if not active.has(row.id):
				return
			_set_down(row)
			world.director.activate_home(row.effect.home)
		"end":
			_end(row)


func _vessel(row: Dictionary, landed: bool) -> Node3D:
	var site: Dictionary = _sites[row.site]
	var at := Vector2(float(site.at[0]), float(site.at[1]))
	var base: float = world.terrain.height(at.x, at.y)
	var footprint: Array = row.effect.footprint_m
	var half := Vector2(float(footprint[0]), float(footprint[1])) * 0.5
	var geometry := {"at": Vector3(at.x, base, at.y), "yaw": deg_to_rad(float(site.yaw_deg)), "half": half}
	var rectangle := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	var surface = _projector._project_surface(geometry, [rectangle])
	var mark := Node3D.new()
	mark.set_meta("row_id", row.id)
	# The vertices are stored relative to the mark's base, so the mark sits on the ground at its own height.
	mark.position = Vector3.UP * base
	var mesh := MeshInstance3D.new()
	mesh.name = "Vessel"
	mesh.mesh = _lowered(surface.mesh, base)
	mesh.material_override = Palette.unshaded(Palette.SLATE if landed else Palette.HAZARD)
	mark.add_child(mesh)
	add_child(mark)
	return mark


func _set_down(row: Dictionary) -> void:
	var state: Dictionary = active[row.id]
	var mesh: MeshInstance3D = state.mark.get_node("Vessel")
	mesh.material_override = Palette.unshaded(Palette.SLATE)


func _lowered(mesh: ArrayMesh, drop: float) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in vertices.size():
		vertices[k] = vertices[k] - Vector3.UP * drop
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var lowered := ArrayMesh.new()
	lowered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return lowered


func _end(row: Dictionary) -> void:
	if not active.has(row.id):
		return
	active[row.id].mark.free()
	active.erase(row.id)


func release() -> void:
	for id in active.keys():
		_end({"id": id, "kind": "fleet_landing"})
	if _projector != null:
		_projector.free()
		_projector = null
	_sites.clear()
	world = null
