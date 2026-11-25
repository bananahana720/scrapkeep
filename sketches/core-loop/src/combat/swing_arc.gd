extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")


static func forecast(player, seconds: float) -> Vector3:
	if player == null or not player.kit.hooked:
		return Vector3.INF
	var kit = player.kit
	var pos: Vector3 = player.ball_position()
	var vel: Vector3 = player.state.velocity
	var anchor: Vector3 = kit.anchor
	var carried := Vector3.ZERO
	if kit.on_body and is_instance_valid(kit.anchor_body) and kit.anchor_body.has_method("anchor_velocity"):
		carried = kit.anchor_body.anchor_velocity()
	var rope: float = kit.rope
	var gravity: float = player.tuning.f("gravity")
	var spring: float = player.tuning.f("rope_spring")
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var steps := int(ceil(seconds / dt))
	var fast: float = player.tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.FAST]
	for i in steps:
		var speed := vel.length()
		if speed > fast:
			vel -= vel / speed * minf(speed, Tuning.QUAD_DRAG * (speed - fast) * (speed - fast) * dt)
		var to := anchor - pos
		var dist := to.length()
		if dist > rope and dist > 0.001:
			var dir := to / dist
			var outward := -(vel - carried).dot(dir)
			if outward > 0.0:
				vel += dir * outward
			vel += dir * (dist - rope) * spring
		vel.y -= gravity * dt
		pos += vel * dt
		anchor += carried * dt
	return pos
