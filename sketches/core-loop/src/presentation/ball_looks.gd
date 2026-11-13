extends RefCounted

# The ball looks behind the launch switch --ball-look=<id>; "today" keeps the game's own
# shells. Andrew picked the cutaway on 13 Nov 2026 (ruling dm). hero_assets.gd is the only caller.
#
#   gyro      three crossed hoops around an open seat            (one shared shell, a candidate)
#   bell      a diving bell: painted prow, a glass back          (one shared shell, a candidate)
#   cutaway   a solid plated ball; a window opens on whichever side faces the camera
#
# The cutaway keeps each pilot's own shell and replaces only what rolls:
#   asset_paths()  before a fit: the whole-shell swaps (none for the cutaway)
#   replate()      the rolling part's mesh becomes plating, at every heft class
#   strip()        hides the lattice's gap panels, which would float inside the plating
#   dress()        after the fit: the window on the plating and on the outer kit
#   ride()         every frame: the window on scrap, parts and panel plates riding the ball
# Shapes come from tools/blender/ball_looks.py.

const TODAY := "today"
const LOOKS := {
	"gyro": "res://assets/models/world_one/ball_look_gyro.glb",
	"bell": "res://assets/models/world_one/ball_look_bell.glb",
	"cutaway": "res://assets/models/world_one/ball_look_cutaway.glb",
}

# The cutaway window: the cosine of its half angle seen from the ball's centre, the ink line
# round it and the halftone fringe outside that. 0.76 is about 40 degrees, which clears a
# seated pilot of half the ball's height and leaves a rim of plating to show the spin.
# Looks that replace only the rolling part of each pilot's own shell.
const PLATED := ["cutaway"]
const WINDOW := 0.76
const WINDOW_INK := 0.035
const WINDOW_FRINGE := 0.11

