extends RefCounted

# Shows the polish pass's baked shading (tools/blender/POLISH.md) on runtime materials.
# The bake writes ambient occlusion and edge wear into the vertex colours of the vertex-colour
# slots, and into UV2 for every face (x: unoccluded fraction, y: wear, 0.5 neutral). Enemy and
# boss scripts swap their own materials onto GLB surfaces (body paint for the hit flash, tints,
# state swaps), and those ignore UV2, so every face outside the vertex-colour slots lost the bake.
# dress() multiplies those surfaces by the bake's shade through StandardMaterial3D's detail layer on
# UV2, so a script can keep mutating its material (albedo, emission) as before. A multiply cannot
# brighten, so convex edges stop at neutral (the vertex slots lift them up to 18%, and Fleet paint's
# edge layer, finish() below, lifts them toward bone): the darkening, which carries the form, matches exactly. The detail layer always writes NORMAL_MAP,
# so the shaded surfaces need usable tangents: the polished GLBs carry a constant UV1, which
# leaves theirs constant and, where one runs along its normal, drew that quad black.
# tangent_safe() rebuilds such a mesh once with tangents square to the normals.

# Slots whose vertex colours already carry the bake (polish.py bake_slots): left alone, or the
# shade would apply twice.
const VERTEX_BAKED := ["paint", "pilot", "ancient_enamel", "hydraulic"]
# polish.py defaults: shade = (1 - AO_STRENGTH * occluded) * (1 + wear), wear in +-EDGE.
const AO_STRENGTH := 0.55
const EDGE := 0.18
# 256 steps: the plate material samples with nearest filtering, and 64 banded on it.
const RAMP := 256
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# The 2010 finish (SIGHT-PERSONA.md sections 5 and 6, items 6 and 7). Fleet paint is what a hand repainted, so its
# convex edges wear toward bone and its rim keeps a pale edge in shade; a casting (an Old Works shell, a Warden's
# enamel) bakes with edge 0 (POLISH.md), so its wear reads neutral and it stays spotless whatever slot it is in.
# The multiply above cannot brighten, so the bone comes from one shared layer drawn after the paint (next_pass):
# where the bake's wear says convex it mixes the lit paint toward lit bone, up to LIFT at the most worn edge, and
# at the silhouette (RIM, rising as the face turns from the eye) it does the same. Both glow faintly in SKY_TINT
# (SKY_GLOW), light no sun gives, so in shade the rust keeps a pale cool edge against warm sandstone instead of going
# near black (visual-assets-audit.md finding 8). It draws nothing on a neutral face that looks at the eye.
# The candidates and their numbers are on the W46-03 pull request's sheet (ruling cq).
const LIFT_SLOTS := ["fleet_paint"]
const LIFT := 0.55
# Wear below LIFT_FROM of the most worn reads as unworn: the bake's soft falloff stays paint, the edge goes bone.
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


# The one shared edge layer every Fleet-paint surface draws after its paint: bone on worn convex edges and a pale,
# faintly sky-lit rim where a face turns from the eye (the constants above).
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


# The bone the edge layer mixes in at bake wear `wear_v` (UV2.y) on a face whose normal meets the eye at `facing`
# (dot(normal, view), 1 head on), as its shader draws it: none on a neutral face (a casting baked with edge 0 reads 0.5
# everywhere) or a crease that looks at the eye, LIFT at the most worn convex edge, RIM at the silhouette.
static func lift_alpha(wear_v: float, facing := 1.0) -> float:
	var edge := LIFT * smoothstep(LIFT_FROM, 1.0, clampf((0.5 - wear_v) * 2.0, 0.0, 1.0))
	var a := maxf(edge, RIM * pow(1.0 - clampf(facing, 0.0, 1.0), RIM_POWER))
	return a if a >= 0.004 else 0.0


# What a surface's slot finish is: "lift" for Fleet paint, "brass" for a brass slot, "" for the rest.
static func finish_of(mesh: Mesh, surface: int) -> String:
	if not (mesh is ArrayMesh):
		return ""
	var slot := (mesh as ArrayMesh).surface_get_name(surface)
	if slot in LIFT_SLOTS:
		return "lift"
	if slot in BRASS_SLOTS:
		return "brass"
	return ""


# Gives `mat` its slot finish in place: Fleet paint the bone edge and rim layer, brass the one satin brass.
static func finish(mat: StandardMaterial3D, kind: String) -> void:
	if kind == "lift":
		mat.next_pass = edge_lift()
	elif kind == "brass":
		Palette.brass_finish(mat)


