extends Node3D

const Tuning := preload("res://src/tuning.gd")
const Rules := preload("res://src/ball_rules.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const BallState := preload("res://src/ball_state.gd")
const KinematicBall := preload("res://src/kinematic_ball.gd")
const RigidBall := preload("res://src/rigid_ball.gd")
const Intent := preload("res://src/intent.gd")
const LabMaterials := preload("res://src/lab_materials.gd")

enum { KINEMATIC, RIGID }

const MODE_NAMES := ["kinematic", "rigid"]

signal shockwave(position: Vector3, strength: float)

var tuning
var state := BallState.new()
var intent := Intent.new()
var source = Intent.Source.new()
var mode := KINEMATIC
var drive_basis := Basis.IDENTITY
var spawn_point := Vector3.ZERO

var _kinematic
var _rigid
var _visual: MeshInstance3D
var _roll := Basis.IDENTITY


func setup(tuning_ref, spawn: Vector3) -> void:
	tuning = tuning_ref
	spawn_point = spawn

	_kinematic = KinematicBall.new()
	_kinematic.name = "KinematicBall"
	add_child(_kinematic)
	_kinematic.setup(tuning, state)
	_kinematic.enemy_touched.connect(_on_enemy_touched)

	_rigid = RigidBall.new()
	_rigid.name = "RigidBall"
	add_child(_rigid)
	_rigid.setup(tuning, state)
	_rigid.intent = intent
	_rigid.enemy_touched.connect(_on_enemy_touched)

	_visual = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_visual.mesh = sphere
	_visual.material_override = LabMaterials.ball_material()
	add_child(_visual)

	set_mode(KINEMATIC)
	reset_to(spawn_point)


func active_body() -> Node3D:
	return _kinematic if mode == KINEMATIC else _rigid


func ball_position() -> Vector3:
	return active_body().global_position


# Switching modes must not change where you are or how fast you are going, or the
# two feels cannot be compared.
func set_mode(new_mode: int) -> void:
	var carried_position := ball_position() if _kinematic != null and is_inside_tree() else spawn_point
	var carried_velocity: Vector3 = state.velocity
	mode = new_mode
	_kinematic.set_active(mode == KINEMATIC)
	_rigid.set_active(mode == RIGID)
	active_body().teleport(carried_position, carried_velocity)


func toggle_mode() -> void:
	set_mode(RIGID if mode == KINEMATIC else KINEMATIC)


func reset_to(point: Vector3) -> void:
	state.reset()
	_roll = Basis.IDENTITY
	_kinematic.teleport(point, Vector3.ZERO)
	_rigid.teleport(point, Vector3.ZERO)


func mode_name() -> String:
	return MODE_NAMES[mode]


func _physics_process(delta: float) -> void:
	source.poll(intent)
	state.tick_timers(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_kinematic.drive_basis = drive_basis
	_rigid.drive_basis = drive_basis
	if mode == KINEMATIC:
		_kinematic.step(intent, delta)
	state.refresh_tier(tuning.f("cruise"))


func _process(delta: float) -> void:
	var body := active_body()
	_visual.global_position = body.global_position
	if mode == RIGID:
		_roll = _rigid.global_transform.basis.orthonormalized()
	else:
		var axis := Rules.roll_axis(state.velocity, state.contact_normal)
		if axis != Vector3.ZERO:
			var angle := (state.velocity - state.contact_normal * state.velocity.dot(state.contact_normal)).length() * delta / Tuning.RADIUS
			_roll = Basis(axis.normalized(), angle) * _roll
			_roll = _roll.orthonormalized()
	_visual.global_basis = _squash_basis() * _roll


func _squash_basis() -> Basis:
	var amount := clampf(state.impact / 26.0, 0.0, 0.42)
	if amount <= 0.001:
		return Basis.IDENTITY
	var align := _align_up(state.contact_normal)
	var scale := Basis.from_scale(Vector3(1.0 + amount * 0.55, 1.0 - amount, 1.0 + amount * 0.55))
	return align * scale * align.inverse()


static func _align_up(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	return Basis(right, up, right.cross(up))


func _on_enemy_touched(enemy: Node3D, normal: Vector3) -> void:
	var velocity: Vector3 = state.velocity
	var away := enemy.global_position - ball_position()
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if velocity.y < -3.0 and normal.y > 0.3:
		# The one mechanic worth keeping from the orchard: a descending rebound
		# gives the air jump back, so bouncing is a way to keep a line going.
		state.air_actions = 1
		state.impact = maxf(state.impact, absf(velocity.y))
		active_body().set_velocity_now(Vector3(velocity.x, tuning.f("jump_speed") * 0.95, velocity.z))
		enemy.knock(away * 0.6 + Vector3.DOWN * 0.2, 7.0)
		shockwave.emit(enemy.global_position, 0.6)
	elif state.tier >= SpeedTier.FAST:
		enemy.knock(away + Vector3.UP * 0.35, 18.0)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
