extends RefCounted


static var ticks := false
static var threaded_in_bot_runs := false


static func msec() -> int:
	if ticks:
		return int(Engine.get_physics_frames() * 1000 / Engine.physics_ticks_per_second)
	return Time.get_ticks_msec()
