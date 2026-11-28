extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

const TINT := &"tint"
const INK := &"ink_colour"
const SEED := 731
const CEILING := 800
const MACHINE_CEILING := 876
const SPECS := {
	"roll_dust": {"pool": 1, "max": 64, "life": 0.7, "speed": [0.4, 1.4], "spread": 75.0, "gravity": 0.6,
		"size": 0.42, "colour": "SANDSTONE", "attach": "ball", "blend": "mix", "shape": "point"},
	"spark_core": {"pool": 4, "max": 24, "life": 0.3, "speed": [8.0, 16.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.1, 0.1, 0.5), "colour": "row", "attach": "world", "blend": "mix", "shape": "point", "align": true},
	"spark_halo": {"pool": 4, "max": 24, "life": 0.3, "speed": [8.0, 16.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.18, 0.18, 0.7), "colour": "row", "attach": "world", "blend": "add", "shape": "point", "align": true, "glow": 2.0},
	"crit_core": {"pool": 2, "max": 24, "life": 0.4, "speed": [9.0, 19.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.17, 0.17, 0.8), "colour": "row", "attach": "world", "blend": "mix", "shape": "point", "align": true},
	"crit_halo": {"pool": 2, "max": 24, "life": 0.4, "speed": [9.0, 19.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.3, 0.3, 1.1), "colour": "row", "attach": "world", "blend": "add", "shape": "point", "align": true, "glow": 2.5},
	"slam_ring": {"pool": 2, "max": 48, "life": 0.42, "speed": [0.0, 0.0], "radial": [11.0, 12.0], "spread": 0.0, "gravity": 0.0,
		"size": 0.5, "colour": "row", "attach": "world", "blend": "add", "shape": "ring", "ring_m": 0.6},
	"slam_dust": {"pool": 2, "max": 24, "life": 0.8, "speed": [2.0, 5.5], "spread": 70.0, "gravity": 1.0,
		"size": 0.7, "colour": "SANDSTONE", "attach": "world", "blend": "mix", "shape": "ring", "ring_m": 1.2},
	"latch_ring": {"pool": 2, "max": 24, "life": 0.2, "speed": [0.0, 0.0], "radial": [-7.0, -6.5], "spread": 0.0, "gravity": 0.0,
		"size": 0.42, "colour": "row", "attach": "world", "blend": "mix", "shape": "ring", "ring_m": 1.2, "glow": 1.5},
	"latch_halo": {"pool": 2, "max": 24, "life": 0.2, "speed": [0.0, 0.0], "radial": [-7.0, -6.5], "spread": 0.0, "gravity": 0.0,
		"size": 0.9, "colour": "row", "attach": "world", "blend": "add", "shape": "ring", "ring_m": 1.2, "glow": 2.0},
	"latch_pulse": {"pool": 2, "max": 16, "life": 0.12, "speed": [9.0, 10.5], "spread": 1.0, "gravity": 0.0, "explosive": 0.6,
		"size": 0.34, "colour": "row", "attach": "world", "blend": "mix", "shape": "point", "forward": true, "glow": 1.8},
	"kill_shards": {"pool": 3, "max": 16, "life": 0.8, "speed": [5.0, 11.0], "spread": 70.0, "gravity": -24.0, "spin": 600.0,
		"size": Vector3(0.3, 0.07, 0.24), "colour": "row", "attach": "world", "blend": "mix", "shape": "point"},
	"crack_debris": {"pool": 2, "max": 32, "life": 1.0, "speed": [4.0, 9.0], "spread": 50.0, "gravity": -24.0,
		"size": Vector3(0.28, 0.2, 0.24), "colour": "CHARCOAL", "attach": "world", "blend": "mix", "shape": "point", "spin": 540.0},
	"cache_ember": {"pool": 2, "max": 24, "life": 1.2, "speed": [1.0, 2.6], "spread": 60.0, "gravity": 0.3,
		"size": 0.34, "colour": "AMBER", "attach": "persist", "blend": "add", "shape": "point", "glow": 1.3, "warm": true, "owner": "vfx"},
	"cache_wisp": {"pool": 2, "max": 8, "life": 2.4, "speed": [0.4, 0.9], "spread": 15.0, "gravity": 0.5, "scale": [1.0, 1.6],
		"size": 0.8, "colour": "CHARCOAL", "attach": "persist", "blend": "mix", "shape": "point", "warm": true, "owner": "vfx"},
	"dig_debris": {"pool": 1, "max": 10, "life": 0.7, "speed": [12.0, 17.0], "spread": 35.0, "gravity": -26.0, "scale": [1.0, 1.8],
		"size": Vector3.ONE * 0.24, "colour": "SANDSTONE", "attach": "world", "blend": "mix", "shape": "point", "owner": "dig"},
	"dig_dust": {"pool": 1, "max": 12, "life": 0.5, "speed": [7.0, 12.0], "spread": 60.0, "gravity": 1.5, "scale": [2.5, 4.0],
		"size": 0.4, "colour": "SANDSTONE", "attach": "world", "blend": "mix", "shape": "point", "owner": "dig"},
	"dig_grit": {"pool": 2, "max": 4, "life": 0.65, "speed": [0.15, 0.4], "spread": 60.0, "gravity": -3.0, "scale": [0.12, 0.25],
		"size": Vector3.ONE * 0.24, "colour": "SANDSTONE", "attach": "persist", "blend": "mix", "shape": "point", "down": true, "owner": "dig"},
	"net_dust": {"pool": 2, "max": 14, "life": 0.6, "speed": [1.5, 3.5], "spread": 80.0, "gravity": 0.8,
		"size": 0.5, "colour": "SANDSTONE", "attach": "world", "blend": "mix", "shape": "ring", "ring_m": 1.0, "owner": "highdraft"},
	"steam_puff": {"pool": 6, "max": 10, "life": 1.1, "speed": [1.0, 2.6], "spread": 30.0, "gravity": 1.2, "grow": true,
		"size": 0.7, "colour": "LEDGER", "alpha": 0.75, "attach": "world", "blend": "mix", "shape": "point", "owner": "machine"},
	"steam_jet": {"pool": 16, "max": 10, "life": 0.6, "speed": [3.0, 6.0], "spread": 12.0, "gravity": 0.8, "grow": true,
		"size": 0.8, "colour": "LEDGER", "alpha": 0.75, "attach": "persist", "blend": "mix", "shape": "point", "owner": "machine"},
	"brass_spark": {"pool": 6, "max": 16, "life": 0.35, "speed": [6.0, 13.0], "spread": 70.0, "gravity": -16.0,
		"size": Vector3(0.08, 0.08, 0.5), "colour": "BRASS", "attach": "world", "blend": "add", "shape": "point", "align": true, "glow": 1.2, "owner": "machine"},
	"arc_fizz": {"pool": 6, "max": 14, "life": 0.18, "speed": [10.0, 18.0], "spread": 180.0, "gravity": 0.0,
		"size": Vector3(0.06, 0.06, 0.6), "colour": "ANCIENT", "attach": "world", "blend": "add", "shape": "point", "align": true, "glow": 1.3, "owner": "machine"},
	"arc_crawl": {"pool": 12, "max": 10, "life": 0.25, "speed": [0.5, 1.5], "spread": 180.0, "gravity": 0.0,
		"size": 0.18, "colour": "ANCIENT", "attach": "persist", "blend": "add", "shape": "ring", "ring_m": 1.1, "glow": 1.8, "owner": "machine"},
	"seam_motes": {"pool": 6, "max": 12, "life": 0.9, "speed": [1.0, 3.0], "spread": 25.0, "gravity": 2.5,
		"size": 0.16, "colour": "ANCIENT", "attach": "world", "blend": "add", "shape": "ring", "ring_m": 0.8, "glow": 1.8, "owner": "machine"},
	"daze_halo": {"pool": 6, "max": 6, "life": 1.2, "speed": [0.0, 0.0], "spread": 0.0, "gravity": 0.0, "local": true, "scale": [0.9, 1.1],
		"size": 0.6, "colour": "AMBER", "attach": "persist", "blend": "mix", "shape": "ring", "ring_m": 0.8, "look": "star", "owner": "machine"},
	"fuse_sputter": {"pool": 4, "max": 6, "life": 0.3, "speed": [1.5, 3.5], "spread": 50.0, "gravity": -6.0,
		"size": 0.08, "colour": "AMBER", "attach": "persist", "blend": "add", "shape": "point", "glow": 2.0, "owner": "machine"},
	"phase_ring": {"pool": 2, "max": 64, "life": 0.6, "speed": [0.0, 0.0], "radial": [16.0, 18.0], "spread": 0.0, "gravity": 0.0,
		"size": 0.35, "colour": "row", "attach": "world", "blend": "mix", "shape": "ring", "ring_m": 1.5, "owner": "machine"},
	"shell_shards": {"pool": 3, "max": 16, "life": 1.1, "speed": [6.0, 12.0], "spread": 60.0, "gravity": -24.0, "spin": 600.0,
		"size": Vector3(0.3, 0.06, 0.22), "colour": "VERDIGRIS", "attach": "world", "blend": "mix", "shape": "point", "owner": "machine"},
	"plate_chunks": {"pool": 3, "max": 16, "life": 1.1, "speed": [6.0, 12.0], "spread": 60.0, "gravity": -24.0, "spin": 600.0,
		"size": Vector3(0.34, 0.08, 0.28), "colour": "RUST", "attach": "world", "blend": "mix", "shape": "point", "owner": "machine"},
}

