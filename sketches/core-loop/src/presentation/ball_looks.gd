extends RefCounted

# Candidate looks for the ball (the "ball look" taste pick, 13 Nov 2026), behind the launch
# switch --ball-look=<id>. A look is one shared shell GLB with the usual Core and Pod parts
# (tools/blender/ball_looks.py); every pilot wears it while the look is on. "today" keeps the
# game's own shells. hero_assets.gd asks for the paths before a fit and calls dress() after.
#
#   gyro      three crossed hoops around an open seat
#   bell      a diving bell: painted prow, a glass back the player sees the pilot through
#   cutaway   a solid plated ball; a window opens on whichever side faces the camera

const TODAY := "today"
const LOOKS := {
	"gyro": "res://assets/models/world_one/ball_look_gyro.glb",
	"bell": "res://assets/models/world_one/ball_look_bell.glb",
	"cutaway": "res://assets/models/world_one/ball_look_cutaway.glb",
}

# The cutaway window: the cosine of its half angle seen from the ball's centre, the ink line
# round it and the halftone fringe outside that. 0.76 is about 40 degrees, which clears a
# seated pilot of half the ball's height and leaves a rim of plating to show the spin.
const WINDOW := 0.76
const WINDOW_INK := 0.035
const WINDOW_FRINGE := 0.11

const CUTAWAY_SHADER := """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform float metal = 0.0;
uniform float rough = 0.8;
uniform vec3 glow : source_color = vec3(0.0);
uniform vec3 lining : source_color = vec3(0.82, 0.77, 0.65);
uniform vec3 ink : source_color = vec3(0.14, 0.16, 0.16);
uniform float window = 0.76;
uniform float ink_width = 0.035;
uniform float fringe = 0.11;
varying vec3 from_centre;
varying vec3 to_camera;
varying vec3 to_eye;
void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	from_centre = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - centre;
	to_camera = CAMERA_POSITION_WORLD - centre;
	to_eye = INV_VIEW_MATRIX[2].xyz;
}
void fragment() {
	float facing = dot(normalize(from_centre), normalize(to_camera));
	if (IN_SHADOW_PASS) {
		// In a light's pass the eye is the light. The half toward it is left out, so the sun
		// reaches the pilot; the far half still throws the whole round shadow on the ground.
		if (dot(normalize(from_centre), normalize(to_eye)) > 0.0) {
			discard;
		}
	} else if (facing > window) {
		discard;
	}
	vec3 base = vertex_tint ? COLOR.rgb : tint.rgb;
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
		// Only the plated ball has an inside; a pad or hub seen from behind is not drawn.
		if (!vertex_tint) {
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


static func ids() -> Array:
	return [TODAY] + LOOKS.keys()


# True for a look's own shell path.
static func is_look(path: String) -> bool:
	return path != "" and LOOKS.values().has(path)


# The look's shell path under each pilot id, for hero_assets.shell_assets; {} for today's.
static func asset_paths(look: String, pilots: Array) -> Dictionary:
	var path := String(LOOKS.get(look, ""))
	var out := {}
	if path != "" and ResourceLoader.exists(path):
		for pilot in pilots:
			out[pilot] = path
	return out


# Gives a fitted shell (hero_assets.fit_shell_into's {core, pod}) the look's own materials.
static func dress(look: String, shell: Dictionary) -> void:
	if shell.is_empty():
		return
	if look == "cutaway":
		_cut(shell.core)
	elif look == "bell":
		for view in (shell.pod as Node).find_children("*", "MeshInstance3D", true, false):
			for i in view.mesh.get_surface_count():
				var was: Material = view.get_active_material(i)
				if was != null and was.resource_name == "glass":
					var canopy := ShaderMaterial.new()
					canopy.shader = _shader("canopy", CANOPY_SHADER)
					view.set_surface_override_material(i, canopy)


# Every surface of the rolling part takes the window, keeping the colour it was painted with.
# A class_accent surface keeps hero_assets' own material, which the ready glow swaps by identity.
static func _cut(core: Node) -> void:
	var views: Array = core.find_children("*", "MeshInstance3D", true, false)
	if core is MeshInstance3D:
		views.append(core)
	for view in views:
		for i in view.mesh.get_surface_count():
			var was: Material = view.get_active_material(i)
			if was != null and was.resource_name == "class_accent":
				continue
			var cut := ShaderMaterial.new()
			cut.shader = _shader("cutaway", CUTAWAY_SHADER)
			cut.set_shader_parameter("window", WINDOW)
			cut.set_shader_parameter("ink_width", WINDOW_INK)
			cut.set_shader_parameter("fringe", WINDOW_FRINGE)
			if was is BaseMaterial3D:
				cut.set_shader_parameter("vertex_tint", was.vertex_color_use_as_albedo)
				cut.set_shader_parameter("tint", was.albedo_color)
				cut.set_shader_parameter("metal", was.metallic)
				cut.set_shader_parameter("rough", was.roughness)
				if was.emission_enabled:
					cut.set_shader_parameter("glow", was.emission * was.emission_energy_multiplier)
			else:
				cut.set_shader_parameter("vertex_tint", true)
			view.set_surface_override_material(i, cut)


static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	return _shaders[key]
