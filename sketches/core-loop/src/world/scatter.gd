extends RefCounted

# Seeded ground scatter: one MultiMeshInstance3D per row of the map's `scatter["kit"]` table, placed
# inside the play rect on ground no steeper than the row's slope, partly buried, clear of the spawn,
# the beacon and the vault. Presentation only: no body, no shape, no global random draw. Each row owns
# a private RandomNumberGenerator seeded from its seed name, so two builds give identical transforms.
# Pieces stand on the ground layer (the height callable), never on a collider that sits above it.
# The batches are not registered as scenery: a visibility range is measured to a batch's bounds
# centre, and a map-wide batch would vanish whole (set_dressing.gd, _batch).

const ScatterRows := preload("res://src/world/scatter_rows.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")

const COIL_INNER := 0.3
const COIL_OUTER := 0.42
const COIL_RINGS := 10
const COIL_SEGMENTS := 5
const SLOPE_PROBE := 1.0
const FLOATS := 12


# ground: (x, z, clearance) -> Vector3 on the drawn ground (terrain.gd _relief_at or _ground_at).
static func build(parent: Node3D, map, ground: Callable) -> Node3D:
	var holder := Node3D.new()
	holder.name = "GroundScatter"
	for row: Dictionary in map.scatter["kit"]:
		var source := _source(row["mesh"])
		if source.is_empty():
			push_warning("scatter: %s has no mesh, the row stays out" % row["mesh"])
			continue
		var xfs := transforms(row, map, ground, source["aabb"])
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = source["mesh"]
		multi.instance_count = xfs.size()
		var buffer := PackedFloat32Array()
		buffer.resize(xfs.size() * FLOATS)
		var origins := PackedVector3Array()
		for i in xfs.size():
			var tr: Transform3D = xfs[i] * (source["local"] as Transform3D)
			var at := i * FLOATS
			buffer[at] = tr.basis.x.x
			buffer[at + 1] = tr.basis.y.x
			buffer[at + 2] = tr.basis.z.x
			buffer[at + 3] = tr.origin.x
			buffer[at + 4] = tr.basis.x.y
			buffer[at + 5] = tr.basis.y.y
			buffer[at + 6] = tr.basis.z.y
			buffer[at + 7] = tr.origin.y
			buffer[at + 8] = tr.basis.x.z
			buffer[at + 9] = tr.basis.y.z
			buffer[at + 10] = tr.basis.z.z
			buffer[at + 11] = tr.origin.z
			origins.append(xfs[i].origin)
		multi.buffer = buffer
		var view := MultiMeshInstance3D.new()
		view.name = "Scatter_%s" % row["seed"]
		view.multimesh = multi
		# The headless dummy server has no readback, so the submitted buffer is kept for tests.
		view.set_meta("instance_buffer", buffer)
		view.set_meta("origins", origins)
		view.set_meta("verts_per_instance", source["verts"])
		view.material_override = load(DigScenery.SLOTS[row["slot"]])
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(view)
	parent.add_child(holder)
	return holder


static func transforms(row: Dictionary, map, ground: Callable, aabb: AABB) -> Array[Transform3D]:
	var rect: Rect2 = map.play_rect
	var clear: Dictionary = map.scatter["clear"]
	var keeps := [[map.spawn, float(clear["spawn"])], [map.beacon, float(clear["beacon"])], [map.vault, float(clear["vault"])]]
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
		if _kept_clear(keeps, Vector2(x, z)):
			continue
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


static func _kept_clear(keeps: Array, at: Vector2) -> bool:
	for keep: Array in keeps:
		if at.distance_to(keep[0] as Vector2) < float(keep[1]):
			return true
	return false


# Tilt +Y onto the ground normal.
static func _lean(normal: Vector3) -> Basis:
	var axis := Vector3.UP.cross(normal)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(normal))


# Visual vertices one row adds on `map`: its placed instances times its mesh's vertices.
static func row_vertices(row: Dictionary, map, ground: Callable) -> int:
	var source := _source(row["mesh"])
	if source.is_empty():
		return 0
	return transforms(row, map, ground, source["aabb"]).size() * int(source["verts"])


# {"mesh", "local", "aabb", "verts"} for a row's mesh source, {} when it cannot be built.
static func _source(spec: String) -> Dictionary:
	if spec == "prim:coil":
		var torus := TorusMesh.new()
		torus.inner_radius = COIL_INNER
		torus.outer_radius = COIL_OUTER
		torus.rings = COIL_RINGS
		torus.ring_segments = COIL_SEGMENTS
		return _found(torus, Transform3D.IDENTITY)
	if spec.begins_with("kit:"):
		return _found(kit_mesh(spec.trim_prefix("kit:")), Transform3D.IDENTITY)
	if spec.begins_with("glb:"):
		var path := spec.trim_prefix("glb:")
		if not ResourceLoader.exists(path):
			return {}
		var scene := (load(path) as PackedScene).instantiate()
		var found := {}
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh != null and view.mesh.get_surface_count() > 0:
				found = _found(view.mesh, DigScenery._relative(view, scene))
				break
		scene.free()
		return found
	return {}


static func _found(mesh: Mesh, local: Transform3D) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	return {"mesh": mesh, "local": local, "aabb": local * mesh.get_aabb(), "verts": (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()}


# One of ScatterRows.KIT: a closed lat-long solid, flat shaded, wound for Godot (clockwise from outside).
static func kit_mesh(kit_name: String) -> ArrayMesh:
	var spec: Dictionary = ScatterRows.KIT[kit_name]
	var segments: int = spec["segments"]
	var rings: int = spec["rings"]
	var grid: Array[Vector3] = []
	grid.append(_jitter(Vector3(0.0, 0.5 * float(spec["squash"]), 0.0), 0, 0, spec))
	for k in range(1, rings):
		var theta := PI * k / rings
		for i in segments:
			var phi := TAU * i / segments
			var p := Vector3(sin(theta) * cos(phi), cos(theta) * float(spec["squash"]), sin(theta) * sin(phi)) * 0.5
			grid.append(_jitter(p, i, k, spec))
	grid.append(_jitter(Vector3(0.0, -0.5 * float(spec["squash"]), 0.0), 0, rings, spec))
	var triangles := []
	var bottom := grid.size() - 1
	for i in segments:
		var j := (i + 1) % segments
		triangles.append_array([grid[0], grid[1 + j], grid[1 + i]])
		for k in range(1, rings - 1):
			var a := 1 + (k - 1) * segments
			var b := 1 + k * segments
			triangles.append_array([grid[a + i], grid[a + j], grid[b + i]])
			triangles.append_array([grid[a + j], grid[b + j], grid[b + i]])
		var last := 1 + (rings - 2) * segments
		triangles.append_array([grid[bottom], grid[last + i], grid[last + j]])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for t in range(0, triangles.size(), 3):
		var a: Vector3 = triangles[t]
		var b: Vector3 = triangles[t + 1]
		var c: Vector3 = triangles[t + 2]
		var n := (b - a).cross(c - a).normalized()
		for p in [a, c, b]:
			verts.append(p)
			normals.append(n)
			uvs.append(Vector2(p.x, p.z) + Vector2(0.5, 0.5))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A fixed hash of the vertex's grid slot, so the same kit name gives the same solid every build.
static func _jitter(p: Vector3, i: int, k: int, spec: Dictionary) -> Vector3:
	var h := sin(float(i) * 12.9898 + float(k) * 78.233 + float(spec["seed"]) * 37.719) * 43758.5453
	return p * (1.0 + float(spec["jitter"]) * (2.0 * (h - floorf(h)) - 1.0))
