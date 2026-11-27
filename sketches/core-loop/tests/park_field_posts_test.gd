extends SceneTree
# Overlapping anchor fields (clip audit, 30 Oct; park_recipes.gd field_posts): two fields authored over the same ground
# planted two posts in one spot (dam hoodoo_5 and hoodoo_9 at (-489, 449), a saguaro grown through a hoodoo, the
# colliders merged). field_posts keeps an earlier field's posts and drops a later field's post within
# ANCHOR_POST_M of one.
# (a) per park, no two kept posts stand closer than ANCHOR_POST_M, of different fields or of one (anchor_posts drops a
#     lane-edge post on a kept post: flume hollow_trestles drew two at (-187, -147));
# (b) every dropped post has a kept post within ANCHOR_POST_M, so the ground it covered stays covered;
# (c) a field's own posts are untouched: its kept posts are anchor_posts' own, in order, and every one-post field (an
#     authored anchor such as crown tarn_west_gap_anchor) keeps its post, but for sinkhole cannon_tube_fill_45, authored
#     on the very spot of cannon_tube_post_2o;
# (d) the dam drops posts (its pairs exist: the positive control), and the drops are pinned per park;
# (e) the perch tops are the kept posts: every PerchPoints.derive top stands on one.
# Evidence limit: placement data only; the look is the clip audit's stills.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const PerchPoints := preload("res://src/world/perch_points.gd")
const T := preload("res://tests/support/t.gd")

const PARKS := ["dam", "flume", "pit", "sinkhole", "islands", "crown"]
# Posts dropped per park at the head that added field_posts (counted by this test, printed below).
const DROPPED := {"dam": 517, "flume": 0, "pit": 0, "sinkhole": 1, "islands": 33, "crown": 598}
# One-post fields that lose their post: sinkhole cannon_tube_fill_45 and cannon_tube_post_2o share (-24.5, -298.0).
const LOST_SINGLE := {"sinkhole": 1}

var _t := T.new("park_field_posts_test")


func _initialize() -> void:
	call_deferred("_run")


func _park(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_%s.json" % name))


func _run() -> void:
	var gap := ParkRecipes.ANCHOR_POST_M
	for name: String in PARKS:
		var park := _park(name)
		var rows := ParkRecipes.placed_rows(park)
		var zones := ParkRecipes.clear_zones(park)
		var kept := ParkRecipes.field_posts(rows, zones)
		var points := PackedVector2Array()
		var dropped := PackedVector2Array()
		var own_ok := true
		var lost_single := 0
		for i in rows.size():
			if not ParkRecipes.is_anchor_field(rows[i]):
				continue
			var all := ParkRecipes.anchor_posts(rows[i], zones)
			var mine: PackedVector2Array = kept.get(i, PackedVector2Array())
			# Kept posts are a subsequence of the field's own posts.
			var k := 0
			for p in all:
				if k < mine.size() and mine[k] == p:
					k += 1
				else:
					dropped.append(p)
			own_ok = own_ok and k == mine.size()
			lost_single += 1 if all.size() == 1 and mine.is_empty() else 0
			for p in mine:
				points.append(p)
		var close := 0
		for a in points.size():
			for b in range(a + 1, points.size()):
				if points[a].distance_to(points[b]) < gap:
					close += 1
		_t.check("(a) %s: no two kept posts within %.0f m (%d posts)" % [name, gap, points.size()], close == 0, "%d pairs" % close)
		var lonely := 0
		for p in dropped:
			var near := false
			for q in points:
				if q.distance_to(p) < gap:
					near = true
					break
			lonely += 0 if near else 1
		_t.check("(b) %s: every dropped post has a kept post within %.0f m (%d dropped)" % [name, gap, dropped.size()], lonely == 0, "%d alone" % lonely)
		_t.check("(c) %s: kept posts are each field's own, in order" % name, own_ok)
		_t.eq("(c) %s: one-post fields that lose their post (only to another one-post field on the same spot)" % name, lost_single, int(LOST_SINGLE.get(name, 0)))
		print("park_field_posts_test: %s keeps %d posts, drops %d" % [name, points.size(), dropped.size()])
		_t.eq("(d) %s posts dropped" % name, dropped.size(), int(DROPPED[name]))
		if name == "dam":
			_t.check("(d) the dam's overlapping fields drop posts (the positive control)", dropped.size() > 0)
			var flat := func(_x: float, _z: float) -> float: return 0.0
			var tops := PerchPoints.derive(park, flat)
			var stray := 0
			for top: Vector3 in tops:
				var on_kept := false
				for q in points:
					if Vector2(top.x, top.z).distance_to(q) < 0.01:
						on_kept = true
						break
				stray += 0 if on_kept else 1
			_t.check("(e) dam perch tops stand on kept posts only (%d tops, %d kept posts)" % [tops.size(), points.size()], stray == 0 and tops.size() <= points.size(), "%d tops off the kept posts" % stray)
	quit(_t.verdict())
