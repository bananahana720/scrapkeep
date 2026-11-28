extends "res://src/combat/enemy.gd"

const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PropMotionRig := preload("res://src/presentation/prop_motion_rig.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")

const HP := 600.0
const DEFAULT_PLATING := 38.0
const SCRAP := 24
const WEIGHT := 5.0
const RADIUS := 2.3
const HIT_REACH := RADIUS + 1.6
const HALF_HEIGHT := 3.45
const BODY_CONTACT := RADIUS + Tuning.RADIUS
const WALK := 5.5
const STALK := 1.6
const SLAM_CROUCH := 0.5
const SLAM_LEAP := 0.9
const SLAM_RADIUS := 7.0
const SLAM_HEIGHT := 9.0
const SLAM_DAMAGE := 24.0
const SLAM_SHOVE := 9.0
const LEAP_CLEAR := RADIUS + 0.5
const LEAP_RAY_LIFT := 0.5
const LEAP_GROUND_PROBE := 4.0
const CHARGE_BRACE := 1.0
const CHARGE_LENGTH := 30.0
const CHARGE_WIDTH := 4.6
const CHARGE_TIME := 0.9
const CHARGE_DAMAGE := 20.0
const CHARGE_SHOVE := 10.0
const WEAK_SECONDS := 2.4
const PHASE_TWO_WIND := 0.75
const TURN_SHAKE := 0.12

enum State { STALK, SLAM_CROUCH, SLAM_LEAP, CHARGE_BRACE, CHARGE, WEAK, TURN, CUE }

var state := State.STALK
var phase := 1
var slam_crouch := SLAM_CROUCH
var charge_brace := CHARGE_BRACE
var attacks := 0
var weak_windows := 0
var hits_landed := 0
var landed_attack: String:
	get:
		return "E04" if state == State.CHARGE else "E03"

var _clock := 0.0
var _next_attack := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _landed := false
var _core: MeshInstance3D
var _core_material: StandardMaterial3D
var _plates: Array = []
var _halo: MeshInstance3D
var _pose_rig: Skeleton3D
var _pose_bones := {}
var _model_plate_material: StandardMaterial3D
var _armour: MeshInstance3D
var _motion_rig: PropMotionRig
var _rig_pivots := {}
var _prev_pose_state := -1
var _prev_flash_active := false
var _core_smoothed := false
var _core_pos_cur := Vector3.ZERO
var _core_scale_cur := 0.8
var _core_lean_cur := 0.0
var _core_color_cur := Palette.VERDIGRIS
var _core_energy_cur := 0.0
static var _shared: Dictionary = {}
static var _asset_warned := false
const POSES := {
	"stalk": {"body": 0.0, "lean": 0.0, "splay": 0.0, "tuck": 0.0, "shield_in": 0.0, "shield_drop": 0.0, "hazard": false},
	"slam_crouch": {"body": -0.3, "lean": 0.0, "splay": 0.6, "tuck": 0.0, "shield_in": 0.45, "shield_drop": 0.0, "hazard": false},
	"slam_leap": {"body": 1.0, "lean": -0.35, "splay": 0.0, "tuck": 1.1, "shield_in": 0.45, "shield_drop": 0.0, "hazard": false},
	"charge_brace": {"body": -0.1, "lean": -0.22, "splay": 0.35, "tuck": 0.0, "shield_in": 0.0, "shield_drop": 0.7, "hazard": true},
	"charge": {"body": -0.1, "lean": -0.22, "splay": 0.35, "tuck": 0.0, "shield_in": 0.0, "shield_drop": 0.7, "hazard": false},
	"weak": {"body": -0.087, "lean": 0.0, "splay": 0.0, "tuck": 0.0, "shield_in": 0.0, "shield_drop": 0.0, "hazard": false},
	"turn": {"body": 0.12, "lean": 0.3, "splay": 0.45, "tuck": 0.0, "shield_in": 0.7, "shield_drop": 0.0, "hazard": false},
	"cue": {"body": -0.05, "lean": -0.12, "splay": 0.35, "tuck": 0.0, "shield_in": 0.3, "shield_drop": 0.35, "hazard": false},
}
const CORE_SOCKET := Vector3(0.0, 0.6, -RADIUS * 0.75)
const MODEL_PATH := "res://assets/models/world_one/enemy_miniboss.glb"
const MODEL_PARTS := ["MinibossHull", "MinibossArmour", "MinibossCore"]
const MODEL_BONES := ["MinibossBody", "MinibossFootLeft", "MinibossFootRight",
	"MinibossFistLeft", "MinibossFistRight", "MinibossPlateLeft", "MinibossPlateRight", "MinibossHalo"]


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "miniboss"
	_set_health(HP * threat)
	plating = spec.get("plating", DEFAULT_PLATING)
	scrap_value = SCRAP
	weight = WEIGHT
	radius = RADIUS
	half_height = HALF_HEIGHT
	var placeholder := _add_capsule(RADIUS, HALF_HEIGHT * 2.0, Palette.COPPER)
	if _build_model():
		placeholder.free()
	else:
		_build_armour()