const CUTAWAY_SHADER := """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform float metal = 0.0;
uniform float rough = 0.8;
// Linear light, already multiplied by its energy.
uniform vec3 glow = vec3(0.0);
uniform vec3 lining : source_color = vec3(0.82, 0.77, 0.65);
uniform vec3 ink : source_color = vec3(0.14, 0.16, 0.16);
uniform float window = 0.76;
uniform float ink_width = 0.035;
uniform float fringe = 0.11;
// The plated ball has an inside, drawn as lining; anything else shows no back face.
uniform bool inside = false;
// A part that rides the ball away from its centre is told where the centre is each frame.
uniform bool held = false;
uniform vec3 centre_at = vec3(0.0);
// A part of the shell whose own origin is off the ball's centre: the centre in its own space.
uniform vec3 centre_local = vec3(0.0);
// hero_assets' equipped paint: the tint takes where the vertex alpha says paint.
uniform vec4 paint_tint : source_color = vec4(1.0);
uniform vec4 lift : source_color = vec4(1.0);
uniform float paint_take = 0.0;
// The pilot's own enamel on the plating's paint-taking gores, in the vertex colours' own space.
uniform vec3 enamel = vec3(1.0);
uniform float enamel_take = 0.0;
// The level part keeps what sits inside the ball (seat, controls): only what stands farther
// from the centre than this, in the model's own units, is cut.
uniform float keep_within = 0.0;
// ...except behind the pilot's back above the seat (the level part's own +Z and +Y past these),
// where only brackets and backrests stand: those count as outer kit at any distance.
// What stands inside the ball is judged by the tube of sight the window opens (the plating's
// radius, in the model's units), not by its angle from the centre, which a rod near the centre
// never reaches.
uniform float tube = 0.0;
uniform bool back_is_kit = false;
// A small pilot's seat back is lowered to this height (the level part's own Y): every vertex of
// the seat back's slab above it is pressed down to it, so the back stays a closed box.
uniform float seat_back_top = 9.0;
uniform float back_above = -0.08;
uniform float back_behind = 0.05;
// hero_assets' plate map, laid on by the three axes as its own materials lay it.
uniform bool plated = false;
uniform sampler2D plate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float plate_scale = 0.667;
varying vec3 local_pos;
varying vec3 local_normal;
varying float model_scale;
varying vec3 from_centre;
varying vec3 to_camera;
varying vec3 to_eye;
void vertex() {
	if (VERTEX.y > seat_back_top && VERTEX.y < -0.05 && abs(VERTEX.x) < 0.26 && VERTEX.z > 0.13 && VERTEX.z < 0.27) {
		VERTEX.y = seat_back_top;
	}
	local_pos = VERTEX;
	local_normal = NORMAL;
	model_scale = length(MODEL_MATRIX[0].xyz);
	vec3 centre = held ? centre_at : (MODEL_MATRIX * vec4(centre_local, 1.0)).xyz;
	from_centre = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - centre;
	to_camera = CAMERA_POSITION_WORLD - centre;
	to_eye = INV_VIEW_MATRIX[2].xyz;
}
void fragment() {
	float facing = dot(normalize(from_centre), normalize(to_camera));
	float reach = length(from_centre) / model_scale;
	if (tube > 0.0 && reach < tube) {
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
	if (cockpit) {
		facing = -1.0;
	} else if (IN_SHADOW_PASS) {
		// In a light's pass the eye is the light. The half toward it is left out, so the sun
		// reaches the pilot; the far half still throws the whole round shadow on the ground.
		if (dot(normalize(from_centre), normalize(to_eye)) > 0.0) {
			discard;
		}
	} else if (facing > window) {
		discard;
	}
	vec3 base = tint.rgb;
	if (vertex_tint) {
		float takes = step(0.05, COLOR.a);
		vec3 own = mix(COLOR.rgb, enamel, enamel_take * takes);
		base *= mix(own * lift.rgb, paint_tint.rgb, paint_take * takes);
	}
	if (plated) {
		vec3 weights = abs(normalize(local_normal));
		weights /= max(weights.x + weights.y + weights.z, 0.001);
		vec3 p = local_pos * plate_scale;
		base *= texture(plate, p.yz).rgb * weights.x + texture(plate, p.xz).rgb * weights.y + texture(plate, p.xy).rgb * weights.z;
	}
	float edge = window - ink_width;
	if (facing > edge) {
		base = ink;
	} else if (facing > edge - fringe) {
		// Halftone dots that grow toward the ink line, fixed to the screen like print.
		vec2 cell = fract(FRAGCOORD.xy / 7.0) - 0.5;
		float grow = (facing - (edge - fringe)) / fringe;
		if (length(cell) < grow * 0.55) {
			base = ink;
		}
	}
	if (FRONT_FACING) {
		ALBEDO = base;
		METALLIC = metal;
		ROUGHNESS = rough;
		EMISSION = glow;
	} else {
		if (!inside) {
			discard;
		}
		ALBEDO = facing > edge ? ink : lining;
		ROUGHNESS = 1.0;
	}
}
"""

# Glass the comic way: nearly clear face-on so the pilot's colours stay true, a firm rim, and
# two slanted glints that say "glass" at any distance. One blended surface.
const CANOPY_SHADER := """shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_never;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float slant = local_pos.x * 0.8 + local_pos.y * 0.6;
	float glint = step(abs(slant - 0.30), 0.045) + step(abs(slant - 0.16), 0.018);
	glint *= step(0.05, local_pos.y) * step(local_pos.y, 0.62);
	ALBEDO = mix(vec3(0.78, 0.94, 1.0), vec3(1.0), glint);
	ALPHA = clamp(0.07 + rim * 0.5 + glint * 0.38, 0.0, 1.0);
	ROUGHNESS = 0.25;
	SPECULAR = 0.1 + rim * 0.5;
}
"""

static var _shaders := {}
static var _platings := {}
static var _inside := {}
static var _enamels := {}
static var _canopy_material: ShaderMaterial


static func ids() -> Array:
	return [TODAY] + LOOKS.keys()


# True for a look's own shell path.
static func is_look(path: String) -> bool:
	return path != "" and LOOKS.values().has(path)


