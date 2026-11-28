extends RefCounted

const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")


const INK := Color(0.08, 0.09, 0.11)
const ROLES := ["pilot", "enemy", "warden", "boss"]
const WIDTH_PX := {"pilot": 1.75, "enemy": 2.0, "warden": 2.5, "boss": 3.4}
const WIDTH_CAP := {"pilot": 0.036, "enemy": 0.072, "warden": 0.135, "boss": 0.22}
const FADE_FROM := 65.0
const FADE_TO := 95.0
const FADE_RANGE := {
	"pilot": Vector2(85.0, 150.0),
	"enemy": Vector2(80.0, 145.0),
	"warden": Vector2(FADE_FROM, FADE_TO),
	"boss": Vector2(115.0, 185.0),
}
const BOSS_KINDS := ["boss", "brindle", "waking", "mind"]
const SKIP_NAMES := ["glass", "lens", "glow", "canopy", "window", "visor", "lamp", "screen", "flame", "class_accent", "kest_fuse",
	"ancient_light", "hazard", "weak_point", "puff", "dust", "smoke", "plume", "trail", "vfx", "jet", "spark", "mote", "dunk"]
const SKIP_NODES := ["Cockpit", "Control"]
const GLOW_LIMIT := 0.3
const WELD := 0.0001
const _CUSTOM := Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3

