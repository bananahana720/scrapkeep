class_name PilotLiveliness
extends SkeletonModifier3D


const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const Comfort := preload("res://src/core/comfort.gd")

const NODE_NAME := "PilotLiveliness"

const SPECIES_PROFILES := {
	"pylon_engineer": {"breath_hz": 0.42, "ear_gain": 1.35, "crest_gain": 0.35, "goggles_gain": 0.45, "tail_gain": 1.25, "head_snap": 1.10},
	"runner_gunner": {"breath_hz": 0.36, "ear_gain": 0.40, "crest_gain": 0.25, "goggles_gain": 0.25, "tail_gain": 0.45, "head_snap": 0.90},
	"demolitions_caster": {"breath_hz": 0.48, "ear_gain": 0.35, "crest_gain": 1.45, "goggles_gain": 1.05, "tail_gain": 1.10, "head_snap": 1.35},
	"tarn": {"breath_hz": 0.32, "ear_gain": 0.85, "crest_gain": 0.40, "goggles_gain": 0.65, "tail_gain": 0.80, "head_snap": 0.85},
	"tally": {"breath_hz": 0.40, "ear_gain": 1.10, "crest_gain": 0.50, "goggles_gain": 0.85, "tail_gain": 0.95, "head_snap": 1.15},
	"remembered_cannon": {"breath_hz": 0.34, "ear_gain": 0.95, "crest_gain": 0.45, "goggles_gain": 0.70, "tail_gain": 0.75, "head_snap": 0.95},
	"line_splicer": {"breath_hz": 0.45, "ear_gain": 1.40, "crest_gain": 0.55, "goggles_gain": 0.90, "tail_gain": 1.45, "head_snap": 1.25},
}

const DEFAULT_PROFILE := {"breath_hz": 0.40, "ear_gain": 1.0, "crest_gain": 0.8, "goggles_gain": 0.8, "tail_gain": 0.9, "head_snap": 1.0}

const MAX_LOOK_YAW_RAD := deg_to_rad(20.0)
const MAX_LOOK_PITCH_RAD := deg_to_rad(12.0)
const MAX_BANK_RAD := deg_to_rad(20.0)
const MAX_LEAN_RAD := deg_to_rad(16.0)
const MAX_RECOIL_RAD := deg_to_rad(18.0)

var pilot_class := "pylon_engineer"
var liveliness_weight := 1.0
var glance_blend := 0.0
var reduced_motion_override := -1

var _phase := 0.0
var _look_yaw := 0.0
var _look_pitch := 0.0
var _bank := 0.0
var _bank_vel := 0.0
var _lean := 0.0
var _lean_vel := 0.0
var _bounce := 0.0
var _bounce_vel := 0.0
var _recoil := 0.0
var _recoil_vel := 0.0
var _secondary_lag := 0.0
var _secondary_vel := 0.0
var _throttle := 0.0
var _pedal_phase := 0.0

var _has_prev_xf := false
var _prev_origin := Vector3.ZERO
var _prev_forward := Vector3.FORWARD
var _prev_vel := Vector3.ZERO

var _controls := {}
var _control_rest := {}


static func attach(pilot: Node, class_id := "") -> SkeletonModifier3D:
	if pilot == null:
		return null
	var found := pilot.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	var skel := found[0] as Skeleton3D
	var existing := skel.get_node_or_null(NODE_NAME) as SkeletonModifier3D
	if existing != null:
		if class_id != "":
			existing.set("pilot_class", class_id)
		return existing
	var rig: SkeletonModifier3D = (load("res://src/presentation/pilot_liveliness.gd") as GDScript).new()
	rig.name = NODE_NAME
	if class_id != "":
		rig.set("pilot_class", class_id)
	skel.add_child(rig)
	skel.move_child(rig, 0)
	return rig


func is_reduced_motion() -> bool:
	if reduced_motion_override == 1:
		return true
	if reduced_motion_override == 0:
		return false
	return Comfort.reduced_motion


