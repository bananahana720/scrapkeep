extends SceneTree
# MOTION-SPEC rows 204 and 205 (DECISIONS "Fixed outline", 2026-10-22): the cockpit stays out
# of the juice transform, so the pod's global scale is 1.0 through a squash and at class V, and
# the juice shell targets 1.0 at every heft class.

const Game := preload("res://src/game.gd")

var _game
var _frames := 0
var _failures := 0
var _pod: Node3D


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _scale_err(n: Node3D) -> float:
	var b := n.global_basis
	return maxf(absf(b.x.length() - 1.0), maxf(absf(b.y.length() - 1.0), absf(b.z.length() - 1.0)))


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frames += 1
	var juice = _game.presentation.juice
	var player = _game.player
	if _frames == 1:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _frames < 40:
		return false
	if _frames == 40:
		_pod = player.find_child("HeroPod", true, false) as Node3D
		_check("pod mounted", _pod != null and _pod.get_parent() == player.pod_mount() and player.pod_mount().get_parent() == player.juice_node().get_parent(), "HeroPod hangs off the level pod mount beside Juice, not under it")
		if _pod == null:
			return _finish()
		juice.squash(0.4, Vector3.UP)
		return false
	if _frames == 42:
		var squashed: float = absf(_game.player.juice_node().global_basis.y.length() - 1.0)
		_check("squash control", squashed > 0.02, "the juice node is squashed %.3f off unit height while the pod is checked" % squashed)
		_check("pod scale in squash", _scale_err(_pod) < 0.001, "pod global scale error %.5f" % _scale_err(_pod))
		var offset: Vector3 = _pod.global_position - player.juice_node().global_position
		_check("pod follows offset", offset.length() < 0.01, "pod origin matches the juice origin to %.4f m" % offset.length())
		juice._heft_class = 5
		return false
	if _frames == 120:
		_check("class V target", is_equal_approx(juice.shell_target(), 1.0), "shell target %.2f at class V" % juice.shell_target())
		_check("class V shell", absf(juice.shell - 1.0) < 0.02, "shell %.3f at class V" % juice.shell)
		_check("pod scale at class V", _scale_err(_pod) < 0.001, "pod global scale error %.5f" % _scale_err(_pod))
		return _finish()
	return false


func _finish() -> bool:
	print("pod_scale_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
