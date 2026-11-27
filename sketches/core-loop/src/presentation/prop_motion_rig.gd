extends RefCounted

const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")


const CYCLE_NONE := ""
const CYCLE_PISTON := "piston"
const CYCLE_TURBINE := "turbine"
const CYCLE_BREATHE := "breathe"

var reduced_motion := false
var clock := 0.0
var _parts: Array[PartState] = []


class PartState extends RefCounted:
	var name: String = ""
	var node: Node3D
	var rest_position := Vector3.ZERO
	var rest_basis := Basis.IDENTITY
	var rest_scale := Vector3.ONE

	var sway_enabled := false
	var sway_stiffness := 26.0
	var sway_damping := 5.2
	var sway_gain := 0.032
	var sway_max_rad := 0.42
	var sway_ambient_amp := 0.03
	var sway_ambient_hz := 0.45
	var sway_phase := 0.0
	var sway_angles := Vector2.ZERO
	var sway_vel := Vector2.ZERO

	var jolt_stiffness := 145.0
	var jolt_damping := 13.5
	var jolt_max_offset := 0.35
	var jolt_rot_gain := 0.45
	var jolt_offset := Vector3.ZERO
	var jolt_vel := Vector3.ZERO
	var jolt_rot := Vector3.ZERO
	var jolt_rot_vel := Vector3.ZERO

	var cycle_mode: String = CYCLE_NONE
	var cycle_axis := Vector3.UP
	var cycle_amplitude := 0.18
	var cycle_hz := 1.2
	var cycle_phase := 0.0
	var cycle_angle := 0.0

	func capture_rest() -> void:
		if not is_instance_valid(node):
			return
		rest_position = node.position
		rest_basis = node.basis.orthonormalized()
		rest_scale = node.scale

	func restore_rest() -> void:
		sway_angles = Vector2.ZERO
		sway_vel = Vector2.ZERO
		jolt_offset = Vector3.ZERO
		jolt_vel = Vector3.ZERO
		jolt_rot = Vector3.ZERO
		jolt_rot_vel = Vector3.ZERO
		if is_instance_valid(node):
			node.position = rest_position
			node.basis = rest_basis
			node.scale = rest_scale


