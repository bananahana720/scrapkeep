extends Node3D

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# The kill mark (FX-01): a kill's own punctuation, so a kill never reads as a bigger hit. The
# hit draws thin copper spokes (vfx.gd "burst"); a kill draws a filled comic burst with ten
# uneven points, an ink outline and a ledger-cream heart, in the pilot's colour. It pops past full size
# in its first frames, starts white-hot (FlashGuard.whiten, so Reduce flashes keeps it cool) and
# fades. One call per merged kill pop: Vfx's pop gate decides when and how big. Vfx throws the
# body's shards in the pilot's colour and ink debris with it. A downed elite or miniboss also
# gets a clock-out card stamped over it with a steam sigh (MachineFx calls card()), in place of
# a word. Andrew picked this look from three candidates on 12 Nov 2026 (ruling cq).
#
# The mark is a camera-facing quad drawn in its own shader, transparent, depth-sorted with the
# other player glyphs and far below the hostile warnings' render priority (threat_grammar.gd
# PRIORITY), so it never covers a warning. It is a player effect (FEEL-READABILITY section 1.1,
# P5): the density governor caps its alpha and life like any glyph's, Reduce flashes keeps only
# FlashGuard's information share of its alpha and cools its white start, and Reduced motion drops
# the overshoot and the card's slam.

const POOL := 4
const LIFE := 0.34
const CARD_LIFE := 0.9
# Share of the life spent popping in to OVERSHOOT of full size, then settling.
const POP := 0.16
const OVERSHOOT := 1.2
const SPIN := 1.6
const CARD_TILT := 0.21
const RENDER_PRIORITY := 0
# How hot the burst starts, before FlashGuard.whiten.
const HEAT := 0.8
# Near the lens the mark keeps its alpha (a kill must never read as a hit) but shrinks so its width
# is at most this share of the view's height (PF-53: with the arm against a wall the lens sits about
# 2 m from the ball and a 3 m mark filled the screen). 0.4 leaves today's mark whole at the play
# distance; inside CAP_WITHIN_M only, so a merged kill's bigger mark at range is not touched. The cap
# eases in from CAP_WITHIN_M down to CAP_FULL_M, so a big merged mark never snaps in size when the
# lens crosses the edge during its pop.
const SCREEN_CAP := 0.4
const CAP_WITHIN_M := 7.5
const CAP_FULL_M := 6.0

const _SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float heat = 0.0;
uniform float turn = 0.0;
uniform int mode = 0;
// Palette CHARCOAL, LEDGER and RUST, set from GDScript so the engine converts them to linear light.
uniform vec3 INK : source_color;
uniform vec3 LEDGER : source_color;
uniform vec3 RUST : source_color;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
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
	float s = (atan(p.y, p.x) / 6.28318 + 0.5) * 10.0;
	float i = floor(s);
	float tri = 1.0 - abs(fract(s) - 0.5) * 2.0;
	float reach = (mod(i, 2.0) < 1.0 ? 0.98 : 0.7) * (0.9 + 0.1 * hash(i));
	float edge = mix(0.4, reach, pow(tri, 1.5));
	if (r > edge) {
		return vec4(0.0);
	}
	vec3 body = mix(tint.rgb, LEDGER, step(r, edge * 0.5));
	body = mix(body, vec3(1.0), clamp(heat, 0.0, 1.0));
	return vec4(mix(body, INK, step(edge - 0.12, r)), 1.0);
}