# The shade as a multiplier, capped at 1. x is the unoccluded fraction; y is the wear with glTF's
# flipped V, so 0 is the most worn convex edge and 1 the deepest crease.
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


# Gives `mat` the UV2 shade in place. A Palette.solid loses its world grain and grime: the polished
# model brings its own surface, and the soft-toy bodies read smooth.
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
	# Into texel centres: an open face (x = 1) on a repeating, filtered ramp would otherwise blend
	# in the fully occluded column from the far edge.
	mat.uv2_scale = Vector3(RAMP - 1.0, RAMP - 1.0, RAMP) / RAMP
	mat.uv2_offset = Vector3(0.5, 0.5, 0.0) / RAMP
	mat.set_meta("bake_look", true)


# A shared material's baked copy, made once per source, for surfaces of a shared mesh. With
# `shade` false the copy only loses the grain, for a vertex-colour slot that carries the bake.
# `kind` is the slot finish (finish_of) the copy also takes.
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


# `mat` without the shade, for a mesh with no UV2 that borrows a dressed material (death debris
# boxes): UV2 reads (0, 0) there, the fully covered corner.
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


# Telegraph stripes read flat: Palette's, and the per-script ones painted with the threat texture.
static func _warning(mat: StandardMaterial3D) -> bool:
	return mat == Palette.hazard_stripe() or mat.get_meta("no_bake", false) \
		or (mat.albedo_texture != null and mat.albedo_texture == Threat.Painter.stripe_texture())


# Every baked surface under `root` that a StandardMaterial3D draws takes the bake's look: outside
# the vertex-colour slots the UV2 shade, inside them (which carry the shade already) just the
# loss of the world grain. A material in `owned` (one the script holds and mutates, such as the
# body paint the hit flash brightens) changes in place, so the script's changes still show; any
# other material is swapped for its twin, on the node or on the shared mesh (an imported mesh's
# cached resource included, so every later instance shares the twin). An owned material that also
# draws a surface wanting another look stays as it is, since a twin would stop drawing the
# script's changes. Each surface also takes its slot's finish (finish_of): an owned material asked for two keeps
# neither. Telegraph stripes stay flat. Shader materials and unbaked meshes are left
# alone. Safe to call again. Returns the surfaces dressed.
static func dress(root: Node, owned: Array = []) -> int:
	var views: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		views.append(root)
	# Which looks each material is asked for: 0 unbaked, 1 shaded, 2 smoothed only.
	var wants := {}
	# Which slot finishes each material is asked for: an owned one asked for two keeps its own.
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
				# One override covers every surface, so like an owned material it takes a finish only when they all share it.
				view.material_override = twin(mat, look == 1, kind if finishes[mat].size() == 1 else "")
			elif view.get_surface_override_material(i) == mat:
				view.set_surface_override_material(i, twin(mat, look == 1, kind))
			else:
				mesh.surface_set_material(i, twin(mat, look == 1, kind))
			dressed += 1
	return dressed


# Makes what dress() would make for one view (its tangent-safe mesh and its materials' twins) without
# changing the view, so a later dress() of its scene finds them made: a warm spreads a model's dress a view a frame.
static func warm_view(view: MeshInstance3D) -> void:
	if view.mesh == null:
		return
	var mesh := tangent_safe(view.mesh)
	for i in mesh.get_surface_count():
		var look := _look(mesh, i)
		var mat := view.get_active_material(i)
		if look != 0 and mat is StandardMaterial3D and not _warning(mat):
			twin(mat, look == 1, finish_of(mesh, i))


# `mesh`, or once per mesh a copy whose shaded surfaces have tangents square to their normals:
# every tangent where the surface's UV1 is a single point (the tangents mean nothing there), else
# only the ones that are zero or run along their normal. The normal map those surfaces draw is
# flat, so any square tangent is right. Names, materials, LODs and the shadow mesh carry over;
# a mesh with blend shapes or custom channels is left as it is. The copy hangs off the source
# mesh's metadata, so it lives exactly as long as the source.
static func tangent_safe(mesh: Mesh) -> Mesh:
	if not (mesh is ArrayMesh) or mesh.get_meta("bake_tangents_ok", false):
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


# 0 leaves the tangents, 1 fixes the bad ones, 2 replaces them all (no tangents, or a UV1 that
# is a single point). Compressed surfaces read back decompressed and rebuild uncompressed.
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


# The surface's imported LODs as add_surface_from_arrays takes them, read back from the server's
# index buffers (16-bit up to 65536 vertices). Any that does not read back cleanly is dropped.
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