# The look's shell path under each pilot id, for hero_assets.shell_assets; {} for today's and
# for a look that keeps each pilot's own shell and replaces only its rolling part (PLATED).
static func asset_paths(look: String, pilots: Array) -> Dictionary:
	var path := String(LOOKS.get(look, ""))
	var out := {}
	if path != "" and not PLATED.has(look) and ResourceLoader.exists(path):
		for pilot in pilots:
			out[pilot] = path
	return out


# Under a plated look the pilot's own shell keeps its level part (kit, weapon ring, cockpit) and
# its hub mounts, and its rolling mesh becomes the look's plating; a heft layer's rolling mesh
# becomes what that class bolts onto the plating. Call before the shell is painted.
static func replate(look: String, core: Node, heft := 1) -> void:
	if core == null or not PLATED.has(look):
		return
	var plating := _plating(look, heft)
	if plating == null:
		return
	var view := core as MeshInstance3D
	if view == null:
		# A heft layer with nothing on the rolling part still gets its plating.
		view = MeshInstance3D.new()
		view.name = "Plating"
		core.add_child(view)
	elif heft == 1 and view.mesh != null:
		# The plating's gores wear the enamel of the lattice they replace: each pilot's own colour.
		view.set_meta(ENAMEL_META, _enamel(view.mesh))
	view.mesh = plating


# The mean vertex colour of a mesh's paint-taking paint surfaces, or null when it has none.
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


# The lattice shells grow by filling their gaps with panels that sit inside the ball's radius.
# Under plating those would float inside the ball beside the pilot, and the plating's own heft
# layers carry the growth instead, so a heft layer's level part hides every mesh that lies
# inside the plating. Kit that stands outside (hoods, drums, hooks) stays.
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
	if not _platings.has(path):
		var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
		var scene: Node = packed.instantiate() if packed != null else null
		var found := scene.find_child("Core", true, false) as MeshInstance3D if scene != null else null
		_platings[path] = found.mesh if found != null else null
		if scene != null:
			scene.free()
	return _platings[path]


# Gives a fitted shell (hero_assets.fit_shell_into's {core, pod}) the look's own materials.
static func dress(look: String, shell: Dictionary) -> void:
	if shell.is_empty():
		return
	if look == "cutaway":
		_cut(shell.core)
		_cut_kit(shell.pod, String(shell.get("pilot", "")))
	elif look == "bell":
		for view in (shell.pod as Node).find_children("*", "MeshInstance3D", true, false):
			for i in view.mesh.get_surface_count():
				var was: Material = view.get_active_material(i)
				if was != null and was.resource_name == "glass":
					view.set_surface_override_material(i, _canopy())


# Every surface of the rolling part takes the window, keeping the colour it was painted with.
# A class_accent surface keeps hero_assets' own material, which the ready glow swaps by identity.
static func _cut(core: Node) -> void:
	var cuts := {}
	for view in _views(core):
		var enamel = view.get_meta(ENAMEL_META) if view.has_meta(ENAMEL_META) else null
		var centre := _centre_in(view, core)
		for i in view.mesh.get_surface_count():
			var was: Material = view.get_active_material(i)
			if was != null and was.resource_name == "class_accent":
				continue
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


# A node's metadata outlives its rendering instance, which must not outlive a material it draws
# with (hero_assets keeps its own surface materials the same way).
static func _wear(view: MeshInstance3D, surface: int, mat: Material) -> void:
	view.set_surface_override_material(surface, mat)
	var held: Array = view.get_meta(WORN_META, [])
	held.append(mat)
	view.set_meta(WORN_META, held)


# A part's meshes that can draw.
static func _views(part: Node) -> Array:
	var views: Array = part.find_children("*", "MeshInstance3D", true, false)
	if part is MeshInstance3D:
		views.append(part)
	return views.filter(func(view): return view.mesh != null)


# The ball's centre (the origin of the shell part `root`) in a mesh's own space, as the mesh
# sits at rest: a mortar or a heft module whose pivot is off the centre still cuts about the ball.
static func _centre_in(view: Node3D, root: Node) -> Vector3:
	var to_root := Transform3D.IDENTITY
	var node: Node = view
	while node != null and node != root:
		if node is Node3D:
			to_root = (node as Node3D).transform * to_root
		node = node.get_parent()
	return to_root.affine_inverse().origin.snappedf(0.001)