vec4 card(vec2 p) {
	vec2 q = abs(p) - vec2(0.92, 0.6);
	if (q.x > 0.0 || q.y > 0.0) {
		return vec4(0.0);
	}
	vec3 paper = LEDGER;
	// Ruled lines, a punched hole and a rust stamp across the bottom right.
	paper = mix(paper, INK, 0.35 * step(abs(fract(p.y * 4.5) - 0.5), 0.05) * step(p.y, 0.3));
	paper = mix(paper, RUST, step(length(p - vec2(0.38, -0.2)), 0.3) * step(0.18, length(p - vec2(0.38, -0.2))));
	paper = mix(paper, INK, step(length(p - vec2(-0.7, 0.38)), 0.08));
	return vec4(mix(paper, INK, step(-0.09, max(q.x, q.y))), 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec4 c = mode == 1 ? card(p) : burst(p);
	if (c.a <= 0.0) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = alpha;
}
"""

var reduced_motion := false
# Marks fired since the run began, by mode, for the tests and notes.
var spawned := {"burst": 0, "card": 0}

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
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		# The quad turns to face the camera in its shader, so its flat box is not where it draws.
		node.extra_cull_margin = 2.0
		node.visible = false
		add_child(node)
		_slots.append({"node": node, "mat": mat, "t": 1.0, "life": LIFE, "size": 1.0, "mode": 0, "seed": 0.0, "alpha": 1.0})


# One kill's burst at `at`, `size` metres across its longest point, in `tint`. `governed` is
# the density governor's (alpha cap, size, life) for a player effect, as Density.apply returns it.
func fire(at: Vector3, size: float, tint: Color, governed := Vector3.ONE) -> void:
	var slot: Dictionary = _slots[_next]
	_next = (_next + 1) % POOL
	_start(slot, at, size * governed.y, tint, LIFE * governed.z, 0, governed.x)
	spawned["burst"] += 1


# A clock-out card stamped over a downed elite.
func card(at: Vector3, size := 1.6) -> void:
	_start(_slots[POOL], at, size, Palette.LEDGER, CARD_LIFE, 1, 1.0)
	spawned["card"] += 1


func clear() -> void:
	for slot in _slots:
		slot["t"] = 1.0
		slot["node"].visible = false


func _start(slot: Dictionary, at: Vector3, size: float, tint: Color, life: float, mode: int, alpha: float) -> void:
	slot["t"] = 0.0
	slot["alpha"] = FlashGuard.info(alpha)
	slot["life"] = life
	slot["size"] = size * 0.5
	slot["mode"] = mode
	slot["seed"] = fmod(at.x * 1.7 + at.z * 3.1, TAU)
	var node: MeshInstance3D = slot["node"]
	node.global_position = at
	node.visible = true
	var mat: ShaderMaterial = slot["mat"]
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("mode", mode)
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


# The size, turn, heat and alpha at the slot's point in its life.
# Under `still` (Reduced motion) the mark grows straight to full size and the card does not slam.
static func shape_at(t: float, mode: int, still := false) -> Dictionary:
	var top := 1.0 if still else OVERSHOOT
	var grow := top * ease(t / POP, 0.4) if t < POP else lerpf(top, 1.0, ease((t - POP) / (1.0 - POP), 0.5))
	if mode == 1:
		# The card slams down from big to its size and holds still, then fades out late.
		grow = 1.0 if still else lerpf(1.6, 1.0, minf(t / 0.12, 1.0))
		return {"scale": grow, "heat": 0.0, "alpha": 1.0 if t < 0.7 else 1.0 - (t - 0.7) / 0.3}
	return {"scale": grow, "heat": FlashGuard.whiten(HEAT) * maxf(0.0, 1.0 - t / POP),
		"alpha": 1.0 if t < 0.45 else 1.0 - (t - 0.45) / 0.55}


# The multiplier (1 or less) that keeps a mark of half-width `half_m` at `node` within SCREEN_CAP of
# the view's height.
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
	var look := shape_at(t, mode, reduced_motion)
	var node: MeshInstance3D = slot["node"]
	node.basis = Basis.IDENTITY.scaled(Vector3.ONE * slot["size"] * float(look["scale"]) * _cap_for(node, slot["size"] * float(look["scale"])))
	var mat: ShaderMaterial = slot["mat"]
	mat.set_shader_parameter("heat", look["heat"])
	mat.set_shader_parameter("alpha", float(look["alpha"]) * float(slot["alpha"]))
	mat.set_shader_parameter("turn", (CARD_TILT if mode == 1 else slot["seed"] + SPIN * t))
