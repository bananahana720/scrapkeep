extends SceneTree

const DropJuice := preload("res://src/presentation/drop_juice.gd")

# The Warden's break cage shows one topper frame per gate tier its bonus cores buy, and
# never more, however often the core count changes. Rebuilds run on separate process
# frames, as they do in play, so the frames queue_freed by one rebuild are gone before
# the next.

var _juice
var _warden: Node3D
var _run := {"bonus_cores": 0}
var _steps := [0, 1, 2, 1, 0, 2, 2, 1]
var _step := 0
var _failures := 0
var _waited := false


func _initialize() -> void:
	_warden = Node3D.new()
	root.add_child(_warden)
	_juice = DropJuice.new()
	_juice.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_juice)
	_juice.ctx = {"run": _run}


func _process(_delta: float) -> bool:
	if _waited:
		_check()
		_step += 1
	_waited = false
	if _step >= _steps.size():
		return _finish()
	_run["bonus_cores"] = _steps[_step]
	_juice._dress_cage({"warden": _warden})
	_waited = true
	return false


func _check() -> void:
	var frames: Array = _juice.cage.get_children().filter(func(c): return not c.is_queued_for_deletion() and c is MeshInstance3D and c.mesh is not CylinderMesh and c.mesh is not TorusMesh)
	var want: int = 1 + mini(_steps[_step], 2)
	var names := frames.map(func(c): return String(c.name))
	var named_ok := names.all(func(n): return n.begins_with("Frame"))
	var ok: bool = frames.size() == want and named_ok
	print("%s bonus %d: %d frames, want %d, names %s" % ["ok" if ok else "FAIL", _steps[_step], frames.size(), want, names])
	if not ok:
		_failures += 1


func _finish() -> bool:
	_juice.free()
	_warden.free()
	print("%d failures" % _failures)
	quit(1 if _failures > 0 else 0)
	return true