# Godot skins NORMAL and TANGENT, never CUSTOM0; skinned welded normals use the N/T frame (CUSTOM0.w > 0.5).
const SHADER := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, skip_vertex_transform;
uniform vec4 ink : source_color = vec4(0.08, 0.09, 0.11, 1.0);
uniform float width_px = 1.8;
uniform float width_cap = 0.06;
uniform float fade_from = 65.0;
uniform float fade_to = 95.0;
%s
void vertex() {
	%s
	vec3 welded = CUSTOM0.xyz;
	float has = step(0.25, dot(welded, welded));
	if (CUSTOM0.w > 0.5) {
		// A bone may scale a frame unevenly: square it up before reading the welded normal back out of it.
		vec3 n = normalize(NORMAL);
		vec3 t = TANGENT - n * dot(n, TANGENT);
		t = dot(t, t) > 1e-8 ? normalize(t) : normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		welded = t * welded.x + cross(n, t) * welded.y + n * welded.z;
	}
	vec3 at = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 out_dir = normalize(MODELVIEW_NORMAL_MATRIX * mix(vec3(0.0, 0.0, 1.0), welded, has));
	float depth = max(-at.z, 0.01);
	// The renderer may flip Y in the projection, so its scale is read unsigned.
	float per_px = 2.0 * depth / (VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]));
	float w = min(width_px * per_px, width_cap) * (1.0 - smoothstep(fade_from, fade_to, depth)) * has;
	// Out along the welded normal, then back along the eye's ray by as much: the rim keeps its place on screen but
	// tucks behind the body's own creases instead of crossing them.
	at += out_dir * w + normalize(at) * w;
	VERTEX = at;
	NORMAL = out_dir;
	POSITION = PROJECTION_MATRIX * vec4(at, 1.0);
	if (IN_SHADOW_PASS || w <= 0.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	}
	%s
}
void fragment() {
	%s
	ALBEDO = ink.rgb;
}
"""
const CUT_UNIFORMS := """uniform float window = 0.76;
uniform bool held = false;
uniform vec3 centre_at = vec3(0.0);
uniform vec3 centre_local = vec3(0.0);
uniform float keep_within = 0.0;
uniform float tube = 0.0;
uniform bool back_is_kit = false;
uniform float seat_back_top = 9.0;
uniform float back_above = -0.08;
uniform float back_behind = 0.05;
varying vec3 local_pos;
varying float model_scale;
varying vec3 from_centre;
varying vec3 to_camera;"""
const CUT_VERTEX_IN := """if (VERTEX.y > seat_back_top && VERTEX.y < -0.05 && abs(VERTEX.x) < 0.26 && VERTEX.z > 0.13 && VERTEX.z < 0.27) {
		VERTEX.y = seat_back_top;
	}
	local_pos = VERTEX;"""
const CUT_VERTEX_OUT := """model_scale = length(MODEL_MATRIX[0].xyz);
	vec3 centre = held ? centre_at : (MODEL_MATRIX * vec4(centre_local, 1.0)).xyz;
	from_centre = (INV_VIEW_MATRIX * vec4(at, 1.0)).xyz - centre;
	to_camera = CAMERA_POSITION_WORLD - centre;"""
const CUT_FRAGMENT := """float facing = dot(normalize(from_centre), normalize(to_camera));
	if (tube > 0.0) {
		vec3 axis = normalize(to_camera);
		float along = dot(from_centre, axis) / model_scale;
		float across = length(from_centre / model_scale - axis * along);
		facing = along > 0.0 ? sqrt(max(0.0, 1.0 - (across / tube) * (across / tube))) : -1.0;
	}
	vec3 seat_pos = local_pos - centre_local;
	bool cockpit = length(from_centre) < keep_within * model_scale;
	if (cockpit && back_is_kit && seat_pos.y > back_above && seat_pos.z > back_behind) {
		cockpit = false;
	}
	if (!cockpit && facing > window) {
		discard;
	}"""
const CUT_PARAMETERS := ["window", "held", "centre_at", "centre_local", "keep_within", "tube", "back_is_kit", "seat_back_top",
	"back_above", "back_behind"]

static var enabled := true
static var _shaders := {}
static var _inks := {}
static var _lifts := {}
static var _stripped := {}


static func apply(root: Node, role := "enemy", owned: Array = []) -> int:
	if not enabled or root == null:
		return 0
	if not role in ROLES:
		role = "enemy"
	var views: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		views.append(root)
	var lined := 0
	for view: MeshInstance3D in views:
		if view.mesh == null or _sheltered(view, root) or view.transparency > 0.0 or view.get_meta("no_ink", false) or _named_off(String(view.name)):
			continue
		var wanted := []
		for i in view.mesh.get_surface_count():
			if drawable(view.mesh, i, view.get_active_material(i)):
				wanted.append(i)
		if wanted.is_empty():
			continue
		var mesh := hull(view.mesh)
		if mesh == null:
			continue
		if view.mesh != mesh:
			view.mesh = mesh
		for i: int in wanted:
			if _line(view, i, role, owned):
				lined += 1
	return lined


static func strip(mat: Material) -> Material:
	if mat == null:
		return null
	if mat.has_meta("ink_source"):
		var source := instance_from_id(mat.get_meta("ink_source")) as Material
		if source != null:
			return source
	if mat.next_pass == null or not mat.next_pass.has_meta("ink_role"):
		return mat
	var key := mat.get_instance_id()
	if not _stripped.has(key) or not is_instance_valid(_stripped[key]):
		var copy := mat.duplicate() as Material
		copy.next_pass = BakeLook.edge_lift() if mat.next_pass.has_meta("ink_lift") else null
		_stripped[key] = copy
	return _stripped[key]


static func reset_for_tests() -> void:
	enabled = true
	_inks.clear()
	_lifts.clear()
	_stripped.clear()


static func role_for(kind: String) -> String:
	var low := kind.to_lower()
	if low in BOSS_KINDS:
		return "boss"
	if low in ["warden", "miniboss"]:
		return "warden"
	if low == "pilot":
		return "pilot"
	return "enemy"


static func fade_range(role: String) -> Vector2:
	if not role in ROLES:
		role = "enemy"
	return FADE_RANGE[role]


static func ink(role: String) -> ShaderMaterial:
	if not role in ROLES:
		role = "enemy"
	if not _inks.has(role):
		var fade := fade_range(role)
		var mat := ShaderMaterial.new()
		mat.shader = _shader_for(false)
		mat.resource_name = "ink_" + role
		mat.set_shader_parameter("ink", INK)
		mat.set_shader_parameter("width_px", WIDTH_PX[role])
		mat.set_shader_parameter("width_cap", WIDTH_CAP[role])
		mat.set_shader_parameter("fade_from", fade.x)
		mat.set_shader_parameter("fade_to", fade.y)
		mat.set_meta("ink_role", role)
		_inks[role] = mat
	return _inks[role]


static func width_at(role: String, depth: float, per_px: float) -> float:
	if not role in ROLES:
		role = "enemy"
	var fade := fade_range(role)
	return minf(WIDTH_PX[role] * per_px, WIDTH_CAP[role]) * (1.0 - smoothstep(fade.x, fade.y, depth))


static func drawable(mesh: Mesh, surface: int, mat: Material) -> bool:
	if mat == null or mat.has_meta("ink_role"):
		return false
	if mesh is ArrayMesh and _named_off((mesh as ArrayMesh).surface_get_name(surface)):
		return false
	if _named_off(mat.resource_name) or mat.get_meta("no_bake", false) or mat.get_meta("no_ink", false):
		return false
	if mat is BaseMaterial3D:
		var base := mat as BaseMaterial3D
		if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.albedo_color.a < 0.99 or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				or base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
			return false
		if base.emission_enabled and base.emission.get_luminance() * base.emission_energy_multiplier > GLOW_LIMIT:
			return false
		return not (mat == PaletteMaterials.hazard_stripe() or (base.albedo_texture != null and base.albedo_texture == Threat.Painter.stripe_texture()))
	if mat is ShaderMaterial:
		var shader := (mat as ShaderMaterial).shader
		if shader == null:
			return false
		var code := shader.code
		if code == BallLooks.CUTAWAY_SHADER:
			return true
		for mark in ["unshaded", "blend_add", "blend_sub", "blend_mul", "depth_draw_never", "ALPHA", "discard"]:
			if code.contains(mark):
				return false
		return true
	return false


static func hull(mesh: Mesh) -> Mesh:
	if mesh == null or mesh.has_meta("ink_hull_of"):
		return mesh
	if mesh.has_meta("ink_hull"):
		return mesh.get_meta("ink_hull") as Mesh if mesh.get_meta("ink_hull") is Mesh else null
	var made := _weld(mesh)
	mesh.set_meta("ink_hull", made if made != null else false)
	return made


static func _weld(mesh: Mesh) -> ArrayMesh:
	if not (mesh is ArrayMesh) or mesh.get_blend_shape_count() > 0:
		return null
	var source := mesh as ArrayMesh
	var surfaces := []
	var packed := false
	for i in source.get_surface_count():
		var format := source.surface_get_format(i)
		packed = packed or (format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0
		if source.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES or (format & _CUSTOM) != 0 \
				or (format & Mesh.ARRAY_FORMAT_NORMAL) == 0:
			return null
		surfaces.append(source.surface_get_arrays(i))
	var sums := {}
	var seen := {}
	for arrays: Array in surfaces:
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for v in points.size():
			var key := points[v].snappedf(WELD)
			var n := normals[v].normalized()
			var known: PackedVector3Array = seen.get(key, PackedVector3Array())
			var fresh := true
			for k in known:
				if k.dot(n) > 0.999:
					fresh = false
					break
			if fresh:
				known.append(n)
				seen[key] = known
				sums[key] = sums.get(key, Vector3.ZERO) + n
	var out := ArrayMesh.new()
	out.resource_name = source.resource_name
	out.blend_shape_mode = source.blend_shape_mode
	for i in surfaces.size():
		var arrays: Array = surfaces[i]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents = arrays[Mesh.ARRAY_TANGENT]
		var skinned: bool = arrays[Mesh.ARRAY_BONES] != null and tangents != null
		var custom := PackedFloat32Array()
		custom.resize(points.size() * 4)
		for v in points.size():
			var welded: Vector3 = sums[points[v].snappedf(WELD)]
			welded = welded.normalized() if welded.length_squared() > 1e-8 else normals[v].normalized()
			var frame := 0.0
			if skinned:
				var n := normals[v].normalized()
				var t := Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])
				t = t - n * n.dot(t)
				t = t.normalized() if t.length_squared() > 1e-8 else n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
				welded = Vector3(welded.dot(t), welded.dot(n.cross(t)), welded.dot(n))
				frame = 1.0
			custom[v * 4] = welded.x
			custom[v * 4 + 1] = welded.y
			custom[v * 4 + 2] = welded.z
			custom[v * 4 + 3] = frame
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (source.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], _lods(source, i), flags)
		if out.get_surface_count() != i + 1:
			return null
		out.surface_set_name(i, source.surface_get_name(i))
		out.surface_set_material(i, source.surface_get_material(i))
	out.custom_aabb = source.custom_aabb
	if not packed:
		out.shadow_mesh = source.shadow_mesh
	if source.get_meta("bake_tangents_ok", false):
		out.set_meta("bake_tangents_ok", true)
	out.set_meta("ink_hull_of", source.get_instance_id())
	return out


static func _line(view: MeshInstance3D, surface: int, role: String, owned: Array) -> bool:
	var mat := view.get_active_material(surface)
	if mat == null:
		return false
	if mat.has_meta("ink_source") or (mat.next_pass != null and mat.next_pass.has_meta("ink_role")):
		return true
	if mat in owned or mat is ShaderMaterial:
		return _chain(mat, role, _cut_ink(mat, role) if _cutaway(mat) else ink(role))
	var twin := _twin(mat, role)
	if twin == null:
		return false
	if view.material_override == mat:
		view.material_override = twin
	else:
		view.set_surface_override_material(surface, twin)
	return true


static func _twin(mat: Material, role: String) -> Material:
	var key := "ink_twin_" + role
	var twin := mat.get_meta(key) as Material if mat.has_meta(key) else null
	if twin == null or twin.get_meta("ink_source", 0) != mat.get_instance_id() \
			or not (twin.next_pass == ink(role) or twin.next_pass == _lift(role)):
		twin = mat.duplicate() as Material
		for meta in twin.get_meta_list():
			if String(meta).begins_with("ink_twin_"):
				twin.remove_meta(meta)
		if not _chain(twin, role, ink(role)):
			return null
		twin.set_meta("ink_source", mat.get_instance_id())
		mat.set_meta(key, twin)
	return twin


static func _chain(mat: Material, role: String, line: ShaderMaterial) -> bool:
	var after := mat.next_pass
	if after == null:
		mat.next_pass = line
	elif after.has_meta("ink_role"):
		return true
	elif after == BakeLook.edge_lift() and line == ink(role):
		mat.next_pass = _lift(role)
	else:
		return false
	return true


static func _cutaway(mat: Material) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader != null \
		and (mat as ShaderMaterial).shader.code == BallLooks.CUTAWAY_SHADER


static func _cut_ink(mat: ShaderMaterial, role: String) -> ShaderMaterial:
	var line := ink(role).duplicate() as ShaderMaterial
	line.shader = _shader_for(true)
	line.set_meta("ink_role", role)
	for key in CUT_PARAMETERS:
		var value = mat.get_shader_parameter(key)
		if value != null:
			line.set_shader_parameter(key, value)
	return line


static func _shader_for(cut: bool) -> Shader:
	if not _shaders.has(cut):
		var shader := Shader.new()
		shader.code = SHADER % ([CUT_UNIFORMS, CUT_VERTEX_IN, CUT_VERTEX_OUT, CUT_FRAGMENT] if cut else ["", "", "", ""])
		_shaders[cut] = shader
	return _shaders[cut]


static func _lift(role: String) -> ShaderMaterial:
	if not _lifts.has(role):
		var copy := BakeLook.edge_lift().duplicate() as ShaderMaterial
		copy.next_pass = ink(role)
		copy.set_meta("ink_role", role)
		copy.set_meta("ink_lift", true)
		_lifts[role] = copy
	return _lifts[role]


static func _named_off(slot: String) -> bool:
	var low := slot.to_lower()
	for word in SKIP_NAMES:
		if low.contains(word):
			return true
	return false


static func _sheltered(view: Node, root: Node) -> bool:
	var node := view
	while node != null:
		for word in SKIP_NODES:
			if String(node.name).begins_with(word):
				return true
		if node == root:
			break
		node = node.get_parent()
	return false


static func _lods(mesh: ArrayMesh, surface: int) -> Dictionary:
	var lods := {}
	var count := mesh.surface_get_array_len(surface)
	for lod in RenderingServer.mesh_get_surface(mesh.get_rid(), surface).get("lods", []):
		var data: PackedByteArray = lod.get("index_data", PackedByteArray())
		var indices := PackedInt32Array()
		if count > 65536:
			indices = data.to_int32_array()
		else:
			indices.resize(data.size() / 2)
			for i in indices.size():
				indices[i] = data.decode_u16(i * 2)
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
