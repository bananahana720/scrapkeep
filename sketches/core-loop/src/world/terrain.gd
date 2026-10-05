extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Reach := preload("res://src/world/map_reach.gd")
const Dig := preload("res://src/world/map_dig.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const DigDeep := preload("res://src/world/map_dig_deep.gd")
const HighdraftCrown := preload("res://src/world/map_highdraft_crown.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

const MAPS := {"spillway": Spillway, "gorge": Gorge, "reach": Reach, "dig": Dig, "highdraft": Highdraft, "dig_deep": DigDeep, "highdraft_crown": HighdraftCrown}

# Owned by writer D (world). The spine reads only the terrain API block below.
#
# Each stage is its own map. The first world's stages are built once at setup (every
# stage of a one-world table), so a stage change is a cheap swap inside the stage_entered
# handler and never a hitch in the launch. A later world's stages are built, all together,
# the first time anything reads one of them (_ensure). Height
# queries read the built grid and interpolate the same two triangles per cell the
# collider uses, so what the spine, combat and build ask about the ground is exactly
# the ground the ball rolls on.

const HALF := 200.0
const STEP := 2.0
const CELLS := int(2.0 * HALF / STEP)
const SIDE := CELLS + 1
# A face steeper than this (the normal's y below it) takes the pylon tint: the ball's
# pylon bites a face that leans less than 60 degrees off vertical (augments.gd).
const PYLON_FACE := 0.866
const PARK_DEPTH := 5000.0

var maps: Array = []
var stage := 1
# The flood the world runs, so material_at can say "water" where it is.
var flood
var environment: Environment
# Moss's bay (bay.gd), set by world, for the read-only bay queries below.
var bay
# The active stage's live overlay heights (terrain changes that have landed, and the
# rubble standing before a cave-in), by the map's overlay ids.
var overlays: Array[String] = []

# Each stage number outside the table is logged once through this (a test sets a sink so the
# errors can be read; with none set it is a push_error), then clamped as before.
var range_errors := {}
var error_sink: Callable

# Per global stage (index stage - 1): the stage's root (null until built) and its grid
# (empty until built). The world of each row, so a read can build its whole world.
var _roots: Array = []
var _heights: Array[PackedFloat32Array] = []
var _worlds: Array[int] = []
var _parent: Node3D
var _arena := false


func _init(table = StageDefs) -> void:
	for row in table.DEFS:
		assert(MAPS.has(row["map"]), "terrain: stage %s names an unknown map '%s'" % [row["stage"], row["map"]])
		maps.append(MAPS[row["map"]].new())
		_worlds.append(int(row.get("world", 1)))
		_roots.append(null)
		_heights.append(PackedFloat32Array())


func map() -> RefCounted:
	return maps[stage - 1]


func map_for(index: int) -> RefCounted:
	return maps[_index(index)]


func build(parent: Node3D) -> void:
	_parent = parent
	_build_sky(parent)
	for i in maps.size():
		if _worlds[i] == _worlds[0]:
			_build_stage(i)


# True once this stage's ground and props exist.
func is_built(index: int) -> bool:
	return _roots[_index(index)] != null


func _build_stage(i: int) -> void:
	var m = maps[i]
	var holder := Node3D.new()
	holder.name = "Stage%d" % (i + 1)
	var heights := _build_ground(holder, m)
	m.build_props(holder, _ground_at.bind(heights))
	_roots[i] = holder
	_heights[i] = heights
	_parent.add_child(holder)
	_park(holder, _arena or i != stage - 1)
	holder.process_mode = Node.PROCESS_MODE_DISABLED if _arena else Node.PROCESS_MODE_INHERIT


# Builds the whole world a stage belongs to, if any of it is not built yet, and returns
# the stage's clamped index. Every read of the ground goes through here.
func _ensure(index: int) -> int:
	var i := _index(index)
	if _roots[i] == null:
		assert(_parent != null, "terrain: build() has not run")
		for j in maps.size():
			if _worlds[j] == _worlds[i] and _roots[j] == null:
				_build_stage(j)
	return i


# Swap the active stage's geometry in. Synchronous, so the flow's spawn and beacon
# queries straight after stage_entered read the new stage. The idle stages stay in the
# physics world, hidden and parked far below: moving a body is cheap, while adding a
# trimesh back to the world rebuilds its tree (measured at about 34 ms a swap).
func use(index: int) -> void:
	stage = _ensure(index) + 1
	_arena = false
	var m = map()
	overlays.clear()
	if "start_overlays" in m:
		overlays.append_array(m.start_overlays)
	for i in _roots.size():
		if _roots[i] == null:
			continue
		_park(_roots[i], i != stage - 1)
		_roots[i].process_mode = Node.PROCESS_MODE_INHERIT


# The arena is not a stage: every map is hidden and its colliders leave the physics
# world until the next use(). Putting a trimesh back rebuilds its tree, which an arena
# entry or a T replay can afford and a launch swap cannot, so only this path does it.
func park_all() -> void:
	_arena = true
	for root in _roots:
		if root == null:
			continue
		_park(root, true)
		root.process_mode = Node.PROCESS_MODE_DISABLED


static func _park(root: Node3D, parked: bool) -> void:
	root.visible = not parked
	root.position = Vector3.DOWN * PARK_DEPTH if parked else Vector3.ZERO


func geometry_root(index: int) -> Node3D:
	return _roots[_ensure(index)]


# The terrain API the spine and the other modules read through ctx.terrain (see
# CONTRACTS.md).
func height(x: float, z: float) -> float:
	var h := _grid_height(_heights[_ensure(stage)], x, z)
	if overlays.is_empty():
		return h
	var ground := h
	var m = map()
	for id in overlays:
		h = maxf(h, m.overlay_height(id, x, z, ground))
	return h


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


func spawn_point(index: int) -> Vector3:
	var s: Vector2 = map_for(index).spawn
	return Vector3(s.x, _grid_height(_heights[_ensure(index)], s.x, s.y) + 2.0, s.y)


func entry_heading(index: int) -> Vector3:
	return (map_for(index).heading as Vector3).normalized()


func beacon_point(index: int) -> Vector3:
	var b: Vector2 = map_for(index).beacon
	return Vector3(b.x, _grid_height(_heights[_ensure(index)], b.x, b.y), b.y)


func scrap_lines(index: int) -> Array:
	return map_for(index).scrap_lines


func contains(point: Vector3) -> bool:
	return absf(point.x) < HALF - 1.0 and absf(point.z) < HALF - 1.0


func rescue_point(near: Vector3) -> Vector3:
	var r: Rect2 = map().play_rect
	return drop_point(clampf(near.x, r.position.x, r.end.x), clampf(near.z, r.position.y, r.end.y), 3.0)


# For the element and material table (TADR-009, owned by build): what lies at or
# under this point, as {"material", "surface_y"}, or {} off the map. Where the flood
# stands over the ground, the answer is its water at the live surface height, so a
# frost or arc resolves against the same surface the ball floats on.
func material_at(point: Vector3) -> Dictionary:
	if not contains(point):
		return {}
	var ground := height(point.x, point.z)
	if flood != null and flood.in_basin(point):
		var surface: float = flood.surface_y()
		if surface > ground:
			return {"material": "water", "surface_y": surface}
	return {"material": map().material_at(point.x, point.z), "surface_y": ground}


# v2 W6 world: the landmark's light (INF on a map without one), the height band a
# point is in ("sky", "shelf", "undercroft", or "" on a map without bands), and the
# bay's reads for the shop UI and the lounge.
func landmark_point(index: int) -> Vector3:
	var m = map_for(index)
	return m.landmark if "landmark" in m else Vector3.INF


func layer_at(point: Vector3) -> String:
	var m = map()
	return m.layer_at(point) if m.has_method("layer_at") else ""


func in_bay(point: Vector3) -> bool:
	return bay != null and bay.inside and bay.on_deck(point)


func moss_point() -> Vector3:
	return bay.moss_point() if bay != null and bay.docked else Vector3.INF


func near_moss(point: Vector3) -> bool:
	return bay != null and bay.near_moss(point)


func ground_callable(index: int) -> Callable:
	return _ground_at.bind(_heights[_ensure(index)])


func vault_point(index: int) -> Vector3:
	var v: Vector2 = map_for(index).vault
	return Vector3(v.x, _grid_height(_heights[_ensure(index)], v.x, v.y), v.y)


func _index(index: int) -> int:
	if index < 1 or index > maps.size():
		_range_error(index)
	return clampi(index, 1, maps.size()) - 1


func _range_error(index: int) -> void:
	if range_errors.has(index):
		return
	range_errors[index] = true
	var text := "terrain: stage %d is outside the table (1 to %d); reading the nearest stage" % [index, maps.size()]
	if error_sink.is_valid():
		error_sink.call(text)
	else:
		push_error(text)


static func _grid_height(heights: PackedFloat32Array, x: float, z: float) -> float:
	var gx := clampf((x + HALF) / STEP, 0.0, CELLS - 0.001)
	var gz := clampf((z + HALF) / STEP, 0.0, CELLS - 0.001)
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var a := heights[j * SIDE + i]
	var b := heights[j * SIDE + i + 1]
	var c := heights[(j + 1) * SIDE + i]
	var d := heights[(j + 1) * SIDE + i + 1]
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


static func _ground_at(x: float, z: float, clearance: float, heights: PackedFloat32Array) -> Vector3:
	return Vector3(x, _grid_height(heights, x, z) + clearance, z)


func _build_ground(parent: Node3D, m: RefCounted) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(SIDE * SIDE)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(SIDE * SIDE)
	colors.resize(SIDE * SIDE)
	uvs.resize(SIDE * SIDE)

	for j in SIDE:
		var z := -HALF + j * STEP
		for i in SIDE:
			var x := -HALF + i * STEP
			var s: Array = m.sample(x, z)
			var idx := j * SIDE + i
			heights[idx] = s[0]
			verts[idx] = Vector3(x, s[0], z)
			uvs[idx] = Vector2(x, z) * 0.1
			colors[idx] = s[1]

	var pylon_tint := Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.25)
	var normals := PackedVector3Array()
	normals.resize(SIDE * SIDE)
	for j in SIDE:
		for i in SIDE:
			var idx := j * SIDE + i
			var left: float = heights[idx - (1 if i > 0 else 0)]
			var right: float = heights[idx + (1 if i < SIDE - 1 else 0)]
			var back: float = heights[idx - (SIDE if j > 0 else 0)]
			var front: float = heights[idx + (SIDE if j < SIDE - 1 else 0)]
			var n := Vector3(left - right, 2.0 * STEP, back - front).normalized()
			normals[idx] = n
			# Form mirrors function: any face a pylon can bite reads as concrete.
			if n.y < PYLON_FACE:
				colors[idx] = colors[idx].lerp(pylon_tint, clampf((PYLON_FACE - n.y) * 6.0, 0.0, 0.8))

	var indices := PackedInt32Array()
	indices.resize(CELLS * CELLS * 6)
	var w := 0
	for j in CELLS:
		for i in CELLS:
			var a := j * SIDE + i
			var b := a + 1
			var c := a + SIDE
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
	preload("res://src/presentation/graphics_preset.gd").register_ground(view)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)
	return heights


func _build_sky(parent: Node3D) -> void:
	var sky_material := Palette.workshop_sky()
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.fog_enabled = true
	environment.fog_density = 0.0009
	environment.fog_light_color = Palette.SAND.lerp(Palette.VERDIGRIS, 0.35)
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 118.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Palette.AMBER.lerp(Color.WHITE, 0.45)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	parent.add_child(sun)
	preload("res://src/presentation/graphics_preset.gd").bind(environment, sun, parent.get_viewport())