func profile() -> Dictionary:
	return SPECIES_PROFILES.get(pilot_class, DEFAULT_PROFILE)


func bind_cockpit_controls(controls: Dictionary) -> void:
	_controls.clear()
	_control_rest.clear()
	for key in controls:
		var node = controls[key]
		if node is Node3D and is_instance_valid(node):
			_controls[String(key)] = node
			_control_rest[String(key)] = (node as Node3D).transform


func reset_state() -> void:
	_phase = 0.0
	_look_yaw = 0.0
	_look_pitch = 0.0
	_bank = 0.0
	_bank_vel = 0.0
	_lean = 0.0
	_lean_vel = 0.0
	_bounce = 0.0
	_bounce_vel = 0.0
	_recoil = 0.0
	_recoil_vel = 0.0
	_secondary_lag = 0.0
	_secondary_vel = 0.0
	_throttle = 0.0
	_pedal_phase = 0.0
	_has_prev_xf = false
	_apply_cockpit_controls(0.0)


func step_motion(
	delta: float,
	local_velocity: Vector3 = Vector3.ZERO,
	turn_rate_rad_s: float = 0.0,
	aim_local_dir: Vector3 = Vector3.FORWARD,
	vertical_accel: float = 0.0,
	glance_amount: float = 0.0
) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	glance_blend = clampf(absf(glance_amount), 0.0, 1.0)
	if is_reduced_motion() or liveliness_weight <= 0.001:
		_decay_to_zero(dt)
		_apply_cockpit_controls(0.0)
		return

	var prof := profile()
	_phase = fmod(_phase + dt * TAU * float(prof.breath_hz), TAU * 8.0)

	var look_scale := 1.0 - glance_blend * 0.85
	var aim_flat := Vector3(aim_local_dir.x, 0.0, aim_local_dir.z)
	var target_yaw := 0.0
	if aim_flat.length_squared() > 0.01:
		target_yaw = clampf(atan2(-aim_local_dir.x, maxf(-aim_local_dir.z, 0.15)), -MAX_LOOK_YAW_RAD, MAX_LOOK_YAW_RAD)
	target_yaw = clampf(target_yaw + clampf(-turn_rate_rad_s * 0.16, -0.30, 0.30), -MAX_LOOK_YAW_RAD, MAX_LOOK_YAW_RAD) * look_scale
	var target_pitch := clampf(aim_local_dir.y * 0.35 + clampf(local_velocity.y * 0.025, -0.20, 0.20), -MAX_LOOK_PITCH_RAD, MAX_LOOK_PITCH_RAD) * look_scale
	var snap_rate := 10.0 * float(prof.head_snap)
	_look_yaw = lerpf(_look_yaw, target_yaw, 1.0 - exp(-snap_rate * dt))
	_look_pitch = lerpf(_look_pitch, target_pitch, 1.0 - exp(-snap_rate * dt))

	var speed_fwd := clampf(-local_velocity.z, -24.0, 28.0)
	var lateral_g := clampf(turn_rate_rad_s * maxf(absf(speed_fwd) * 0.08, 0.35) + local_velocity.x * 0.055, -2.2, 2.2)
	var target_bank := clampf(lateral_g * 0.20, -MAX_BANK_RAD, MAX_BANK_RAD)
	var bank_acc := (target_bank - _bank) * 68.0 - _bank_vel * 11.5
	_bank_vel += bank_acc * dt
	_bank = clampf(_bank + _bank_vel * dt, -MAX_BANK_RAD, MAX_BANK_RAD)

	var target_lean := clampf(speed_fwd * 0.011 - vertical_accel * 0.008, -MAX_LEAN_RAD, MAX_LEAN_RAD)
	var lean_acc := (target_lean - _lean) * 58.0 - _lean_vel * 10.5
	_lean_vel += lean_acc * dt
	_lean = clampf(_lean + _lean_vel * dt, -MAX_LEAN_RAD, MAX_LEAN_RAD)

	var bounce_target := clampf(-vertical_accel * 0.004, -0.18, 0.18)
	var bounce_acc := (bounce_target - _bounce) * 95.0 - _bounce_vel * 12.0
	_bounce_vel += bounce_acc * dt
	_bounce = clampf(_bounce + _bounce_vel * dt, -0.25, 0.25)

	var recoil_acc := (0.0 - _recoil) * 140.0 - _recoil_vel * 15.0
	_recoil_vel += recoil_acc * dt
	_recoil = clampf(_recoil + _recoil_vel * dt, -MAX_RECOIL_RAD, MAX_RECOIL_RAD)

	var sec_drive := _bank * 0.85 + _bounce * 1.4 - _recoil * 0.9
	var sec_acc := (sec_drive - _secondary_lag) * 82.0 - _secondary_vel * 9.0
	_secondary_vel += sec_acc * dt
	_secondary_lag = clampf(_secondary_lag + _secondary_vel * dt, -0.55, 0.55)

	var speed_norm := clampf(local_velocity.length() / 16.0, 0.0, 1.0)
	_throttle = lerpf(_throttle, speed_norm, 1.0 - exp(-8.0 * dt))
	_pedal_phase = fmod(_pedal_phase + dt * (1.5 + speed_norm * 7.5), TAU)
	_apply_cockpit_controls(liveliness_weight)