const _HEAD := """
shader_type spatial;
render_mode %s;
instance uniform vec4 tint : source_color = vec4(1.0);
// How far a hot particle starts toward white; it cools over its life (FlashGuard.whiten scales it).
instance uniform float heat = 0.0;
// Palette.CHARCOAL, set from GDScript so the engine converts it to linear light (a literal would not be).
uniform vec3 ink_colour : source_color;
varying float v_life;
varying float v_seed;
float seed_of(int id) {
	return fract(sin(float(id) * 12.9898 + 78.233) * 43758.5453);
}
"""
const LENS_FADE := Vector2(1.5, 4.0)
const _BILLBOARD := """
void vertex() {
	v_life = INSTANCE_CUSTOM.y;
	v_seed = seed_of(INSTANCE_ID);
	float c = cos(INSTANCE_CUSTOM.x);
	float s = sin(INSTANCE_CUSTOM.x);
	mat4 facing = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	facing = facing * mat4(vec4(c, -s, 0.0, 0.0), vec4(s, c, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float k = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing * mat4(vec4(k, 0.0, 0.0, 0.0), vec4(0.0, k, 0.0, 0.0), vec4(0.0, 0.0, k, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
"""
const _LOOKS := {
	"puff": ["unshaded, cull_disabled, blend_mix, depth_draw_never", "billboard", """
uniform vec2 lens_fade = vec2(1.5, 4.0);
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = 0.8 + 0.09 * sin(a * 5.0 + v_seed * 6.283) + 0.05 * sin(a * 3.0 - v_seed * 17.0);
	if (r > edge) {
		discard;
	}
	vec3 n = vec3(p / edge, sqrt(max(0.0, 1.0 - r * r / (edge * edge))));
	float lit = step(0.25, dot(n, normalize(vec3(-0.45, 0.7, 0.55))));
	vec3 base = tint.rgb * COLOR.rgb;
	vec3 shade = mix(base * vec3(0.84, 0.85, 0.9), base * 1.06, lit);
	float ink = smoothstep(edge - 0.07, edge - 0.02, r);
	ALBEDO = mix(shade, base * 0.7, ink * 0.5);
	ALPHA = tint.a * COLOR.a * smoothstep(lens_fade.x, lens_fade.y, length(VERTEX));
}
"""],
	"glow": ["unshaded, cull_disabled, blend_add, depth_draw_never", "billboard", """
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float halo = pow(max(0.0, 1.0 - r), 2.2);
	float hot = heat * (1.0 - v_life) * (1.0 - smoothstep(0.0, 0.3, r));
	// The glow multiplier spreads the halo wider instead of clipping it white, so the hue survives on sand.
	float g = max(COLOR.r, max(COLOR.g, COLOR.b));
	halo = pow(max(0.0, 1.0 - r), 2.2 / max(g, 1.0));
	ALBEDO = mix(tint.rgb * min(COLOR.rgb, vec3(1.0)), vec3(1.0), clamp(hot, 0.0, 1.0));
	ALPHA = tint.a * COLOR.a * halo * 0.8;
}
"""],
	"streak": ["unshaded, cull_disabled, %s", "streak", """
void fragment() {
	float along = UV.y;
	float across = abs(UV.x * 2.0 - 1.0);
	float w = mix(1.0, 0.18, along);
	float body = 1.0 - smoothstep(w * 0.7, w, across);
	float tip = 1.0 - smoothstep(0.85, 1.0, 1.0 - along);
	float core = (1.0 - smoothstep(0.0, w * 0.45, across)) * (1.0 - along);
	float hot = clamp(heat * (1.0 - v_life) * core * 1.6, 0.0, 1.0);
	ALBEDO = mix(tint.rgb * %s, vec3(1.0), hot);%s
	ALPHA = tint.a * COLOR.a * body * tip%s;
}
"""],
	"chunk": ["diffuse_toon, specular_disabled, cull_back, blend_mix, depth_draw_opaque", "chunk", """
void fragment() {
	ALBEDO = tint.rgb * min(COLOR.rgb, vec3(1.0)) * (0.82 + 0.3 * v_seed);
	ROUGHNESS = 0.9;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
"""],
	"star": ["unshaded, cull_disabled, blend_mix, depth_draw_opaque", "billboard", """
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	// Five points, one straight up: 1 at a tip, 0 in a notch.
	float tip = pow(0.5 + 0.5 * cos(5.0 * (atan(p.y, p.x) - 1.5708)), 2.0);
	float edge = mix(0.46, 0.97, tip);
	if (r > edge) {
		discard;
	}
	vec3 base = tint.rgb * COLOR.rgb;
	vec3 fill = mix(base, mix(base, vec3(1.0), 0.45), step(r, edge * 0.32));
	ALBEDO = mix(fill, ink_colour, step(edge - 0.2, r));
	ALPHA = tint.a * COLOR.a;
}
"""],
	"bead": ["unshaded, cull_disabled, blend_mix, depth_draw_opaque", "billboard", """
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	if (r > 0.95) {
		discard;
	}
	vec3 base = tint.rgb * COLOR.rgb;
	float hot = clamp(heat * (1.0 - v_life) * (1.0 - smoothstep(0.0, 0.35, r)), 0.0, 1.0);
	vec3 fill = mix(base, vec3(1.0), hot);
	ALBEDO = mix(fill, vec3(0.141, 0.165, 0.157), smoothstep(0.66, 0.72, r));
	ALPHA = tint.a * COLOR.a;
}
"""],
}
const _STREAK_VERTEX := """
void vertex() {
	v_life = INSTANCE_CUSTOM.y;
	v_seed = seed_of(INSTANCE_ID);
	vec3 along = MODEL_MATRIX[1].xyz;
	float len = length(along);
	along /= max(len, 0.0001);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	vec3 side = cross(along, to_eye);
	side = length(side) > 0.0001 ? normalize(side) : normalize(INV_VIEW_MATRIX[0].xyz);
	float wid = length(MODEL_MATRIX[0].xyz);
	mat4 facing = mat4(vec4(side * wid, 0.0), vec4(along * len, 0.0), vec4(cross(side, along), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
"""
const _CHUNK_VERTEX := """
void vertex() {
	v_life = INSTANCE_CUSTOM.y;
	v_seed = seed_of(INSTANCE_ID);
	vec3 axis = normalize(vec3(v_seed - 0.5, 0.6, fract(v_seed * 7.13) - 0.5));
	float a = INSTANCE_CUSTOM.x + v_seed * 6.283;
	float c = cos(a);
	float s = sin(a);
	mat3 turn = mat3(c) + (1.0 - c) * outerProduct(axis, axis) + s * mat3(vec3(0.0, axis.z, -axis.y), vec3(-axis.z, 0.0, axis.x), vec3(axis.y, -axis.x, 0.0));
	VERTEX = turn * VERTEX;
	NORMAL = turn * NORMAL;
}
"""
const HEAT := {"glow": 0.55, "streak": 0.7, "bead": 0.35, "puff": 0.0, "chunk": 0.0, "star": 0.0}

