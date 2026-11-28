class_name CraftLookdev
extends RefCounted


const FlashGuard := preload("res://src/core/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")

const MASTER_SHADER_PATH := "res://assets/shaders/craft_master_weathering.gdshader"
const FLOOR_SHADER_PATH := "res://assets/shaders/craft_combat_floor.gdshader"
const DETAIL_INC_PATH := "res://assets/shaders/craft_triplanar_detail.gdshaderinc"

const PRESET_PATHS := {
	"oxidized_hull_plating": "res://assets/materials/craft/oxidized_hull_plating.tres",
	"oil_slicked_iron": "res://assets/materials/craft/oil_slicked_iron.tres",
	"scorched_concrete": "res://assets/materials/craft/scorched_concrete.tres",
	"plasma_conduit_core": "res://assets/materials/craft/plasma_conduit_core.tres",
	"combat_floor_apron": "res://assets/materials/craft/combat_floor_apron.tres",
}

const ROLE_ALIASES := {
	"hull": "oxidized_hull_plating",
	"fleet_hull": "oxidized_hull_plating",
	"oxidized_hull": "oxidized_hull_plating",
	"hull_plating": "oxidized_hull_plating",
	"patch_oxide": "oxidized_hull_plating",
	"copper_coil": "oxidized_hull_plating",
	"iron": "oil_slicked_iron",
	"iron_frame": "oil_slicked_iron",
	"machinery_iron": "oil_slicked_iron",
	"cable_rubber": "oil_slicked_iron",
	"concrete": "scorched_concrete",
	"concrete_plinth": "scorched_concrete",
	"dam_concrete": "scorched_concrete",
	"conduit": "plasma_conduit_core",
	"plasma_core": "plasma_conduit_core",
	"emissive_core": "plasma_conduit_core",
	"floor": "combat_floor_apron",
	"combat_floor": "combat_floor_apron",
	"apron": "combat_floor_apron",
}

const HERO_SURFACE_PRESETS := {
	"hull_plating": "oxidized_hull_plating",
	"iron_frame": "oil_slicked_iron",
	"copper_coil": "oxidized_hull_plating",
	"patch_oxide": "oxidized_hull_plating",
	"concrete_plinth": "scorched_concrete",
	"emissive_core": "plasma_conduit_core",
	"cable_rubber": "oil_slicked_iron",
}

static var _cache: Dictionary = {}
static var _unmasked_cache: Dictionary = {}
static var _micro_normal_tex: ImageTexture = null


static func reset_for_tests() -> void:
	for id in _cache:
		var mat := _cache[id] as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path == MASTER_SHADER_PATH:
			mat.set_shader_parameter("reduce_flashes", false)
	_cache.clear()
	_unmasked_cache.clear()
	_micro_normal_tex = null


static func preset_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in PRESET_PATHS.keys():
		out.append(String(id))
	return out


static func resolve_id(name_or_alias: String) -> String:
	var key := name_or_alias.strip_edges().to_lower()
	if PRESET_PATHS.has(key):
		return key
	if ROLE_ALIASES.has(key):
		return String(ROLE_ALIASES[key])
	return ""


static func preset_path(name_or_alias: String) -> String:
	var id := resolve_id(name_or_alias)
	if id == "":
		return ""
	return String(PRESET_PATHS[id])


static func encode_mask(edge_wear: float, cavity_grime: float, emissive: float = 0.0, weight: float = 1.0) -> Color:
	return Color(
		clampf(edge_wear, 0.0, 1.0),
		clampf(cavity_grime, 0.0, 1.0),
		clampf(emissive, 0.0, 1.0),
		clampf(weight, 0.0, 1.0),
	)


static func has_vertex_color_masks(mesh: Mesh, surface_idx: int = 0) -> bool:
	if not (mesh is ArrayMesh) or surface_idx < 0 or surface_idx >= mesh.get_surface_count():
		return false
	return ((mesh as ArrayMesh).surface_get_format(surface_idx) & Mesh.ARRAY_FORMAT_COLOR) != 0