func observe_frame(still: bool, _eye_world: Vector3, delta: float, glance_turn: float = 0.0) -> void:
	var skel := get_skeleton()
	if skel == null or delta <= 0.0:
		return
	var xf := skel.global_transform
	var fwd := (-xf.basis.z).normalized()
	var local_vel := Vector3.ZERO
	var turn_rate := 0.0
	var vert_acc := 0.0
	if _has_prev_xf and delta > 0.0005:
		var world_vel := (xf.origin - _prev_origin) / delta
		local_vel = xf.basis.orthonormalized().inverse() * world_vel
		var yaw_cross := _prev_forward.cross(fwd).y
		var yaw_dot := clampf(_prev_forward.dot(fwd), -1.0, 1.0)
		turn_rate = clampf(atan2(yaw_cross, yaw_dot) / delta, -8.0, 8.0)
		vert_acc = clampf((world_vel.y - _prev_vel.y) / delta, -40.0, 40.0)
		_prev_vel = world_vel
	else:
		_prev_vel = Vector3.ZERO
	_prev_origin = xf.origin
	_prev_forward = fwd
	_has_prev_xf = true
	if still:
		local_vel *= 0.15
		turn_rate *= 0.2
	step_motion(delta, local_vel, turn_rate, Vector3.FORWARD, vert_acc, glance_turn)


func trigger_recoil(strength: float = 1.0) -> void:
	if is_reduced_motion():
		return
	var s := clampf(strength, 0.0, 2.0)
	_recoil_vel += 2.6 * s
	_secondary_vel -= 1.8 * s


func trigger_landing(impact: float = 1.0) -> void:
	if is_reduced_motion():
		return
	var s := clampf(impact, 0.0, 2.0)
	_bounce_vel -= 2.4 * s
	_lean_vel += 1.4 * s
	_secondary_vel += 2.0 * s


func trigger_reaction(event_or_clip: String) -> bool:
	var row := PilotReactions.impulse_for(event_or_clip)
	if row.is_empty():
		return false
	if is_reduced_motion():
		return true
	_recoil_vel += float(row.get("recoil", 0.0))
	_bounce_vel += float(row.get("bounce", 0.0))
	_lean_vel += float(row.get("lean", 0.0))
	_secondary_vel += float(row.get("secondary", 0.0))
	return true


