extends RefCounted
# The carrier bank (MOTION-SPEC row 208): the level carrier tilts off a steep face so the
# weapon ring and the gap-bracket modules stay inside the 1.0 collider's reach along the contact
# normal. Draw only; physics never reads it. Pure functions, so a test can pose any shell.
#
# Frames: points and normals here are in the Pod's frame (the pod only yaws, so its up is world up).
# The bank is Basis(UP x normal, angle): it leans the carrier's up toward the face, which lifts
# the wall-side edge of the ring and the low side modules. Angle 0 on floors and gentle slopes.

const UP := Vector3.UP
# Support distance the carrier may reach along the contact normal (the collider is 1.0; 0.01 m of air).
const LIMIT := 0.99
# Six bisection steps over 90 degrees settle within 1.5 degrees, on the clear side whenever any
# bank clears (solve reports when none does).
const STEPS := 6
const MAX_ANGLE := PI * 0.5
# Below this |UP x normal| the face is a floor (or a ceiling) and has no side to bank toward.
const FLAT := 0.0005


# The convex hull of a point cloud: the only points that can ever be furthest along a direction.
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


# Furthest reach, along `toward` (a unit direction), of the ring hull yawed by `yaw` about Y
# and the bracket hull, both after `bank`.
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


# The bank that keeps the support along -normal at `limit` or less, and what it leaves over:
# {angle, reach, clears}. `reach` is the support at `angle`; `clears` is reach <= limit (the
# bisection's own test, no epsilon). The angle is the smallest one (to bisection precision, rounded
# up) that clears, 0 when 0 already does or on a floor. When nothing clears (a hull point farther
# than `limit` from the pivot never can, rotation keeps its radius) the angle is the least-reach one
# of those evaluated (0, each midpoint, MAX_ANGLE), the smallest angle on a tie.
static func solve(ring: PackedVector3Array, yaw: float, brackets: PackedVector3Array, normal: Vector3, limit := LIMIT, steps := STEPS) -> Dictionary:
	var toward := -normal
	var level := support(ring, yaw, brackets, Basis.IDENTITY, toward)
	if UP.cross(normal).length() < FLAT or level <= limit:
		return {"angle": 0.0, "reach": level, "clears": level <= limit}
	var lo := 0.0
	var hi := MAX_ANGLE
	var hi_reach := INF
	var best_angle := 0.0
	var best_reach := level
	for i in steps:
		var mid := (lo + hi) * 0.5
		var r := support(ring, yaw, brackets, basis_for(normal, mid), toward)
		if r < best_reach:
			best_angle = mid
			best_reach = r
		if r <= limit:
			hi = mid
			hi_reach = r
		else:
			lo = mid
	if hi_reach <= limit:
		return {"angle": hi, "reach": hi_reach, "clears": true}
	var end := support(ring, yaw, brackets, basis_for(normal, MAX_ANGLE), toward)
	if end < best_reach:
		best_angle = MAX_ANGLE
		best_reach = end
	return {"angle": best_angle, "reach": best_reach, "clears": false}


# The angle of solve, for callers that do not need the residual.
static func angle_for(ring: PackedVector3Array, yaw: float, brackets: PackedVector3Array, normal: Vector3, limit := LIMIT, steps := STEPS) -> float:
	return solve(ring, yaw, brackets, normal, limit, steps)["angle"]


# One frame of the normal's smoothing toward the target (a unit vector; an empty one holds).
static func smooth(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3:
	var blended := current.lerp(target, 1.0 - exp(-rate * delta))
	return blended.normalized() if blended.length() > 0.001 else target
