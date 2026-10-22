extends RefCounted

# The main-thread check for code that makes or touches nodes, meshes or other server objects. Worker and loader
# threads plan data only: a mesh made off the main thread races the headless renderer's RID owner ("Attempting to
# initialize the wrong RID"), and a node call there trips the scene tree's thread guard. A guarded path calls
# main_only first and returns when it is false. Off the main thread it counts the call and, in a debug build,
# fails an assert (a SCRIPT ERROR naming the path), so a planted worker call shows in any test or bot log.

static var violations := 0
static var last_violation := ""
static var _lock := Mutex.new()


static func main_only(where: String) -> bool:
	var on_main := OS.get_thread_caller_id() == OS.get_main_thread_id()
	if not on_main:
		_lock.lock()
		violations += 1
		last_violation = where
		_lock.unlock()
	assert(on_main, "thread_guard: %s ran off the main thread" % where)
	return on_main
