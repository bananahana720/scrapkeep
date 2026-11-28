extends RefCounted


static func basis_up(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	side = (side - up * side.dot(up)).normalized()
	return Basis(side, up, side.cross(up))