static func is_visual_pivot(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		return false
	return true


func add_part(label: String, visual_pivot: Node3D, config := {}) -> PartState:
	if not is_visual_pivot(visual_pivot):
		push_error("PropMotionRig: refusing to bind collider or null node (%s)" % label)
		return null
	var p := PartState.new()
	p.name = label
	p.node = visual_pivot
	p.capture_rest()

	p.sway_enabled = bool(config.get("sway", false))
	p.sway_stiffness = maxf(1.0, float(config.get("sway_stiffness", p.sway_stiffness)))
	p.sway_damping = maxf(0.2, float(config.get("sway_damping", p.sway_damping)))
	p.sway_gain = float(config.get("sway_gain", p.sway_gain))
	p.sway_max_rad = clampf(float(config.get("sway_max_rad", p.sway_max_rad)), 0.01, 1.2)
	p.sway_ambient_amp = maxf(0.0, float(config.get("sway_ambient_amp", p.sway_ambient_amp)))
	p.sway_ambient_hz = maxf(0.0, float(config.get("sway_ambient_hz", p.sway_ambient_hz)))
	p.sway_phase = float(config.get("sway_phase", 0.0))

	p.jolt_stiffness = maxf(4.0, float(config.get("jolt_stiffness", p.jolt_stiffness)))
	p.jolt_damping = maxf(0.5, float(config.get("jolt_damping", p.jolt_damping)))
	p.jolt_max_offset = maxf(0.01, float(config.get("jolt_max_offset", p.jolt_max_offset)))
	p.jolt_rot_gain = float(config.get("jolt_rot_gain", p.jolt_rot_gain))

	p.cycle_mode = String(config.get("cycle", CYCLE_NONE))
	var axis: Vector3 = config.get("axis", Vector3.UP)
	p.cycle_axis = axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP
	p.cycle_amplitude = float(config.get("amplitude", p.cycle_amplitude))
	p.cycle_hz = float(config.get("hz", p.cycle_hz))
	p.cycle_phase = float(config.get("phase", 0.0))

	_parts.append(p)
	return p


func part_count() -> int:
	return _parts.size()


func part(label: String) -> PartState:
	for p in _parts:
		if p.name == label:
			return p
	return null


func _calm() -> bool:
	return reduced_motion or EnemyMotion.motion_scale <= 0.0


func apply_impulse(direction_world: Vector3, strength := 1.0, target_label := "") -> void:
	if _calm() or strength <= 0.0:
		return
	var dir := direction_world.normalized() if direction_world.length_squared() > 0.0001 else Vector3.BACK
	for p in _parts:
		if target_label != "" and p.name != target_label:
			continue
		if not is_instance_valid(p.node):
			continue
		var local_dir := dir
		var parent := p.node.get_parent() as Node3D
		if parent != null and parent.is_inside_tree():
			local_dir = (parent.global_basis.inverse() * dir).normalized()
		p.jolt_vel += local_dir * (strength * 2.4)
		var torque_axis := Vector3.UP.cross(local_dir)
		if torque_axis.length_squared() < 0.0001:
			torque_axis = Vector3.RIGHT
		p.jolt_rot_vel += torque_axis.normalized() * (strength * p.jolt_rot_gain * 4.0)
		if p.sway_enabled:
			p.sway_vel += Vector2(local_dir.z, -local_dir.x) * (strength * 1.8)


func reset() -> void:
	clock = 0.0
	for p in _parts:
		p.cycle_angle = 0.0
		p.restore_rest()


func clear() -> void:
	reset()
	_parts.clear()


func step(delta: float, world_velocity := Vector3.ZERO, rpm_scale := 1.0) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	var calm := _calm()
	if calm:
		for p in _parts:
			if is_instance_valid(p.node):
				p.restore_rest()
		return

	clock += dt
	var kept: Array[PartState] = []
	for p in _parts:
		if not is_instance_valid(p.node):
			continue
		kept.append(p)
		_step_part(p, dt, world_velocity, rpm_scale)
	_parts = kept


func _step_part(p: PartState, dt: float, world_velocity: Vector3, rpm_scale: float) -> void:
	var parent := p.node.get_parent() as Node3D
	var local_vel := world_velocity
	if parent != null and parent.is_inside_tree():
		local_vel = parent.global_basis.inverse() * world_velocity

	var sway_basis := Basis.IDENTITY
	if p.sway_enabled:
		var ambient_x := p.sway_ambient_amp * sin(clock * TAU * p.sway_ambient_hz + p.sway_phase)
		var ambient_z := p.sway_ambient_amp * 0.65 * cos(clock * TAU * p.sway_ambient_hz * 0.77 + p.sway_phase)
		var target := Vector2(
			clampf(local_vel.z * p.sway_gain + ambient_x, -p.sway_max_rad, p.sway_max_rad),
			clampf(-local_vel.x * p.sway_gain + ambient_z, -p.sway_max_rad, p.sway_max_rad)
		)
		var accel := (target - p.sway_angles) * p.sway_stiffness - p.sway_vel * p.sway_damping
		p.sway_vel += accel * dt
		p.sway_angles += p.sway_vel * dt
		p.sway_angles.x = clampf(p.sway_angles.x, -p.sway_max_rad, p.sway_max_rad)
		p.sway_angles.y = clampf(p.sway_angles.y, -p.sway_max_rad, p.sway_max_rad)
		sway_basis = Basis(Vector3.RIGHT, p.sway_angles.x) * Basis(Vector3.BACK, p.sway_angles.y)

	var j_accel := -p.jolt_stiffness * p.jolt_offset - p.jolt_damping * p.jolt_vel
	p.jolt_vel += j_accel * dt
	p.jolt_offset += p.jolt_vel * dt
	if p.jolt_offset.length() > p.jolt_max_offset:
		p.jolt_offset = p.jolt_offset.normalized() * p.jolt_max_offset
	var jr_accel := -p.jolt_stiffness * p.jolt_rot - p.jolt_damping * p.jolt_rot_vel
	p.jolt_rot_vel += jr_accel * dt
	p.jolt_rot += p.jolt_rot_vel * dt
	var jolt_basis := Basis.IDENTITY
	var jr_len := p.jolt_rot.length()
	if jr_len > 0.0001:
		jolt_basis = Basis(p.jolt_rot / jr_len, clampf(jr_len, 0.0, 0.5))

	var cycle_pos := Vector3.ZERO
	var cycle_basis := Basis.IDENTITY
	var cycle_scale := Vector3.ONE
	match p.cycle_mode:
		CYCLE_PISTON:
			var t := fposmod(clock * p.cycle_hz + p.cycle_phase, 1.0)
			var stroke := sin(PI * clampf(t / 0.38, 0.0, 1.0)) if t < 0.38 else 0.08 * sin(TAU * (t - 0.38) / 0.62)
			cycle_pos = p.cycle_axis * (stroke * p.cycle_amplitude)
		CYCLE_TURBINE:
			p.cycle_angle = wrapf(p.cycle_angle + TAU * p.cycle_hz * rpm_scale * dt, -TAU, TAU)
			cycle_basis = Basis(p.cycle_axis, p.cycle_angle)
		CYCLE_BREATHE:
			var wave := 0.5 - 0.5 * cos(clock * TAU * p.cycle_hz + p.cycle_phase)
			cycle_pos = p.cycle_axis * (wave * p.cycle_amplitude * 0.45)
			var swell := 1.0 + wave * p.cycle_amplitude * 0.18
			var squash := 1.0 - wave * p.cycle_amplitude * 0.07
			cycle_scale = Vector3(swell, squash, swell)

	p.node.position = p.rest_position + p.jolt_offset + cycle_pos
	p.node.basis = (p.rest_basis * sway_basis * jolt_basis * cycle_basis).orthonormalized()
	p.node.scale = p.rest_scale * cycle_scale
