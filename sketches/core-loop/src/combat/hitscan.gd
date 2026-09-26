extends RefCounted

# The shared hitscan core every weapon builds on (v2's zap, generalized). Two rays:
# the camera's centre ray finds what the crosshair is on, then a ray from the ball to
# that point finds what the shot actually reaches, so cover between the ball and the
# target stops the shot even when the camera can see past it.

const WORLD_AND_ENEMIES := 5


static func cast(space: PhysicsDirectSpaceState3D, aim_from: Vector3, aim_dir: Vector3,
		origin: Vector3, reach: float, mask := WORLD_AND_ENEMIES) -> Dictionary:
	var target := aim_from + aim_dir.normalized() * reach
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim_from, target, mask))
	if not sight.is_empty():
		target = sight["position"]
	var shot := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + (target - origin) * 1.05, mask))
	var end: Vector3 = shot["position"] if not shot.is_empty() else target
	var enemy: Node3D = null
	if not shot.is_empty() and (shot["collider"] as Node).is_in_group("enemy"):
		enemy = shot["collider"]
	return {"from": origin, "to": end, "enemy": enemy}
