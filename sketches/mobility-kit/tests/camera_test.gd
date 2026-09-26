extends SceneTree

const Lab := preload("res://src/lab.gd")

var _lab
var _frames := 0
var _near := 0
var _samples := 0


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false
	var cam: Camera3D = _lab.camera.cam

	var gap := cam.global_position.distance_to(_lab.player.ball_position())
	_samples += 1
	if gap < 3.0:
		_near += 1
	if _frames < 150:
		return false
	var ok := _near == 0
	print("[camera] %d of %d frames put the camera within 3 m of the ball (needs 0) -> %s" % [_near, _samples, "PASS" if ok else "FAIL"])
	print("camera_test: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
