extends RefCounted

const Groups := preload("res://src/core/groups.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")

const WORLD := PhysicsLayers.WORLD_MASK
const WORLD_AND_ENEMIES := PhysicsLayers.WORLD_AND_ENEMIES_MASK


static func aim(space: PhysicsDirectSpaceState3D, aim_from: Vector3, aim_dir: Vector3,
		origin: Vector3, reach: float) -> Dictionary:
	var dir := aim_dir.normalized()
	var skip := maxf(0.0, (origin - aim_from).dot(dir))
	var start := aim_from + dir * skip
	var point := start + dir * reach
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, point, WORLD_AND_ENEMIES))
	if not sight.is_empty():
		point = sight["position"]
	var to := point
	var blocked := false
	if origin.distance_squared_to(point) > 0.01:
		var cover := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, point, WORLD))
		if not cover.is_empty():
			to = cover["position"]
			blocked = true
	return {"point": point, "to": to, "blocked": blocked, "on_enemy": not sight.is_empty() and (sight["collider"] as Node).is_in_group(Groups.ENEMY)}


static func cast(space: PhysicsDirectSpaceState3D, aim_from: Vector3, aim_dir: Vector3,
		origin: Vector3, reach: float, mask := WORLD_AND_ENEMIES) -> Dictionary:
	var target := aim_from + aim_dir.normalized() * reach
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim_from, target, mask))
	if not sight.is_empty():
		target = sight["position"]
	var shot := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + (target - origin) * 1.05, mask))
	var end: Vector3 = shot["position"] if not shot.is_empty() else target
	var enemy: Node3D = null
	if not shot.is_empty() and (shot["collider"] as Node).is_in_group(Groups.ENEMY):
		enemy = shot["collider"]
	return {"from": origin, "to": end, "enemy": enemy}
