extends RefCounted

# Shows the polish pass's baked shading (tools/blender/POLISH.md) on runtime materials.
# The bake writes ambient occlusion and edge wear into the vertex colours of the vertex-colour
# slots, and into UV2 for every face (x: unoccluded fraction, y: wear, 0.5 neutral). Enemy and
# boss scripts swap their own materials onto GLB surfaces (body paint for the hit flash, tints,
# state swaps), and those ignore UV2, so every face outside the vertex-colour slots lost the bake.
# dress() multiplies those surfaces by the bake's shade through StandardMaterial3D's detail layer on
# UV2, so a script can keep mutating its material (albedo, emission) as before. A multiply cannot
# brighten, so convex edges stop at neutral (the vertex slots lift them up to 18%): the
# darkening, which carries the form, matches exactly.

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

static var _ramp: ImageTexture
static var _twins := {}


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
static func twin(mat: StandardMaterial3D, shade := true) -> StandardMaterial3D:
	if mat.get_meta("bake_look", false) or mat.get_meta("bake_smooth", false):
		return mat
	var key := [mat.get_instance_id(), shade]
	if not _twins.has(key) or not is_instance_valid(_twins[key]):
		var copy := mat.duplicate() as StandardMaterial3D
		if shade:
			apply(copy)
		else:
			Palette.smooth(copy)
			copy.set_meta("bake_smooth", true)
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
# script's changes. Telegraph stripes stay flat. Shader materials and unbaked meshes are left
# alone. Safe to call again. Returns the surfaces dressed.
static func dress(root: Node, owned: Array = []) -> int:
	var views: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		views.append(root)
	# Which looks each material is asked for: 0 unbaked, 1 shaded, 2 smoothed only.
	var wants := {}
	for view: MeshInstance3D in views:
		if view.mesh == null:
			continue
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i)
			if not wants.has(mat):
				wants[mat] = {}
			wants[mat][_look(view.mesh, i)] = true
	var dressed := 0
	for view: MeshInstance3D in views:
		var mesh := view.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var look := _look(mesh, i)
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
			elif view.material_override == mat:
				if wants[mat].size() > 1:
					continue
				view.material_override = twin(mat, look == 1)
			elif view.get_surface_override_material(i) == mat:
				view.set_surface_override_material(i, twin(mat, look == 1))
			else:
				mesh.surface_set_material(i, twin(mat, look == 1))
			dressed += 1
	return dressed


static func _look(mesh: Mesh, surface: int) -> int:
	if not has_bake(mesh, surface):
		return 0
	return 2 if vertex_baked(mesh, surface) else 1
