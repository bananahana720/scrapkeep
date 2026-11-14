extends SceneTree

const JoltLayer := preload("res://src/combat/jolt_layer.gd")
const BoomTender := preload("res://src/combat/boom_tender.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const T := preload("res://tests/support/t.gd")

# W1-66 (gameplay critique finding 4): the jolt layer lays its mat, and the boom tender aims its lane,
# where the ball's roll carries it by the time the threat is live, so a ball holding its line meets it
# and the answer is a jump (the mat) or a turn (the boom), not only speed. counter.gd _ahead is the one
# rule: the ball's predicted spot along its curve, capped at a reach, at the ball's height.
#
# Evidence limit: a stand-in ball on a straight roll; whether a player reads the lead is a play check.

class Ball extends RefCounted:
	var at := Vector3(10.0, 2.0, -4.0)
	var v := Vector3.ZERO
	func ball_position() -> Vector3:
		return at
	func planar_velocity() -> Vector3:
		return v


class Still extends RefCounted:
	func ball_position() -> Vector3:
		return Vector3(1.0, 0.0, 1.0)


var _t := T.new("lay_ahead_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PackPressure.observe(Vector3.ZERO)
	var ball := Ball.new()
	for kind in [JoltLayer, BoomTender]:
		var enemy = kind.new()
		enemy.target = ball
		var name: String = "jolt layer" if kind == JoltLayer else "boom tender"
		ball.v = Vector3.ZERO
		_t.eq("%s: a still ball is aimed at as it stands" % name, enemy._ahead(1.0, 12.0), ball.at)
		ball.v = Vector3(6.0, 0.0, 0.0)
		_t.check("%s: a rolling ball is led along its line" % name, enemy._ahead(1.0, 12.0).is_equal_approx(ball.at + Vector3(6.0, 0.0, 0.0)), str(enemy._ahead(1.0, 12.0)))
		ball.v = Vector3(0.0, 0.0, 40.0)
		var far: Vector3 = enemy._ahead(1.0, 12.0)
		_t.near("%s: the lead stops at its reach" % name, Vector2(far.x - ball.at.x, far.z - ball.at.z).length(), 12.0, 0.001)
		_t.near("%s: the lead keeps the ball's height" % name, far.y, ball.at.y)
		enemy.target = Still.new()
		_t.eq("%s: a target with no velocity is aimed at as it stands" % name, enemy._ahead(1.0, 12.0), Vector3(1.0, 0.0, 1.0))
		enemy.free()
	_t.check("the mat leads at most two of its radii", JoltLayer.LAY_AHEAD <= 12.0 + 0.001)
	_t.check("the boom leads no further than its lane plus the cruise of half a sweep", BoomTender.LEAD_REACH <= BoomTender.LANE_LENGTH + 2.0)
	quit(_t.verdict())

# smoke: solo timeout=60s
