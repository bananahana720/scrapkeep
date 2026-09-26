extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# The whole stage is one continuous height field. Shelves, chute channels and the
# bypass deck are blended into each other by weight rather than stitched from
# separate meshes, so a rolling sphere never catches a seam and every contact
# normal means something.

const HALF := 200.0
const STEP := 2.0

const TOP_H := 30.0
const MID_H := 15.0
const BASIN_H := 0.0

const RISER_TOP := Vector2(-57.0, -47.0)
const RISER_MID := Vector2(41.0, 51.0)

const BASIN_CENTRE := Vector2(0.0, 110.0)
const BASIN_BOWL := 3.5
const BASIN_RADIUS := 95.0
const FLOOD_DEPTH := 7.0

const CHUTE_R := 13.0
const CHUTE_OUTER := 24.0
const CHUTE_BOWL := 17.0
const CHUTE_SINK := 3.0

const CHUTES := [
	{"x": -62.0, "z0": -78.0, "z1": -24.0, "h0": TOP_H, "h1": MID_H},
	{"x": 54.0, "z0": -78.0, "z1": -24.0, "h0": TOP_H, "h1": MID_H},
	{"x": -18.0, "z0": 20.0, "z1": 76.0, "h0": MID_H, "h1": BASIN_H},
	{"x": 96.0, "z0": 20.0, "z1": 76.0, "h0": MID_H, "h1": BASIN_H},
]

const BYPASS_X := 140.0
const BYPASS_FLAT := 9.0
const BYPASS_OUTER := 22.0

const SPAWN := Vector2(-62.0, -96.0)
const PUMP_HOUSE := Vector2(34.0, -148.0)
const HATCH := Vector2(0.0, 110.0)
const BYPASS_FOOT := Vector2(140.0, 116.0)
const BYPASS_TOP := Vector2(140.0, -96.0)

const CACHE_SPOTS := [
	Vector2(58.0, -126.0), Vector2(-96.0, -6.0), Vector2(104.0, 6.0),
	Vector2(-100.0, 94.0), Vector2(108.0, 136.0),
]

const SCRAP_LINES := [
	[Vector2(-62.0, -82.0), Vector2(-62.0, -10.0)],
	[Vector2(54.0, -82.0), Vector2(54.0, -10.0)],
	[Vector2(-18.0, 16.0), Vector2(-18.0, 90.0)],
	[Vector2(96.0, 16.0), Vector2(96.0, 90.0)],
	[Vector2(140.0, 110.0), Vector2(140.0, -92.0)],
	[Vector2(-56.0, -104.0), Vector2(30.0, -142.0)],
	[Vector2(-88.0, -4.0), Vector2(86.0, 2.0)],
	[Vector2(-96.0, 88.0), Vector2(-20.0, 140.0)],
	[Vector2(30.0, 142.0), Vector2(100.0, 120.0)],
]


# [height, chute weight, bypass weight]: the build needs the weights for tinting,
# so one sample answers both questions instead of recomputing them side by side.
static func sample(x: float, z: float) -> Array:
	var h := _shelf(z) + _bowl(x, z)
	var by := _bypass(x, z)
	h = lerpf(h, by[0], by[1])
	var ch := _chutes(x, z)
	h = lerpf(h, ch[0], ch[1])
	h += _ripple(x, z) * (1.0 - maxf(by[1], ch[1]))
	return [h + _walls(x, z), ch[1], by[1]]


static func height(x: float, z: float) -> float:
	return sample(x, z)[0]


static func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


static func at(spot: Vector2, clearance := 1.8) -> Vector3:
	return drop_point(spot.x, spot.y, clearance)


static func chute_entry(index: int) -> Vector3:
	var c: Dictionary = CHUTES[index]
	return drop_point(c["x"], c["z0"] + 8.0, 2.0)


static func in_basin(point: Vector3) -> bool:
	return Vector2(point.x, point.z).distance_to(BASIN_CENTRE) < BASIN_RADIUS


static func _shelf(z: float) -> float:
	var h := lerpf(TOP_H, MID_H, smoothstep(RISER_TOP.x, RISER_TOP.y, z))
	return lerpf(h, BASIN_H, smoothstep(RISER_MID.x, RISER_MID.y, z))


