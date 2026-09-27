extends SceneTree

const Stage := preload("res://src/stage.gd")
const Terrain := preload("res://src/terrain.gd")
const PlayerBall := preload("res://src/player_ball.gd")

const BUDGET := 75.0
const TARGET_HEIGHT := Terrain.TOP_H - 2.0
# The spawn sits above TARGET_HEIGHT, so a read taken before the reset lands would
# pass without climbing anything. The first read must be at the ramp foot.
const START_TOLERANCE := 1.0


# The slow ground route has to be walkable with nothing but the drive input, or
# the stage has no guaranteed way back up and the route choice is fake.
class Forward:
	extends RefCounted

	func poll(out) -> void:
		out.clear()
		out.move = Vector2(0.0, 1.0)


var _stage
var _started := false
var _ticks := 0
var _best := -99.0
var _start_offset := -1.0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


# Counted in physics ticks, not idle-frame seconds: the rigid reset lands on the
# next tick, and a starved machine fits less simulated time into a wall second.
func _physics_process(_delta: float) -> bool:
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

	_ticks += 1
	var at: Vector3 = _stage.player.ball_position()
	if _ticks == 1:
		_start_offset = at.distance_to(Terrain.at(Terrain.BYPASS_FOOT, 2.0))
	_best = maxf(_best, at.y)
	if at.y < TARGET_HEIGHT and _ticks < _to_ticks(BUDGET):
		return false

	var seconds := float(_ticks) / Engine.physics_ticks_per_second
	var at_foot := _start_offset < START_TOLERANCE
	var made_it := _best >= TARGET_HEIGHT
	print("bypass: first read %.2f m from the ramp foot (needs < %.1f) -> %s"
		% [_start_offset, START_TOLERANCE, "PASS" if at_foot else "FAIL"])
	print("bypass: highest point %.2f m after %.1f s of driving forward in rigid mode (needs >= %.1f) -> %s"
		% [_best, seconds, TARGET_HEIGHT, "PASS" if made_it else "FAIL"])
	print("bypass: ended at (%.1f, %.1f, %.1f), budget %.0f s" % [at.x, at.y, at.z, BUDGET])
	var ok := at_foot and made_it
	var verdict := "PASS"
	if not at_foot:
		verdict = "FAILED to start at the ramp foot"
	elif not made_it:
		verdict = "FAILED to reach the top shelf"
	print("bypass_test: %s" % verdict)
	_stage.free()
	quit(0 if ok else 1)
	return true


static func _to_ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)
