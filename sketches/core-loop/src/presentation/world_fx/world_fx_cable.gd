extends MeshInstance3D

const Palette := preload("res://src/core/palette.gd")

const SIDES := 6
const SEGMENTS := 24

const _SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 albedo : source_color = vec3(0.16, 0.2, 0.19);
uniform vec3 wind = vec3(1.0, 0.0, 0.25);
uniform float sway_m = 0.9;
uniform float gust_hz = 0.23;
uniform bool motion_enabled = true;
uniform float phase = 0.0;

void vertex() {
	if (motion_enabled) {
		float u = UV.x;
		float w = sin(u * 3.14159);
		float t = TIME * gust_hz * 6.28318 + phase;
		float gust = 0.6 + 0.4 * sin(t * 0.37 + phase * 1.7);
		vec3 lean = normalize(wind) * (0.55 + 0.45 * sin(t)) * gust;
		vec3 bob = vec3(0.0, -0.25 * sin(t * 1.3 + u * 2.0), 0.0);
		VERTEX += (lean + bob) * sway_m * w;
	}
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 0.55;
	METALLIC = 0.4;
}
"""

static var _shader: Shader


static func make(a: Vector3, b: Vector3, sag_m := 3.0, radius_m := 0.06, colour := Palette.CABLE, sway_m := -1.0) -> MeshInstance3D:
	var c: MeshInstance3D = load("res://src/presentation/world_fx/world_fx_cable.gd").new()
	c.name = "Cable"
	c.mesh = tube(a, b, sag_m, radius_m)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("albedo", colour)
	mat.set_shader_parameter("sway_m", sway_m if sway_m >= 0.0 else clampf(a.distance_to(b) * 0.02, 0.15, 1.6))
	mat.set_shader_parameter("phase", fmod(absf(a.x * 0.37 + a.z * 0.61 + b.y * 0.13), 6.283))
	c.material_override = mat
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return c


func set_motion(enabled: bool) -> void:
	(material_override as ShaderMaterial).set_shader_parameter("motion_enabled", enabled)


static func tube(a: Vector3, b: Vector3, sag_m: float, radius_m: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var u := float(i) / SEGMENTS
		pts.append(a.lerp(b, u) + Vector3.DOWN * sag_m * 4.0 * u * (1.0 - u))
	for i in SEGMENTS + 1:
		var fwd := (pts[mini(i + 1, SEGMENTS)] - pts[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(fwd).normalized()
		for k in SIDES + 1:
			var ang := TAU * float(k) / SIDES
			var n := side * cos(ang) + up * sin(ang)
			st.set_uv(Vector2(float(i) / SEGMENTS, float(k) / SIDES))
			st.set_normal(n)
			st.add_vertex(pts[i] + n * radius_m)
	var ring := SIDES + 1
	for i in SEGMENTS:
		for k in SIDES:
			var i0 := i * ring + k
			var i1 := i0 + ring
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i0 + 1)
			st.add_index(i0 + 1)
			st.add_index(i1)
			st.add_index(i1 + 1)
	return st.commit()
