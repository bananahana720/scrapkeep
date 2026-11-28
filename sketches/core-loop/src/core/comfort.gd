extends RefCounted

static var reduced_motion := false


static func motion_scale() -> float:
	return 0.0 if reduced_motion else 1.0