static var _shaders := {}
static var _meshes := {}

static func lens_alpha(eye_m: float) -> float:
	return smoothstep(LENS_FADE.x, LENS_FADE.y, eye_m)


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, {})


static func effects(kind: String, variant := "") -> Dictionary:
	var row := EventKinds.juice(kind)
	if variant != "" and row.has(variant) and row[variant].has("fx"):
		return row[variant]["fx"]
	if variant != "" and row.has(variant) and not row[variant].is_empty():
		return row[variant]
	return row.get("fx", {})


static func colour(id: String, kind: String) -> Color:
	var source: String = spec(id).get("colour", "row")
	if source == "row":
		return EventKinds.color(kind)
	var named: Dictionary = (Palette as Script).get_script_constant_map()
	var tint: Color = named.get(source, Palette.SAND)
	tint.a = float(spec(id).get("alpha", 1.0))
	return tint


static func ceiling(owner := "vfx") -> int:
	var total := 0
	for id in SPECS:
		if SPECS[id].get("owner", "vfx") == owner:
			total += int(SPECS[id]["pool"]) * int(SPECS[id]["max"])
	return total


static func look(id: String) -> String:
	var s := spec(id)
	if s.is_empty():
		return ""
	if s.has("look"):
		return s["look"]
	if s["size"] is Vector3:
		if s.get("align", false):
			return "streak"
		return "chunk"
	if s["blend"] == "add":
		return "glow"
	if s.get("colour", "row") == "row":
		return "bead"
	return "puff"


