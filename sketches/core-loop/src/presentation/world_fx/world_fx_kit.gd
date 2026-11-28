extends RefCounted

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Palette := preload("res://src/core/palette.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")

const SEED := 917
const CLEAR_RADIUS := 7.0
const SHAPES := ["dot", "streak", "paper", "ring", "glint", "arc"]

const _SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, %s;
// 0 dot, 1 streak, 2 paper, 3 ring, 4 glint, 5 arc
uniform int shape = 0;
// 0 camera billboard, 1 axis billboard along the particle's Y (its velocity), 2 none, 3 flat
uniform int facing = 0;
uniform float ink = 0.0;
uniform vec3 ink_colour : source_color = vec3(%.2f, %.2f, %.2f);
uniform bool clear_zone = false;
uniform vec3 clear_center = vec3(0.0, -10000.0, 0.0);
uniform float clear_radius = 7.0;
uniform float near_fade = 2.5;
instance uniform vec4 tint : source_color = vec4(1.0);
varying vec3 centre;

void vertex() {
	centre = MODEL_MATRIX[3].xyz;
	if (facing == 0) {
		mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		float a = INSTANCE_CUSTOM.x;
		mat4 rot = mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		mat4 sc = mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * bb * rot * sc;
	} else if (facing == 1) {
		vec3 up = MODEL_MATRIX[1].xyz;
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
		vec3 side = cross(normalize(up), to_cam);
		side = length(side) < 0.001 ? MODEL_MATRIX[0].xyz : normalize(side) * length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(up, 0.0), vec4(to_cam, 0.0), MODEL_MATRIX[3]);
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = 0.0;
	float rim = 0.0;
	vec3 col = COLOR.rgb;
	if (shape == 0) {
		float soft = clamp(1.0 - r, 0.0, 1.0);
		a = soft * soft * (3.0 - 2.0 * soft) * soft;
		if (ink > 0.0) {
			a = step(r, 0.92);
			rim = smoothstep(0.72, 0.8, r);
		}
	} else if (shape == 1) {
		float across = clamp(1.0 - abs(p.x), 0.0, 1.0);
		float along = smoothstep(-1.0, 0.2, p.y) * smoothstep(1.0, 0.75, p.y);
		a = across * across * along;
	} else if (shape == 2) {
		vec2 q = abs(p);
		a = step(max(q.x, q.y), 0.96);
		rim = ink > 0.0 ? step(0.8, max(q.x, q.y)) : 0.0;
		col *= FRONT_FACING ? 1.0 : 0.72;
	} else if (shape == 3) {
		a = smoothstep(0.1, 0.0, abs(r - 0.84)) * step(r, 1.0);
	} else if (shape == 4) {
		float star = max(exp(-abs(p.x) * 26.0) * exp(-abs(p.y) * 2.6), exp(-abs(p.y) * 26.0) * exp(-abs(p.x) * 2.6));
		a = clamp(star + pow(clamp(1.0 - r * 2.2, 0.0, 1.0), 2.0), 0.0, 1.0);
	} else {
		// A rainbow: the upper half of a band, hue running red outside to violet inside.
		float band = (r - 0.62) / 0.3;
		a = step(0.0, band) * step(band, 1.0) * step(p.y, 0.0) * sin(clamp(band, 0.0, 1.0) * 3.14159);
		vec3 hue = clamp(abs(fract(vec3(band * 0.8) + vec3(0.0, 0.667, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
		col = mix(col, hue, 0.85);
	}
	col = mix(col * tint.rgb, ink_colour, rim * ink);
	float fade = smoothstep(near_fade * 0.4, near_fade, distance(centre, CAMERA_POSITION_WORLD));
	if (clear_zone) {
		fade *= smoothstep(clear_radius * 0.55, clear_radius, distance(centre, clear_center));
	}
	ALBEDO = col;
	ALPHA = clamp(a * COLOR.a * tint.a * fade, 0.0, 1.0);
}
"""

static var _materials := {}


static func facing_of(shape: String) -> int:
	match shape:
		"streak":
			return 1
		"paper":
			return 2
		"ring":
			return 3
	return 0


static func material(shape: String, blend: String, ambient := false, ink := 0.0, near_m := 2.5) -> ShaderMaterial:
	var key := "%s|%s|%s|%.2f|%.1f" % [shape, blend, ambient, ink, near_m]
	if _materials.has(key):
		return _materials[key]
	var shader := Shader.new()
	shader.code = _SHADER % [
		"blend_add, depth_draw_never" if blend == "add" else "blend_mix, depth_draw_never",
		Palette.INK_DEEP.r, Palette.INK_DEEP.g, Palette.INK_DEEP.b,
	]
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("shape", SHAPES.find(shape))
	mat.set_shader_parameter("facing", facing_of(shape))
	mat.set_shader_parameter("ink", ink)
	mat.set_shader_parameter("clear_zone", ambient)
	mat.set_shader_parameter("clear_radius", CLEAR_RADIUS)
	mat.set_shader_parameter("near_fade", near_m)
	mat.render_priority = 1 if blend == "add" else 0
	_materials[key] = mat
	return mat


static func set_clear(center: Vector3) -> void:
	for key in _materials:
		var mat: ShaderMaterial = _materials[key]
		if mat.get_shader_parameter("clear_zone"):
			mat.set_shader_parameter("clear_center", center)


static func ambient_materials() -> Array:
	return _materials.values().filter(func(m): return m.get_shader_parameter("clear_zone"))


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


static func _gradient(colours: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colours.size():
		offsets.append(float(i) / maxf(1.0, colours.size() - 1.0))
		cols.append(colours[i])
	g.offsets = offsets
	g.colors = cols
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


static func _scale_curve(kind: String) -> CurveTexture:
	match kind:
		"grow":
			return _curve([Vector2(0.0, 0.35), Vector2(1.0, 1.0)])
		"puff":
			return _curve([Vector2(0.0, 0.25), Vector2(0.3, 0.85), Vector2(1.0, 1.0)])
		"const":
			return _curve([Vector2(0.0, 1.0), Vector2(1.0, 1.0)])
	return _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.2)])


static func _alpha_curve(burst: bool) -> CurveTexture:
	if burst:
		return _curve([Vector2(0.0, 1.0), Vector2(0.6, 0.8), Vector2(1.0, 0.0)])
	return _curve([Vector2(0.0, 0.0), Vector2(0.2, 1.0), Vector2(0.75, 1.0), Vector2(1.0, 0.0)])


static func _emission(pm: ParticleProcessMaterial, s: Dictionary) -> void:
	var emit: Dictionary = s.get("emit", {})
	if emit.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = emit["box"]
	elif emit.has("sphere"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = emit["sphere"]
	elif emit.has("ring"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = emit["ring"]
		pm.emission_ring_inner_radius = emit["ring"] * emit.get("inner", 0.9)
		pm.emission_ring_height = emit.get("height", 0.0)
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	if s["attach"] != "camera" and s["attach"] != "ball":
		pm.emission_shape_offset = s.get("offset", Vector3.ZERO)


static func build(id: String) -> GPUParticles3D:
	var s: Dictionary = Specs.SPECS[id]
	var burst: bool = s["attach"] == "burst"
	var pm := ParticleProcessMaterial.new()
	pm.direction = s.get("dir", Vector3.UP)
	pm.spread = s.get("spread", 180.0)
	pm.initial_velocity_min = s["speed"][0]
	pm.initial_velocity_max = s["speed"][1]
	var g = s.get("gravity", 0.0)
	pm.gravity = g if g is Vector3 else Vector3(0.0, float(g), 0.0)
	if s.has("damping"):
		pm.damping_min = s["damping"][0]
		pm.damping_max = s["damping"][1]
	if s.has("radial"):
		pm.radial_velocity_min = s["radial"][0]
		pm.radial_velocity_max = s["radial"][1]
	if s.has("orbit"):
		pm.orbit_velocity_min = s["orbit"][0]
		pm.orbit_velocity_max = s["orbit"][1]
	if s.has("turb"):
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = s["turb"][0]
		pm.turbulence_noise_scale = s["turb"][1]
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
	if s.has("spin"):
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.angular_velocity_min = -float(s["spin"])
		pm.angular_velocity_max = float(s["spin"])
	elif s["shape"] == "dot" or s["shape"] == "glint":
		pm.angle_min = -180.0
		pm.angle_max = 180.0
	pm.particle_flag_align_y = s["shape"] == "streak"
	pm.particle_flag_rotate_y = s["shape"] == "paper"
	pm.scale_min = s["size"][0]
	pm.scale_max = s["size"][1]
	pm.scale_curve = _scale_curve(s.get("grow", "fade" if burst else "const"))
	pm.alpha_curve = _alpha_curve(burst)
	_emission(pm, s)
	var colour = s.get("colour", "SAND")
	var glow: float = s.get("glow", 1.0)
	if colour is Array:
		var ramp: Array = colour.map(func(c): return Specs.colour(c))
		if s.get("pick", "life") == "random":
			pm.color_initial_ramp = _gradient(ramp)
		else:
			pm.color_ramp = _gradient(ramp)
		pm.color = Color(glow, glow, glow, float(s.get("alpha", 1.0)))
	else:
		var c: Color = Specs.colour(colour)
		pm.color = Color(c.r * glow, c.g * glow, c.b * glow, float(s.get("alpha", 1.0)))
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	if s["shape"] == "ring":
		mesh.orientation = PlaneMesh.FACE_Y
	if s["shape"] == "streak":
		mesh.size = Vector2(s.get("width", 0.08), 1.0)
	mesh.material = material(s["shape"], s.get("blend", "mix"), s.get("ambient", false), s.get("ink", 0.0), s.get("near_m", 2.5))
	var p := GPUParticles3D.new()
	p.name = "WorldFx_%s" % id
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.amount = int(s["max"])
	p.lifetime = s["life"]
	p.one_shot = burst
	p.explosiveness = s.get("explosive", 1.0 if burst else 0.0)
	p.randomness = 0.3 if not burst else 0.0
	p.local_coords = false
	p.emitting = false
	p.preprocess = float(s["life"]) if s.get("warm", not burst) else 0.0
	p.use_fixed_seed = true
	p.seed = SEED
	p.fixed_fps = 30
	p.interpolate = true
	p.visibility_aabb = s.get("aabb", AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60)))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_instance_shader_parameter(FxLibrary.TINT, Color.WHITE)
	p.set_meta("world_fx", id)
	return p


static func quad(shape: String, size: Vector2, colour: Color, blend := "mix", alpha := 1.0, near_m := 2.5) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material(shape, blend, false, 0.0, near_m)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_instance_shader_parameter(FxLibrary.TINT, Color(colour.r, colour.g, colour.b, alpha))
	return view


static func share(s: Dictionary, low: bool, reduced: bool) -> float:
	var r := float(s.get("low", 0.5)) if low else 1.0
	if reduced:
		r = 0.0 if not s.get("motion", true) else r * 0.5
	return r


static func low_preset() -> bool:
	return String(load("res://src/presentation/graphics_preset.gd").current) == "low"


static func dressing_share(id: String, low := false, reduced := false) -> float:
	var row: Dictionary = Specs.DRESSING[id]
	return (float(row.get("low", 1.0)) if low else 1.0) * (float(row.get("reduced", 1.0)) if reduced else 1.0)


static func dressing_count(id: String, full: int, low := false, reduced := false) -> int:
	return int(floor(full * dressing_share(id, low, reduced) + 0.000001))


static func dressing_shown(id: String) -> bool:
	var flag := String(Specs.DRESSING[id].get("preset", ""))
	if flag == "":
		return true
	var preset = load("res://src/presentation/graphics_preset.gd")
	return bool(preset.PRESETS[preset.current].get(flag, true))


static func dressing_colour(id: String) -> Color:
	return Specs.colour(String(Specs.DRESSING[id].get("colour", "SAND")))


static func dressing_alpha(id: String) -> float:
	return float(Specs.DRESSING[id].get("alpha", 1.0))


static func follow_quality(host: Node) -> void:
	load("res://src/presentation/graphics_preset.gd").register_dressing_host(host)


static func cost(id: String, low := false, reduced := false) -> int:
	return int(round(float(Specs.SPECS[id]["max"]) * share(Specs.SPECS[id], low, reduced)))
