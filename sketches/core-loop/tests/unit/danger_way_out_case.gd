extends RefCounted

const NearMiss := preload("res://src/combat/near_miss.gd")

# The danger mark's way out (combat/near_miss.gd way_out): the shortest flat way to a warning's
# edge, from the same committed shape its damage reads.


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.01


func run(t) -> void:
	var ring := {"form": "radial", "centre": Vector3.ZERO, "r_in": 0.0, "r_out": 6.0, "a0": 0.0, "a1": TAU}
	var way := NearMiss.way_out(ring, Vector3(2.0, 0.0, 0.0))
	t.check("a ring: straight out from its centre", _near(way, Vector3.RIGHT), str(way))
	var band := {"form": "radial", "centre": Vector3.ZERO, "r_in": 4.0, "r_out": 10.0, "a0": 0.0, "a1": TAU}
	way = NearMiss.way_out(band, Vector3(0.0, 0.0, 5.0))
	t.check("a band, nearer its hole: inward", _near(way, Vector3.FORWARD), str(way))
	way = NearMiss.way_out(band, Vector3(0.0, 0.0, 9.0))
	t.check("a band, nearer its rim: outward", _near(way, Vector3.BACK), str(way))
	var wedge := {"form": "radial", "centre": Vector3.ZERO, "r_in": 0.0, "r_out": 20.0, "a0": -0.3, "a1": 0.3}
	way = NearMiss.way_out(wedge, Vector3(5.0, 0.0, 1.0))
	t.check("a wedge, near its upper side: across that side", way.z > 0.9, str(way))
	way = NearMiss.way_out(wedge, Vector3(5.0, 0.0, -1.0))
	t.check("a wedge, near its lower side: across that side", way.z < -0.9, str(way))
	var lane := {"form": "lane", "centre": Vector3.ZERO, "dir": Vector3.RIGHT, "back": 0.0, "length": 30.0, "half_width": 2.0}
	way = NearMiss.way_out(lane, Vector3(10.0, 0.0, 0.5))
	t.check("a lane: sideways toward the nearer side", _near(way, Vector3.BACK), str(way))
	way = NearMiss.way_out(lane, Vector3(29.5, 0.0, 0.0))
	t.check("a lane, at its far end: off the end", _near(way, Vector3.RIGHT), str(way))
	way = NearMiss.way_out(lane, Vector3(0.5, 0.0, 0.0))
	t.check("a lane, at its start: back off the start", _near(way, Vector3.LEFT), str(way))
	var charge := {"form": "lane", "centre": Vector3.ZERO, "dir": Vector3.RIGHT, "back": 4.0, "length": 30.0, "half_width": 3.0}
	way = NearMiss.way_out(charge, Vector3(0.5, 0.0, 0.5))
	t.check("a lane reaching back past its start: sideways, not off the start", _near(way, Vector3.BACK), str(way))
	t.check("no shape: no way", NearMiss.way_out({}, Vector3.ZERO) == Vector3.ZERO, "")
