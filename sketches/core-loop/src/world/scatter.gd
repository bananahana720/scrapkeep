extends RefCounted

# Seeded ground scatter (wave 12 probe P-GROUND): one MultiMeshInstance3D per scatter_rows.gd row,
# placed inside the map's play rect on ground no steeper than the row's slope, partly buried.
# Presentation only: no body, no shape, no global random draw. Each row owns a private
# RandomNumberGenerator seeded from its seed name, so two builds give identical transforms.

const ScatterRows := preload("res://src/world/scatter_rows.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

const COIL_INNER := 0.3
const COIL_OUTER := 0.42
const SLOPE_PROBE := 1.0


# ground: (x, z, clearance) -> Vector3 on the built grid (terrain.gd _ground_at).
static func build(parent: Node3D, map_id: String, rect: Rect2, ground: Callable) -> Node3D:
	var holder := Node3D.new()
	holder.name = "GroundScatter"
	for row: Dictionary in ScatterRows.for_map(map_id):
		var source := _source(row["mesh"])
		if source.is_empty():
			push_warning("scatter: %s has no mesh, the row stays out" % row["mesh"])
			continue
		var xfs := transforms(row, rect, ground, source["aabb"])
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = source["mesh"]
		multi.instance_count = xfs.size()
		var origins := PackedVector3Array()
		for i in xfs.size():
			multi.set_instance_transform(i, xfs[i] * source["local"])
			origins.append(xfs[i].origin)
		var view := MultiMeshInstance3D.new()
		view.name = "Scatter_%s" % row["kind"]
		view.multimesh = multi
		view.set_meta("origins", origins)
		view.material_override = load(DigScenery.SLOTS[row["slot"]])
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(view)
		GraphicsPreset.register_scenery(view)
	parent.add_child(holder)
	return holder


static func transforms(row: Dictionary, rect: Rect2, ground: Callable, aabb: AABB) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(row["seed"]).hash()
	var count := int(float(row["density"]) * rect.get_area() / 100.0)
	var scale_range: Vector2 = row["scale"]
	var out: Array[Transform3D] = []
	for i in count:
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		var yaw := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var tilt := rng.randf_range(-0.25, 0.25)
		var at: Vector3 = ground.call(x, z, 0.0)
		var dx: float = (ground.call(x + SLOPE_PROBE, z, 0.0) as Vector3).y - (ground.call(x - SLOPE_PROBE, z, 0.0) as Vector3).y
		var dz: float = (ground.call(x, z + SLOPE_PROBE, 0.0) as Vector3).y - (ground.call(x, z - SLOPE_PROBE, 0.0) as Vector3).y
		var normal := Vector3(-dx, 2.0 * SLOPE_PROBE, -dz).normalized()
		if normal.y < float(row["slope"]):
			continue
		var basis := _lean(normal) * Basis(Vector3.RIGHT, tilt) * Basis(Vector3.UP, yaw)
		var sink := (aabb.position.y + aabb.size.y * float(row["bury"])) * s
		out.append(Transform3D(basis.scaled(Vector3.ONE * s), at - normal * sink))
	return out


# Tilt +Y onto the ground normal.
static func _lean(normal: Vector3) -> Basis:
	var axis := Vector3.UP.cross(normal)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(normal))


# {"mesh", "local", "aabb"} for a row's mesh source, {} when it cannot be built.
static func _source(spec: String) -> Dictionary:
	if spec == "prim:coil":
		var torus := TorusMesh.new()
		torus.inner_radius = COIL_INNER
		torus.outer_radius = COIL_OUTER
		torus.rings = 16
		torus.ring_segments = 6
		return {"mesh": torus, "local": Transform3D.IDENTITY, "aabb": torus.get_aabb()}
	if spec.begins_with("glb:"):
		var path := spec.trim_prefix("glb:")
		if not ResourceLoader.exists(path):
			return {}
		var scene := (load(path) as PackedScene).instantiate()
		var found := {}
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh != null and view.mesh.get_surface_count() > 0:
				var local := DigScenery._relative(view, scene)
				found = {"mesh": view.mesh, "local": local, "aabb": local * view.mesh.get_aabb()}
				break
		scene.free()
		return found
	return {}