func snapshot() -> Dictionary:
	return {
		"pilot_class": pilot_class,
		"reduced_motion": is_reduced_motion(),
		"phase": _phase,
		"breath_signal": _breath_signal(),
		"look_yaw": _look_yaw,
		"look_pitch": _look_pitch,
		"bank": _bank,
		"lean": _lean,
		"bounce": _bounce,
		"recoil": _recoil,
		"secondary_lag": _secondary_lag,
		"throttle": _throttle,
	}


func _breath_signal() -> float:
	return sin(_phase) * 0.72 + sin(_phase * 2.0 + 0.6) * 0.28


func _decay_to_zero(dt: float) -> void:
	var k := 1.0 - exp(-14.0 * dt)
	_look_yaw = lerpf(_look_yaw, 0.0, k)
	_look_pitch = lerpf(_look_pitch, 0.0, k)
	_bank = lerpf(_bank, 0.0, k)
	_bank_vel = 0.0
	_lean = lerpf(_lean, 0.0, k)
	_lean_vel = 0.0
	_bounce = lerpf(_bounce, 0.0, k)
	_bounce_vel = 0.0
	_recoil = lerpf(_recoil, 0.0, k)
	_recoil_vel = 0.0
	_secondary_lag = lerpf(_secondary_lag, 0.0, k)
	_secondary_vel = 0.0
	_throttle = lerpf(_throttle, 0.0, k)


func _apply_cockpit_controls(weight: float) -> void:
	if _controls.is_empty():
		return
	for key in _controls:
		var node: Node3D = _controls[key]
		if not is_instance_valid(node):
			continue
		var rest: Transform3D = _control_rest[key]
		if weight <= 0.001 or is_reduced_motion():
			node.transform = rest
			continue
		match key:
			"yoke":
				var roll := clampf(_bank * 0.48 * weight, -deg_to_rad(10.0), deg_to_rad(10.0))
				var pitch := clampf((_lean * 0.35 + _recoil * 0.45) * weight, -deg_to_rad(8.0), deg_to_rad(9.0))
				node.transform = rest * Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3.ZERO)
			"throttle":
				var throw_x := -(_throttle * deg_to_rad(32.0) + _recoil * 0.35) * weight
				node.transform = rest * Transform3D(Basis(Vector3.RIGHT, throw_x), Vector3.ZERO)
			"pedal_l":
				var p_l := (sin(_pedal_phase) * 0.14 * _throttle + maxf(-_bounce, 0.0) * 0.45) * weight
				node.transform = rest * Transform3D(Basis(Vector3.RIGHT, p_l), Vector3.ZERO)
			"pedal_r":
				var p_r := (-sin(_pedal_phase) * 0.14 * _throttle + maxf(-_bounce, 0.0) * 0.45) * weight
				node.transform = rest * Transform3D(Basis(Vector3.RIGHT, p_r), Vector3.ZERO)


func _apply_world_axis_rotation(skel: Skeleton3D, bone_name: String, world_axis: Vector3, angle: float) -> void:
	if absf(angle) < 1e-5:
		return
	var bone := skel.find_bone(bone_name)
	if bone < 0:
		return
	var parent := skel.get_bone_parent(bone)
	var axis := world_axis.normalized()
	if parent >= 0:
		axis = (skel.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse() * axis).normalized()
	var q := Quaternion(axis, angle)
	skel.set_bone_pose_rotation(bone, q * skel.get_bone_pose_rotation(bone))


