extends SceneTree

const Stage := preload("res://src/stage.gd")
const Terrain := preload("res://src/terrain.gd")
const PlayerBall := preload("res://src/player_ball.gd")

const BUDGET := 75.0
const TARGET_HEIGHT := Terrain.TOP_H - 2.0


# The slow ground route has to be walkable with nothing but the drive input, or
# the stage has no guaranteed way back up and the route choice is fake.
class Forward:
	extends RefCounted

	func poll(out) -> void:
		out.clear()
		out.move = Vector2(0.0, 1.0)


var _stage
var _started := false
var _clock := 0.0
var _best := -99.0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _process(delta: float) -> bool:
	if not _started:
		if _stage.player == null:
			return false
		_started = true
		_stage.director.paused = true
		_stage.player.set_mode(PlayerBall.RIGID)
		_stage.player.reset_to(Terrain.at(Terrain.BYPASS_FOOT, 2.0))
		_stage.player.source = Forward.new()
		# Yaw 0 points the drive basis down -Z, which is up the bypass.
		_stage.camera.yaw = 0.0
		return false

	_clock += delta
	var at: Vector3 = _stage.player.ball_position()
	_best = maxf(_best, at.y)
	if at.y < TARGET_HEIGHT and _clock < BUDGET:
		return false

	var made_it := _best >= TARGET_HEIGHT
	print("bypass: highest point %.2f m after %.1f s of driving forward in rigid mode (needs >= %.1f) -> %s"
		% [_best, _clock, TARGET_HEIGHT, "PASS" if made_it else "FAIL"])
	print("bypass: ended at (%.1f, %.1f, %.1f), budget %.0f s" % [at.x, at.y, at.z, BUDGET])
	print("bypass_test: %s" % ("PASS" if made_it else "FAILED to reach the top shelf"))
	_stage.free()
	quit(0 if made_it else 1)
	return true
