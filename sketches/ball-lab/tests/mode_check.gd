extends SceneTree

const Lab := preload("res://src/lab.gd")
const PlayerBall := preload("res://src/player_ball.gd")

const DRIVE := 2.5
const BOUNCE_WINDOW := 1.2


class ScriptedSource:
	extends RefCounted

	var move := Vector2.ZERO
	var jump := false
	var boost := false

	func poll(out) -> void:
		out.clear()
		out.move = move
		out.jump_pressed = jump
		out.boost_pressed = boost
		jump = false
		boost = false


var _lab
var _source := ScriptedSource.new()
var _stage := 0
var _clock := 0.0
var _failures := 0
var _carried := {}
var _enemy: Node3D
var _enemy_from := Vector3.ZERO


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(delta: float) -> bool:
	if _lab.player == null:
		return false
	if _stage == 0:
		_lab.player.source = _source
		_lab.player.reset_to(_lab.field.spawn)
		_source.move = Vector2(0.0, 1.0)
		_stage = 1
		return false

	_clock += delta
	match _stage:
		1:
			if _clock > 1.0:
				_source.jump = true
			if _clock > 1.5:
				_source.boost = true
			if _clock < DRIVE:
				return false
			var speed: float = _lab.player.state.velocity.length()
			_report("drive", speed > 6.0, "kinematic drive reached %.2f m/s in %.1fs" % [speed, DRIVE])
			_carried = {"at": _lab.player.ball_position(), "v": _lab.player.state.velocity}
			_lab.player.toggle_mode()
			_stage = 2
			_clock = 0.0
		2:
			if _clock < 0.2:
				return false
			var moved: float = _lab.player.ball_position().distance_to(_carried["at"])
			var speed_before: float = (_carried["v"] as Vector3).length()
			var speed_after: float = _lab.player.state.velocity.length()
			_report("toggle", _lab.player.mode_name() == "rigid" and moved < 8.0,
				"mode carried position within %.2f m and %.1f -> %.1f m/s" % [moved, speed_before, speed_after])
			_enemy = _lab.enemies[0]
			_enemy_from = _enemy.global_position
			_lab.player.toggle_mode()
			_lab.player.reset_to(_enemy.global_position + Vector3.UP * 4.0)
			_lab.player.active_body().set_velocity_now(Vector3.DOWN * 14.0)
			_stage = 3
			_clock = 0.0
		3:
			if _lab.player.state.velocity.y > 1.0:
				_report("rebound", true, "descending hit bounced the ball to %.1f m/s upward with air jump %s"
					% [_lab.player.state.velocity.y, "restored" if _lab.player.state.air_actions > 0 else "spent"])
				_stage = 4
				_clock = 0.0
			elif _clock > BOUNCE_WINDOW:
				_report("rebound", false, "no upward rebound within %.1fs" % BOUNCE_WINDOW)
				_stage = 4
				_clock = 0.0
		4:
			if _clock < 0.5:
				return false
			var pushed: float = _enemy.global_position.distance_to(_enemy_from)
			_report("knockback", pushed > 0.2, "enemy moved %.2f m from the hit" % pushed)
			print("mode_check: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_lab.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false
