extends RefCounted

static func run(tag: String, c: Callable) -> void:
	var t := Time.get_ticks_usec()
	c.call()
	var dt := Time.get_ticks_usec() - t
	if dt > 300:
		print("DEFER_PROBE f%d %s %.2f" % [Engine.get_physics_frames(), tag, dt / 1000.0])
