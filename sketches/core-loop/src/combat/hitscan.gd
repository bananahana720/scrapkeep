extends RefCounted

# The shared aim query every weapon reads (v2's zap, generalized). Two rays:
# the camera's centre ray finds what the crosshair is on, then a ray from the ball to
# that point finds what the shot actually reaches, so cover between the ball and the
# target stops the shot even when the camera can see past it. The reticle marks the
# same centre ray, so what it shows is what the shot is sent at (TADR-008).
#
# The centre ray starts level with the ball rather than at the lens: anything between
# the camera and the ball (a wall behind a mounted pylon, an enemy on your tail) is
# behind the shooter and must not catch the aim. That matters most in the shoulder view.

const WORLD := 1
const WORLD_AND_ENEMIES := 5


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
	return {"point": point, "to": to, "blocked": blocked, "on_enemy": not sight.is_empty() and (sight["collider"] as Node).is_in_group("enemy")}


# Kept for any caller that wants a single instant hit: the first enemy the shot reaches.
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
