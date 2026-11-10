extends RefCounted

# The look census: every look a scan of the tree finds drawn, keyed the way a renderer keys the
# pipelines it builds, so a look first drawn in play (a pipeline the 4080 builds on that frame, a
# hitch) is named with its tick and owner. Headless, no GPU.
#
# A look is one surface of one visible GeometryInstance3D: the node's class, its mesh's vertex
# format (or its kind, for a mesh made in code), skinned or not, whether it casts a shadow, whether
# it fades through instance transparency, and its material's shader-relevant state (class, every
# switch and mode, which texture slots are set; a ShaderMaterial is its shader). Colours and energies
# are not part of a look: changing them builds nothing. A script that flips a switch in play
# (emission_enabled on a hit flash) makes a new look.
#
# Forward+ (the PC) builds a surface's pipelines when the instance is registered, out of sight or
# not, so a look counts from the scan it is in the tree visible, wherever it stands. Only the PC
# confirms a pipeline; this names the candidates.
#
# Use: `var census := LookCensus.new()`, then `census.scan(root, tick)` as often as the moment
# needs; it returns the new looks as rows {tick, path, owner, key} and keeps them in `rows`.
# tools/look_census_run.gd runs it over a bot run; tests/look_after_warm_test.gd holds the warm to it.

# Material properties that are state, not look: a texture's presence is a look, its pixels are not.
const SKIP := {"resource_local_to_scene": true, "resource_name": true, "render_priority": true}

var seen := {}
var rows: Array[Dictionary] = []
# A material's look by its instance, for one scan: a material shared by many surfaces is read once
# a scan, and every scan reads it fresh (a dress or a flash flips switches in place).
var _by_material := {}


func scan(root: Node, tick: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_by_material.clear()
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		for key in keys_of(geo):
			if seen.has(key):
				continue
			seen[key] = tick
			var row := {"tick": tick, "path": str(root.get_path_to(geo)), "owner": owner_of(geo), "key": key}
			found.append(row)
			rows.append(row)
	return found


# Marks every look under `root` seen, without a row: what a moment drew before the census watched.
func absorb(root: Node, tick: int = 0) -> void:
	_by_material.clear()
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).is_visible_in_tree():
			for key in keys_of(node):
				seen[key] = tick


func keys_of(geo: GeometryInstance3D) -> Array[String]:
	var head := "%s|shadow=%d|fade=%d" % [geo.get_class(), geo.cast_shadow, int(geo.transparency > 0.0)]
	var out: Array[String] = []
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh == null:
			return out
		# Skinned when the mesh carries bones and its skeleton path finds a skeleton.
		var skinned := int(mi.mesh is ArrayMesh and _has_bones(mi.mesh) and mi.get_node_or_null(mi.skeleton) is Skeleton3D)
		for i in mi.mesh.get_surface_count():
			out.append("%s|%s|skin=%d|%s" % [head, _format(mi.mesh, i), skinned, look(mi.get_active_material(i))])
	elif geo is MultiMeshInstance3D:
		var mm := (geo as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			return out
		for i in mm.mesh.get_surface_count():
			var mat: Material = geo.material_override if geo.material_override != null else mm.mesh.surface_get_material(i)
			out.append("%s|%s|%s" % [head, _format(mm.mesh, i), look(mat)])
	elif geo is GPUParticles3D:
		var p := geo as GPUParticles3D
		for pass_i in p.draw_passes:
			var mesh: Mesh = p.get("draw_pass_%d" % (pass_i + 1))
			if mesh == null:
				continue
			for i in mesh.get_surface_count():
				var mat: Material = geo.material_override if geo.material_override != null else mesh.surface_get_material(i)
				out.append("%s|%s|%s" % [head, _format(mesh, i), look(mat)])
	elif geo is Label3D or geo is SpriteBase3D:
		# These build their own material from their switches.
		var parts := [head]
		for prop in ["billboard", "shaded", "double_sided", "no_depth_test", "fixed_size", "alpha_cut", "texture_filter", "transparent"]:
			if prop in geo:
				parts.append("%s=%s" % [prop, geo.get(prop)])
		parts.append(look(geo.material_override))
		out.append("|".join(parts))
	else:
		out.append("%s|%s" % [head, look(geo.material_override)])
	return out


func look(mat: Material) -> String:
	if mat == null:
		return "default"
	var id := mat.get_instance_id()
	if not _by_material.has(id):
		_by_material[id] = _look(mat)
	return _by_material[id]


static func _look(mat: Material) -> String:
	if mat is ShaderMaterial:
		var shader := (mat as ShaderMaterial).shader
		return "shader:%s" % (shader.resource_path if shader != null and shader.resource_path != "" else str(shader.get_instance_id() if shader != null else 0))
	var parts := [mat.get_class()]
	for prop in mat.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE == 0 or SKIP.has(prop.name):
			continue
		match prop.type:
			TYPE_BOOL, TYPE_INT:
				parts.append("%s=%s" % [prop.name, mat.get(prop.name)])
			TYPE_OBJECT:
				if prop.hint == PROPERTY_HINT_RESOURCE_TYPE and String(prop.hint_string).contains("Texture"):
					if mat.get(prop.name) != null:
						parts.append(prop.name)
	if mat.next_pass != null:
		parts.append("next[%s]" % _look(mat.next_pass))
	return ",".join(parts)


static func _format(mesh: Mesh, surface: int) -> String:
	if mesh is ArrayMesh:
		return "fmt=%d,prim=%d" % [(mesh as ArrayMesh).surface_get_format(surface), (mesh as ArrayMesh).surface_get_primitive_type(surface)]
	return mesh.get_class()


static func _has_bones(mesh: ArrayMesh) -> bool:
	for i in mesh.get_surface_count():
		if mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_BONES:
			return true
	return false


# The nearest scripted node above `node`, by its script's file: who drew it.
static func owner_of(node: Node) -> String:
	var at := node
	while at != null and at.get_script() == null:
		at = at.get_parent()
	return "none" if at == null else String((at.get_script() as Script).resource_path.get_file())
