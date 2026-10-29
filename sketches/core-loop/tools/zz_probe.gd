extends RefCounted

# Probe only (claude/project-thread-5uuwga-probe-volley, never stacks): main-thread times of the
# lobber volley, fleet vessel and Warden engage paths, summed per frame and printed as "ZP f=<frame> ...".

static var _frame := -1
static var _acc := {}


static func add(key: String, usec: int) -> void:
	var f := Engine.get_process_frames()
	if f != _frame:
		_flush()
		_frame = f
	_acc[key] = int(_acc.get(key, 0)) + usec


static func _flush() -> void:
	if _acc.is_empty():
		return
	var loud := false
	for k in _acc:
		if not k.ends_with("_phys") and int(_acc[k]) >= 500:
			loud = true
	var phys := int(_acc.get("game_phys", 0)) + int(_acc.get("world_phys", 0)) + int(_acc.get("combat_phys", 0))
	if loud or phys >= 6000:
		var keys := _acc.keys()
		keys.sort()
		var parts := PackedStringArray()
		for k in keys:
			parts.append("%s=%.2f" % [k, int(_acc[k]) / 1000.0])
		print("ZP f=%d %s" % [_frame, " ".join(parts)])
	_acc.clear()
