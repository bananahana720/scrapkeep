extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Finishes := preload("res://src/presentation/highdraft_finishes.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const DIR := "res://assets/models/highdraft/"
const NODE_NAME := "MindArenaDress"
const PARTS := {
	"Island": ["island_large.glb", "IslandStone"],
	"Rim": ["island_rim.glb", "HardwareSkin"],
	"Rib": ["island_rib.glb", "HardwareSkin"],
	"Cloud": ["sky_cloud.glb", "CloudHull"],
	"Mesa": ["sky_mesa.glb", "MesaHull"],
	"Post": ["w3_deck_post.glb", "DeckPost"],
}
const FLOOR_LIFT := 0.02
const SKY_RING := 460.0
const INLAY_LIFT := 0.035
const INLAY_WIDTH := 0.78
const INLAY_RINGS := [6.5, 13.5, 22.0, 30.0, 34.2]
const INLAY_THRESHOLD_RING := 33.1
const INLAY_SPOKES := 12
const INLAY_IRON := Color("272d30")
const INLAY_COPPER := Color("84603e")
const POST_COUNT := 32
const POST_OUT := 1.05
const DECK_ROUGHNESS := 0.46

static var dir := DIR
static var _sky_material: ShaderMaterial
static var _panorama_task := -1
static var _panorama_out := {}
static var _kit_ahead := {}

var _saved := {}
var _greybox: Array[Dictionary] = []


# Godot headless Dummy rasterizer mesh RIDs are not thread-safe; load on main thread when headless.
static func prepare() -> void:
	for key in PARTS:
		var path: String = dir.path_join(PARTS[key][0])
		if not AppShell.headless() and ResourceLoader.exists(path) \
				and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)
	if _sky_material == null and _panorama_task < 0:
		var out := {}
		_panorama_out = out
		_panorama_task = WorkerThreadPool.add_task(func(): out["image"] = _paint_panorama(), false, "mind panorama")


static func settle() -> void:
	if _panorama_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_panorama_task)
		_panorama_task = -1
		_panorama_out = {}
	for key in PARTS:
		var path: String = dir.path_join(PARTS[key][0])
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)
	_kit_ahead = {}


static func reset_for_tests() -> void:
	settle()
	dir = DIR
	_sky_material = null


static func warm_kit() -> bool:
	for key in PARTS:
		var path: String = dir.path_join(PARTS[key][0])
		if _kit_ahead.has(path):
			continue
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
		_kit_ahead[path] = _kit_part(key)
		return false
	return true


static func _take(path: String) -> Resource:
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(path)
	return load(path)


static func attach(module):
	var dress = new()
	var meshes := dress._load_kit()
	if meshes.size() != PARTS.size():
		dress.free()
		push_warning("arena_mind_dress: kit missing or malformed; keeping the greybox arena")
		return null
	dress.name = NODE_NAME
	module.pad.add_child(dress)
	dress.position.y = module.PAD_THICK * 0.5
	dress._build(meshes, module.PAD_RADIUS)
	for child in module.pad.get_children():
		if child is MeshInstance3D:
			dress._greybox.append({"view": child, "visible": child.visible})
			child.visible = false
	dress._apply_environment(module.ctx.terrain, module.ctx.root)
	module.ctx.events.boss_defeated.connect(dress.restore_environment)
	return dress


func _load_kit() -> Dictionary:
	var meshes := {}
	var ahead := _kit_ahead
	_kit_ahead = {}
	for key in PARTS:
		var path: String = dir.path_join(PARTS[key][0])
		var mesh: Mesh = ahead[path] if ahead.has(path) else _kit_part(key)
		if mesh == null:
			return {}
		meshes[key] = mesh
	return meshes


static func _kit_part(key: String) -> Mesh:
	var path: String = dir.path_join(PARTS[key][0])
	if not ResourceLoader.exists(path):
		return null
	var packed := _take(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		return null
	var scene := instance as Node3D
	var view := scene.find_child(PARTS[key][1], true, false) as MeshInstance3D
	var mesh := _rebuild_mesh(view.mesh) if view != null and view.transform.is_equal_approx(Transform3D.IDENTITY) else null
	var cosmetic := scene.find_children("*", "CollisionObject3D", true, false).is_empty() \
		and scene.find_children("*", "CollisionShape3D", true, false).is_empty()
	scene.free()
	if mesh == null or not cosmetic:
		return null
	if key == "Rim":
		return _rim_skirt(mesh)
	return Finishes.aerial_mesh(mesh) if key == "Mesa" else mesh


static func _rebuild_mesh(source: Mesh) -> ArrayMesh:
	if source == null or source.get_surface_count() == 0:
		return null
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var original := source.surface_get_material(surface) as BaseMaterial3D
		if original == null:
			return null
		var material := _slot_material(String(original.resource_name), original.albedo_texture)
		if material == null:
			return null
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if vertices.is_empty() or normals.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0 \
			or source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES \
			or (colors.size() != vertices.size() and material.albedo_texture == null):
			return null
		for index in indices:
			if index < 0 or index >= vertices.size():
				return null
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		mesh.surface_set_material(surface, material)
	return mesh


static func _slot_material(slot: String, texture: Texture2D) -> StandardMaterial3D:
	if slot not in ["stone", "M1_stone", "steel", "glass"]:
		return null
	var material := StandardMaterial3D.new()
	material.resource_name = slot
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.roughness = 0.92 if slot in ["stone", "M1_stone"] else 0.52
	if slot == "steel":
		material.metallic = 0.32
		material.metallic_specular = 0.65
	if slot == "glass":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.62)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		preload("res://src/presentation/craft/craft_lookdev.gd").enrich_standard_pbr(material, 0.42 if slot == "steel" else 0.34, 0.18)
	return material


