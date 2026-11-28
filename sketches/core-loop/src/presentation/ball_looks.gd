extends RefCounted

const TODAY := "today"
const LOOKS := {
	"gyro": "res://assets/models/world_one/ball_look_gyro.glb",
	"bell": "res://assets/models/world_one/ball_look_bell.glb",
	"cutaway": "res://assets/models/world_one/ball_look_cutaway.glb",
}

const PLATED := ["cutaway"]
const COCKPIT := "res://assets/models/world_one/ball_look_cutaway_cockpit.glb"
const COCKPIT_NODE := "Cockpit"
const WINDOW := 0.76
const WINDOW_INK := 0.035
const WINDOW_FRINGE := 0.11

const CUTAWAY_SHADER_RES := preload("res://assets/shaders/actor_ball_cutaway.gdshader")
const CUTAWAY_BANDS_SHADER_RES := preload("res://assets/shaders/actor_ball_cutaway_bands.gdshader")
const CUTAWAY_FUSE_SHADER_RES := preload("res://assets/shaders/actor_ball_cutaway_fuse.gdshader")
const CANOPY_SHADER_RES := preload("res://assets/shaders/actor_ball_canopy.gdshader")
static var CUTAWAY_SHADER: String = CUTAWAY_SHADER_RES.code

static var _shaders := {}
static var _platings := {}
static var _inside := {}
static var _enamels := {}
static var _canopy_material: ShaderMaterial


static func ids() -> Array:
	return [TODAY] + LOOKS.keys()


static func is_look(path: String) -> bool:
	return path != "" and LOOKS.values().has(path)


static func asset_paths(look: String, pilots: Array) -> Dictionary:
	var path := String(LOOKS.get(look, ""))
	var out := {}
	if path != "" and not PLATED.has(look) and ResourceLoader.exists(path):
		for pilot in pilots:
			out[pilot] = path
	return out


static func replate(look: String, core: Node, heft := 1) -> void:
	if core == null or not PLATED.has(look):
		return
	var plating := _plating(look, heft)
	if plating == null:
		return
	var view := core as MeshInstance3D
	if view == null:
		view = MeshInstance3D.new()
		view.name = "Plating"
		core.add_child(view)
	elif heft == 1 and view.mesh != null:
		view.set_meta(ENAMEL_META, _enamel(view.mesh))
	view.mesh = plating


const ENAMEL_META := "ball_enamel"
const WORN_META := "ball_window_worn"

static func _enamel(mesh: Mesh):
	if not _enamels.has(mesh):
		var sum := Vector3.ZERO
		var count := 0
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat == null or mat.resource_name != "paint":
				continue
			var colors = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			if colors == null:
				continue
			for c in colors:
				if c.a > 0.05:
					sum += Vector3(c.r, c.g, c.b)
					count += 1
		_enamels[mesh] = sum / float(count) if count > 0 else null
	return _enamels[mesh]


const INSIDE_RADIUS := 0.96
const INSIDE_SHARE := 0.9

static func strip(look: String, pod_layer: Node) -> void:
	if pod_layer == null or not PLATED.has(look):
		return
	var views: Array = pod_layer.find_children("*", "MeshInstance3D", true, false)
	if pod_layer is MeshInstance3D:
		views.append(pod_layer)
	for view in views:
		if view.mesh != null and _inside_share(view.mesh) >= INSIDE_SHARE:
			view.layers = 0
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _inside_share(mesh: Mesh) -> float:
	if not _inside.has(mesh):
		var points := mesh.get_faces()
		var count := 0
		for point in points:
			if point.length() < INSIDE_RADIUS:
				count += 1
		_inside[mesh] = float(count) / maxf(1.0, float(points.size()))
	return _inside[mesh]


static func _plating(look: String, heft: int) -> Mesh:
	var path := String(LOOKS[look])
	if heft > 1:
		path = path.replace(".glb", "_c%d.glb" % heft)
	return _part(path, "Core")


static func _part(path: String, part: String) -> Mesh:
	if not _platings.has(path):
		var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
		var scene: Node = packed.instantiate() if packed != null else null
		var found := scene.find_child(part, true, false) as MeshInstance3D if scene != null else null
		_platings[path] = found.mesh if found != null else null
		if scene != null:
			scene.free()
	return _platings[path]


