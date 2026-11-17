extends RefCounted

# The iron bents of the tiled trough end 6 m below its origin. Cast concrete piers carry them
# down to the baked ground. Offsets are the leg soles in flume_works.py's frame2 and spec_flume.
const RECIPE := "flume_reach_120"
const SOLE_X := 3.7
const SOLE_Y := -6.0
const BENTS := [0.35, 12.0, 24.0, 36.0, 48.0, 60.0, 72.0, 84.0, 96.0, 108.0, 119.65]
const EMBED_M := 0.75
const CONCRETE := preload("res://assets/materials/gpw_workshop.gdshader")


# One mesh and one matching shape per reach. Keep the two sides independent so the slope can
# pass under the trough without a sill across the lower line.
static func fit(frame: Transform3D, tiles: Array[Transform3D], ground: Callable) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed := false
	for side: float in [-1.0, 1.0]:
		for k in tiles.size():
			var tile := tiles[k]
			for i in BENTS.size():
				if i == 0 and k > 0:
					continue  # the foundation at the preceding tile's end carries both bents
				var top := tile * Vector3(side * SOLE_X, SOLE_Y, BENTS[i])
				var cap_depth := 0.36 * tile.basis.z.z
				if i == BENTS.size() - 1 and k + 1 < tiles.size():
					var paired := tiles[k + 1] * Vector3(side * SOLE_X, SOLE_Y, BENTS[0])
					cap_depth += (paired.z - top.z) * 0.5
					top = (top + paired) * 0.5
				if _pier(surface, frame, ground, top, cap_depth):
					placed = true
	if not placed:
		return null
	surface.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = CONCRETE
	material.set_shader_parameter("base_color", Color("786c57"))
	surface.set_material(material)
	var mesh := surface.commit()
	# The workshop's corner wear assumes one piece centred on its own origin. Use its
	# grain and form seams here, with the wear beyond the bounds of this batched mesh.
	var bounds := mesh.get_aabb()
	material.set_shader_parameter("half_extents", bounds.position.abs().max(bounds.end.abs()) + Vector3.ONE)
	return mesh


static func _pier(surface: SurfaceTool, frame: Transform3D, ground: Callable, top: Vector3, cap_depth: float) -> bool:
	# Embed the steel sole and flare only the concrete. The width stays small enough to leave
	# room to roll under the central span, even where the weir foot has a 30 m drop.
	top.y += 0.13
	var at := frame * top
	var drop := at.y - float(ground.call(at.x, at.z))
	var base_width := clampf(0.52 + drop * 0.018, 0.52, 1.15)
	var base_depth := cap_depth + clampf(drop * 0.023, 0.20, 0.75)
	var low := INF
	for x: float in [-base_width, 0.0, base_width]:
		for z: float in [-base_depth, 0.0, base_depth]:
			var sample := frame * (top + Vector3(x, 0.0, z))
			low = minf(low, float(ground.call(sample.x, sample.z)))
	if low >= at.y - 0.03:
		return false  # the existing steel is already seated in the hillside
	var base := top - Vector3.UP * (at.y - low + EMBED_M)
	var upper := _ring(top, 0.40, cap_depth)
	var lower := _ring(base, base_width, base_depth)
	for i in 4:
		var j := (i + 1) % 4
		surface.add_triangle_fan(PackedVector3Array([lower[i], lower[j], upper[j], upper[i]]))
	surface.add_triangle_fan(upper)
	lower.reverse()
	surface.add_triangle_fan(lower)
	return true


static func _ring(point: Vector3, x: float, z: float) -> PackedVector3Array:
	return PackedVector3Array([
		point + Vector3(-x, 0.0, -z), point + Vector3(x, 0.0, -z),
		point + Vector3(x, 0.0, z), point + Vector3(-x, 0.0, z),
	])