static func _material(id: String) -> ShaderMaterial:
	return look_material(look(id), spec(id)["blend"])


static func look_material(kind: String, blend := "mix") -> ShaderMaterial:
	var key := kind + ":" + (blend if kind == "streak" else "")
	if not _shaders.has(key):
		var row: Array = _LOOKS[kind]
		var modes: String = row[0]
		var body: String = row[2]
		if kind == "streak":
			modes = modes % ("blend_add, depth_draw_never" if blend == "add" else "blend_mix, depth_draw_opaque")
			var ink := "\n\tALBEDO = mix(ALBEDO, ink_colour, smoothstep(w * 0.5, w * 0.62, across));"
			body = body % (["min(COLOR.rgb, vec3(1.0))", "", " * (1.0 - smoothstep(0.0, 1.0, across)) * 0.7"] if blend == "add" else ["COLOR.rgb", ink, ""])
		var vertex: String = {"billboard": _BILLBOARD, "streak": _STREAK_VERTEX, "chunk": _CHUNK_VERTEX}[row[1]]
		var shader := Shader.new()
		shader.code = (_HEAD % modes) + vertex + body
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(INK, Palette.CHARCOAL)
		if kind == "puff":
			mat.set_shader_parameter("lens_fade", LENS_FADE)
		_shaders[key] = mat
	return _shaders[key]