static func furnish(look: String, pod: Node) -> void:
	if pod == null or not PLATED.has(look) or pod.has_node(COCKPIT_NODE):
		return
	var mesh := _part(COCKPIT, COCKPIT_NODE)
	if mesh == null:
		return
	var view := MeshInstance3D.new()
	view.name = COCKPIT_NODE
	view.mesh = mesh
	pod.add_child(view)


static func dress(look: String, shell: Dictionary) -> void:
	if shell.is_empty():
		return
	if look == "cutaway":
		_cut(shell.core)
		cut_kit(shell.pod, String(shell.get("pilot", "")))
	elif look == "bell":
		for view in (shell.pod as Node).find_children("*", "MeshInstance3D", true, false):
			for i in view.mesh.get_surface_count():
				var was: Material = view.get_active_material(i)
				if was != null and was.resource_name == "glass":
					view.set_surface_override_material(i, _canopy())


static func light_pilot(look: String, pilot: Node) -> void:
	if not PLATED.has(look):
		return
	var lit := {}
	for view in _views(pilot):
		for i in view.mesh.get_surface_count():
			var was := view.get_active_material(i) as BaseMaterial3D
			if was == null or was.backlight_enabled or was.emission_enabled or was.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			if not lit.has(was):
				var mat: BaseMaterial3D = was.duplicate()
				mat.backlight_enabled = true
				mat.backlight = Color(PILOT_BACKLIGHT, PILOT_BACKLIGHT, PILOT_BACKLIGHT)
				mat.rim_enabled = true
				mat.rim = PILOT_RIM
				mat.rim_tint = PILOT_RIM_TINT
				lit[was] = mat
			_wear(view, i, lit[was])


static func _cut(core: Node) -> void:
	var cuts := {}
	for view in _views(core):
		var enamel = view.get_meta(ENAMEL_META) if view.has_meta(ENAMEL_META) else null
		var centre := _centre_in(view, core)
		for i in view.mesh.get_surface_count():
			var was: Material = view.get_active_material(i)
			var key := [was, enamel, centre]
			if not cuts.has(key):
				var cut := _windowed(was)
				cut.set_shader_parameter("inside", cut.get_shader_parameter("vertex_tint"))
				cut.set_shader_parameter("centre_local", centre)
				if enamel != null:
					cut.set_shader_parameter("enamel", enamel)
					cut.set_shader_parameter("enamel_take", 1.0)
				cuts[key] = cut
			_wear(view, i, cuts[key])


const SOURCE_META := "ball_window_source"
const TWINS_META := "ball_window_twins"
const WINDOW_PARAMETERS := ["window", "ink_width", "fringe", "inside", "held", "centre_at", "centre_local", "keep_within",
	"tube", "back_is_kit", "seat_back_top", "back_above", "back_behind", "enamel", "enamel_take"]

static func keep_window(view: MeshInstance3D, surface: int, mat: Material) -> Material:
	var worn := view.get_surface_override_material(surface) as ShaderMaterial
	if mat == null or worn == null or worn == mat or not worn.has_meta(SOURCE_META):
		return mat
	if worn.get_meta(SOURCE_META) == mat:
		return worn
	if not _takes_window(mat):
		return mat
	var twins: Dictionary = view.get_meta(TWINS_META, {})
	var key := "%d:%d" % [surface, mat.get_instance_id()]
	if not twins.has(key):
		var cut := _windowed(mat)
		for name in WINDOW_PARAMETERS:
			var value = worn.get_shader_parameter(name)
			if value != null:
				cut.set_shader_parameter(name, value)
		cut.next_pass = _gated(worn.next_pass) if _variant(mat) == "bands" else worn.next_pass
		twins[key] = cut
		var back_key := "%d:%d" % [surface, (worn.get_meta(SOURCE_META) as Object).get_instance_id()]
		if not twins.has(back_key):
			twins[back_key] = worn
		view.set_meta(TWINS_META, twins)
	return twins[key]


static func unwindowed(mat: Material) -> Material:
	return mat.get_meta(SOURCE_META) as Material if mat != null and mat.has_meta(SOURCE_META) else mat


const GATE_AT := "void fragment() {"
const GATE := """instance uniform int lit_count = 0;
instance uniform int heft_class = 1;
void fragment() {
	if (UV2.y > float(heft_class) + 0.1) {
		discard;
	}"""

