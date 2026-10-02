extends RefCounted

const Holds := preload("res://src/combat/holds.gd")

# The hold bound (holds.gd bound): a hold may bend the ball's path but never lower its
# planar speed or turn its heading faster than 60 degrees a second.
# - against the velocity: removed; along it: whole;
# - across it: capped at speed * PI / 3;
# - under 1 m/s there is no heading, and any pull passes whole;
# - one second of the capped sideways pull turns the heading 60 degrees or less and
#   never lowers the speed.

var _t


func run(t) -> void:
	_t = t
	_directions()
	_rest()
	_second_of_pull()


func _close(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001


func _directions() -> void:
	var v := Vector3(0.0, 0.0, -20.0)
	var back := Holds.bound(v, Vector3(0.0, 0.0, 30.0))
	_t.check("bound: a pull straight back is removed", _close(back, Vector3.ZERO), "got %s" % [back])
	var side := Holds.bound(v, Vector3(40.0, 0.0, 0.0))
	_t.check("bound: a sideways pull is capped at speed * PI / 3",
		_close(side, Vector3(20.0 * PI / 3.0, 0.0, 0.0)), "got %s, cap %.3f" % [side, 20.0 * PI / 3.0])
	var small := Holds.bound(v, Vector3(5.0, 0.0, 0.0))
	_t.check("bound: a sideways pull under the cap passes whole", _close(small, Vector3(5.0, 0.0, 0.0)), "got %s" % [small])
	var forward := Holds.bound(v, Vector3(0.0, 0.0, -9.0))
	_t.check("bound: a pull forward passes whole", _close(forward, Vector3(0.0, 0.0, -9.0)), "got %s" % [forward])
	var mixed := Holds.bound(v, Vector3(40.0, 3.0, 30.0))
	_t.check("bound: a diagonal loses its backward part, keeps a capped side and its vertical",
		_close(mixed, Vector3(20.0 * PI / 3.0, 3.0, 0.0)), "got %s" % [mixed])


func _rest() -> void:
	var slow := Vector3(0.5, 0.0, 0.0)
	for pull in [Vector3(-40.0, 0.0, 0.0), Vector3(0.0, 0.0, 40.0), Vector3(7.0, 2.0, -3.0)]:
		_t.check("bound: at 0.5 m/s a pull passes whole", _close(Holds.bound(slow, pull), pull), "pull %s" % [pull])


func _second_of_pull() -> void:
	var v := Vector3(0.0, 0.0, -20.0)
	var start := v
	var step := 1.0 / 240.0
	var lowest := v.length()
	for i in 240:
		var a := Holds.bound(v, Vector3(40.0, 0.0, 0.0))
		v += a * step
		lowest = minf(lowest, v.length())
	var turned := rad_to_deg(start.angle_to(v))
	_t.check("bound: a second of capped sideways pull turns at most 60 degrees", turned <= 60.0, "turned %.2f degrees" % turned)
	_t.check("bound: speed is not lower after the pull", lowest >= start.length() - 0.0001, "lowest speed %.4f of %.1f" % [lowest, start.length()])
