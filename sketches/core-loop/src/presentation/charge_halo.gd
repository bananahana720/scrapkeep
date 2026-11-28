extends Node3D

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

const HOOPS := 4
const HOOP_SEGMENTS := 16
const HOOP_SECTION := 0.006
const CORE_LINE := 0.0015
const RADIUS_START := 0.16
const RADIUS_FULL := 0.105
const HOOP_FADE_S := 0.06
const HOOP_PITCH := 0.045
const SPIN_DEG_S := 90.0
const GLOW_LOW := 0.6
const GLOW_HIGH := 1.6
const SLEEVE_RADIUS := 0.058
const SLEEVE_SIDES := 10
const SLEEVE_FROM := -0.01
const SLEEVE_TO := 0.15
const SLEEVE_ALPHA := 0.35
const PULSE_S := 0.3
const PULSE_GAIN := 0.6
const COLLAPSE_S := 0.1
const SPARKS := 12
const SPARK_LIFE := 0.25
const SPARK_RATE := 24.0
const RINGS := 2
const RING_LIFE := 0.22
const RING_FROM := 0.2
const RING_TO := 1.4
const RING_TRAVEL := 3.0
const TAP_FLOOR := 0.25
const ARC_LENGTH := 0.6
const ARC_LIFE := 0.08
const DRAWS := 2
const RENDER_PRIORITY := -4

const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float r_start = 0.16;
uniform float r_full = 0.105;
uniform float pitch = 0.045;
uniform float sleeve_r = 0.058;
uniform float sleeve_alpha = 0.35;
uniform float core_line = 0.0015;
instance uniform float fill = 0.0;
instance uniform float t = 0.0;
instance uniform vec4 hoops = vec4(0.0);
instance uniform float glow = 1.0;
instance uniform float close = 0.0;
instance uniform float collapse = 0.0;
varying float v_alpha;
varying float v_across;
varying float v_sleeve;
varying float v_z;

// VERTEX carries (radial offset, bore offset, across) and UV (angle, hoop index or -1 for the
// sleeve); the shader places every vertex, so the mesh is built once and never rewritten.
void vertex() {
	float ang = UV.x;
	float k = UV.y;
	vec3 raw = VERTEX;
	float shrink = 1.0 - collapse;
	if (k < -0.5) {
		float r = sleeve_r * shrink;
		VERTEX = vec3(cos(ang) * r, sin(ang) * r, raw.y);
		v_alpha = sleeve_alpha * fill * shrink;
		v_sleeve = 1.0;
		v_across = 1.0;
		v_z = raw.y;
	} else {
		float spin = mod(k, 2.0) < 0.5 ? t : -t;
		float a = ang + spin;
		float r = mix(r_start, r_full, fill) * shrink + raw.x;
		VERTEX = vec3(cos(a) * r, sin(a) * r, k * pitch * (1.0 - close) + raw.y);
		float h = k < 0.5 ? hoops.x : (k < 1.5 ? hoops.y : (k < 2.5 ? hoops.z : hoops.w));
		v_alpha = h * shrink;
		v_sleeve = 0.0;
		v_across = raw.z;
		v_z = 0.0;
	}
}

