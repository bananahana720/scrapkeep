extends SceneTree

# The base a batched test runs on (tools/test_batch.gd swaps `extends SceneTree` for this).
# The runner renames a test's own quit( calls to _batch_quit( and its _process and
# _physics_process to _batch_process and _batch_physics_process, so a test's end (quit, or a
# frame callback returning true) ends that test and the runner starts the next one.

static var batch
var _batch_done := false


func _batch_quit(exit_code: int = 0) -> void:
	if _batch_done:
		return
	_batch_done = true
	batch.finish(exit_code)


func _process(delta: float) -> bool:
	if not _batch_done and has_method("_batch_process") and call("_batch_process", delta):
		_batch_quit(0)
	return false


func _physics_process(delta: float) -> bool:
	if not _batch_done and has_method("_batch_physics_process") and call("_batch_physics_process", delta):
		_batch_quit(0)
	return false
