extends RefCounted

const VERTEX_BAKED := ["paint", "pilot", "ancient_enamel", "hydraulic"]
const AO_STRENGTH := 0.55
const EDGE := 0.18
const RAMP := 256
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const LIFT_SLOTS := ["fleet_paint"]
const LIFT := 0.55
const LIFT_FROM := 0.2
const RIM := 0.45
const RIM_POWER := 3.0
const SKY_TINT := Color("c4d2e8")
const SKY_GLOW := 0.18
const BRASS_SLOTS := ["brass", "requisition_tag"]
const LIFT_SHADER := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 bone : source_color;
uniform vec4 sky : source_color;
uniform float lift = 0.55;
uniform float from = 0.2;
uniform float rim = 0.45;
uniform float rim_power = 3.0;
uniform float glow = 0.18;
void fragment() {
	// UV2.y is the bake's wear with glTF's flipped V: 0.5 neutral, 0 the most worn convex edge, 1 the deepest crease.
	float worn = clamp((0.5 - UV2.y) * 2.0, 0.0, 1.0);
	float edge = lift * smoothstep(from, 1.0, worn);
	float side = rim * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float a = max(edge, side);
	if (a < 0.004) {
		discard;
	}
	ALBEDO = bone.rgb;
	ROUGHNESS = 0.9;
	EMISSION = sky.rgb * glow;
	ALPHA = a;
}
"""

static var _ramp: ImageTexture
static var _twins := {}
static var _lift: ShaderMaterial


static func edge_lift() -> ShaderMaterial:
	if _lift == null:
		var shader := Shader.new()
		shader.code = LIFT_SHADER
		_lift = ShaderMaterial.new()
		_lift.shader = shader
		_lift.resource_name = "edge_lift"
		_lift.set_shader_parameter("bone", Palette.SAND)
		_lift.set_shader_parameter("lift", LIFT)
		_lift.set_shader_parameter("from", LIFT_FROM)
		_lift.set_shader_parameter("rim", RIM)
		_lift.set_shader_parameter("rim_power", RIM_POWER)
		_lift.set_shader_parameter("sky", SKY_TINT)
		_lift.set_shader_parameter("glow", SKY_GLOW)
	return _lift


static func lift_alpha(wear_v: float, facing := 1.0) -> float:
	var edge := LIFT * smoothstep(LIFT_FROM, 1.0, clampf((0.5 - wear_v) * 2.0, 0.0, 1.0))
	var a := maxf(edge, RIM * pow(1.0 - clampf(facing, 0.0, 1.0), RIM_POWER))
	return a if a >= 0.004 else 0.0


static func finish_of(mesh: Mesh, surface: int) -> String:
	if not (mesh is ArrayMesh):
		return ""
	var slot := (mesh as ArrayMesh).surface_get_name(surface)
	if slot in LIFT_SLOTS:
		return "lift"
	if slot in BRASS_SLOTS:
		return "brass"
	return ""


static func finish(mat: StandardMaterial3D, kind: String) -> void:
	if kind == "lift":
		mat.next_pass = edge_lift()
	elif kind == "brass":
		Palette.brass_finish(mat)


# glTF flips V, so y=0 is convex wear and y=1 is deepest crease.
static func ramp() -> ImageTexture:
	if _ramp == null:
		var img := Image.create_empty(RAMP, RAMP, false, Image.FORMAT_RGB8)
		for j in RAMP:
			var wear := (1.0 - float(j) / (RAMP - 1) * 2.0) * EDGE
			for i in RAMP:
				var occluded := 1.0 - float(i) / (RAMP - 1)
				var shade := minf((1.0 - AO_STRENGTH * occluded) * (1.0 + wear), 1.0)
				img.set_pixel(i, j, Color(shade, shade, shade))
		_ramp = ImageTexture.create_from_image(img)
	return _ramp


static func has_bake(mesh: Mesh, surface: int) -> bool:
	return mesh is ArrayMesh and (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0


static func vertex_baked(mesh: Mesh, surface: int) -> bool:
	return mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_name(surface) in VERTEX_BAKED


static func apply(mat: StandardMaterial3D) -> void:
	if mat.get_meta("bake_look", false):
		return
	Palette.smooth(mat)
	mat.detail_enabled = true
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = ramp()
	mat.detail_mask = null
	mat.uv2_triplanar = false
	mat.uv2_world_triplanar = false
	mat.uv2_scale = Vector3(RAMP - 1.0, RAMP - 1.0, RAMP) / RAMP
	mat.uv2_offset = Vector3(0.5, 0.5, 0.0) / RAMP
	mat.set_meta("bake_look", true)


static func twin(mat: StandardMaterial3D, shade := true, kind := "") -> StandardMaterial3D:
	if mat.get_meta("bake_look", false) or mat.get_meta("bake_smooth", false):
		return mat
	var key := [mat.get_instance_id(), shade, kind]
	if not _twins.has(key) or not is_instance_valid(_twins[key]):
		var copy := mat.duplicate() as StandardMaterial3D
		if shade:
			apply(copy)
		else:
			Palette.smooth(copy)
			copy.set_meta("bake_smooth", true)
		finish(copy, kind)
		_twins[key] = copy
	return _twins[key]


static func unbaked(mat: Material) -> Material:
	if not (mat is StandardMaterial3D and mat.get_meta("bake_look", false)):
		return mat
	var key := [mat.get_instance_id(), "unbaked"]
	if not _twins.has(key) or not is_instance_valid(_twins[key]):
		var copy := mat.duplicate() as StandardMaterial3D
		copy.detail_enabled = false
		copy.detail_albedo = null
		copy.next_pass = null
		copy.set_meta("bake_look", false)
		_twins[key] = copy
	return _twins[key]


static func _warning(mat: StandardMaterial3D) -> bool:
	return mat == Palette.hazard_stripe() or mat.get_meta("no_bake", false) \
		or (mat.albedo_texture != null and mat.albedo_texture == Threat.Painter.stripe_texture())


static func dress(root: Node, owned: Array = []) -> int:
	var views: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		views.append(root)
	var wants := {}
	var finishes := {}
	for view: MeshInstance3D in views:
		if view.mesh == null:
			continue
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i)
			if not wants.has(mat):
				wants[mat] = {}
				finishes[mat] = {}
			wants[mat][_look(view.mesh, i)] = true
			finishes[mat][finish_of(view.mesh, i)] = true
	var dressed := 0
	for view: MeshInstance3D in views:
		if view.mesh == null:
			continue
		view.mesh = tangent_safe(view.mesh)
		var mesh := view.mesh
		for i in mesh.get_surface_count():
			var look := _look(mesh, i)
			var kind := finish_of(mesh, i)
			var mat := view.get_active_material(i)
			if look == 0 or not (mat is StandardMaterial3D) or mat.get_meta("bake_look", false) \
					or mat.get_meta("bake_smooth", false) or _warning(mat):
				continue
			if mat in owned:
				if wants[mat].size() > 1:
					continue
				if look == 1:
					apply(mat)
				else:
					Palette.smooth(mat)
					mat.set_meta("bake_smooth", true)
				if finishes[mat].size() == 1:
					finish(mat, kind)
			elif view.material_override == mat:
				if wants[mat].size() > 1:
					continue
				view.material_override = twin(mat, look == 1, kind if finishes[mat].size() == 1 else "")
			elif view.get_surface_override_material(i) == mat:
				view.set_surface_override_material(i, twin(mat, look == 1, kind))
			else:
				mesh.surface_set_material(i, twin(mat, look == 1, kind))
			dressed += 1
	return dressed


static func warm_view(view: MeshInstance3D) -> void:
	if view.mesh == null:
		return
	var mesh := tangent_safe(view.mesh)
	for i in mesh.get_surface_count():
		var look := _look(mesh, i)
		var mat := view.get_active_material(i)
		if look != 0 and mat is StandardMaterial3D and not _warning(mat):
			twin(mat, look == 1, finish_of(mesh, i))


static func tangent_safe(mesh: Mesh) -> Mesh:
	if not (mesh is ArrayMesh) or mesh.get_meta("bake_tangents_ok", false) or mesh.has_meta("ink_hull_of"):
		return mesh
	if mesh.has_meta("bake_safe"):
		return mesh.get_meta("bake_safe")
	var source := mesh as ArrayMesh
	var fix := []
	var plain := source.get_blend_shape_count() == 0
	for i in source.get_surface_count():
		fix.append(_tangent_fix(source, i) if _look(source, i) == 1 else 0)
		plain = plain and (source.surface_get_format(i) & _CUSTOM) == 0
	if (not fix.has(1) and not fix.has(2)) or not plain:
		mesh.set_meta("bake_tangents_ok", true)
		return mesh
	var out := ArrayMesh.new()
	out.resource_name = source.resource_name
	for i in source.get_surface_count():
		var arrays := source.surface_get_arrays(i)
		if fix[i] > 0:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			tangents.resize(normals.size() * 4)
			for v in normals.size():
				var n := normals[v]
				if fix[i] == 1 and not _bad(Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2]), n):
					continue
				var t := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
				tangents[v * 4] = t.x
				tangents[v * 4 + 1] = t.y
				tangents[v * 4 + 2] = t.z
				tangents[v * 4 + 3] = 1.0
			arrays[Mesh.ARRAY_TANGENT] = tangents
		out.add_surface_from_arrays(source.surface_get_primitive_type(i), arrays, [], _lods(source, i),
			source.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		if out.get_surface_count() != i + 1:
			mesh.set_meta("bake_tangents_ok", true)
			return mesh
		out.surface_set_name(i, source.surface_get_name(i))
		out.surface_set_material(i, source.surface_get_material(i))
	out.custom_aabb = source.custom_aabb
	out.shadow_mesh = source.shadow_mesh
	out.set_meta("bake_tangents_ok", true)
	mesh.set_meta("bake_safe", out)
	return out


const _CUSTOM := Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3


static func _tangent_fix(mesh: ArrayMesh, surface: int) -> int:
	var format := mesh.surface_get_format(surface)
	if (format & Mesh.ARRAY_FORMAT_NORMAL) == 0:
		return 0
	if (format & Mesh.ARRAY_FORMAT_TANGENT) == 0:
		return 2
	var arrays := mesh.surface_get_arrays(surface)
	if (format & Mesh.ARRAY_FORMAT_TEX_UV) == 0:
		return 2
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var single := true
	for uv in uvs:
		if not uv.is_equal_approx(uvs[0]):
			single = false
			break
	if single:
		return 2
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for v in normals.size():
		if _bad(Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2]), normals[v]):
			return 1
	return 0


static func _bad(tangent: Vector3, normal: Vector3) -> bool:
	return tangent.length() < 0.5 or absf(tangent.normalized().dot(normal)) > 0.9


static func _lods(mesh: ArrayMesh, surface: int) -> Dictionary:
	var lods := {}
	var count := mesh.surface_get_array_len(surface)
	var wide := count > 65536
	for lod in RenderingServer.mesh_get_surface(mesh.get_rid(), surface).get("lods", []):
		var data: PackedByteArray = lod.get("index_data", PackedByteArray())
		var indices := (data.to_int32_array() if wide else _u16(data))
		if indices.is_empty() or indices.size() % 3 != 0:
			continue
		var ok := true
		for index in indices:
			if index < 0 or index >= count:
				ok = false
				break
		if ok:
			lods[float(lod.get("edge_length", 0.0))] = indices
	return lods


static func _u16(data: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(data.size() / 2)
	for i in out.size():
		out[i] = data.decode_u16(i * 2)
	return out


static func _look(mesh: Mesh, surface: int) -> int:
	if not has_bake(mesh, surface):
		return 0
	return 2 if vertex_baked(mesh, surface) else 1