func state_name() -> String:
	return ["stalk", "slam_crouch", "slam_leap", "charge_brace", "charge", "weak", "turn", "cue"][state]


func enter_phase(next: int) -> void:
	if next <= phase:
		return
	phase = mini(next, FightPhases.MINI_MAX)
	slam_crouch = maxf(ChallengeDials.TELL_FLOOR - SLAM_LEAP, SLAM_CROUCH * PHASE_TWO_WIND)
	charge_brace = maxf(ChallengeDials.TELL_FLOOR, CHARGE_BRACE * PHASE_TWO_WIND)
	_clear_telegraph()
	_enter(State.TURN)
	if is_instance_valid(_reaction_bus) and _reaction_bus.has_signal("fight_phase_changed"):
		_reaction_bus.fight_phase_changed.emit(kind, phase, FightPhases.MINI_MAX)


func take_damage(amount: float) -> float:
	if state == State.TURN:
		return 0.0
	var removed := super.take_damage(amount)
	if not _dead and phase == 1 and hp <= max_hp * FightPhases.MINI_TURN:
		enter_phase(2)
	return removed


func absorbs_hit(_result: Dictionary) -> bool:
	return state == State.TURN


func crushable() -> bool:
	return state != State.TURN


func is_weak() -> bool:
	return state == State.WEAK


func plating_now() -> float:
	return 0.0 if state == State.WEAK else plating


func knock(direction: Vector3, force: float) -> void:
	if state == State.SLAM_LEAP or state == State.CHARGE:
		return
	super.knock(direction, force)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or target == null:
		if state != State.SLAM_LEAP:
			_move(delta, Vector3.ZERO)
		return
	_clock += delta
	var to_ball := _flat_to_ball()
	match state:
		State.STALK:
			_move(delta, to_ball.normalized() * WALK if to_ball.length() > RADIUS + 3.0 else Vector3.ZERO)
			if _clock >= STALK and is_on_floor():
				_begin_attack(to_ball)
		State.SLAM_CROUCH:
			_move(delta, Vector3.ZERO)
			_fill(_clock / (slam_crouch + SLAM_LEAP))
			if _clock >= slam_crouch:
				_enter(State.SLAM_LEAP)
				_leap_from = global_position
		State.SLAM_LEAP:
			_fill((slam_crouch + _clock) / (slam_crouch + SLAM_LEAP))
			var t := clampf(_clock / SLAM_LEAP, 0.0, 1.0)
			var arc := _leap_from.lerp(_leap_to, t) + Vector3.UP * SLAM_HEIGHT * 4.0 * t * (1.0 - t)
			global_position = arc
			velocity = Vector3.ZERO
			if t >= 1.0:
				_land_slam()
		State.CHARGE_BRACE:
			_move(delta, Vector3.ZERO)
			_fill(_clock / charge_brace)
			if _clock >= charge_brace:
				_enter(State.CHARGE)
				_landed = false
		State.CHARGE:
			var lane := telegraph()
			if lane == null:
				_open_weak_window()
				return
			_move(delta, lane.dir * CHARGE_LENGTH / CHARGE_TIME)
			var along: float = (global_position - lane.center).dot(lane.dir)
			lane.run_body(along, HIT_REACH)
			_check_charge(lane)
			if _clock >= CHARGE_TIME or along >= lane.length:
				_open_weak_window()
		State.WEAK:
			_move(delta, Vector3.ZERO)
			if _clock >= WEAK_SECONDS:
				_enter(State.STALK)
		State.TURN:
			_move(delta, Vector3.ZERO)
			if _clock >= FightPhases.TRANSITION_SECONDS:
				_enter(State.STALK)
		State.CUE:
			_move(delta, Vector3.ZERO)
			if _clock >= FightPhases.CUE_LEAD:
				charge_brace = FightPhases.CUED_WARN
				_begin_attack(to_ball)


