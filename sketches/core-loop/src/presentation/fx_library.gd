extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")

# W12 P-FX: GPU particle effects, one spec per effect. An event's EventKinds.JUICE row
# names the effects it plays and how many particles each throws ("fx": {spec: count});
# the spec says how the particles move and where their colour comes from.
#   pool     emitters of this effect, reused oldest first
#   max      particles one emitter holds; pool x max is the effect's ceiling
#   life     seconds a particle lives
#   speed    initial speed range, metres per second
#   radial   outward speed from the emitter's centre (the slam ring)
#   spread   cone half-angle in degrees around up
#   gravity  vertical acceleration
#   size     the particle mesh: a float is a ball's diameter, a Vector3 a box
#   colour   "row" takes the event row's colour, any other value names a Palette const
#   attach   "world" stays where it fired, "ball" follows the ball and emits continuously
#   blend    "add" glows over the scene, "mix" is solid matter
#   shape    "point" or "ring" (emission on a flat ring of ring_m radius)
# Emitters use a fixed seed, so a capture at a fixed tick repeats. No lights.
const SEED := 731
const SPECS := {
	"roll_dust": {"pool": 1, "max": 64, "life": 0.7, "speed": [0.4, 1.4], "spread": 75.0, "gravity": 0.6,
		"size": 0.42, "colour": "SANDSTONE", "attach": "ball", "blend": "mix", "shape": "point"},
	"hit_sparks": {"pool": 10, "max": 24, "life": 0.3, "speed": [7.0, 14.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.05, 0.05, 0.34), "colour": "row", "attach": "world", "blend": "add", "shape": "point", "align": true},
	"slam_ring": {"pool": 2, "max": 72, "life": 0.42, "speed": [0.0, 0.0], "radial": [11.0, 12.0], "spread": 0.0, "gravity": 0.0,
		"size": 0.5, "colour": "row", "attach": "world", "blend": "add", "shape": "ring", "ring_m": 0.6},
	"slam_dust": {"pool": 2, "max": 28, "life": 0.8, "speed": [2.0, 5.5], "spread": 70.0, "gravity": 1.0,
		"size": 0.7, "colour": "SANDSTONE", "attach": "world", "blend": "mix", "shape": "ring", "ring_m": 1.2},
	"latch_flash": {"pool": 3, "max": 16, "life": 0.2, "speed": [3.0, 6.0], "spread": 180.0, "gravity": 0.0,
		"size": Vector3(0.06, 0.06, 0.5), "colour": "row", "attach": "world", "blend": "add", "shape": "point", "align": true},
	"crack_debris": {"pool": 3, "max": 32, "life": 1.0, "speed": [4.0, 9.0], "spread": 50.0, "gravity": -24.0,
		"size": Vector3(0.28, 0.2, 0.24), "colour": "row", "attach": "world", "blend": "mix", "shape": "point", "spin": 540.0},
}

const _SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, %s;
instance uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a;
}
"""

static var _shaders := {}


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, {})


# The effects an event plays, from its JUICE row: {spec id: particle count}.
static func effects(kind: String) -> Dictionary:
	return EventKinds.juice(kind).get("fx", {})


static func colour(id: String, kind: String) -> Color:
	var source: String = spec(id).get("colour", "row")
	if source == "row":
		return EventKinds.color(kind)
	var named: Dictionary = (Palette as Script).get_script_constant_map()
	return named.get(source, Palette.SAND)


static func ceiling() -> int:
	var total := 0
	for id in SPECS:
		total += int(SPECS[id]["pool"]) * int(SPECS[id]["max"])
	return total


static func _material(blend: String) -> ShaderMaterial:
	if not _shaders.has(blend):
		var shader := Shader.new()
		shader.code = _SHADER % ("blend_add, depth_draw_never" if blend == "add" else "blend_mix, depth_draw_opaque")
		_shaders[blend] = shader
	var mat := ShaderMaterial.new()
	mat.shader = _shaders[blend]
	return mat


# One emitter, configured from its spec; the caller owns placement, tint and restart.
static func build(id: String) -> GPUParticles3D:
	var s := spec(id)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = s["spread"]
	pm.initial_velocity_min = s["speed"][0]
	pm.initial_velocity_max = s["speed"][1]
	if s.has("radial"):
		pm.radial_velocity_min = s["radial"][0]
		pm.radial_velocity_max = s["radial"][1]
	pm.gravity = Vector3(0.0, s["gravity"], 0.0)
	pm.particle_flag_align_y = s.get("align", false)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
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
	fade.add_point(Vector2(1.0, 0.0 if s["blend"] == "add" else 0.35))
	var fade_tex := CurveTexture.new()
	fade_tex.curve = fade
	pm.scale_curve = fade_tex
	if s["blend"] == "add" or s["attach"] == "ball":
		pm.alpha_curve = fade_tex
	var mesh: PrimitiveMesh
	if s["size"] is Vector3:
		var box := BoxMesh.new()
		box.size = s["size"]
		mesh = box
	else:
		var ball := SphereMesh.new()
		ball.radius = float(s["size"]) * 0.5
		ball.height = float(s["size"])
		ball.radial_segments = 8
		ball.rings = 4
		mesh = ball
	mesh.material = _material(s["blend"])
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.amount = int(s["max"])
	p.lifetime = s["life"]
	p.one_shot = s["attach"] != "ball"
	p.explosiveness = 1.0 if p.one_shot else 0.0
	p.local_coords = false
	p.emitting = false
	p.use_fixed_seed = true
	p.seed = SEED
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 10, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.name = "Fx_%s" % id
	return p