const HEAT_GROUP := &"fx_heat"

static func set_heat(p: GeometryInstance3D, kind := "") -> void:
	if kind == "":
		kind = p.get_meta("fx_look", "")
	if HEAT.has(kind):
		p.set_meta("fx_look", kind)
		p.set_instance_shader_parameter("heat", FlashGuard.whiten(HEAT[kind]))
		if not p.is_in_group(HEAT_GROUP):
			p.add_to_group(HEAT_GROUP)


static func material_of(p: GPUParticles3D) -> Material:
	return p.draw_pass_1.surface_get_material(0)


static func look_mesh(kind: String, size, blend := "mix") -> Mesh:
	var key := kind + ":" + blend + ":" + str(size)
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	match kind:
		"chunk":
			mesh = _shard(size if size is Vector3 else Vector3.ONE * float(size))
		"streak":
			var quad := QuadMesh.new()
			quad.size = Vector2(size.x * 2.0, maxf(size.y, size.z)) if size is Vector3 else Vector2.ONE * float(size)
			mesh = quad
		_:
			var quad := QuadMesh.new()
			var d: float = (size.x if size is Vector3 else float(size)) * (1.25 if kind == "puff" else 1.0)
			quad.size = Vector2(d, d)
			mesh = quad
	_meshes[key] = mesh
	return mesh


static func _shard(size: Vector3) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var corners: Array[Vector3] = []
	for i in 8:
		var c := Vector3(-0.5 if i & 1 == 0 else 0.5, -0.5 if i & 2 == 0 else 0.5, -0.5 if i & 4 == 0 else 0.5)
		c *= Vector3(rng.randf_range(0.7, 1.15), rng.randf_range(0.7, 1.15), rng.randf_range(0.7, 1.15))
		corners.append(c * size * 1.15)
	corners[7] *= 0.45
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		for tri in [[f[0], f[1], f[2]], [f[0], f[2], f[3]]]:
			var a: Vector3 = corners[tri[0]]
			var b: Vector3 = corners[tri[1]]
			var c: Vector3 = corners[tri[2]]
			var n := (b - a).cross(c - a).normalized()
			if n.dot((a + b + c) / 3.0) < 0.0:
				n = -n
				var swap := b
				b = c
				c = swap
			for v in [a, c, b]:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