func _couple_arm_to_grip(skel: Skeleton3D, upper_name: String, lower_name: String, hand_name: String, grip_world: Vector3, blend: float) -> void:
	var u_idx := skel.find_bone(upper_name)
	var l_idx := skel.find_bone(lower_name)
	var h_idx := skel.find_bone(hand_name)
	if u_idx < 0 or l_idx < 0 or h_idx < 0 or not skel.is_inside_tree():
		return
	var skel_inv := skel.global_transform.affine_inverse()
	var target_skel := skel_inv * grip_world
	var u_pos := skel.get_bone_global_pose(u_idx).origin
	var l_pos := skel.get_bone_global_pose(l_idx).origin
	var h_pos := skel.get_bone_global_pose(h_idx).origin
	var len_u := u_pos.distance_to(l_pos)
	var len_l := l_pos.distance_to(h_pos)
	if len_u < 0.01 or len_l < 0.01:
		return

	var cur_dist := u_pos.distance_to(h_pos)
	var want_dist := clampf(u_pos.distance_to(target_skel), absf(len_u - len_l) + 0.01, (len_u + len_l) * 0.992)
	var cos_cur := clampf((len_u * len_u + len_l * len_l - cur_dist * cur_dist) / (2.0 * len_u * len_l), -1.0, 1.0)
	var cos_want := clampf((len_u * len_u + len_l * len_l - want_dist * want_dist) / (2.0 * len_u * len_l), -1.0, 1.0)
	var d_elbow := clampf((acos(cos_want) - acos(cos_cur)) * blend, -deg_to_rad(36.0), deg_to_rad(36.0))
	var v_ul := (l_pos - u_pos).normalized()
	var v_lh := (h_pos - l_pos).normalized()
	var hinge_axis := v_ul.cross(v_lh)
	if hinge_axis.length_squared() > 1e-6 and absf(d_elbow) > 1e-4:
		_apply_world_axis_rotation(skel, lower_name, -hinge_axis.normalized(), d_elbow)

	u_pos = skel.get_bone_global_pose(u_idx).origin
	h_pos = skel.get_bone_global_pose(h_idx).origin
	var cur_dir := h_pos - u_pos
	var want_dir := target_skel - u_pos
	if cur_dir.length_squared() < 1e-5 or want_dir.length_squared() < 1e-5:
		return
	var cur_n := cur_dir.normalized()
	var want_n := want_dir.normalized()
	var dot_v := clampf(cur_n.dot(want_n), -1.0, 1.0)
	if dot_v > 0.99995:
		return
	var rot_axis := cur_n.cross(want_n)
	if rot_axis.length_squared() < 1e-8:
		return
	var angle := clampf(acos(dot_v) * blend, -deg_to_rad(42.0), deg_to_rad(42.0))
	_apply_world_axis_rotation(skel, upper_name, rot_axis.normalized(), angle)


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or is_reduced_motion() or liveliness_weight <= 0.001:
		return
	var w := liveliness_weight
	var prof := profile()
	var breath := _breath_signal() * w
	var sway := sin(_phase * 0.5 + 0.9) * deg_to_rad(1.6) * w

	var spine1_pitch := clampf((breath * deg_to_rad(2.2) - _lean * 0.22 + _bounce * 0.30 + _recoil * 0.90) * w, -deg_to_rad(6.0), deg_to_rad(18.0))
	var spine2_pitch := clampf((breath * deg_to_rad(3.2) - _lean * 0.25 + _bounce * 0.38 + _recoil * 1.15) * w, -deg_to_rad(6.0), deg_to_rad(20.0))
	var spine1_roll := clampf((_bank * 0.36 + sway * 0.5) * w, -deg_to_rad(10.0), deg_to_rad(10.0))
	var spine2_roll := clampf((_bank * 0.44 + sway) * w, -deg_to_rad(11.0), deg_to_rad(11.0))

	_apply_world_axis_rotation(skel, "spine_01", Vector3.RIGHT, spine1_pitch)
	_apply_world_axis_rotation(skel, "spine_01", Vector3.BACK, spine1_roll)
	_apply_world_axis_rotation(skel, "spine_02", Vector3.RIGHT, spine2_pitch)
	_apply_world_axis_rotation(skel, "spine_02", Vector3.BACK, spine2_roll)

	var neck_yaw := _look_yaw * 0.38 * w
	var head_yaw := _look_yaw * 0.62 * w
	var neck_pitch := clampf((-breath * deg_to_rad(1.2) + _look_pitch * 0.40 + _recoil * 0.50) * w, -deg_to_rad(5.0), deg_to_rad(16.0))
	var head_pitch := clampf((-breath * deg_to_rad(1.6) + _look_pitch * 0.55 + _bounce * 0.18 + _recoil * 0.68) * w, -deg_to_rad(5.0), deg_to_rad(18.0))
	var head_roll := (-_bank * 0.26) * w

	_apply_world_axis_rotation(skel, "neck", Vector3.UP, neck_yaw)
	_apply_world_axis_rotation(skel, "neck", Vector3.RIGHT, neck_pitch)
	_apply_world_axis_rotation(skel, "head", Vector3.UP, head_yaw)
	_apply_world_axis_rotation(skel, "head", Vector3.RIGHT, head_pitch)
	_apply_world_axis_rotation(skel, "head", Vector3.BACK, head_roll)

	var sh_lift := (breath * deg_to_rad(2.2) + _recoil * 0.35) * w
	_apply_world_axis_rotation(skel, "shoulder.L", Vector3.BACK, sh_lift)
	_apply_world_axis_rotation(skel, "shoulder.R", Vector3.BACK, -sh_lift)
	var yoke_node = _controls.get("yoke")
	if yoke_node is Node3D and is_instance_valid(yoke_node) and (yoke_node as Node3D).is_inside_tree():
		var yxf := (yoke_node as Node3D).global_transform
		_couple_arm_to_grip(skel, "upper_arm.L", "lower_arm.L", "hand.L", yxf * Vector3(-0.320, 0.215, 0.020), 0.98 * w)
		_couple_arm_to_grip(skel, "upper_arm.R", "lower_arm.R", "hand.R", yxf * Vector3(0.320, 0.215, 0.020), 0.98 * w)
	else:
		_apply_world_axis_rotation(skel, "upper_arm.L", Vector3.RIGHT, (-_recoil * 0.35) * w)
		_apply_world_axis_rotation(skel, "upper_arm.R", Vector3.RIGHT, (-_recoil * 0.35) * w)

	var ear_g := float(prof.ear_gain) * w
	var ear_lag := (_secondary_lag * 0.65 + breath * deg_to_rad(3.0)) * ear_g
	_apply_world_axis_rotation(skel, "ear.L", Vector3.BACK, ear_lag + _bank * 0.35 * ear_g)
	_apply_world_axis_rotation(skel, "ear.R", Vector3.BACK, -ear_lag + _bank * 0.35 * ear_g)
	_apply_world_axis_rotation(skel, "ear.L", Vector3.RIGHT, (_bounce * 0.55 - _recoil * 0.45) * ear_g)
	_apply_world_axis_rotation(skel, "ear.R", Vector3.RIGHT, (_bounce * 0.55 - _recoil * 0.45) * ear_g)

	var crest_g := float(prof.crest_gain) * w
	_apply_world_axis_rotation(skel, "crest", Vector3.RIGHT, (_secondary_lag * 0.50 + absf(_recoil) * 0.85 + breath * deg_to_rad(2.5)) * crest_g)
	_apply_world_axis_rotation(skel, "curl.L", Vector3.BACK, (_secondary_lag * 0.45 + sway) * ear_g)
	_apply_world_axis_rotation(skel, "curl.R", Vector3.BACK, (-_secondary_lag * 0.45 + sway) * ear_g)

	var gog_g := float(prof.goggles_gain) * w
	var gog_pitch := clampf((_bounce * 0.22 - _recoil * 0.16) * gog_g, -deg_to_rad(2.5), deg_to_rad(2.5))
	_apply_world_axis_rotation(skel, "goggles", Vector3.RIGHT, gog_pitch)

	var tail_g := float(prof.tail_gain) * w
	var tail_wag := (sin(_phase * 1.5) * deg_to_rad(5.5) - _bank * 0.75) * tail_g
	_apply_world_axis_rotation(skel, "tail.01", Vector3.UP, tail_wag)
	_apply_world_axis_rotation(skel, "tail.02", Vector3.UP, tail_wag * 1.25)
