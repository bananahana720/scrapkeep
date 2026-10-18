extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")

# W12 VX-FX: GPU particle effects, one spec per effect. An event's EventKinds.JUICE row
# names the effects it plays and how many particles each throws ("fx": {spec: count});
# the spec says how the particles move and where their colour comes from.
#   pool     emitters of this effect, reused oldest first
#   max      particles one emitter holds; pool x max is the effect's ceiling
#   life     seconds a particle lives
#   speed    initial speed range, metres per second
#   radial   outward speed from the emitter's centre (negative collapses a ring inward)
#   spread   cone half-angle in degrees around the emitter's direction (up, or forward)
#   gravity  vertical acceleration
#   size     the particle mesh: a float is a ball's diameter, a Vector3 a box
#   colour   "row" takes the event row's colour, any other value names a Palette const
#   attach   "world" fires once where it is told, "ball" follows the ball and emits
#            continuously, "persist" emits continuously where it was placed until stopped
#   blend    "add" glows over the scene, "mix" is solid matter
#   glow     brightness multiplier on the tint, so an additive spark still reads on sand
#   warm     a persistent emitter starts with a full cloud (preprocess = life), not a trickle
#   shape    "point" or "ring" (emission on a flat ring of ring_m radius)
#   forward  the emitter's direction is its own -Z, aimed at a target (the latch's pulse)
#   owner    "vfx" pools are built by Vfx under its root; others belong to the node named
#            ("machine" is MachineFx: what enemies and bosses throw off)
#   grow     a puff that swells as it fades (steam), instead of shrinking
#   alpha    the spec colour's opacity (steam is thin, not a solid ball)
#   local    particles ride the emitter, so turning the emitter turns them (a daze halo)
# Emitters use a fixed seed, so a capture at a fixed tick repeats. No lights.
const SEED := 731
# Pool x max over the "vfx" specs; fx_library_test pins it.
const CEILING := 752
# Pool x max over the "machine" specs; machine_fx_test pins it.
const MACHINE_CEILING := 876
const SPECS := {
	"roll_dust": {"pool": 1, "max": 64, "life": 0.7, "speed": [0.4, 1.4], "spread": 75.0, "gravity": 0.6,
		"size": 0.42, "colour": "SANDSTONE", "attach": "ball", "blend": "mix", "shape": "point"},
	"spark_core": {"pool": 4, "max": 24, "life": 0.3, "speed": [8.0, 16.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.07, 0.07, 0.5), "colour": "row", "attach": "world", "blend": "mix", "shape": "point", "align": true},
	"spark_halo": {"pool": 4, "max": 24, "life": 0.3, "speed": [8.0, 16.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.18, 0.18, 0.7), "colour": "row", "attach": "world", "blend": "add", "shape": "point", "align": true, "glow": 2.0},
	"crit_core": {"pool": 2, "max": 24, "life": 0.4, "speed": [9.0, 19.0], "spread": 180.0, "gravity": -12.0,
		"size": Vector3(0.12, 0.12, 0.8), "colour": "row", "attach": "world", "blend": "mix", "shape": "point", "align": true},
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
	# Machine effects (machine_fx.gd). Fleet crews leak steam and throw brass sparks; ancients
	# fizz in their seam light and shed cast shell. Steam is ledger cream, never white, so
	# it never reads as frost or a flash, and dense enough to show against sandstone.
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
	"daze_halo": {"pool": 6, "max": 6, "life": 0.6, "speed": [0.0, 0.0], "spread": 0.0, "gravity": 0.0, "local": true,
		"size": 0.3, "colour": "AMBER", "attach": "persist", "blend": "add", "shape": "ring", "ring_m": 0.7, "glow": 1.0, "owner": "machine"},
	"fuse_sputter": {"pool": 4, "max": 6, "life": 0.3, "speed": [1.5, 3.5], "spread": 50.0, "gravity": -6.0,
		"size": 0.08, "colour": "AMBER", "attach": "persist", "blend": "add", "shape": "point", "glow": 2.0, "owner": "machine"},
	"phase_ring": {"pool": 2, "max": 64, "life": 0.6, "speed": [0.0, 0.0], "radial": [16.0, 18.0], "spread": 0.0, "gravity": 0.0,
		"size": 0.35, "colour": "row", "attach": "world", "blend": "mix", "shape": "ring", "ring_m": 1.5, "owner": "machine"},
	"shell_shards": {"pool": 3, "max": 16, "life": 1.1, "speed": [6.0, 12.0], "spread": 60.0, "gravity": -24.0, "spin": 600.0,
		"size": Vector3(0.3, 0.06, 0.22), "colour": "VERDIGRIS", "attach": "world", "blend": "mix", "shape": "point", "owner": "machine"},
	"plate_chunks": {"pool": 3, "max": 16, "life": 1.1, "speed": [6.0, 12.0], "spread": 60.0, "gravity": -24.0, "spin": 600.0,
		"size": Vector3(0.34, 0.08, 0.28), "colour": "RUST", "attach": "world", "blend": "mix", "shape": "point", "owner": "machine"},
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
# A crit's own set comes from the row's "crit" sub-dict, a low preset's from "low".
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


# One material per blend mode, shared by every emitter; colour is an instance uniform.
static func _material(blend: String) -> ShaderMaterial:
	if not _shaders.has(blend):
		var shader := Shader.new()
		shader.code = _SHADER % ("blend_add, depth_draw_never" if blend == "add" else "blend_mix, depth_draw_opaque")
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_shaders[blend] = mat
	return _shaders[blend]


# One emitter, configured from its spec; the caller owns placement, tint and restart.
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


# One effect fired: the emitter restarts at `at` with `count` of its particles in `tint`
# (the spec's own colour when tint is transparent). `toward` aims a forward spec.
static func fire(p: GPUParticles3D, id: String, kind: String, count: int, at: Vector3, tint := Color.TRANSPARENT, toward := Vector3.ZERO) -> void:
	p.amount_ratio = clampf(float(count) / float(p.amount), 0.0, 1.0)
	if toward.length() > 0.01 and spec(id).get("forward", false):
		p.global_transform = Transform3D(Basis.looking_at(toward.normalized(), Vector3.UP), at)
	else:
		p.global_transform = Transform3D(Basis.IDENTITY, at)
	p.set_instance_shader_parameter("tint", tint if tint.a > 0.0 else colour(id, kind))
	p.restart()
	p.emitting = true