void fragment() {
	float shade;
	if (v_sleeve > 0.5) {
		// Only the near wall, so the far one never doubles it; bright between the hoops and dark on
		// them, so the copper turns stay copper.
		if (!FRONT_FACING) {
			discard;
		}
		shade = 0.5 - 0.5 * cos(v_z * 6.2831853 / pitch);
	} else {
		shade = smoothstep(core_line * 0.5, core_line * 0.5 + 0.0004, abs(v_across));
	}
	ALBEDO = tint.rgb * glow * shade * v_alpha;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
varying float v_alpha;
void vertex() {
	v_alpha = INSTANCE_CUSTOM.r;
}
void fragment() {
	ALBEDO = tint.rgb * 1.4 * v_alpha;
}
"""

var reduced_motion := false
var fill := 0.0
var _state := "idle"
var _spin := 0.0
var _hoop_alpha: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _pulse_t := -1.0
var _pulsed := false
var _close := 0.0
var _collapse := 0.0
var _glow := 1.0
var _halo: Node3D
var _mesh: MeshInstance3D
var _sparks: GPUParticles3D
var _rings: MultiMeshInstance3D
var _ring_age: Array[float] = []
var _ring_from: Array[Vector3] = []
var _ring_aim: Array[Vector3] = []
var _ring_next := 0
var _mount_xf := Transform3D.IDENTITY
var spawned := {}


func _init() -> void:
	name = "ChargeHalo"
	_rings = _build_rings()
	add_child(_rings)
	_build_halo()


func charge(value: float) -> void:
	fill = clampf(value, 0.0, 1.0)
	if fill <= 0.0:
		return
	if _state != "charging":
		_state = "charging"
		_collapse = 0.0
		_pulse_t = -1.0
		_pulsed = false
		_close = 0.0
		if rings_alive() >= RINGS:
			_end_ring(_oldest_ring())


func release(aim: Vector3) -> void:
	_end_halo()
	var dir := aim
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = forward()
	var i := _ring_next
	_ring_next = (_ring_next + 1) % RINGS
	_ring_age[i] = 0.0
	_ring_from[i] = tip()
	_ring_aim[i] = dir.normalized()
	_draw_ring(i)
	spawned["release"] = spawned.get("release", 0) + 1


func tap() -> void:
	_end_halo()
	spawned["tap"] = spawned.get("tap", 0) + 1


func cancel() -> void:
	if _state != "charging":
		return
	_state = "collapsing"
	_collapse = 0.0
	spawned["cancel"] = spawned.get("cancel", 0) + 1


func stop() -> void:
	_end_halo()
	for i in RINGS:
		_end_ring(i)
	_rings.visible = false


func charging() -> bool:
	return _state == "charging"


func state() -> String:
	return _state


func mount(ring: Node3D, at: Transform3D) -> void:
	if not halo_ready():
		_build_halo()
	var parent: Node = ring if ring != null else self
	if _halo.get_parent() != parent:
		if _halo.get_parent() != null:
			_halo.get_parent().remove_child(_halo)
		parent.add_child(_halo)
	_mount_xf = at
	_halo.transform = at


func place(at: Transform3D) -> void:
	if halo_ready() and _halo.get_parent() == self and _halo.is_inside_tree():
		_halo.global_transform = at


func halo_ready() -> bool:
	return _halo != null and is_instance_valid(_halo)


func mounted_on() -> Node:
	return _halo.get_parent() if halo_ready() else null


func tip() -> Vector3:
	if halo_ready() and _halo.is_inside_tree():
		return _halo.global_position
	return global_position if is_inside_tree() else Vector3.ZERO


func forward() -> Vector3:
	if halo_ready() and _halo.is_inside_tree():
		return -_halo.global_basis.z
	return Vector3.FORWARD


func hoops_shown() -> int:
	var n := 0
	for a in _hoop_alpha:
		if a >= 0.5:
			n += 1
	return n if _state != "idle" else 0


func hoop_alpha(k: int) -> float:
	return _hoop_alpha[k]


func hoop_radius() -> float:
	return lerpf(RADIUS_START, RADIUS_FULL, fill) * (1.0 - _collapse)


func halo_shown() -> bool:
	return halo_ready() and _mesh.visible


func glow() -> float:
	return _glow


func closed() -> float:
	return _close


func rings_alive() -> int:
	var n := 0
	for age in _ring_age:
		if age >= 0.0:
			n += 1
	return n


func ring_radius(i: int) -> float:
	return _ring_size(_ring_age[i]) if _ring_age[i] >= 0.0 else 0.0


func sparks_cap() -> int:
	return _sparks.amount if halo_ready() else 0


func spark_ratio() -> float:
	return _sparks.amount_ratio if halo_ready() and _sparks.emitting else 0.0


func draws_alive() -> int:
	return (1 if halo_shown() else 0) + (1 if rings_alive() > 0 else 0)


func step(delta: float) -> void:
	_step_halo(delta)
	for i in RINGS:
		if _ring_age[i] < 0.0:
			continue
		_ring_age[i] += delta
		if _ring_age[i] >= RING_LIFE:
			_end_ring(i)
		else:
			_draw_ring(i)
	_rings.visible = rings_alive() > 0


func _step_halo(delta: float) -> void:
	if not halo_ready():
		return
	match _state:
		"charging":
			for k in HOOPS:
				var target := 1.0 if fill >= float(k) / HOOPS else 0.0
				_hoop_alpha[k] = move_toward(_hoop_alpha[k], target, delta / HOOP_FADE_S)
			if not reduced_motion:
				_spin = fmod(_spin + deg_to_rad(SPIN_DEG_S) * (1.0 + fill) * delta, TAU)
			var swell := 0.0
			if fill >= 0.999 and not _pulsed:
				_pulsed = true
				_pulse_t = 0.0
				spawned["pulse"] = spawned.get("pulse", 0) + 1
			if _pulse_t >= 0.0:
				_pulse_t += delta
				var u := clampf(_pulse_t / PULSE_S, 0.0, 1.0)
				swell = sin(PI * u)
				_close = 1.0 if reduced_motion else smoothstep(0.0, 1.0, u)
				if u >= 1.0:
					_pulse_t = -1.0
			var base := lerpf(GLOW_LOW, GLOW_HIGH, fill)
			_glow = FlashGuard.spike(base, base * (1.0 + PULSE_GAIN * swell))
		"collapsing":
			_collapse = minf(1.0, _collapse + delta / COLLAPSE_S)
			if _collapse >= 1.0:
				_end_halo()
	var on := _state != "idle"
	_mesh.visible = on
	var emit := _state == "charging" and not reduced_motion
	_sparks.amount_ratio = clampf(SPARK_RATE * SPARK_LIFE / SPARKS * fill, 0.0, 1.0)
	if _sparks.emitting != emit:
		_sparks.emitting = emit
	if not on:
		return
	_mesh.set_instance_shader_parameter("fill", fill)
	_mesh.set_instance_shader_parameter("t", _spin)
	_mesh.set_instance_shader_parameter("hoops", Vector4(_hoop_alpha[0], _hoop_alpha[1], _hoop_alpha[2], _hoop_alpha[3]))
	_mesh.set_instance_shader_parameter("glow", _glow)
	_mesh.set_instance_shader_parameter("close", _close)
	_mesh.set_instance_shader_parameter("collapse", _collapse)


func _end_halo() -> void:
	_state = "idle"
	fill = 0.0
	_collapse = 0.0
	_close = 0.0
	_pulse_t = -1.0
	_glow = GLOW_LOW
	for k in HOOPS:
		_hoop_alpha[k] = 0.0
	if halo_ready():
		_mesh.visible = false
		_sparks.emitting = false


static func _ring_size(age: float) -> float:
	var u := clampf(age / RING_LIFE, 0.0, 1.0)
	return lerpf(RING_FROM, RING_TO, 1.0 - (1.0 - u) * (1.0 - u))


func _draw_ring(i: int) -> void:
	var u := clampf(_ring_age[i] / RING_LIFE, 0.0, 1.0)
	var travel := 0.0 if reduced_motion else RING_TRAVEL * (1.0 - (1.0 - u) * (1.0 - u))
	var aim: Vector3 = _ring_aim[i]
	var at: Vector3 = _ring_from[i] + aim * travel
	var basis := Basis.looking_at(aim, Vector3.UP).scaled(Vector3.ONE * _ring_size(_ring_age[i]))
	_rings.multimesh.set_instance_transform(i, Transform3D(basis, at))
	_rings.multimesh.set_instance_custom_data(i, Color(FlashGuard.info(1.0 - u), 0.0, 0.0, 0.0))


func _end_ring(i: int) -> void:
	_ring_age[i] = -1.0
	_rings.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_rings.multimesh.set_instance_custom_data(i, Color(0, 0, 0, 0))


func _oldest_ring() -> int:
	var oldest := 0
	for i in RINGS:
		if _ring_age[i] > _ring_age[oldest]:
			oldest = i
	return oldest


func _build_halo() -> void:
	_halo = Node3D.new()
	_halo.name = "ChargeHalo"
	_mesh = MeshInstance3D.new()
	_mesh.name = "HaloMesh"
	_mesh.mesh = halo_mesh()
	_mesh.material_override = _material(HALO_SHADER)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.custom_aabb = AABB(Vector3(-0.2, -0.2, -0.05), Vector3(0.4, 0.4, 0.4))
	_mesh.visible = false
	_halo.add_child(_mesh)
	_sparks = _build_sparks()
	_halo.add_child(_sparks)
	add_child(_halo)
	_halo.transform = _mount_xf


func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", Palette.ARC)
	mat.render_priority = RENDER_PRIORITY
	return mat


static func halo_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var h := HOOP_SECTION * 0.5
	for k in HOOPS:
		for s in HOOP_SEGMENTS:
			var a0 := TAU * float(s) / HOOP_SEGMENTS
			var a1 := TAU * float(s + 1) / HOOP_SEGMENTS
			for face in [[h, -1], [-h, -1], [-h, 1], [h, 1]]:
				var fixed: float = face[0]
				var radial: bool = face[1] < 0
				var corners := [[a0, -h], [a1, -h], [a1, h], [a0, h]]
				for j in [0, 1, 2, 0, 2, 3]:
					var c: Array = corners[j]
					var across: float = c[1]
					var v := Vector3(fixed, across, across) if radial else Vector3(across, fixed, across)
					verts.append(v)
					uvs.append(Vector2(c[0], k))
	for s in SLEEVE_SIDES:
		var a0 := TAU * float(s) / SLEEVE_SIDES
		var a1 := TAU * float(s + 1) / SLEEVE_SIDES
		var corners := [[a0, SLEEVE_FROM], [a1, SLEEVE_FROM], [a1, SLEEVE_TO], [a0, SLEEVE_TO]]
		for j in [0, 1, 2, 0, 2, 3]:
			verts.append(Vector3(0.0, corners[j][1], 1.0))
			uvs.append(Vector2(corners[j][0], -1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_sparks() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3.ZERO
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.03, 0.01, 0.01)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Palette.ARC, Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	pm.color_ramp = ramp
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.process_material = pm
	var mesh := FxLibrary.look_mesh("glow", 0.03, "add")
	mesh.material = FxLibrary.look_material("glow", "add")
	p.draw_pass_1 = mesh
	p.set_meta("fx_look", "glow")
	p.amount = SPARKS
	p.lifetime = SPARK_LIFE
	p.local_coords = true
	p.emitting = false
	p.use_fixed_seed = true
	p.seed = FxLibrary.SEED
	p.visibility_aabb = AABB(Vector3(-0.6, -0.6, -0.8), Vector3(1.2, 1.2, 1.2))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_instance_shader_parameter(FxLibrary.TINT, Color.WHITE)
	return p


func _build_rings() -> MultiMeshInstance3D:
	const SEGMENTS := 40
	const INNER := 0.9
	var verts := PackedVector3Array()
	for s in SEGMENTS:
		var a0 := TAU * float(s) / SEGMENTS
		var a1 := TAU * float(s + 1) / SEGMENTS
		var o0 := Vector3(cos(a0), sin(a0), 0.0)
		var o1 := Vector3(cos(a1), sin(a1), 0.0)
		for v in [o0, o1, o1 * INNER, o0, o1 * INNER, o0 * INNER]:
			verts.append(v)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = RINGS
	var node := MultiMeshInstance3D.new()
	node.name = "ReleaseRings"
	node.multimesh = mm
	node.material_override = _material(RING_SHADER)
	node.top_level = true
	node.visible = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_age.resize(RINGS)
	_ring_from.resize(RINGS)
	_ring_aim.resize(RINGS)
	for i in RINGS:
		_ring_age[i] = -1.0
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	return node
