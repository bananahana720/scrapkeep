extends CharacterBody3D

const Tuning := preload("res://src/tuning.gd")
const Rules := preload("res://src/ball_rules.gd")

signal enemy_touched(enemy: Node3D, normal: Vector3)

var tuning
var state
var drive_basis := Basis.IDENTITY

var _probe: ShapeCast3D


func setup(tuning_ref, state_ref) -> void:
	tuning = tuning_ref
	state = state_ref
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	add_child(shape)
	_probe = Rules.make_probe(self)
	add_child(_probe)


func set_active(active: bool) -> void:
	set_collision_layer_value(2, active)
	_probe.enabled = active
	visible = active


func set_velocity_now(new_velocity: Vector3) -> void:
	state.velocity = new_velocity


func teleport(to: Vector3, new_velocity: Vector3) -> void:
	global_position = to
	reset_physics_interpolation()
	state.velocity = new_velocity


func step(intent, delta: float) -> void:
	Rules.probe_ground(_probe, state)
	var wish := Rules.wish_direction(intent, drive_basis, state)
	state.velocity += Rules.slope_gravity(state, tuning) * delta
	state.velocity += Rules.drive_accel(state, tuning, wish, intent) * delta
	state.velocity += Rules.resistance(state, tuning, intent, delta)
	state.velocity += Rules.stick(state, delta)
	state.velocity += Rules.boost(state, tuning, intent, wish, -drive_basis.z)
	state.velocity += Rules.jump(state, tuning)
	_sweep(delta)
	velocity = state.velocity


func _sweep(delta: float) -> void:
	var motion: Vector3 = state.velocity * delta
	for _i in 4:
		var hit := move_and_collide(motion)
		if hit == null:
			return
		var normal := hit.get_normal()
		var collider := hit.get_collider()
		if collider != null and collider.is_in_group("enemy"):
			enemy_touched.emit(collider, normal)
		else:
			var into: float = state.velocity.dot(normal)
			if into < 0.0:
				var impact: float = -into
				state.impact = maxf(state.impact, impact)
				var bounce: float = tuning.f("restitution") if impact > 4.0 else 0.0
				# Tangential speed survives untouched; only the normal part rebounds.
				state.velocity -= normal * into * (1.0 + bounce)
		motion = hit.get_remainder().slide(normal)
		if motion.length_squared() < 0.000001:
			return
