extends RefCounted

# The clock the hit-stop gates read. A played game uses the wall clock. tools/bot_run.gd
# runs at --fixed-fps faster than real time, where wall-clock spacing depends on CPU
# load; a stop that passes or fails the gate changes Engine.time_scale and so the
# physics, and a seed stops replaying. Bot runs set `ticks` to count physics ticks
# instead, which the fixed step makes the same on every run.

static var ticks := false


static func msec() -> int:
	if ticks:
		return int(Engine.get_physics_frames() * 1000 / Engine.physics_ticks_per_second)
	return Time.get_ticks_msec()