static func duplicate_preset(preset_id: String, res_name: String) -> ShaderMaterial:
	var base := preset_material(preset_id)
	if base == null:
		return null
	var copy := base.duplicate(false) as ShaderMaterial
	copy.resource_name = res_name
	return copy


static func bind_surface_materials(mi: MeshInstance3D, materials: Callable) -> int:
	if mi == null or mi.mesh == null or not (mi.mesh is ArrayMesh):
		return 0
	var am := mi.mesh as ArrayMesh
	var count := am.get_surface_count()
	var bound := 0
	mi.material_override = null
	for i in count:
		var slot := am.surface_get_name(i)
		var mat: Material = materials.call(slot)
		if mat != null:
			mi.set_surface_override_material(i, mat)
			bound += 1
	return bound


static func preset_material(name_or_alias: String) -> ShaderMaterial:
	var id := resolve_id(name_or_alias)
	if id == "":
		push_warning("CraftLookdev: unknown material preset '%s'" % name_or_alias)
		return null
	if _cache.has(id):
		var cached := _cache[id] as ShaderMaterial
		_apply_flash_guard(cached, FlashGuard.on)
		return cached
	var path := String(PRESET_PATHS[id])
	var mat := load(path) as ShaderMaterial
	if mat == null:
		push_warning("CraftLookdev: failed to load ShaderMaterial at '%s'" % path)
		return null
	_apply_flash_guard(mat, FlashGuard.on)
	_cache[id] = mat
	return mat


static func make_unmasked_variant(name_or_alias: String) -> ShaderMaterial:
	var id := resolve_id(name_or_alias)
	if id == "":
		return null
	if _unmasked_cache.has(id):
		var cached := _unmasked_cache[id] as ShaderMaterial
		_apply_flash_guard(cached, FlashGuard.on)
		return cached
	var base := preset_material(id)
	if base == null:
		return null
	var copy := base.duplicate(false) as ShaderMaterial
	if copy.shader != null and copy.shader.resource_path == MASTER_SHADER_PATH:
		copy.set_shader_parameter("use_vertex_masks", false)
	elif copy.shader != null and copy.shader.resource_path == FLOOR_SHADER_PATH:
		copy.set_shader_parameter("use_vertex_grime", false)
	copy.resource_name = id + "_unmasked"
	_apply_flash_guard(copy, FlashGuard.on)
	_unmasked_cache[id] = copy
	return copy


static func bind_mesh(node: MeshInstance3D, preset_id: String, surface_idx: int = -1, auto_unmask: bool = true) -> ShaderMaterial:
	if node == null:
		return null
	var shared := preset_material(preset_id)
	if shared == null:
		return null
	if node.mesh == null:
		node.material_override = shared
		return shared
	var count := node.mesh.get_surface_count()
	if count <= 0:
		node.material_override = shared
		return shared
	if surface_idx >= 0:
		if surface_idx >= count:
			push_warning("CraftLookdev: surface index %d out of range (%d)" % [surface_idx, count])
			return null
		var chosen := _choose_for_surface(node.mesh, surface_idx, preset_id, shared, auto_unmask)
		node.set_surface_override_material(surface_idx, chosen)
		return chosen
	node.material_override = null
	var last_mat: ShaderMaterial = shared
	for i in count:
		var chosen := _choose_for_surface(node.mesh, i, preset_id, shared, auto_unmask)
		node.set_surface_override_material(i, chosen)
		last_mat = chosen
	return last_mat


static func bind_mesh_surfaces(node: MeshInstance3D, surface_presets: Dictionary, fallback_preset: String = "", auto_unmask: bool = true) -> int:
	if node == null or node.mesh == null:
		return 0
	var bound := 0
	var count := node.mesh.get_surface_count()
	node.material_override = null
	for i in count:
		var preset_id := ""
		if surface_presets.has(i):
			preset_id = String(surface_presets[i])
		else:
			var sname := (node.mesh as ArrayMesh).surface_get_name(i) if node.mesh is ArrayMesh else ""
			if sname != "" and surface_presets.has(sname):
				preset_id = String(surface_presets[sname])
			elif fallback_preset != "":
				preset_id = fallback_preset
		if preset_id == "":
			continue
		if bind_mesh(node, preset_id, i, auto_unmask) != null:
			bound += 1
	return bound


