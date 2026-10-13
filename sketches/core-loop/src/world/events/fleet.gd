extends Node3D

# Telegraph projects the footprint decal; land raises a grounded greybox hull and wakes its home.

const Palette := preload("res://src/core/palette.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")
const HULL_HEIGHT_M := 2.0

var world
var active := {}
var _sites := {}


func setup(world_ref) -> void:
	world = world_ref
	name = "FleetEvents"
	for site in world.terrain.map().park.park_rows:
		_sites[site.id] = site


func handle(action: String, row: Dictionary, _ctx: Dictionary) -> void:
	if row.kind != "fleet_landing":
		return
	match action:
		"telegraph":
			active[row.id] = {"mark": _vessel(row)}
		"land":
			if not active.has(row.id):
				return
			_set_down(row)
			world.director.activate_home(row.effect.home)
		"end":
			_end(row)


func _vessel(row: Dictionary) -> Node3D:
	var site: Dictionary = _sites[row.site]
	var at := Vector2(float(site.at[0]), float(site.at[1]))
	var base: float = world.terrain.height(at.x, at.y)
	var footprint: Array = row.effect.footprint_m
	var half := Vector2(float(footprint[0]), float(footprint[1])) * 0.5
	var geometry := {"at": Vector3(at.x, base, at.y), "yaw": deg_to_rad(float(site.yaw_deg)), "half": half}
	var rectangle := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	var surface = EventGround.project_surface(world, geometry, [rectangle])
	var mark := Node3D.new()
	mark.set_meta("row_id", row.id)
	# The vertices are stored relative to the mark's base, so the mark sits on the ground at its own height.
	mark.position = Vector3.UP * base
	var mesh := MeshInstance3D.new()
	mesh.name = "Vessel"
	mesh.mesh = _lowered(surface.mesh, base)
	mesh.material_override = Palette.unshaded(Palette.HAZARD)
	mark.add_child(mesh)
	add_child(mark)
	return mark


func _set_down(row: Dictionary) -> void:
	var state: Dictionary = active[row.id]
	var mesh: MeshInstance3D = state.mark.get_node("Vessel")
	mesh.mesh = _hull(mesh.mesh)
	mesh.material_override = Palette.unshaded(Palette.SLATE)


# Extrude the projected triangles so the hull's entire underside follows the terrain.
func _hull(floor_mesh: ArrayMesh) -> ArrayMesh:
	var floor_vertices: PackedVector3Array = floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vertices := PackedVector3Array()
	var up := Vector3.UP * HULL_HEIGHT_M
	for k in range(0, floor_vertices.size(), 3):
		var a := floor_vertices[k]
		var b := floor_vertices[k + 1]
		var c := floor_vertices[k + 2]
		vertices.append_array([c, b, a, a + up, b + up, c + up])
		for edge in [[a, b], [b, c], [c, a]]:
			vertices.append_array([edge[0], edge[1], edge[1] + up, edge[0], edge[1] + up, edge[0] + up])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var hull := ArrayMesh.new()
	hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return hull


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
	_sites.clear()
	world = null