func _build(meshes: Dictionary, radius: float) -> void:
	var island := MeshInstance3D.new()
	island.name = "SummitIsland"
	island.mesh = meshes["Island"]
	var scale_xz: float = radius / (island.mesh.get_aabb().size.x * 0.5)
	island.scale = Vector3(scale_xz, 2.0, scale_xz)
	island.position.y = FLOOR_LIFT
	add_child(island)
	var rim: Array[Transform3D] = []
	var count := 56
	var reach := radius - 0.9
	var pitch := TAU * reach / count
	for k in count:
		var angle := TAU * k / count
		var basis := Basis(Vector3.UP, PI * 0.5 - angle).scaled(Vector3(pitch / 4.0, 1.0, 1.0))
		rim.append(Transform3D(basis, Vector3(cos(angle) * reach, 0.025, sin(angle) * reach)))
	_multi("EdgeFascia", meshes["Rim"], rim)
	var ribs: Array[Transform3D] = []
	for k in 16:
		var angle := TAU * k / 16.0
		var basis := Basis(Vector3.UP, -angle).scaled(Vector3(1.65, 1.85, 1.65))
		ribs.append(Transform3D(basis, Vector3(cos(angle) * (radius - 6.0), -2.5, sin(angle) * (radius - 6.0))))
	_multi("UndersideRibs", meshes["Rib"], ribs)
	_wet_deck(island)
	_inlays(radius)
	var posts: Array[Transform3D] = []
	for k in POST_COUNT:
		var angle := TAU * (k + 0.5) / POST_COUNT
		var at := radius + POST_OUT
		var pylon := k % 4 == 0
		var scale_post := Vector3(1.18, 1.55, 1.18) if pylon else Vector3(0.95, 1.0, 0.95)
		posts.append(Transform3D(Basis(Vector3.UP, PI * 0.5 - angle).scaled(scale_post), Vector3(cos(angle) * at, -0.55, sin(angle) * at)))
	_multi("EdgePosts", meshes["Post"], posts)
	_sky_pieces(meshes)


func _wet_deck(island: MeshInstance3D) -> void:
	var mesh := island.mesh as ArrayMesh
	for i in mesh.get_surface_count():
		var wet := (mesh.surface_get_material(i) as StandardMaterial3D).duplicate() as StandardMaterial3D
		wet.roughness = DECK_ROUGHNESS
		wet.metallic_specular = 0.75
		wet.albedo_color = Color("cfd4df")
		mesh.surface_set_material(i, wet)


