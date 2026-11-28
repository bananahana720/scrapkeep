extends RefCounted

const Augments := preload("res://src/movement/augments.gd")


const STICKY := 1.5


static func target(kit, tuning, space: PhysicsDirectSpaceState3D, enemies: Array, from: Vector3,
		forward: Vector3, ball: Vector3) -> Dictionary:
	var reach: float = tuning.f("rope_range")
	var assist: float = tuning.f("grapple_assist_deg")
	forward = forward.normalized()
	var locked := _lock(kit, tuning, space, enemies, from, forward, ball, reach)
	if not locked.is_empty():
		return locked
	return Augments.grapple_target(space, from, forward, ball, reach, assist,
		Augments.WORLD_MASK | Augments.ENEMY_MASK | Augments.STAKE_MASK, false)


static func _lock(kit, tuning, space: PhysicsDirectSpaceState3D, enemies: Array, from: Vector3,
		forward: Vector3, ball: Vector3, reach: float) -> Dictionary:
	var cone := deg_to_rad(tuning.f("harpoon_lock_deg"))
	var held = kit.lock_body
	var found: Array = []
	for enemy in enemies:
		if not Augments.hookable_body(enemy):
			continue
		var centre: Vector3 = enemy.global_position
		var gap := centre.distance_to(ball)
		if gap > reach or (centre - ball).dot(forward) <= 0.0:
			continue
		var angle := forward.angle_to(centre - from)
		if angle <= cone * (STICKY if enemy == held else 1.0):
			found.append([angle, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for entry in found:
		var enemy: Node3D = entry[1]
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, enemy.global_position, Augments.WORLD_MASK)).is_empty():
			kit.lock_body = enemy
			var away := ball - enemy.global_position
			return {"state": Augments.AIM_BODY, "point": enemy.global_position,
				"normal": away.normalized() if away.length() > 0.01 else Vector3.UP, "body": enemy}
	kit.lock_body = null
	return {}
