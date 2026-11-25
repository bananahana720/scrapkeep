extends SceneTree


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