func _inlays(radius: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var strip := func(a: Vector2, b: Vector2, colour: Color, width := INLAY_WIDTH) -> void:
		var side := (b - a).orthogonal().normalized() * width * 0.5
		var quad := [a - side, b - side, b + side, a - side, b + side, a + side]
		for p: Vector2 in quad:
			vertices.append(Vector3(p.x, INLAY_LIFT, p.y))
			normals.append(Vector3.UP)
			colors.append(colour)
	var all_rings: Array = INLAY_RINGS.duplicate()
	all_rings.append(INLAY_THRESHOLD_RING)
	for r: float in all_rings:
		var segments := int(ceil(TAU * r / 2.0))
		var col := INLAY_COPPER if r == INLAY_RINGS[-1] or r == INLAY_RINGS[2] else INLAY_IRON
		var width := INLAY_WIDTH * 1.15 if r == INLAY_RINGS[-1] or r == INLAY_THRESHOLD_RING else INLAY_WIDTH
		for k in segments:
			var a0 := TAU * k / segments
			var a1 := TAU * (k + 1) / segments
			strip.call(Vector2(cos(a0), sin(a0)) * r, Vector2(cos(a1), sin(a1)) * r, col, width)
	for k in INLAY_SPOKES:
		var angle := TAU * k / INLAY_SPOKES
		var dir := Vector2(cos(angle), sin(angle))
		var cardinal := k % 3 == 0
		var col := INLAY_COPPER if cardinal else INLAY_IRON
		strip.call(dir * INLAY_RINGS[0], dir * minf(INLAY_RINGS[-1], radius - 1.5), col, INLAY_WIDTH * (1.25 if cardinal else 0.85))
		if cardinal:
			var perp := dir.orthogonal()
			var base_pt := dir * INLAY_RINGS[3]
			strip.call(base_pt - perp * 1.9, dir * (INLAY_RINGS[3] + 1.8), INLAY_COPPER, INLAY_WIDTH * 0.85)
			strip.call(base_pt + perp * 1.9, dir * (INLAY_RINGS[3] + 1.8), INLAY_COPPER, INLAY_WIDTH * 0.85)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.resource_name = "inlay"
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.34
	material.metallic = 0.58
	material.metallic_specular = 0.72
	preload("res://src/presentation/craft/craft_lookdev.gd").enrich_standard_pbr(material, 0.36, 0.25)
	mesh.surface_set_material(0, material)
	var view := MeshInstance3D.new()
	view.name = "DeckInlays"
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


static func _rim_skirt(source: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var original_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in vertices.size():
			var point := vertices[i]
			point.z += 0.45 * smoothstep(0.0, 0.35, -point.y)
			vertices[i] = point
		var normals := PackedVector3Array()
		normals.resize(vertices.size())
		for t in range(0, indices.size(), 3):
			var face := (vertices[indices[t + 1]] - vertices[indices[t]]).cross(vertices[indices[t + 2]] - vertices[indices[t]])
			if face.dot(original_normals[indices[t]]) < 0.0:
				face = -face
			for k in 3:
				normals[indices[t + k]] += face
		for i in normals.size():
			normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.000001 else original_normals[i]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh


func _multi(label: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	var bounds := AABB()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var placed: AABB = transforms[i] * mesh.get_aabb()
		bounds = placed if i == 0 else bounds.merge(placed)
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = mm
	view.custom_aabb = bounds
	view.set_meta("placements", transforms)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


func _sky_pieces(meshes: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_310_006
	var clouds: Array[Transform3D] = []
	for k in 36:
		var angle := TAU * k / 36.0 + rng.randf_range(-0.05, 0.05)
		var reach := rng.randf_range(250.0, 560.0)
		var wide := rng.randf_range(1.6, 3.0)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, 1.0, wide))
		clouds.append(Transform3D(basis, Vector3(cos(angle) * reach, minf(-64.0, -26.0 - global_position.y), sin(angle) * reach)))
	_multi("CloudDeck", meshes["Cloud"], clouds)
	var mesas: Array[Transform3D] = []
	for k in 7:
		var angle := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var reach := rng.randf_range(SKY_RING, SKY_RING + 80.0)
		var scale := rng.randf_range(2.0, 3.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		mesas.append(Transform3D(basis, Vector3(cos(angle) * reach, -100.0, sin(angle) * reach)))
	_multi("DistantMesas", meshes["Mesa"], mesas)


func _apply_environment(terrain, root: Node) -> void:
	if terrain == null or terrain.environment == null:
		return
	var env: Environment = terrain.environment
	var sun: DirectionalLight3D
	for light in root.find_children("*", "DirectionalLight3D", true, false):
		if light.name != "SkyFill":
			sun = light
			break
	var look: Dictionary = WorldLook.ARENAS.mind
	if _sky_material == null:
		_sky_material = PaletteMaterials.time_sky_material(_make_panorama())
		var graded := WorldLook.grade(look)
		for key in graded:
			_sky_material.set(key, graded[key])
	var sky := Sky.new()
	sky.sky_material = _sky_material
	var values := WorldLook.environment(look, GraphicsPreset.PRESETS[GraphicsPreset.current].air)
	values["sky"] = sky
	_saved = GraphicsPreset.set_lighting(self, env, values, WorldLook.lights(look, sun), "arena", look)


func restore_environment() -> void:
	GraphicsPreset.release_lighting(get_instance_id())
	_saved = {}


func release() -> void:
	restore_environment()
	for row in _greybox:
		if is_instance_valid(row["view"]):
			row["view"].visible = row["visible"]
	_greybox.clear()


func _exit_tree() -> void:
	release()


static func _make_panorama() -> ImageTexture:
	if _panorama_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_panorama_task)
		_panorama_task = -1
	var image: Image = _panorama_out.get("image")
	_panorama_out = {}
	if image == null:
		image = _paint_panorama()
	return ImageTexture.create_from_image(image)


static func _paint_panorama() -> Image:
	var image := Image.create_empty(512, 256, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 301006
	noise.frequency = 1.0
	noise.fractal_octaves = 2
	var haze := Color("72829c")
	var high := Color("566682")
	var cream := Color("f2dec4")
	for y in 256:
		var elevation := (0.5 - float(y) / 255.0) * PI
		for x in 512:
			var angle := float(x) / 512.0 * TAU
			var color := haze.lerp(high, clampf(elevation * 2.2, 0.0, 1.0))
			if elevation < 0.0:
				color = haze.lerp(cream, clampf(-elevation * 9.0, 0.0, 1.0))
			elif elevation > 0.05:
				var direction := Vector3(cos(angle) * cos(elevation), sin(elevation), sin(angle) * cos(elevation))
				var cloud := noise.get_noise_3d(direction.x * 4.0, direction.y * 9.0, direction.z * 4.0)
				color = color.lerp(cream, smoothstep(0.3, 0.55, cloud) * smoothstep(0.05, 0.25, elevation) * 0.7)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return image