func _enter(next: int) -> void:
	state = next
	_clock = 0.0


func _begin_attack(to_ball: Vector3) -> void:
	attacks += 1
	if _next_attack == 0:
		# It lands as the ring fills, at the end of the crouch and the leap, on ground it can reach.
		var at := _slam_spot(PackPressure.lead_aim(target, global_position, slam_crouch + SLAM_LEAP, 0.0, 0.0, BODY_CONTACT))
		_leap_to = Vector3(at.x, terrain.height(at.x, at.z) + HALF_HEIGHT, at.z)
		_commit_ring(Threat.Type.PROJECTILE, at, SLAM_RADIUS, 4.0)
		telegraph().set_flight(global_position + Vector3.DOWN * HALF_HEIGHT, 4.0 * SLAM_HEIGHT)
		_enter(State.SLAM_CROUCH)
	else:
		var aim := PackPressure.lead_aim(target, global_position, charge_brace, CHARGE_LENGTH / CHARGE_TIME, HIT_REACH, BODY_CONTACT) - global_position
		aim.y = 0.0
		var heading := aim if aim.length() > 0.5 else (to_ball if to_ball.length() > 0.5 else -global_basis.z)
		_commit_lane(Threat.Type.LANE, global_position, heading, CHARGE_LENGTH, CHARGE_WIDTH, 4.0).run_body(0.0, HIT_REACH)
		_enter(State.CHARGE_BRACE)
	_next_attack = 1 - _next_attack


func _slam_spot(led: Vector3) -> Vector3:
	var ball := _ball()
	var flat := Vector3(led.x - ball.x, 0.0, led.z - ball.z)
	if flat.length() < 0.5 or not is_inside_tree():
		return ball
	var space := get_world_3d().direct_space_state
	var from := ball + Vector3.UP * LEAP_RAY_LIFT
	var to := Vector3(led.x, terrain.height(led.x, led.z) + 1.0 + LEAP_RAY_LIFT, led.z)
	var at := led
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD_MASK))
	if not hit.is_empty():
		var room := Vector3(hit.position.x - ball.x, 0.0, hit.position.z - ball.z).length() - LEAP_CLEAR
		if room <= 0.0:
			return ball
		at = ball + flat.normalized() * room
	var top := Vector3(at.x, terrain.height(at.x, at.z) + LEAP_GROUND_PROBE, at.z)
	if space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * LEAP_GROUND_PROBE * 2.0, PhysicsLayers.WORLD_MASK)).is_empty():
		return ball
	return Vector3(at.x, ball.y, at.z)


func _after_slam() -> void:
	if phase < 2:
		_open_weak_window()
		return
	_clear_telegraph()
	if is_instance_valid(_reaction_bus) and _reaction_bus.has_signal("attack_cued"):
		_reaction_bus.attack_cued.emit(kind, "E04", FightPhases.CUED_TOTAL)
	_enter(State.CUE)


func _land_slam() -> void:
	var ring := telegraph()
	if ring != null and ring.contains(_ball()):
		var away := _flat_to_ball()
		away = away.normalized() if away.length() > 0.1 else Vector3.ZERO
		hits_landed += 1
		hit_player.emit(SLAM_DAMAGE, away * SLAM_SHOVE + Vector3.UP * 5.0)
	_after_slam()


func _check_charge(lane: Node3D) -> void:
	if _landed:
		return
	var to := _flat_to_ball()
	if to.length() > HIT_REACH or not lane.contains(_ball()):
		return
	_landed = true
	hits_landed += 1
	hit_player.emit(CHARGE_DAMAGE, lane.dir * CHARGE_SHOVE + Vector3.UP * 3.0)


func _open_weak_window() -> void:
	_clear_telegraph()
	weak_windows += 1
	if phase >= 2:
		charge_brace = maxf(ChallengeDials.TELL_FLOOR, CHARGE_BRACE * PHASE_TWO_WIND)
	_enter(State.WEAK)