static func _gated(line: Material) -> Material:
	var source := line as ShaderMaterial
	if source == null or source.shader == null:
		return null
	if source.shader.code.contains("heft_class"):
		return source
	if source.shader.code.count(GATE_AT) != 1:
		return null
	var gated := source.duplicate() as ShaderMaterial
	gated.shader = _shader("gated:%d" % source.shader.code.hash(), source.shader.code.replace(GATE_AT, GATE))
	return gated


static func _wear(view: MeshInstance3D, surface: int, mat: Material) -> void:
	view.set_surface_override_material(surface, mat)
	var held: Array = view.get_meta(WORN_META, [])
	held.append(mat)
	view.set_meta(WORN_META, held)


static func _views(part: Node) -> Array:
	var views: Array = part.find_children("*", "MeshInstance3D", true, false)
	if part is MeshInstance3D:
		views.append(part)
	return views.filter(func(view): return view.mesh != null)


static func _centre_in(view: Node3D, root: Node) -> Vector3:
	var to_root := Transform3D.IDENTITY
	var node: Node = view
	while node != null and node != root:
		if node is Node3D:
			to_root = (node as Node3D).transform * to_root
		node = node.get_parent()
	return to_root.affine_inverse().origin.snappedf(0.001)


static func _takes_window(was: Material) -> bool:
	if was == null:
		return false
	if was is BaseMaterial3D:
		return was.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and was.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	if _variant(was) != "":
		return true
	return was is ShaderMaterial and was.get_shader_parameter("paint_take") != null and was.get_shader_parameter("class_color") == null


const VARIANTS := {"bands": "instance uniform int lit_count", "fuse": "instance uniform float fuse_glow"}

static func _variant(was: Material) -> String:
	var shader: Shader = (was as ShaderMaterial).shader if was is ShaderMaterial else null
	if shader != null:
		for kind in VARIANTS:
			if shader.code.contains(VARIANTS[kind]):
				return kind
	return ""


const PILOT_BACKLIGHT := 0.82
const PILOT_RIM := 0.55
const PILOT_RIM_TINT := 0.35
const KIT_KEEP_WITHIN := 0.93
const PLATING_RADIUS := 0.965
const LOW_SEAT_BACK := {"runner_gunner": -0.24}

static func cut_kit(pod: Node, pilot: String) -> void:
	var cuts := {}
	var dome := pod.find_child("Dome", true, false)
	for view in _views(pod):
		if dome != null and dome.is_ancestor_of(view):
			continue
		var centre := _centre_in(view, pod)
		for i in view.mesh.get_surface_count():
			var was: Material = view.get_active_material(i)
			if not _takes_window(was):
				continue
			var seat: float = LOW_SEAT_BACK.get(pilot, 9.0) if view == pod else 9.0
			var key := [was, centre, seat]
			if not cuts.has(key):
				var cut := _windowed(was)
				cut.set_shader_parameter("keep_within", KIT_KEEP_WITHIN)
				cut.set_shader_parameter("back_is_kit", true)
				cut.set_shader_parameter("tube", PLATING_RADIUS)
				cut.set_shader_parameter("seat_back_top", seat)
				cut.set_shader_parameter("centre_local", centre)
				cuts[key] = cut
			_wear(view, i, cuts[key])