static func bind_hero_mesh(node: MeshInstance3D, fallback_preset: String = "oxidized_hull_plating", auto_unmask: bool = true) -> int:
	return bind_mesh_surfaces(node, HERO_SURFACE_PRESETS, fallback_preset, auto_unmask)


static func bind_tree(root_node: Node, default_preset: String = "", meta_key: String = "craft_preset", auto_unmask: bool = true) -> int:
	if root_node == null:
		return 0
	var bound := 0
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var cur := stack.pop_back() as Node
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var target := ""
			if mi.has_meta(meta_key):
				target = String(mi.get_meta(meta_key))
			elif default_preset != "":
				target = default_preset
			if target != "" and bind_mesh(mi, target, -1, auto_unmask) != null:
				bound += 1
		for child in cur.get_children():
			stack.append(child)
	return bound


static func sync_flash_guard(reduce_flashes: bool = FlashGuard.on) -> void:
	for id in PRESET_PATHS:
		var mat := _cache.get(id) as ShaderMaterial
		if mat != null:
			_apply_flash_guard(mat, reduce_flashes)
		var um := _unmasked_cache.get(id) as ShaderMaterial
		if um != null:
			_apply_flash_guard(um, reduce_flashes)


static func _choose_for_surface(mesh: Mesh, surface_idx: int, preset_id: String, shared: ShaderMaterial, auto_unmask: bool) -> ShaderMaterial:
	if auto_unmask and not has_vertex_color_masks(mesh, surface_idx):
		var variant := make_unmasked_variant(preset_id)
		if variant != null:
			return variant
	return shared


static func _apply_flash_guard(mat: ShaderMaterial, reduce_flashes: bool) -> void:
	if mat == null or mat.shader == null:
		return
	if mat.shader.resource_path == MASTER_SHADER_PATH:
		mat.set_shader_parameter("reduce_flashes", reduce_flashes)


static func micro_normal_texture() -> ImageTexture:
	if _micro_normal_tex != null:
		return _micro_normal_tex
	var sz := 128
	var noise := FastNoiseLite.new()
	noise.seed = 40731
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var h := noise.get_seamless_image(sz, sz)
	var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGB8)
	for y in sz:
		var ym := (y - 1 + sz) % sz
		var yp := (y + 1) % sz
		for x in sz:
			var xm := (x - 1 + sz) % sz
			var xp := (x + 1) % sz
			var dx := (h.get_pixel(xp, y).r - h.get_pixel(xm, y).r) * 2.2
			var dy := (h.get_pixel(x, yp).r - h.get_pixel(x, ym).r) * 2.2
			var n := Vector3(-dx, -dy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	_micro_normal_tex = ImageTexture.create_from_image(img)
	return _micro_normal_tex


static func make_weathered_pbr(
	albedo: Color,
	roughness: float = 0.72,
	metallic: float = 0.24,
	emit_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	emit_energy: float = 0.0,
	triplanar_scale: float = 0.35,
	normal_scale: float = 0.42
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.albedo_texture = Palette.painted_texture(256)
	mat.roughness = roughness
	mat.roughness_texture = Palette.painted_texture(256)
	mat.metallic = metallic
	mat.normal_enabled = true
	mat.normal_texture = micro_normal_texture()
	mat.normal_scale = normal_scale
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * triplanar_scale
	if emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emit_color
		mat.emission_energy_multiplier = emit_energy
	return mat


static func enrich_standard_pbr(mat: StandardMaterial3D, normal_scale: float = 0.38, triplanar_scale: float = 0.22) -> StandardMaterial3D:
	if mat == null:
		return null
	if mat.albedo_texture == null:
		mat.albedo_texture = Palette.painted_texture(256)
	if mat.roughness_texture == null:
		mat.roughness_texture = Palette.painted_texture(256)
	mat.normal_enabled = true
	if mat.normal_texture == null:
		mat.normal_texture = micro_normal_texture()
	mat.normal_scale = normal_scale
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * triplanar_scale
	return mat