static func _bowl(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(BASIN_CENTRE)
	return -BASIN_BOWL * (1.0 - smoothstep(25.0, 85.0, d)) * smoothstep(52.0, 70.0, z)


static func _ripple(x: float, z: float) -> float:
	return 0.85 * sin(x * 0.055) * cos(z * 0.047) + 0.45 * sin((x + z) * 0.031)


static func _walls(x: float, z: float) -> float:
	var rim := 55.0 * smoothstep(162.0, 199.0, maxf(absf(x), absf(z)))
	var canyon := 78.0 * (1.0 - smoothstep(-158.0, -116.0, x))
	return maxf(rim, canyon)


# The deck is flat on every shelf and inclined only across the risers, so the
# bypass never floats above the ground it is supposed to connect.
static func bypass_deck(z: float) -> float:
	if z >= 105.0:
		return BASIN_H
	if z >= 35.0:
		return lerpf(MID_H, BASIN_H, (z - 35.0) / 70.0)
	if z >= -15.0:
		return MID_H
	if z >= -85.0:
		return lerpf(MID_H, TOP_H, (-15.0 - z) / 70.0)
	return TOP_H


static func _bypass(x: float, z: float) -> Array:
	var adx := absf(x - BYPASS_X)
	if adx > BYPASS_OUTER:
		return [0.0, 0.0]
	var w := 1.0 - smoothstep(BYPASS_FLAT + 5.0, BYPASS_OUTER, adx)
	w *= 1.0 - smoothstep(150.0, 178.0, z)
	w *= smoothstep(-162.0, -130.0, z)
	if w <= 0.0:
		return [0.0, 0.0]
	var lip := 0.0
	if adx > BYPASS_FLAT:
		lip = minf((adx - BYPASS_FLAT) * 1.3, 6.0)
	return [bypass_deck(z) + lip, w]


static func _chutes(x: float, z: float) -> Array:
	var best := [0.0, 0.0]
	for c in CHUTES:
		var r := _chute(c, x, z)
		if r[1] > best[1]:
			best = r
	return best


static func _chute(c: Dictionary, x: float, z: float) -> Array:
	var adx: float = absf(x - c["x"])
	if adx > CHUTE_OUTER:
		return [0.0, 0.0]
	var w: float = 1.0 - smoothstep(CHUTE_R + 4.0, CHUTE_OUTER, adx)
	w *= smoothstep(c["z0"] - 16.0, c["z0"] - 2.0, z)
	w *= 1.0 - smoothstep(c["z1"] + 2.0, c["z1"] + 16.0, z)
	if w <= 0.0:
		return [0.0, 0.0]
	var t: float = clampf(inverse_lerp(c["z0"], c["z1"], z), 0.0, 1.0)
	# Mostly linear: a smoothstepped floor is flat at both ends, and a fast lane
	# that does not pitch over until its middle never gets the ball moving.
	var deck: float = lerpf(c["h0"], c["h1"], lerpf(t, smoothstep(0.0, 1.0, t), 0.3)) - CHUTE_SINK
	var arc: float = minf(adx, CHUTE_R)
	var cross: float = CHUTE_BOWL - sqrt(CHUTE_BOWL * CHUTE_BOWL - arc * arc)
	if adx > CHUTE_R:
		cross += (adx - CHUTE_R) * 1.1
	return [deck + cross, w]


func build(parent: Node3D) -> void:
	_build_ground(parent)
	_build_props(parent)
	_build_sky(parent)


func _build_ground(parent: Node3D) -> void:
	var cells := int(round(2.0 * HALF / STEP))
	var side := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(side * side)
	colors.resize(side * side)
	uvs.resize(side * side)

	for j in side:
		var z := -HALF + j * STEP
		for i in side:
			var x := -HALF + i * STEP
			var s := sample(x, z)
			var idx := j * side + i
			heights[idx] = s[0]
			verts[idx] = Vector3(x, s[0], z)
			uvs[idx] = Vector2(x, z) * 0.1
			var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.35)
			tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), s[1] * 0.9)
			tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), s[2] * 0.85)
			colors[idx] = tint

	var normals := PackedVector3Array()
	normals.resize(side * side)
	for j in side:
		for i in side:
			var idx := j * side + i
			var left: float = heights[idx - (1 if i > 0 else 0)]
			var right: float = heights[idx + (1 if i < side - 1 else 0)]
			var back: float = heights[idx - (side if j > 0 else 0)]
			var front: float = heights[idx + (side if j < side - 1 else 0)]
			normals[idx] = Vector3(left - right, 2.0 * STEP, back - front).normalized()

	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var w := 0
	for j in cells:
		for i in cells:
			var a := j * side + i
			var b := a + 1
			var c := a + side
			var d := c + 1
			# Clockwise from above is Godot's front-face winding, and a trimesh
			# collider only collides on its front faces.
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = c
			indices[w + 3] = b
			indices[w + 4] = d
			indices[w + 5] = c
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = Palette.ground_material()
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)


func _build_props(parent: Node3D) -> void:
	var concrete := Palette.striped(Palette.CHARCOAL, Palette.VERDIGRIS)
	var copper := Palette.solid(Palette.COPPER)
	var rust := Palette.solid(Palette.RUST)

	var house := at(PUMP_HOUSE, 0.0)
	_box(parent, Vector3(22.0, 11.0, 15.0), house + Vector3.UP * 5.0, concrete)
	_box(parent, Vector3(24.0, 1.2, 17.0), house + Vector3.UP * 11.2, Palette.solid(Palette.VERDIGRIS))
	for dx in [-7.0, 7.0]:
		_cylinder(parent, 1.9, 9.0, house + Vector3(dx, 16.0, -4.0), copper)

	# Kerbs flank each chute mouth so the fast lane reads as an entrance, not a dip.
	for c in CHUTES:
		var mouth_z: float = c["z0"] - 3.0
		for side in [-1.0, 1.0]:
			var kx: float = c["x"] + side * (CHUTE_R + 3.0)
			_box(parent, Vector3(2.0, 2.4, 16.0), drop_point(kx, mouth_z, 0.4), rust)

	# Two mid-shelf benches: low lips to carry a scrap line and launch off.
	_box(parent, Vector3(26.0, 3.0, 9.0), at(Vector2(-58.0, -4.0), 0.6), concrete)
	_box(parent, Vector3(26.0, 3.0, 9.0), at(Vector2(66.0, 2.0), 0.6), concrete)


func _box(parent: Node3D, size: Vector3, origin: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = origin
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)


func _cylinder(parent: Node3D, radius: float, height_m: float, origin: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = origin
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height_m
	mesh.mesh = cyl
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height_m
	shape.shape = cyl_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)


func _build_sky(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.13, 0.22, 0.30)
	sky_material.sky_horizon_color = Palette.AMBER.lerp(Palette.SAND, 0.4)
	sky_material.ground_bottom_color = Palette.CHARCOAL
	sky_material.ground_horizon_color = Palette.SANDSTONE
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_density = 0.0009
	env.fog_light_color = Palette.SAND.lerp(Palette.VERDIGRIS, 0.35)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 118.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Palette.AMBER.lerp(Color.WHITE, 0.45)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	parent.add_child(sun)