static func build(id: String) -> GPUParticles3D:
	var s := spec(id)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.0, -1.0) if s.get("forward", false) else (Vector3.DOWN if s.get("down", false) else Vector3.UP)
	pm.spread = s["spread"]
	pm.initial_velocity_min = s["speed"][0]
	pm.initial_velocity_max = s["speed"][1]
	if s.has("radial"):
		pm.radial_velocity_min = s["radial"][0]
		pm.radial_velocity_max = s["radial"][1]
	pm.gravity = Vector3(0.0, s["gravity"], 0.0)
	var glow: float = s.get("glow", 1.0)
	pm.color = Color(glow, glow, glow)
	pm.particle_flag_align_y = s.get("align", false)
	pm.scale_min = s.get("scale", [0.6, 1.2])[0]
	pm.scale_max = s.get("scale", [0.6, 1.2])[1]
	if s.has("spin"):
		pm.angular_velocity_min = -float(s["spin"])
		pm.angular_velocity_max = float(s["spin"])
	if s["shape"] == "ring":
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = s["ring_m"]
		pm.emission_ring_inner_radius = s["ring_m"] * 0.9
		pm.emission_ring_height = 0.0
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0 if s["blend"] == "add" or s.get("grow", false) else 0.35))
	var fade_tex := CurveTexture.new()
	fade_tex.curve = fade
	pm.scale_curve = fade_tex
	if s.get("grow", false):
		var swell := Curve.new()
		swell.max_value = 2.0
		swell.add_point(Vector2(0.0, 0.5))
		swell.add_point(Vector2(1.0, 1.8))
		var swell_tex := CurveTexture.new()
		swell_tex.curve = swell
		pm.scale_curve = swell_tex
	if s["blend"] == "add" or s["attach"] == "ball" or s.get("grow", false):
		pm.alpha_curve = fade_tex
	var kind := look(id)
	if kind == "puff":
		pm.damping_min = 0.6
		pm.damping_max = 1.8
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		if not s.has("spin"):
			pm.angular_velocity_min = -40.0
			pm.angular_velocity_max = 40.0
		if s.get("grow", false) or s["attach"] == "persist":
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			pm.turbulence_noise_scale = 3.0
			pm.turbulence_influence_min = 0.05
			pm.turbulence_influence_max = 0.15
	elif kind == "streak":
		pm.damping_min = 2.0
		pm.damping_max = 5.0
	elif kind == "glow" or kind == "bead":
		pm.angle_min = 0.0
		pm.angle_max = 360.0
	var mesh := look_mesh(kind, s["size"], s["blend"])
	if mesh is PrimitiveMesh:
		mesh.material = _material(id)
	else:
		mesh.surface_set_material(0, _material(id))
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.set_meta("fx_look", kind)
	if kind == "puff" or kind == "bead" or kind == "star":
		p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.amount = int(s["max"])
	p.lifetime = s["life"]
	p.one_shot = s["attach"] == "world"
	p.explosiveness = s.get("explosive", 1.0) if p.one_shot else 0.0
	p.local_coords = s.get("local", false)
	p.emitting = false
	p.preprocess = float(s["life"]) if s.get("warm", false) else 0.0
	p.use_fixed_seed = true
	p.seed = SEED
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 10, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.name = "Fx_%s" % id
	return p


static func fire(p: GPUParticles3D, id: String, kind: String, count: int, at: Vector3, tint := Color.TRANSPARENT, toward := Vector3.ZERO) -> void:
	p.amount_ratio = clampf(float(count) / float(p.amount), 0.0, 1.0)
	if toward.length() > 0.01 and spec(id).get("forward", false):
		p.global_transform = Transform3D(Basis.looking_at(toward.normalized(), Vector3.UP), at)
	else:
		p.global_transform = Transform3D(Basis.IDENTITY, at)
	p.set_instance_shader_parameter(TINT, tint if tint.a > 0.0 else colour(id, kind))
	set_heat(p, look(id))
	p.restart()
	p.emitting = true


static func burst(parent: Node, id: String, at: Vector3, count := -1, tint := Color.TRANSPARENT, toward := Vector3.ZERO, isolate := false) -> GPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := build(id)
	p.one_shot = true
	p.explosiveness = float(spec(id).get("explosive", 1.0))
	parent.add_child(p)
	if isolate:
		p.top_level = true
	var n := count if count > 0 else int(spec(id)["max"])
	fire(p, id, "", n, at, tint, toward)
	var tree := parent.get_tree()
	if tree != null:
		var ref: WeakRef = weakref(p)
		tree.create_timer(p.lifetime + 0.15).timeout.connect(func() -> void:
			var node: Object = ref.get_ref()
			if node != null and (node as GPUParticles3D).speed_scale > 0.0:
				(node as Node).queue_free()
		)
	return p
