extends Node3D

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Comfort := preload("res://src/core/comfort.gd")


const POOL := 4
const LIFE := 0.34
const CARD_LIFE := 0.9
const FUSION_LIFE := 0.42
const SHOCKWAVE_LIFE := 0.3
const POP := 0.16
const OVERSHOOT := 1.2
const FUSION_OVERSHOOT := 1.28
const SPIN := 1.6
const CARD_TILT := 0.21
const RENDER_PRIORITY := 0
const HEAT := 0.8
const SCREEN_CAP := 0.4
const CAP_WITHIN_M := 7.5
const CAP_FULL_M := 6.0

const MODE_BURST := 0
const MODE_CARD := 1
const MODE_FUSION := 2
const MODE_SHOCKWAVE := 3

const _SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 accent : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float heat = 0.0;
uniform float turn = 0.0;
uniform float punch = 0.0;
uniform float progress = 0.0;
uniform int mode = 0;
uniform int style = 0;
uniform vec3 INK : source_color;
uniform vec3 LEDGER : source_color;
uniform vec3 RUST : source_color;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

float halftone(vec2 p, float freq) {
	vec2 cell = fract(p * freq) - 0.5;
	return step(length(cell), 0.24);
}

void vertex() {
	float c = cos(turn);
	float s = sin(turn);
	vec2 v = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	float k = length(MODEL_MATRIX[0].xyz);
	vec3 world = MODEL_MATRIX[3].xyz + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * k;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

vec4 burst(vec2 p) {
	float r = length(p);
	float spokes = mix(10.0, 14.0, step(0.5, punch));
	float s = (atan(p.y, p.x) / 6.28318 + 0.5) * spokes;
	float i = floor(s);
	float tri = 1.0 - abs(fract(s) - 0.5) * 2.0;
	float reach = (mod(i, 2.0) < 1.0 ? 0.98 : 0.7) * (0.9 + 0.1 * hash(i));
	float edge = mix(0.4 - 0.05 * punch, reach, pow(tri, 1.5));
	if (r > edge) {
		return vec4(0.0);
	}
	vec3 body = mix(tint.rgb, LEDGER, step(r, edge * 0.5));
	float dots = halftone(p, 7.5) * step(edge * 0.48, r) * step(r, edge - 0.14);
	body = mix(body, accent.rgb, dots * (0.25 + 0.35 * punch));
	float inner_ink = step(abs(r - edge * 0.52), 0.028 * punch) * step(0.25, punch);
	body = mix(body, INK, inner_ink);
	body = mix(body, vec3(1.0), clamp(heat, 0.0, 1.0));
	return vec4(mix(body, INK, step(edge - 0.12, r)), 1.0);
}

vec4 card(vec2 p) {
	vec2 q = abs(p) - vec2(0.92, 0.6);
	if (q.x > 0.0 || q.y > 0.0) {
		return vec4(0.0);
	}
	vec3 paper = LEDGER;
	paper = mix(paper, INK, 0.14 * halftone(p, 9.0) * step(0.22, p.x - p.y));
	paper = mix(paper, INK, 0.35 * step(abs(fract(p.y * 4.5) - 0.5), 0.05) * step(p.y, 0.3));
	float ring_d = length(p - vec2(0.38, -0.2));
	float stamp = step(ring_d, 0.31) * step(0.18, ring_d);
	float bar_a = step(abs(p.y + 0.15), 0.032) * step(abs(p.x - 0.38), 0.36);
	float bar_b = step(abs(p.y + 0.25), 0.032) * step(abs(p.x - 0.38), 0.36);
	paper = mix(paper, RUST, clamp(stamp + bar_a + bar_b, 0.0, 1.0));
	paper = mix(paper, INK, step(length(p - vec2(-0.7, 0.38)), 0.08));
	paper = mix(paper, tint.rgb, step(0.42, p.y) * step(-0.55, p.x) * step(p.x, 0.78));
	return vec4(mix(paper, INK, step(-0.09, max(q.x, q.y))), 1.0);
}

vec4 fusion(vec2 p) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = 0.85;
	float inner = 0.42;
	if (style == 0) {
		float hex = cos(mod(a + 3.14159, 1.0472) - 0.5236);
		float spire = pow(0.5 + 0.5 * cos(6.0 * a), 2.5);
		edge = mix(0.62 / max(hex, 0.45), 0.96, spire * 0.65);
		inner = 0.48;
	} else if (style == 1) {
		float bolt = abs(fract((a / 6.28318 + 0.5) * 12.0) - 0.5) * 2.0;
		edge = mix(0.42, 0.98, pow(1.0 - bolt, 1.8));
		inner = 0.38;
	} else if (style == 2) {
		float tooth = fract((a / 6.28318 + 0.5) * 8.0);
		edge = mix(0.6, 0.96, step(0.35, tooth) * (1.0 - 0.35 * tooth));
		inner = 0.46;
	} else if (style == 3) {
		float split = abs(sin(4.0 * a));
		edge = mix(0.48, 0.98, pow(split, 0.7));
		inner = 0.44;
	} else if (style == 4) {
		float swirl = 0.5 + 0.5 * sin(6.0 * a + r * 5.0);
		edge = mix(0.5, 0.97, pow(swirl, 1.4));
		inner = 0.4;
	} else {
		float lobe = 0.5 + 0.5 * cos(8.0 * a + 0.7 * sin(4.0 * a));
		edge = mix(0.55, 0.98, pow(lobe, 1.2));
		inner = 0.5;
	}
	if (r > edge) {
		return vec4(0.0);
	}
	vec3 body = mix(tint.rgb, accent.rgb, step(r, edge * inner));
	body = mix(body, LEDGER, step(r, edge * 0.22));
	float dots = halftone(p, 8.0) * step(edge * inner, r) * step(r, edge - 0.12);
	body = mix(body, accent.rgb, dots * 0.4);
	float seam = step(abs(r - edge * inner), 0.045);
	body = mix(body, INK, seam);
	body = mix(body, vec3(1.0), clamp(heat, 0.0, 1.0));
	return vec4(mix(body, INK, step(edge - 0.11, r)), 1.0);
}

