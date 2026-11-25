extends RefCounted

const UP := Vector3.UP
const LIMIT := 0.99
const STEPS := 6
const MAX_ANGLE := PI * 0.5
const FLAT := 0.0005


static func hull(points: PackedVector3Array) -> PackedVector3Array:
	if points.size() < 4:
		return points
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var cloud := ArrayMesh.new()
	cloud.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	var shape := cloud.create_convex_shape(true, false)
	return shape.points if shape != null and shape.points.size() >= 4 else points


static func support(ring: PackedVector3Array, yaw: float, brackets: PackedVector3Array, bank: Basis, toward: Vector3) -> float:
	var d := bank.inverse() * toward
	var best := -INF
	var ring_d := Basis(UP, -yaw) * d
	for p in ring:
		best = maxf(best, p.dot(ring_d))
	for p in brackets:
		best = maxf(best, p.dot(d))
	return best


static func basis_for(normal: Vector3, angle: float) -> Basis:
	var axis := UP.cross(normal)
	if angle <= 0.0 or axis.length() < FLAT:
		return Basis.IDENTITY
	return Basis(axis.normalized(), angle)


static func solve(ring: PackedVector3Array, yaw: float, brackets: PackedVector3Array, normal: Vector3, limit := LIMIT, steps := STEPS) -> Dictionary:
	var toward := -normal
	var level := support(ring, yaw, brackets, Basis.IDENTITY, toward)
	if UP.cross(normal).length() < FLAT or level <= limit:
		return {"angle": 0.0, "reach": level, "clears": level <= limit}
	var lo := 0.0
	var hi := MAX_ANGLE
	for i in steps:
		var mid := (lo + hi) * 0.5
		if support(ring, yaw, brackets, basis_for(normal, mid), toward) <= limit:
			hi = mid
		else:
			lo = mid
	var reach := support(ring, yaw, brackets, basis_for(normal, hi), toward)
	return {"angle": hi, "reach": reach, "clears": reach <= limit}


static func angle_for(ring: PackedVector3Array, yaw: float, brackets: PackedVector3Array, normal: Vector3, limit := LIMIT, steps := STEPS) -> float:
	return solve(ring, yaw, brackets, normal, limit, steps)["angle"]


static func smooth(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3:
	var blended := current.lerp(target, 1.0 - exp(-rate * delta))
	return blended.normalized() if blended.length() > 0.001 else target