static func _windowed(was: Material) -> ShaderMaterial:
	var cut := ShaderMaterial.new()
	var kind := _variant(was)
	if kind == "bands":
		cut.shader = CUTAWAY_BANDS_SHADER_RES
	elif kind == "fuse":
		cut.shader = CUTAWAY_FUSE_SHADER_RES
	else:
		cut.shader = CUTAWAY_SHADER_RES
	if was != null:
		cut.set_meta(SOURCE_META, was)
	cut.resource_name = was.resource_name if was != null else ""
	cut.set_shader_parameter("window", WINDOW)
	cut.set_shader_parameter("ink_width", WINDOW_INK)
	cut.set_shader_parameter("fringe", WINDOW_FRINGE)
	cut.set_shader_parameter("vertex_tint", true)
	if was is BaseMaterial3D:
		cut.set_shader_parameter("vertex_tint", was.vertex_color_use_as_albedo)
		cut.set_shader_parameter("tint", Color.WHITE if was.vertex_color_use_as_albedo else was.albedo_color)
		cut.set_shader_parameter("lift", was.albedo_color if was.vertex_color_use_as_albedo else Color.WHITE)
		cut.set_shader_parameter("paint_tint", Color.WHITE)
		cut.set_shader_parameter("paint_take", 0.0)
		cut.set_shader_parameter("metal", was.metallic)
		cut.set_shader_parameter("rough", was.roughness)
		if was.emission_enabled:
			var lit: Color = was.emission.srgb_to_linear() * was.emission_energy_multiplier
			cut.set_shader_parameter("glow", Vector3(lit.r, lit.g, lit.b))
		if was.albedo_texture != null and was.uv1_triplanar:
			cut.set_shader_parameter("plated", true)
			cut.set_shader_parameter("plate", was.albedo_texture)
			cut.set_shader_parameter("plate_scale", was.uv1_scale.x)
	elif was is ShaderMaterial:
		if was.get_shader_parameter("plate_texture") != null:
			cut.set_shader_parameter("plated", true)
			cut.set_shader_parameter("plate", was.get_shader_parameter("plate_texture"))
		for key in ["paint_tint", "lift", "paint_take", "class_color", "strength"]:
			var value = was.get_shader_parameter(key)
			if value != null:
				cut.set_shader_parameter(key, value)
		if kind == "fuse":
			cut.set_shader_parameter("vertex_tint", false)
			cut.set_shader_parameter("tint", was.get_shader_parameter("class_color"))
			cut.set_shader_parameter("rough", 0.5)
	return cut


const RIDER_META := "ball_window"

static func ride(look: String, roll: Node3D) -> void:
	if roll == null or not PLATED.has(look):
		return
	if not roll.has_meta(RIDER_META):
		roll.set_meta(RIDER_META, {"cuts": {}, "dirty": true})
		roll.child_entered_tree.connect(_watch.bind(roll))
		for child in roll.get_children():
			_watch(child, roll)
	var state: Dictionary = roll.get_meta(RIDER_META)
	var cuts: Dictionary = state.cuts
	if state.dirty:
		state.dirty = false
		for node in roll.find_children("*", "GeometryInstance3D", true, false):
			if not node.has_meta(RIDER_META):
				node.set_meta(RIDER_META, true)
				_cut_rider(node, cuts)
	var centre := roll.global_position if roll.is_inside_tree() else Vector3.ZERO
	for cut in cuts.values():
		cut.set_shader_parameter("centre_at", centre)


static func _watch(child: Node, roll: Node3D) -> void:
	_mark(child, roll)
	var mark := _mark.bind(roll)
	if not child.child_entered_tree.is_connected(mark):
		child.child_entered_tree.connect(mark)


static func _mark(_node: Node, roll: Node3D) -> void:
	if is_instance_valid(roll) and roll.has_meta(RIDER_META):
		roll.get_meta(RIDER_META).dirty = true


static func _cut_rider(node: GeometryInstance3D, cuts: Dictionary) -> void:
	var multi := node as MultiMeshInstance3D
	var view := node as MeshInstance3D
	if node.material_override != null:
		if _takes_window(node.material_override):
			node.material_override = _rider(cuts, node.material_override)
	elif multi != null and multi.multimesh != null and multi.multimesh.mesh != null:
		var mesh: Mesh = multi.multimesh.mesh.duplicate()
		for i in mesh.get_surface_count():
			if _takes_window(mesh.surface_get_material(i)):
				mesh.surface_set_material(i, _rider(cuts, mesh.surface_get_material(i)))
		multi.multimesh.mesh = mesh
	elif view != null and view.mesh != null:
		for i in view.mesh.get_surface_count():
			if _takes_window(view.get_active_material(i)):
				view.set_surface_override_material(i, _rider(cuts, view.get_active_material(i)))


static func _rider(cuts: Dictionary, was: Material) -> Material:
	var cut := _windowed(was)
	var key := ""
	for name in ["vertex_tint", "tint", "metal", "rough", "glow", "paint_tint", "paint_take", "plate", "plate_scale"]:
		key += str(cut.get_shader_parameter(name)) + "|"
	if not cuts.has(key):
		cut.set_shader_parameter("held", true)
		cuts[key] = cut
	return cuts[key]


static func _canopy() -> ShaderMaterial:
	if _canopy_material == null:
		_canopy_material = ShaderMaterial.new()
		_canopy_material.shader = CANOPY_SHADER_RES
	return _canopy_material


static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	return _shaders[key]
