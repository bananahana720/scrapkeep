extends RefCounted

# W1-129. These flume towers straddle cut banks. Give the hanging end its own
# concrete footing, under the tower's footprint and clear of the opening beside it.
# The original mesh, grapple face and ride sensor stay at their authored height.
const ENDS := {
	"flume_ride_pier_3": 1.0, "flume_ride_pier_34": 1.0,
	"bluff_ride_pier_9": 1.0, "bluff_ride_pier_19": 1.0, "bluff_ride_pier_21": -1.0,
}
const CAPITAL := Vector2(1.40, 0.58)
const BASE := Vector2(1.58, 0.77)
const END_INSET := 1.05
const JOIN := 0.08
const EMBED := 0.35
const MIN_DROP := 0.5
const CONCRETE := preload("res://assets/materials/gpw_workshop.gdshader")


static func fit(row: Dictionary, place: Transform3D, ground: Callable) -> ArrayMesh:
	var id: String = row.get("id", "")
	if not ENDS.has(id) or not ground.is_valid():
		return null
	var recipe: String = row.get("recipe", "")
	if recipe != "flume_bent_50" and recipe != "surge_pylon_28":
		return null
	var z := float(ENDS[id]) * (float(row["size"][0]) * 0.5 - END_INSET)
	var bottom := _bottom(place, ground, z)
	if bottom > -MIN_DROP:
		return null
	var upper := _ring(JOIN, z, CAPITAL)
	var lower := _ring(bottom - EMBED, z, BASE)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in 4:
		var j := (i + 1) % 4
		surface.add_triangle_fan(PackedVector3Array([lower[i], lower[j], upper[j], upper[i]]))
	surface.add_triangle_fan(upper)
	lower.reverse()
	surface.add_triangle_fan(lower)
	surface.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = CONCRETE
	material.set_shader_parameter("base_color", Color("877b68"))
	# Keep the shader's mould lines and grain, without applying corner wear in tower space.
	material.set_shader_parameter("half_extents", Vector3(BASE.x + 1.0, absf(bottom) + 1.0, absf(z) + BASE.y + 1.0))
	surface.set_material(material)
	return surface.commit()


static func _bottom(place: Transform3D, ground: Callable, z: float) -> float:
	var low := INF
	for across: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for along: float in [-1.0, 0.0, 1.0]:
			var at := place * Vector3(across * BASE.x, 0.0, z + along * BASE.y)
			low = minf(low, float(ground.call(at.x, at.z)))
	return low - place.origin.y


static func _ring(y: float, z: float, extent: Vector2) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-extent.x, y, z - extent.y), Vector3(extent.x, y, z - extent.y),
		Vector3(extent.x, y, z + extent.y), Vector3(-extent.x, y, z + extent.y),
	])