vec4 shockwave(vec2 p) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float front = mix(0.35, 0.94, progress);
	float band = mix(0.22, 0.09, progress);
	float rays = 0.5 + 0.5 * cos(16.0 * a);
	float outer = front + band * (0.55 + 0.45 * pow(rays, 2.0));
	float inner = max(0.05, front - band * 0.75);
	if (r > outer || r < inner) {
		return vec4(0.0);
	}
	vec3 body = mix(tint.rgb, accent.rgb, step(r, front));
	body = mix(body, vec3(1.0), clamp(heat, 0.0, 1.0));
	float keyline = step(outer - 0.06, r) + step(r, inner + 0.05);
	return vec4(mix(body, INK, clamp(keyline, 0.0, 1.0)), 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec4 c = burst(p);
	if (mode == 1) {
		c = card(p);
	} else if (mode == 2) {
		c = fusion(p);
	} else if (mode == 3) {
		c = shockwave(p);
	}
	if (c.a <= 0.0) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = alpha;
}
"""

var spawned := {"burst": 0, "card": 0, "fusion": 0, "shockwave": 0, "shift_over": 0}

var _slots: Array = []
var _next := 0


func _init() -> void:
	name = "KillMark"
	var shader := Shader.new()
	shader.code = _SHADER
	for i in POOL + 1:
		var node := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		node.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.render_priority = RENDER_PRIORITY
		mat.set_shader_parameter("INK", Palette.CHARCOAL)
		mat.set_shader_parameter("LEDGER", Palette.LEDGER)
		mat.set_shader_parameter("RUST", Palette.RUST)
		mat.set_shader_parameter("accent", Palette.LEDGER_CREAM)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		node.extra_cull_margin = 2.0
		node.visible = false
		add_child(node)
		_slots.append({"node": node, "mat": mat, "t": 1.0, "life": LIFE, "size": 1.0, "mode": 0, "seed": 0.0,
			"alpha": 1.0, "style": 0, "punch": 0.0})


func _bump_spawned(key: String) -> void:
	spawned[key] = int(spawned.get(key, 0)) + 1


func fire(at: Vector3, size: float, tint: Color, governed := Vector3.ONE, punch := 0.0) -> void:
	var slot: Dictionary = _slots[_next]
	_next = (_next + 1) % POOL
	_start(slot, at, size * governed.y, tint, LIFE * governed.z, MODE_BURST, governed.x,
		Palette.LEDGER_CREAM, 0, clampf(punch, 0.0, 1.0))
	_bump_spawned("burst")


func card(at: Vector3, size := 1.6, tint := Palette.LEDGER) -> void:
	_start(_slots[POOL], at, size, tint, CARD_LIFE, MODE_CARD, 1.0, Palette.RUST, 0, 0.0)
	_bump_spawned("card")


func shift_over(at: Vector3, size := 1.85, tint := Palette.AMBER, governed := Vector3.ONE) -> void:
	fire(at, size * 1.15, tint, governed, 1.0)
	_start(_slots[POOL], at + Vector3.UP * 0.45, size * governed.y, tint, CARD_LIFE * governed.z,
		MODE_CARD, governed.x, Palette.RUST, 0, 1.0)
	_bump_spawned("card")
	_bump_spawned("shift_over")


func fusion_burst(at: Vector3, size: float, primary: Color, accent: Color, style: int, governed := Vector3.ONE) -> void:
	var slot: Dictionary = _slots[_next]
	_next = (_next + 1) % POOL
	_start(slot, at, size * governed.y, primary, FUSION_LIFE * governed.z, MODE_FUSION, governed.x,
		accent, clampi(style, 0, 5), 0.85)
	_bump_spawned("fusion")


func shockwave(at: Vector3, size: float, tint: Color, accent := Palette.LEDGER_CREAM, governed := Vector3.ONE) -> void:
	var slot: Dictionary = _slots[_next]
	_next = (_next + 1) % POOL
	_start(slot, at, size * governed.y, tint, SHOCKWAVE_LIFE * governed.z, MODE_SHOCKWAVE, governed.x,
		accent, 0, 1.0)
	_bump_spawned("shockwave")


func clear() -> void:
	for slot in _slots:
		slot["t"] = 1.0
		slot["node"].visible = false


func _start(slot: Dictionary, at: Vector3, size: float, tint: Color, life: float, mode: int, alpha: float,
		accent := Palette.LEDGER_CREAM, style := 0, punch := 0.0) -> void:
	slot["t"] = 0.0
	slot["alpha"] = FlashGuard.info(alpha)
	slot["life"] = maxf(0.05, life)
	slot["size"] = size * 0.5
	slot["mode"] = mode
	slot["style"] = style
	slot["punch"] = punch
	slot["seed"] = fmod(at.x * 1.7 + at.z * 3.1, TAU)
	var node: MeshInstance3D = slot["node"]
	node.global_position = at
	node.visible = true
	var mat: ShaderMaterial = slot["mat"]
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("accent", accent)
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("style", style)
	mat.set_shader_parameter("punch", punch)
	_draw(slot)


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	for slot in _slots:
		if slot["t"] >= 1.0:
			continue
		slot["t"] = minf(1.0, slot["t"] + delta / slot["life"])
		if slot["t"] >= 1.0:
			slot["node"].visible = false
		else:
			_draw(slot)


static func shape_at(t: float, mode: int, still := false) -> Dictionary:
	if mode == MODE_CARD:
		var card_grow := 1.0 if still else lerpf(1.6, 1.0, minf(t / 0.12, 1.0))
		return {"scale": card_grow, "heat": 0.0, "alpha": 1.0 if t < 0.7 else 1.0 - (t - 0.7) / 0.3}
	if mode == MODE_FUSION:
		var f_top := 1.0 if still else FUSION_OVERSHOOT
		var f_grow := f_top * ease(t / POP, 0.35) if t < POP else lerpf(f_top, 1.0, ease((t - POP) / (1.0 - POP), 0.5))
		return {"scale": f_grow, "heat": FlashGuard.whiten(HEAT) * maxf(0.0, 1.0 - t / POP),
			"alpha": 1.0 if t < 0.5 else 1.0 - (t - 0.5) / 0.5}
	if mode == MODE_SHOCKWAVE:
		var s_grow := lerpf(0.7, 1.1, t) if still else lerpf(0.45, 1.35, ease(t, 0.3))
		return {"scale": s_grow, "heat": FlashGuard.whiten(HEAT * 0.7) * maxf(0.0, 1.0 - t / 0.25),
			"alpha": 1.0 if t < 0.35 else 1.0 - (t - 0.35) / 0.65}
	var top := 1.0 if still else OVERSHOOT
	var grow := top * ease(t / POP, 0.4) if t < POP else lerpf(top, 1.0, ease((t - POP) / (1.0 - POP), 0.5))
	return {"scale": grow, "heat": FlashGuard.whiten(HEAT) * maxf(0.0, 1.0 - t / POP),
		"alpha": 1.0 if t < 0.45 else 1.0 - (t - 0.45) / 0.55}


func _cap_for(node: Node3D, half_m: float) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 1.0
	return cap(half_m, node.global_position.distance_to(cam.global_position), cam.fov)


static func cap(half_m: float, eye_m: float, fov_deg: float) -> float:
	if eye_m >= CAP_WITHIN_M or half_m <= 0.0:
		return 1.0
	var view_h := 2.0 * eye_m * tan(deg_to_rad(fov_deg) * 0.5)
	var capped := minf(1.0, SCREEN_CAP * view_h * 0.5 / half_m)
	return lerpf(capped, 1.0, clampf((eye_m - CAP_FULL_M) / (CAP_WITHIN_M - CAP_FULL_M), 0.0, 1.0))


func _draw(slot: Dictionary) -> void:
	var t: float = slot["t"]
	var mode: int = slot["mode"]
	var look := shape_at(t, mode, Comfort.reduced_motion)
	var node: MeshInstance3D = slot["node"]
	node.basis = Basis.IDENTITY.scaled(Vector3.ONE * slot["size"] * float(look["scale"]) * _cap_for(node, slot["size"] * float(look["scale"])))
	var mat: ShaderMaterial = slot["mat"]
	mat.set_shader_parameter("heat", look["heat"])
	mat.set_shader_parameter("alpha", float(look["alpha"]) * float(slot["alpha"]))
	mat.set_shader_parameter("progress", t)
	var spin_mult := 1.4 if mode == MODE_FUSION else (0.5 if mode == MODE_SHOCKWAVE else 1.0)
	mat.set_shader_parameter("turn", (CARD_TILT if mode == MODE_CARD else slot["seed"] + SPIN * spin_mult * t))