# What may take the window: plain opaque lit surfaces and hero_assets' plain paint. Glass, an
# unshaded halo, class accents (the ready glow swaps them by identity) and a live shader of a
# pilot's or a part's own keep their materials, because the window's material cannot draw them.
static func _takes_window(was: Material) -> bool:
	if was == null or was.resource_name == "class_accent":
		return false
	if was is BaseMaterial3D:
		return was.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and was.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	return was is ShaderMaterial and was.get_shader_parameter("paint_take") != null and was.get_shader_parameter("class_color") == null


# The level part: kit that stands outside the ball (weapon ring, hoods, drums) takes the window
# where it comes between the camera and the pilot; the cockpit inside the ball is never cut.
# _takes_window says which surfaces are swapped.
const KIT_KEEP_WITHIN := 0.93
const PLATING_RADIUS := 0.965
# Pilots too small for the shared seat back (shell_base.py: seat top -0.30, back top -0.10), and
# the height their back is lowered to.
const LOW_SEAT_BACK := {"runner_gunner": -0.24}

static func _cut_kit(pod: Node, pilot: String) -> void:
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


# A material's colour, metal, roughness, glow and equipped paint behind the window.
static func _windowed(was: Material) -> ShaderMaterial:
	var cut := ShaderMaterial.new()
	cut.shader = _shader("cutaway", CUTAWAY_SHADER)
	cut.set_shader_parameter("window", WINDOW)
	cut.set_shader_parameter("ink_width", WINDOW_INK)
	cut.set_shader_parameter("fringe", WINDOW_FRINGE)
	cut.set_shader_parameter("vertex_tint", true)
	if was is BaseMaterial3D:
		cut.set_shader_parameter("vertex_tint", was.vertex_color_use_as_albedo)
		cut.set_shader_parameter("tint", was.albedo_color)
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
		for key in ["paint_tint", "lift", "paint_take"]:
			var value = was.get_shader_parameter(key)
			if value != null:
				cut.set_shader_parameter(key, value)
	return cut


# What rides the rolling ball outside the shell (scrap chunks, part hardware, panel plates)
# would stand between the camera and the pilot, so under a plated look it takes the same
# window. Call every frame with the node those parts ride: the window follows the ball, and
# the riders are walked again only after a node joins the roll node or one of its children
# (Accretion, PanelShell). The state lives on the roll node, with one cut material per look.
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
	child.child_entered_tree.connect(_mark.bind(roll))


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
		# A multimesh has no surface overrides, and its mesh is shared with other balls.
		var mesh: Mesh = multi.multimesh.mesh.duplicate()
		for i in mesh.get_surface_count():
			if _takes_window(mesh.surface_get_material(i)):
				mesh.surface_set_material(i, _rider(cuts, mesh.surface_get_material(i)))
		multi.multimesh.mesh = mesh
	elif view != null and view.mesh != null:
		for i in view.mesh.get_surface_count():
			if _takes_window(view.get_active_material(i)):
				view.set_surface_override_material(i, _rider(cuts, view.get_active_material(i)))


# One cut material per look a rider can have, so a run's redraws add no materials.
static func _rider(cuts: Dictionary, was: Material) -> Material:
	var cut := _windowed(was)
	var key := ""
	for name in ["vertex_tint", "tint", "metal", "rough", "glow", "paint_tint", "paint_take", "plate", "plate_scale"]:
		key += str(cut.get_shader_parameter(name)) + "|"
	if not cuts.has(key):
		cut.set_shader_parameter("held", true)
		cuts[key] = cut
	return cuts[key]


# The canopy takes no parameters, so every bell shares one material.
static func _canopy() -> ShaderMaterial:
	if _canopy_material == null:
		_canopy_material = ShaderMaterial.new()
		_canopy_material.shader = _shader("canopy", CANOPY_SHADER)
	return _canopy_material


static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	return _shaders[key]
