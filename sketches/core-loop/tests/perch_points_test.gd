extends SceneTree

const PerchPoints := preload("res://src/world/perch_points.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Terrain := preload("res://src/world/terrain.gd")
const T := preload("res://tests/support/t.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")

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

	# Real data: a shipped park's anchor fields give perches, the same on every run. (Islands is
	# checked below.)
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
		# Was 0 while the full-width bands cleared every islands post (park_recipes.gd spans_park); the returned hoodoo
		# posts in the perch band (rise 6 to 10 m) were 120 tops, and are 78 since a post within ANCHOR_POST_M of another is
		# dropped (field_posts across fields, anchor_posts for lane-edge posts; clip audit, 30 Oct): each dropped top had a
		# kept post within a footprint.
		_t.eq("park_islands: the returned posts in the perch band give perch tops", PerchPoints.derive(islands.park, _flat).size(), 78)
	_landform_tops()
	_park_coverage()
	quit(_t.verdict())


func _row(id: String, element: String, at: Array, size: Array, stamp := "") -> Dictionary:
	return {"id": id, "element": element, "recipe": "greybox:" + element, "at": at, "size": size, "yaw_deg": 0.0, "stamp": stamp, "y": null}


func _stage(rows: Array) -> Dictionary:
	return {"park_rows": rows, "activity_rows": [], "routes": [], "waymarks": [], "play_rect": [-200.0, -200.0, 400.0, 400.0]}


# Landform tops (the second source) on synthetic ground: a planted step in band is found, planted steps
# that are too low, too tall or on a slope are refused, and a ledge box in band offers its top.
func _landform_tops() -> void:
	var shelf := func(rise: float) -> Callable:
		return func(x: float, _z: float) -> float: return rise if x < 0.0 else 0.0
	var park := _stage([_row("shelf", "ground", [-60.0, 0.0], [120.0, 8.0, 120.0], "plateau")])
	var found := PerchPoints.ledges(park, shelf.call(8.0))
	_t.check("an 8 m step has landform tops", found.size() > 3, str(found.size()))
	var ok := not found.is_empty()
	for ledge: Vector4 in found:
		ok = ok and ledge.x < 0.0 and absf(ledge.y - 8.0) < 0.001 and absf(ledge.w) < 0.001 and PerchPoints.valid_ledge(ledge) and ledge.x > -24.0 - PerchPoints.DECK_HALF - 0.001
	_t.check("every top stands 8 m over the base, on the high side, within the last ring of the step", ok)
	_t.eq("ledges() is deterministic", PerchPoints.ledges(park, shelf.call(8.0)), found)
	var sorted := true
	for i in range(1, found.size()):
		sorted = sorted and (found[i - 1].x < found[i].x or (found[i - 1].x == found[i].x and found[i - 1].z <= found[i].z))
	_t.check("landform tops are sorted by x then z", sorted)
	# Planted negatives: the same rows over a 12 m cliff, a 4 m kerb and a 25 degree slope give no perch.
	_t.eq("negative control: a 12 m cliff is no perch", PerchPoints.ledges(_stage([_row("shelf", "ground", [-60.0, 0.0], [120.0, 12.0, 120.0], "plateau")]), shelf.call(12.0)).size(), 0)
	_t.eq("negative control: a 4 m kerb is no perch", PerchPoints.ledges(_stage([_row("shelf", "ground", [-60.0, 0.0], [120.0, 4.0, 120.0], "plateau")]), shelf.call(4.0)).size(), 0)
	var slope := func(x: float, _z: float) -> float: return maxf(0.0, -x * 0.47)
	_t.eq("negative control: a slope is no flat deck", PerchPoints.ledges(park, slope).size(), 0)
	# A route lane through the step keeps its tops off the lane (the ball rolls there).
	var laned := _stage([_row("shelf", "ground", [-60.0, 0.0], [120.0, 8.0, 120.0], "plateau")])
	laned["waymarks"] = ["a", "b"]
	laned["activity_rows"] = [{"id": "a", "at": [-80.0, 0.0]}, {"id": "b", "at": [-10.0, 0.0]}]
	var off_lane := PerchPoints.ledges(laned, shelf.call(8.0))
	var clear := true
	for ledge: Vector4 in off_lane:
		var on_leg := Geometry2D.get_closest_point_to_segment(Vector2(ledge.x, ledge.z), Vector2(-80.0, 0.0), Vector2(-10.0, 0.0))
		clear = clear and Vector2(ledge.x, ledge.z).distance_to(on_leg) > 20.0 + PerchPoints.DECK_CLEAR - 0.001
	_t.check("tops stay off a route lane", clear and off_lane.size() < found.size(), "%d vs %d" % [off_lane.size(), found.size()])
	# A ledge box in band offers its top; one too tall does not.
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var boxes := PerchPoints.ledges(_stage([_row("gatehouse", "ledge", [10.0, 10.0], [12.0, 8.0, 12.0])]), flat)
	_t.eq("an 8 m ledge box offers its top", boxes, [Vector4(10.0, 8.0, 10.0, 0.0)])
	_t.eq("negative control: a 12 m ledge box offers none", PerchPoints.ledges(_stage([_row("gatehouse", "ledge", [10.0, 10.0], [12.0, 12.0, 12.0])]), flat).size(), 0)
	# pick(): a planted good landform top among planted bad ones is the answer.
	var bad_ledges: Array = [Vector4(5.0, 3.0, 0.0, 0.0), Vector4(5.0, 14.0, 0.0, 0.0), Vector4(100.0, 8.0, 0.0, 0.0)]
	_t.eq("planted bad landform tops are all refused", PerchPoints.pick([], Vector3.ZERO, flat, [], 1, bad_ledges), Vector3.INF)
	_t.eq("a planted good landform top among them is returned", PerchPoints.pick([], Vector3.ZERO, flat, [], 1, bad_ledges + [Vector4(25.0, 8.0, 0.0, 0.0)]), Vector3(25.0, 8.0, 0.0))
	_t.check("valid_ledge refuses 3 m and 14 m and accepts 8 m", not PerchPoints.valid_ledge(bad_ledges[0]) and not PerchPoints.valid_ledge(bad_ledges[1]) and PerchPoints.valid_ledge(Vector4(0.0, 18.0, 0.0, 10.0)))


# Per-park coverage on the baked ground of the four stages that had no post perch (and the two that
# had): landform tops exist, each is flat, in band, in the play rect and off lanes and solids; 200
# seeded pack points drawn as the director's ring draws them (tests/support/park_ground.gd) get a
# perch within 40 m at least as often as before, and a park whose tops are emptied gets none.
func _park_coverage() -> void:
	# Floors are the measured counts less a margin (coordinator target 60 percent is not met: see the report).
	# Crown's pack-coverage floor is 20: 36 of 200 on a232338f, 23 on cand/alpha-w17-stack. Cause (measured by
	# reverting only these rows): commit 7f7435c7 (Content, crown greybox stand-ins) moved gauntlet_net
	# [280,175] -> [302.9,142.2], shrank it to [80,19.5,80] and added gauntlet_net_2 plus lane waypoints, so
	# the gauntlet and last_net pack points have no landform top within 40 m; the 66 tops are unchanged.
	# Restore trigger: Dressing's perch anchors on the crown net decks; raise this back to at least 36 in
	# the perch-reader PR once they land.
	var floors := {"dam": [20, 10], "flume": [20, 25], "sinkhole": [6, 1], "islands": [20, 45], "pit": [6, 20], "crown": [6, 20]}
	for id: String in floors:
		var park_map := ParkMap.new("res://src/world/park/park_%s.json" % id)
		var ground := ParkGround.ground("park_%s" % id)
		_t.check("park_%s loads with its baked ground" % id, park_map.ok and ground.is_valid())
		if not park_map.ok or not ground.is_valid():
			continue
		var park := park_map.park
		var posts := PerchPoints.derive(park, ground)
		var ledges := PerchPoints.ledges(park, ground)
		_t.eq("park_%s ledges are deterministic" % id, PerchPoints.ledges(park, ground), ledges)
		_t.check("park_%s has at least %d candidate tops" % [id, floors[id][0]], posts.size() + ledges.size() >= floors[id][0], "%d posts, %d landform" % [posts.size(), ledges.size()])
		var zones := PerchPoints.ledge_zones(park)
		var r: Array = park["play_rect"]
		var play := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var sound := true
		var why := ""
		for ledge: Vector4 in ledges:
			var spread := 0.0
			var lo := INF
			var hi := -INF
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
				var g := float(ground.call(ledge.x + corner.x * PerchPoints.DECK_HALF, ledge.z + corner.y * PerchPoints.DECK_HALF))
				lo = minf(lo, g)
				hi = maxf(hi, g)
			spread = hi - lo
			if not PerchPoints.valid_ledge(ledge) or absf(float(ground.call(ledge.x, ledge.z)) - ledge.y) > 0.001 or spread > PerchPoints.LEVEL_M + 0.001 \
					or not play.has_point(Vector2(ledge.x, ledge.z)) or not PerchPoints.ledge_clear(zones, Vector2(ledge.x, ledge.z)):
				sound = false
				why = str(ledge)
				break
		_t.check("park_%s: every landform top is in band, flat, in the play rect, off lanes and solids" % id, sound, why)
		var blocked := PerchPoints.blockers(park)
		var packs := ParkGround.pack_points(park, 200)
		_t.eq("park_%s draws 200 pack points" % id, packs.size(), 200)
		var before := 0
		var after := 0
		var none := 0
		var valid_picks := true
		var repeatable := true
		for i in packs.size():
			if PerchPoints.pick(posts, packs[i], ground, blocked, i).is_finite():
				before += 1
			var pick := PerchPoints.pick(posts, packs[i], ground, blocked, i, ledges)
			if pick.is_finite():
				after += 1
				repeatable = repeatable and pick == PerchPoints.pick(posts, packs[i], ground, blocked, i, ledges)
				var near_ok := Vector2(pick.x, pick.z).distance_to(Vector2(packs[i].x, packs[i].z)) <= PerchPoints.RANGE_M + 0.001
				var as_post := posts.has(pick) and PerchPoints.valid(pick, ground, blocked)
				var as_ledge := false
				for ledge: Vector4 in ledges:
					as_ledge = as_ledge or (Vector3(ledge.x, ledge.y, ledge.z) == pick and PerchPoints.valid_ledge(ledge))
				valid_picks = valid_picks and near_ok and (as_post or as_ledge)
			# Planted negative: the same park with its tops emptied has no perch.
			if PerchPoints.pick([], packs[i], ground, blocked, i, []).is_finite():
				none += 1
		_t.check("park_%s: the same seed returns the same perch twice" % id, repeatable)
		_t.check("park_%s: every returned perch is within 40 m and passes its band, deck and collider checks" % id, valid_picks)
		_t.eq("park_%s: a park with its tops emptied returns INF for every pack" % id, none, 0)
		_t.check("park_%s: perch within 40 m of %d of 200 packs, at least the %d before" % [id, after, before], after >= before and after >= floors[id][1], "before %d after %d" % [before, after])
		print("perch_points_test: park_%s posts %d landform %d packs with a perch before %d after %d of 200" % [id, posts.size(), ledges.size(), before, after])
