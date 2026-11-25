extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const OFF_GROUND_M := 0.3
const TOWER_MIN_GAP_M := Tuning.RADIUS * 2.0
const LINE_CLEARANCE_M := 0.3
static var plant_ignore_lines := false
const SAMPLES_ACROSS := [-1.0, -0.5, 0.0, 0.5, 1.0]
const SAMPLES_ALONG := [-1.0, 0.0, 1.0]
const CONCRETE := preload("res://assets/materials/gpw_workshop.gdshader")
const WEAR_MARGIN := Vector3.ONE

const TOWER := {
	"tiled": false,
	"x": [0.0],
	"y": 0.0,
	"end_inset": 1.05,
	"min_gap": TOWER_MIN_GAP_M,
	"top": Vector2(1.40, 0.58),
	"flare_lift": Vector2.ZERO,
	"flare_rate": Vector2.ZERO,
	"flare_min": Vector2(0.18, 0.19),
	"flare_max": Vector2(0.18, 0.19),
	"join": 0.08,
	"embed": 0.35,
	"color": Color("877b68"),
}

const TABLE := {
	"flume_reach_120": {
		"tiled": true,
		"x": [-3.7, 3.7],
		"y": -6.0,
		"stations": [0.35, 12.0, 24.0, 36.0, 48.0, 60.0, 72.0, 84.0, 96.0, 108.0, 119.65],
		"top": Vector2(0.40, 0.36),
		"flare_lift": Vector2(0.12, 0.0),
		"flare_rate": Vector2(0.018, 0.023),
		"flare_min": Vector2(0.12, 0.20),
		"flare_max": Vector2(0.75, 0.75),
		"join": 0.13,
		"embed": 0.75,
		"color": Color("786c57"),
	},
	"flume_bent_50": TOWER,
	"surge_pylon_28": TOWER,
}


static func fit(row: Dictionary, frame: Transform3D, at_origin: Transform3D, tiles: Array[Transform3D], ground: Callable, ridden := Callable()) -> Dictionary:
	var recipe := String(row.get("recipe", ""))
	if not TABLE.has(recipe) or not ground.is_valid():
		return {}
	var entry: Dictionary = TABLE[recipe]
	var places: Array[Transform3D] = []
	if entry["tiled"]:
		places = tiles
	else:
		places.append(at_origin)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var placed := false
	for x: float in entry["x"]:
		for k in places.size():
			var stations := _stations(entry, row)
			for i in stations.size():
				if entry["tiled"] and i == 0 and k > 0:
					continue
				var sole := Vector3(x, entry["y"], stations[i])
				var top := places[k] * sole
				var depth := float(entry["top"].y) * places[k].basis.z.length()
				if entry["tiled"] and i == stations.size() - 1 and k + 1 < places.size():
					var paired: Vector3 = places[k + 1] * Vector3(x, entry["y"], stations[0])
					depth += (paired.z - top.z) * 0.5
					top = (top + paired) * 0.5
				if _cast(surface, entry, frame, ground, top, depth, ridden):
					placed = true
	if not placed:
		return {}
	surface.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = CONCRETE
	material.set_shader_parameter("base_color", entry["color"])
	surface.set_material(material)
	var mesh := surface.commit()
	var bounds := mesh.get_aabb()
	material.set_shader_parameter("half_extents", bounds.position.abs().max(bounds.end.abs()) + WEAR_MARGIN)
	var view := MeshInstance3D.new()
	view.name = "Footings"
	view.mesh = mesh
	var shape := CollisionShape3D.new()
	shape.name = "Footings"
	shape.shape = mesh.create_trimesh_shape()
	return {"view": view, "shape": shape}


static func _stations(entry: Dictionary, row: Dictionary) -> Array:
	if entry.has("stations"):
		return entry["stations"]
	var reach := float(row["size"][0]) * 0.5 - float(entry["end_inset"])
	return [-reach, reach]


static func _cast(surface: SurfaceTool, entry: Dictionary, frame: Transform3D, ground: Callable, sole: Vector3, depth: float, ridden: Callable) -> bool:
	var at := frame * sole
	var drop := at.y - float(ground.call(at.x, at.z))
	var flare: Vector2 = (entry["flare_lift"] + entry["flare_rate"] * drop).clamp(entry["flare_min"], entry["flare_max"])
	var top_half := Vector2(entry["top"].x, depth)
	var base_half := Vector2(top_half.x + flare.x, depth + flare.y)
	var low := INF
	for across: float in SAMPLES_ACROSS:
		for along: float in SAMPLES_ALONG:
			var sample := frame * (sole + Vector3(across * base_half.x, 0.0, along * base_half.y))
			low = minf(low, float(ground.call(sample.x, sample.z)))
	if at.y - low <= float(entry.get("min_gap", OFF_GROUND_M)):
		return false
	if ridden.is_valid() and not plant_ignore_lines \
			and ridden.call(Vector2(at.x, at.z), base_half.length() + Tuning.RADIUS + LINE_CLEARANCE_M):
		return false
	var upper := _ring(sole + Vector3.UP * float(entry["join"]), top_half)
	var lower := _ring(sole - Vector3.UP * (at.y - low + float(entry["embed"])), base_half)
	for i in 4:
		var j := (i + 1) % 4
		surface.add_triangle_fan(PackedVector3Array([lower[i], lower[j], upper[j], upper[i]]))
	surface.add_triangle_fan(upper)
	lower.reverse()
	surface.add_triangle_fan(lower)
	return true


static func _ring(point: Vector3, half: Vector2) -> PackedVector3Array:
	return PackedVector3Array([
		point + Vector3(-half.x, 0.0, -half.y), point + Vector3(half.x, 0.0, -half.y),
		point + Vector3(half.x, 0.0, half.y), point + Vector3(-half.x, 0.0, half.y),
	])
