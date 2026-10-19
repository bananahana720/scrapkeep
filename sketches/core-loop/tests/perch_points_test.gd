extends SceneTree

const PerchPoints := preload("res://src/world/perch_points.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Terrain := preload("res://src/world/terrain.gd")
const T := preload("res://tests/support/t.gd")

# The Dispatcher's perch points (src/world/perch_points.gd; ENEMY-PRIORITY.md 4a): tops derived from
# a park's anchor fields, 6 to 10 m over the ground, within 40 m of the pack, clear of landform
# colliders, the same for one seed. Planted bad perches (too low, too tall, inside a collider, too
# far) must be refused and a planted good one must be returned, so a pick that accepts everything
# or nothing fails here. A park with no post in band answers INF and the Dispatcher builds its mast.

var _t := T.new("perch_points_test")


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _park(post_rise: float) -> Dictionary:
	return {
		"park_rows": [
			{"id": "posts", "element": "anchor_field", "recipe": "greybox:anchor_field", "at": [0.0, 0.0],
				"size": [120.0, post_rise, 120.0], "yaw_deg": 0.0},
			{"id": "bowl", "element": "bowl", "recipe": "greybox:bowl", "at": [60.0, 60.0],
				"size": [30.0, 6.0, 30.0], "yaw_deg": 0.0},
		],
		"activity_rows": [],
		"routes": [],
		"waymarks": [],
	}


func _initialize() -> void:
	var park := _park(8.0)
	var tops := PerchPoints.derive(park, _flat)
	_t.check("an 8 m anchor field yields perch tops", tops.size() > 10, str(tops.size()))
	var all_in_band := true
	for top: Vector3 in tops:
		all_in_band = all_in_band and absf(top.y - 8.0) < 0.001
	_t.check("every derived top is 8 m over its ground", all_in_band)
	_t.eq("derive is deterministic", PerchPoints.derive(park, _flat), tops)
	var sorted := true
	for i in range(1, tops.size()):
		sorted = sorted and (tops[i - 1].x < tops[i].x or (tops[i - 1].x == tops[i].x and tops[i - 1].z <= tops[i].z))
	_t.check("tops are sorted by x then z", sorted)
	# Planted negative control: a field whose posts are 14 m tall (park_test.json's) is out of band.
	_t.eq("negative control: 14 m posts are no perch", PerchPoints.derive(_park(14.0), _flat).size(), 0)
	_t.eq("negative control: 5 m posts are no perch", PerchPoints.derive(_park(5.0), _flat).size(), 0)
	_t.check("6 m posts are perches", PerchPoints.derive(_park(6.0), _flat).size() > 0)
	_t.check("10 m posts are perches", PerchPoints.derive(_park(10.0), _flat).size() > 0)

	var blocked := PerchPoints.blockers(park)
	_t.check("the bowl is a collider footprint", blocked.size() >= 1)
	var near := Vector3(-10.0, 0.0, 5.0)
	var pick := PerchPoints.pick(tops, near, _flat, blocked, 3)
	_t.check("a perch is found", pick.is_finite())
	if pick.is_finite():
		_t.check("within 40 m of the pack", Vector2(pick.x, pick.z).distance_to(Vector2(near.x, near.z)) <= PerchPoints.RANGE_M + 0.001)
		_t.check("6 to 10 m over the ground", pick.y >= 6.0 - 0.001 and pick.y <= 10.0 + 0.001)
		_t.check("kept off the pack", Vector2(pick.x, pick.z).distance_to(Vector2(near.x, near.z)) >= PerchPoints.STAND_OFF)
	_t.eq("one seed, one perch", PerchPoints.pick(tops, near, _flat, blocked, 3), pick)
	var distinct := {}
	for salt in 24:
		distinct[PerchPoints.pick(tops, near, _flat, blocked, salt)] = true
	_t.check("the salt varies the pick", distinct.size() > 1, str(distinct.size()))
	# Planted negative control: a pick that ignored the salt would collapse to one answer above;
	# one that ignored the point would give the far pack the same perch.
	var far_pick := PerchPoints.pick(tops, Vector3(-55.0, 0.0, -50.0), _flat, blocked, 3)
	_t.check("another pack gets a perch near it", far_pick.is_finite() and Vector2(far_pick.x, far_pick.z).distance_to(Vector2(-55.0, -50.0)) <= PerchPoints.RANGE_M + 0.001)
	_t.eq("a pack far from every post gets none", PerchPoints.pick(tops, Vector3(400.0, 0.0, 400.0), _flat, blocked, 3), Vector3.INF)

	# Planted bad perches: low, tall, inside the bowl's footprint, out of range. All refused.
	var bad: Array = [Vector3(5.0, 3.0, 0.0), Vector3(5.0, 14.0, 0.0), Vector3(60.0, 8.0, 60.0), Vector3(100.0, 8.0, 0.0)]
	_t.eq("planted bad perches are all refused", PerchPoints.pick(bad, Vector3.ZERO, _flat, blocked, 1), Vector3.INF)
	for top: Vector3 in bad:
		_t.check("valid() refuses %s" % str(top), not PerchPoints.valid(top, _flat, blocked) or Vector2(top.x, top.z).distance_to(Vector2.ZERO) > PerchPoints.RANGE_M)
	_t.check("valid() refuses the perch inside the collider", not PerchPoints.valid(Vector3(60.0, 8.0, 60.0), _flat, blocked))
	_t.check("valid() refuses a top 3 m up", not PerchPoints.valid(Vector3(5.0, 3.0, 0.0), _flat, blocked))
	_t.check("valid() refuses a top 14 m up", not PerchPoints.valid(Vector3(5.0, 14.0, 0.0), _flat, blocked))
	# ... and a planted good one among them is the answer, so a refuse-everything pick fails.
	var good := Vector3(25.0, 8.0, 0.0)
	_t.eq("a planted good perch among the bad is returned", PerchPoints.pick(bad + [good], Vector3.ZERO, _flat, blocked, 1), good)
	_t.check("valid() accepts it", PerchPoints.valid(good, _flat, blocked))
	# The rise is read over the ground under the top, not over zero.
	var hill := func(_x: float, _z: float) -> float: return 20.0
	_t.check("a top 8 m over a 20 m hill is in band", PerchPoints.valid(Vector3(0.0, 28.0, 0.0), hill, []))
	_t.check("the same y over the hill's 20 m is not 8 m up from zero", not PerchPoints.valid(Vector3(0.0, 8.0, 0.0), hill, []))
	# Pack-adjacent tops lose to tops at the stand-off.
	var close := Vector3(3.0, 8.0, 0.0)
	var off := Vector3(20.0, 8.0, 0.0)
	_t.eq("a top at the stand-off wins over one on the pack", PerchPoints.pick([close, off], Vector3.ZERO, _flat, [], 5), off)
	_t.eq("a lone close top is still a perch", PerchPoints.pick([close], Vector3.ZERO, _flat, [], 5), close)
	_t.eq("no tops, no perch", PerchPoints.pick([], Vector3.ZERO, _flat, [], 5), Vector3.INF)

	# A stage that is not a park file has no perch: the Dispatcher brings its mast.
	var StageDefs := preload("res://src/core/stage_defs.gd")
	var terrain := Terrain.new(StageDefs)
	_t.eq("a non-park stage answers INF", terrain.perch_near(Vector3.ZERO, 1), Vector3.INF)

	# Real data: a shipped park's anchor fields give perches, the same on every run.
	# (The Islands' 279 hoodoo posts all sit on route lanes, which anchor_posts keeps clear, so
	# they place no post and give no perch: the Dispatcher builds its mast there.)
	for id in ["pit", "crown"]:
		var park_map := ParkMap.new("res://src/world/park/park_%s.json" % id)
		_t.check("park_%s loads" % id, park_map.ok)
		if not park_map.ok:
			continue
		var real := PerchPoints.derive(park_map.park, _flat)
		_t.check("park_%s has perch tops" % id, real.size() > 0, str(real.size()))
		_t.eq("park_%s derive is deterministic" % id, PerchPoints.derive(park_map.park, _flat), real)
		var sample: Vector3 = real[real.size() / 2] if not real.is_empty() else Vector3.ZERO
		var beside := Vector3(sample.x + 8.0, 0.0, sample.z)
		var hit := PerchPoints.pick(real, beside, _flat, PerchPoints.blockers(park_map.park), 7)
		_t.check("a pack beside a real post gets a perch", hit.is_finite())
		if hit.is_finite():
			_t.check("it is in band and within 40 m", hit.y >= 6.0 - 0.001 and hit.y <= 10.0 + 0.001 and Vector2(hit.x, hit.z).distance_to(Vector2(beside.x, beside.z)) <= 40.001)
		print("perch_points_test: park_%s %d tops" % [id, real.size()])
	var islands := ParkMap.new("res://src/world/park/park_islands.json")
	_t.check("park_islands loads", islands.ok)
	if islands.ok:
		_t.eq("park_islands: every post is on a route lane, so no perch and the mast fallback", PerchPoints.derive(islands.park, _flat).size(), 0)
	quit(_t.verdict())