func _build_model() -> bool:
	var parts := _parts()
	if parts.is_empty():
		return false
	_pose_rig = parts.rig.instantiate() as Skeleton3D
	_visual_parent().add_child(_pose_rig)
	for bone_name in MODEL_BONES:
		_pose_bones[bone_name] = _pose_rig.find_bone(bone_name)
	_base_color = Color.WHITE
	_material.albedo_color = Color.WHITE
	_material.vertex_color_use_as_albedo = true
	_model_plate_material = _plate_material()
	_model_plate_material.next_pass = BakeLook.edge_lift()
	_core_material = Palette.solid(Palette.VERDIGRIS)
	for part in parts.meshes:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		_visual_parent().add_child(mi)
		if part.skin != null:
			mi.skin = part.skin
			mi.skeleton = mi.get_path_to(_pose_rig)
		match part.name:
			"MinibossHull": mi.material_override = _material
			"MinibossArmour":
				_armour = mi
				mi.material_override = _model_plate_material
			"MinibossCore":
				_core = mi
				mi.material_override = _core_material
	_init_motion_rig()
	_model_pose(0.0)
	return true


func _init_motion_rig() -> void:
	_motion_rig = PropMotionRig.new()
	_rig_pivots.clear()
	var specs := {
		"body": {"cycle": PropMotionRig.CYCLE_BREATHE, "axis": Vector3.UP, "amplitude": 0.18, "hz": 0.85, "jolt_stiffness": 135.0, "jolt_damping": 11.5, "jolt_max_offset": 0.24, "jolt_rot_gain": 0.28},
		"fist_l": {"sway": true, "sway_stiffness": 24.0, "sway_damping": 4.8, "sway_gain": 0.022, "sway_max_rad": 0.24, "sway_ambient_amp": 0.045, "sway_ambient_hz": 0.72, "sway_phase": 0.0, "cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.UP, "amplitude": 0.12, "hz": 0.85, "phase": 0.0, "jolt_stiffness": 130.0, "jolt_damping": 11.0, "jolt_max_offset": 0.22},
		"fist_r": {"sway": true, "sway_stiffness": 24.0, "sway_damping": 4.8, "sway_gain": 0.022, "sway_max_rad": 0.24, "sway_ambient_amp": 0.045, "sway_ambient_hz": 0.72, "sway_phase": PI, "cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.UP, "amplitude": 0.12, "hz": 0.85, "phase": 0.5, "jolt_stiffness": 130.0, "jolt_damping": 11.0, "jolt_max_offset": 0.22},
		"shutter_l": {"jolt_stiffness": 150.0, "jolt_damping": 12.0, "jolt_max_offset": 0.14, "jolt_rot_gain": 0.36},
		"shutter_r": {"jolt_stiffness": 150.0, "jolt_damping": 12.0, "jolt_max_offset": 0.14, "jolt_rot_gain": 0.36},
	}
	for label in specs:
		var pivot := Node3D.new()
		pivot.name = "RigDriver_" + label
		_visual_parent().add_child(pivot)
		_rig_pivots[label] = pivot
		_motion_rig.add_part(label, pivot, specs[label])


static func _asset_fallback() -> Dictionary:
	if not _asset_warned:
		push_warning("miniboss: missing or malformed " + MODEL_PATH + "; using primitive fallback")
		_asset_warned = true
	return {}


static func _scene_transform(node: Node3D, scene: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != scene and parent is Node3D:
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	if not ResourceLoader.exists(MODEL_PATH):
		return _asset_fallback()
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		return _asset_fallback()
	var instance := packed.instantiate()
	if not instance is Node3D:
		instance.free()
		return _asset_fallback()
	var scene := instance as Node3D
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if rig == null:
		scene.free()
		return _asset_fallback()
	for bone_name in MODEL_BONES:
		if rig.find_bone(bone_name) < 0:
			scene.free()
			return _asset_fallback()
	var meshes := []
	for part_name in MODEL_PARTS:
		var mi := scene.find_child(part_name, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() != 1:
			scene.free()
			return _asset_fallback()
		var material := mi.mesh.surface_get_material(0)
		var slot: String = {"MinibossHull": "fleet_paint", "MinibossArmour": "part_state", "MinibossCore": "core_state"}[part_name]
		if material == null or material.resource_name != slot or (part_name != "MinibossCore" and mi.skin == null):
			scene.free()
			return _asset_fallback()
		var mesh := mi.mesh.duplicate() as ArrayMesh
		if mesh == null:
			scene.free()
			return _asset_fallback()
		if part_name == "MinibossArmour":
			var arrays := mesh.surface_get_arrays(0)
			if arrays[Mesh.ARRAY_COLOR] == null:
				scene.free()
				return _asset_fallback()
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if colors.size() != (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				scene.free()
				return _asset_fallback()
			var uvs := PackedVector2Array()
			for color in colors:
				uvs.append(Vector2(0.5 / 24.0 if color.r < 0.01 else 1.0 / 6.0, 0.25))
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var painted := Palette.solid(Color.WHITE)
		painted.vertex_color_use_as_albedo = true
		mesh.surface_set_material(0, painted)
		meshes.append({"name": part_name, "mesh": mesh, "skin": mi.skin,
			"xform": _scene_transform(mi, scene)})
	var rig_transform := _scene_transform(rig, scene)
	for child in rig.get_children():
		child.free()
	rig.get_parent().remove_child(rig)
	rig.transform = rig_transform
	var packed_rig := PackedScene.new()
	var error := packed_rig.pack(rig)
	rig.free()
	scene.free()
	if error != OK:
		return _asset_fallback()
	_shared = {"meshes": meshes, "rig": packed_rig}
	return _shared


func _model_pose(delta: float) -> void:
	var weak := state == State.WEAK
	var row: Dictionary = POSES[state_name()]
	var t := 1.0
	var fists := Vector3.ZERO
	var foot_angle := 0.0
	var lift := 0.0
	var foot_up := 0.0
	match state:
		State.SLAM_CROUCH:
			t = clampf(_clock / slam_crouch, 0.0, 1.0)
			fists = Vector3(0.0, 0.35, 0.5) * t
			foot_angle = 0.2 * t
		State.SLAM_LEAP:
			var leap := clampf(_clock / SLAM_LEAP, 0.0, 1.0)
			var raise := 1.0 - smoothstep(0.55, 1.0, leap)
			fists = Vector3(0.0, 1.8 * raise - 0.6 * (1.0 - raise), -0.5)
			foot_angle = -0.6 * raise
			lift = maxf(0.0, float(row.body) * HALF_HEIGHT * raise * smoothstep(0.0, 0.15, leap) - _leap_clearance())
			foot_up = lift + float(row.tuck) * raise
		State.CHARGE_BRACE:
			t = clampf(_clock / charge_brace, 0.0, 1.0)
			fists = Vector3(0.0, 0.3, -0.85) * t
		State.CHARGE:
			fists = Vector3(0.0, 0.3, -0.85)
		State.TURN:
			t = clampf(_clock / 0.3, 0.0, 1.0)
			fists = Vector3(0.0, 1.4, 0.2) * t
			lift = TURN_SHAKE * sin(_clock * 60.0) * (1.0 - _clock / FightPhases.TRANSITION_SECONDS)
		State.CUE:
			t = clampf(_clock / FightPhases.CUE_LEAD, 0.0, 1.0)
			fists = Vector3(0.0, 0.2, -0.5) * t
	var drop: float = lift if state == State.SLAM_LEAP else float(row.body) * HALF_HEIGHT * t + (lift if state == State.TURN else 0.0)
	var body_basis := Basis(Vector3.RIGHT, float(row.lean) * t)
	var calm := Comfort.reduced_motion
	var body_sec_pos := Vector3.ZERO
	var body_sec_basis := Basis.IDENTITY
	var fist_l_pos := Vector3.ZERO
	var fist_r_pos := Vector3.ZERO
	var fist_l_basis := Basis.IDENTITY
	var fist_r_basis := Basis.IDENTITY
	var shutter_l_basis := Basis.IDENTITY
	var shutter_r_basis := Basis.IDENTITY
	if _motion_rig != null:
		_motion_rig.reduced_motion = calm
		if delta > 0.0:
			if not calm and _prev_pose_state != -1 and _prev_pose_state != state:
				if _prev_pose_state == State.SLAM_LEAP and (state == State.WEAK or state == State.CUE):
					_motion_rig.apply_impulse(Vector3.DOWN, 1.3)
				elif state == State.TURN:
					_motion_rig.apply_impulse(Vector3.UP, 1.0)
			if not calm and _flash > 0.0 and not _prev_flash_active:
				_motion_rig.apply_impulse(Vector3.BACK, 0.85)
			_motion_rig.step(delta, velocity)
			if not calm:
				var bp: Node3D = _rig_pivots.get("body")
				if bp != null and state != State.SLAM_LEAP:
					body_sec_pos = bp.position
					body_sec_basis = bp.basis
				var fl: Node3D = _rig_pivots.get("fist_l")
				var fr: Node3D = _rig_pivots.get("fist_r")
				if fl != null and state != State.CHARGE_BRACE and state != State.CHARGE:
					fist_l_pos = fl.position
					fist_l_basis = fl.basis
				if fr != null and state != State.CHARGE_BRACE and state != State.CHARGE:
					fist_r_pos = fr.position
					fist_r_basis = fr.basis
				var sl: Node3D = _rig_pivots.get("shutter_l")
				var sr: Node3D = _rig_pivots.get("shutter_r")
				if sl != null and state != State.STALK:
					shutter_l_basis = sl.basis
				if sr != null and state != State.STALK:
					shutter_r_basis = sr.basis
		elif calm:
			_motion_rig.reset()
	_prev_pose_state = state
	_prev_flash_active = _flash > 0.0
	var socket := body_basis * CORE_SOCKET + Vector3.UP * drop + body_sec_pos
	for bone_name in MODEL_BONES:
		var index: int = _pose_bones[bone_name]
		var rest := _pose_rig.get_bone_rest(index)
		var pos := body_basis * rest.origin + Vector3.UP * drop
		var basis := body_basis * rest.basis
		var size := Vector3.ONE
		var side := -1.0 if bone_name.ends_with("Left") else 1.0
		if bone_name == "MinibossBody":
			pos += body_sec_pos
			basis = body_basis * body_sec_basis * rest.basis
		elif "Foot" in bone_name:
			pos = rest.origin + Vector3(side * float(row.splay) * t, foot_up, 0.0)
			basis = Basis(Vector3.BACK, -side * float(row.splay) * 0.5 * t) * Basis(Vector3.RIGHT, foot_angle) * rest.basis
		elif "Fist" in bone_name:
			var f_pos := fist_l_pos if side < 0.0 else fist_r_pos
			var f_bas := fist_l_basis if side < 0.0 else fist_r_basis
			pos += fists + f_pos
			basis = body_basis * f_bas * rest.basis
		elif "Plate" in bone_name:
			var open := 1.15 if weak else -float(row.shield_in) * t
			pos += body_basis * Vector3(-side * float(row.shield_in) * t, -float(row.shield_drop) * t, 0.0)
			var current := _pose_rig.get_bone_pose_rotation(index)
			var s_bas := shutter_l_basis if side < 0.0 else shutter_r_basis
			basis = body_basis * Basis(Vector3.UP, side * open) * s_bas * rest.basis
			var desired := basis.get_rotation_quaternion()
			basis = Basis(current.slerp(desired, 1.0 - exp(-14.0 * delta))) if delta > 0.0 else Basis(desired)
		elif bone_name == "MinibossHalo":
			pos = _pose_rig.transform.affine_inverse() * socket
			basis = body_basis * Basis(Vector3.UP, _clock * 5.0) * rest.basis
			size = Vector3.ONE if weak else Vector3.ZERO
		_pose_rig.set_bone_pose_position(index, pos)
		_pose_rig.set_bone_pose_rotation(index, basis.get_rotation_quaternion())
		_pose_rig.set_bone_pose_scale(index, size)
	_armour.material_override = Threat.Painter.hazard_stripe() if row.hazard else _model_plate_material
	var blend := 1.0 if (delta <= 0.0 or not _core_smoothed) else (1.0 - exp(-16.0 * delta))
	if blend >= 0.9999:
		blend = 1.0
	var pulse := 1.0 + (0.0 if calm else 0.12 * sin(Time.get_ticks_msec() * 0.018)) if weak else 1.0
	var target_scale := 1.5 * pulse if weak else 0.8
	var target_lean := float(row.lean) * t
	var target_color := Palette.live() if weak else Palette.VERDIGRIS
	var target_energy := FlashGuard.spike(1.2, 4.0) if weak else 0.0
	if blend >= 1.0:
		_core_pos_cur = socket
		_core_scale_cur = target_scale
		_core_lean_cur = target_lean
		_core_color_cur = target_color
		_core_energy_cur = target_energy
	else:
		_core_pos_cur = _core_pos_cur.lerp(socket, blend)
		_core_scale_cur = lerpf(_core_scale_cur, target_scale, blend)
		_core_lean_cur = lerpf(_core_lean_cur, target_lean, blend)
		_core_color_cur = _core_color_cur.lerp(target_color, blend)
		_core_energy_cur = lerpf(_core_energy_cur, target_energy, blend)
	_core_smoothed = true
	_core.position = _core_pos_cur
	_core.rotation.x = _core_lean_cur
	_core.scale = Vector3.ONE * _core_scale_cur
	_core_material.albedo_color = _core_color_cur
	_core_material.emission_enabled = weak or _core_energy_cur > 0.02
	_core_material.emission = Palette.live()
	_core_material.emission_energy_multiplier = _core_energy_cur
	if tint_state == "":
		_model_plate_material.albedo_color = Palette.SLATE
	if _model_plate_material.next_pass == null:
		_model_plate_material.next_pass = BakeLook.edge_lift()


func _leap_clearance() -> float:
	if terrain == null or not is_inside_tree():
		return 0.0
	return maxf(0.0, global_position.y - HALF_HEIGHT - terrain.height(global_position.x, global_position.z))


func _build_armour() -> void:
	_core_material = Palette.solid(Palette.SAND, 0.4)
	_core = MeshInstance3D.new()
	_core.mesh = EnemyBossCraft.brindle_vent_cap(1.0, 2.0)
	_core.material_override = _core_material
	_core.position = CORE_SOCKET
	_visual_parent().add_child(_core)
	var plate_material := _plate_material()
	plate_material.next_pass = BakeLook.edge_lift()
	for side in [-1.0, 1.0]:
		var plate := MeshInstance3D.new()
		plate.mesh = EnemyBossCraft.brindle_armour_plate(Vector3(RADIUS * 1.1, HALF_HEIGHT * 1.3, 0.5))
		plate.material_override = plate_material
		plate.position = Vector3(side * RADIUS * 0.5, 0.6, -RADIUS - 0.1)
		_visual_parent().add_child(plate)
		_plates.append({"node": plate, "side": side})
	_halo = MeshInstance3D.new()
	_halo.mesh = EnemyBossCraft.reward_canister_band(1.8, 0.4)
	_halo.material_override = Palette.unshaded(Palette.SAND)
	_halo.position = Vector3.UP * (HALF_HEIGHT + 1.4)
	_halo.visible = false
	_visual_parent().add_child(_halo)
	for i in 5:
		var angle := TAU * i / 5.0
		_accent(EnemyBossCraft.dispatch_pod(0.4, 1.6), Palette.COPPER, 1.8, Vector3(cos(angle) * 1.3, HALF_HEIGHT + 0.5, sin(angle) * 1.3))


func _pose(delta: float) -> void:
	if _pose_rig != null:
		_model_pose(delta)
	else:
		_primitive_pose(delta)
	if not is_instance_valid(target):
		return
	if state in [State.STALK, State.CHARGE_BRACE, State.WEAK, State.SLAM_CROUCH, State.TURN, State.CUE]:
		var to := _flat_to_ball()
		if state == State.CHARGE_BRACE and telegraph() != null:
			to = telegraph().dir
		if to.length() > 0.5:
			var want := atan2(-to.x, -to.z)
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-8.0 * delta))


func _primitive_pose(delta: float) -> void:
	if _core == null:
		return
	var weak := state == State.WEAK
	var open := 1.0 if weak else 0.0
	for entry in _plates:
		var plate: MeshInstance3D = entry["node"]
		var side: float = entry["side"]
		plate.position.x = lerpf(plate.position.x, side * RADIUS * (0.5 + 0.9 * open), 1.0 - exp(-14.0 * delta))
		plate.rotation.y = lerpf(plate.rotation.y, side * 0.9 * open, 1.0 - exp(-14.0 * delta))
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.018) if weak else 1.0
	_core.scale = Vector3.ONE * (1.5 * pulse if weak else 0.8)
	_core_material.emission_energy_multiplier = FlashGuard.spike(1.2, 4.0) if weak else 1.2
	_halo.visible = weak
	if weak:
		_halo.rotate_y(delta * 5.0)
