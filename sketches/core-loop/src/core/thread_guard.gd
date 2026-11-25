extends RefCounted

# In Godot debug builds a failing assert() aborts main_only() and returns null instead of bool.

static var violations := 0
static var last_violation := ""
static var _lock := Mutex.new()


static func reset_for_tests() -> void:
	_lock.lock()
	violations = 0
	last_violation = ""
	_lock.unlock()


static func main_only(where: String) -> bool:
	var on_main := OS.get_thread_caller_id() == OS.get_main_thread_id()
	if not on_main:
		_lock.lock()
		violations += 1
		last_violation = where
		_lock.unlock()
	assert(on_main, "thread_guard: %s ran off the main thread" % where)
	return on_main
