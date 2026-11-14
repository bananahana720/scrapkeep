extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Posts := preload("res://src/world/survey_posts.gd")

# Survey posts (BACKLOG W1-103, src/world/survey_posts.gd).
# (a) rows(): on a long flat line a kept slot is a row of five posts, one a beat, alternating sides; the same seed
#     gives the same rows and another seed other rows; no row within CLEAR_M of a site, on a ramp's gap or on ground
#     steeper than SLOPE;
# (b) on the real dam and flume, with their real ground, over 40 run seeds: most runs have a row, and the longest
#     stretch of the floor line with no site and no row is printed before and after (the pull request's measure);
# (c) in the real game the flag off builds nothing; on, the stage's rows stand on its ground; a ball through all
#     five knocks them flat and scrap lands ahead; a slow ball knocks nothing.

const SEEDS := 40
const RUN_SEED := 7

var _game
var _t := preload("res://tests/support/t.gd").new("survey_posts_test")


func _initialize() -> void:
	_pure()
	_run()


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _pure() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(0, 1500)])
	var all := []
	for seed_value in 12:
		all.append(Posts.rows(line, 9.8, [], [], _flat, seed_value))
	var rows: Array = all[0]
	_t.check("a long flat line holds rows", not rows.is_empty() and rows.size() <= 6, "%d rows" % rows.size())
	var shaped := true
	for row in rows:
		var posts: Array = row["posts"]
		shaped = shaped and posts.size() == Posts.POSTS
		for i in posts.size():
			shaped = shaped and is_equal_approx(absf(posts[i].x), Posts.SIDE_M)
			if i > 0:
				shaped = shaped and is_equal_approx(posts[i].z - posts[i - 1].z, 9.8) and posts[i].x * posts[i - 1].x < 0.0
	_t.check("a row is five posts, one a beat, alternating sides", shaped, str(rows[0]["posts"]) if not rows.is_empty() else "none")
	_t.check("the same seed gives the same rows", Posts.rows(line, 9.8, [], [], _flat, 0) == rows, "seed 0 twice")
	_t.check("other seeds give other rows", all.any(func(other): return other != rows), "12 seeds")
	var kept := 0
	for other in all:
		kept += other.size()
	_t.check("about two slots in three stand", kept > 12 * 5 * 0.45 and kept < 12 * 5 * 0.9, "%d rows over 12 seeds of 5 or 6 slots" % kept)
	var site := Vector2(0, 150)
	var clear := true
	for other in all:
		for row in Posts.rows(line, 9.8, [], [{"at": site, "r": Posts.CLEAR_M}], _flat, all.find(other)):
			for post in row["posts"]:
				clear = clear and Vector2(post.x, post.z).distance_to(site) >= Posts.CLEAR_M - Posts.SIDE_M
	_t.check("no row stands near a site", clear, "site at 150 m")
	var ramped := true
	for seed_value in 12:
		for row in Posts.rows(line, 9.8, [[0.0, 1500.0]], [], _flat, seed_value):
			ramped = false
	_t.check("no row stands on a ramp's stretch", ramped, "the whole line a gap")
	var steep := func(_x: float, z: float) -> float: return z * 0.8
	var none := true
	for seed_value in 12:
		none = none and Posts.rows(line, 9.8, [], [], steep, seed_value).is_empty()
	_t.check("no row stands on a steep run", none, "0.8 m a metre")


# The longest stretch of the floor line, in seconds at 20 m/s, with no site within 60 m and no row on it.
func _longest(points: PackedVector2Array, sites: Array, rows: Array) -> float:
	var marks := [0.0]
	var along := 0.0
	var free_from := 0.0
	var longest := 0.0
	for i in range(1, points.size()):
		var leg := points[i] - points[i - 1]
		var steps := maxi(1, int(leg.length() / 5.0))
		for s in steps:
			var p := points[i - 1] + leg * (float(s) / steps)
			var d := along + leg.length() * s / steps
			var busy: bool = sites.any(func(at: Vector2) -> bool: return at.distance_to(p) <= 60.0)
			busy = busy or rows.any(func(row: Dictionary) -> bool: return Vector2(row["posts"][2].x, row["posts"][2].z).distance_to(p) <= 25.0)
			if busy:
				longest = maxf(longest, d - free_from)
				free_from = d
		along += leg.length()
	return maxf(longest, along - free_from) / 20.0


# Over SEEDS run seeds on the stage now loaded, with its real ground: every run's rows, and what they do to the
# floor line's longest empty stretch. Prints the measure for the pull request.
func _measure(stage: int) -> void:
	var map = _game.ctx.terrain.map_for(stage)
	var id: String = map.park.map
	var trail: Dictionary = map.scrap_trail
	if not _t.check("%s has a floor line" % id, not trail.is_empty(), id):
		return
	var clear: Array = Posts.keep_clear(map)
	# The measure counts what scripts/poi-census.mjs counts as a site: the beacon and the activity, rescue and
	# survival rows, which are keep_clear()'s plain rings of CLEAR_M.
	var sites: Array = clear.filter(func(c: Dictionary) -> bool: return not c.has("half") and c["r"] == Posts.CLEAR_M).map(func(c: Dictionary) -> Vector2: return c["at"])
	var ground := func(x: float, z: float) -> float: return _game.ctx.terrain.height(x, z)
	var before := _longest(trail["points"], sites, [])
	var after := []
	var counts := []
	for seed_value in SEEDS:
		var rows := Posts.rows(trail["points"], float(trail["spacing_m"]), trail["gaps"], clear, ground, seed_value)
		counts.append(rows.size())
		after.append(_longest(trail["points"], sites, rows))
	after.sort()
	counts.sort()
	print("survey_posts_test measure %s: rows a run %d to %d, median %d; longest empty stretch of the floor line %.1f s -> median %.1f s, worst %.1f s (%d run seeds, real ground)" % [
		id, counts[0], counts[-1], counts[SEEDS >> 1], before, after[SEEDS >> 1], after[-1], SEEDS])
	_t.check("%s: most runs have a row" % id, counts[SEEDS >> 2] >= 1, "lower quartile %d" % counts[SEEDS >> 2])
	var kept := true
	for seed_value in SEEDS:
		for row in Posts.rows(trail["points"], float(trail["spacing_m"]), trail["gaps"], clear, ground, seed_value):
			for post in row["posts"]:
				var on_line := Vector2(post.x, post.z)
				kept = kept and clear.all(func(c: Dictionary) -> bool: return not Posts.near(c.merged({"r": float(c["r"]) - Posts.SIDE_M - 0.5}, true), on_line))
	_t.check("%s: no post stands near a site or inside a fight's ground" % id, kept, "%d places kept clear" % clear.size())


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = 23
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	# A run seed of the test's own (a test run's is the clock's), picked so both stages keep a slot.
	_game.run.run_seed = RUN_SEED
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)
	var posts = _game.world.survey_posts
	_measure(1)
	_t.check("with the flag off nothing stands", posts.standing.is_empty() and posts.get_child_count() == 0, "%d rows" % posts.standing.size())
	_game.ctx.tuning.set_option("posts", "on")
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)
	if not _t.check("with the flag on the dam's rows stand", not posts.standing.is_empty(), "%d rows" % posts.standing.size()):
		quit(_t.verdict())
		return
	var row: Dictionary = posts.standing[0]
	var trail: Dictionary = _game.ctx.terrain.scrap_trail(1)
	var beside := true
	for post in row["posts"]:
		var at := Vector2(post.global_position.x, post.global_position.z)
		var nearest := INF
		for i in range(1, trail["points"].size()):
			nearest = minf(nearest, at.distance_to(Geometry2D.get_closest_point_to_segment(at, trail["points"][i - 1], trail["points"][i])))
		beside = beside and absf(nearest - Posts.SIDE_M) < 0.2
	_t.check("each post stands a step beside the floor line", beside, str(row["posts"][0].global_position))
	# A ball falling straight down beside a post knocks nothing either.
	_game.player.reset_to(row["posts"][0].global_position + Vector3.UP * 2.5, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.DOWN * 12.0)
	await physics_frame
	_t.eq("a falling ball knocks nothing", row["hit"], 0)
	# A slow ball knocks nothing.
	var first: Vector3 = row["posts"][0].global_position
	_game.player.reset_to(first + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await _frames(3)
	_t.eq("a ball at rest knocks nothing", row["hit"], 0)
	# Through all five at speed.
	var scrap_before: int = _game.ctx.build.scrap.count()
	for i in Posts.POSTS:
		var at: Vector3 = row["posts"][i].global_position
		var heading: Vector3 = (row["posts"][mini(i + 1, Posts.POSTS - 1)].global_position - row["posts"][maxi(i - 1, 0)].global_position).normalized()
		_game.player.reset_to(at + Vector3.UP * 1.0, Vector3.ZERO)
		_game.player.set_velocity_now(heading * 14.0)
		await _frames(2)
	_t.eq("a ball through all five knocks all five", row["hit"], Posts.POSTS)
	_t.check("the set throws scrap ahead", posts.sets_paid == 1 and _game.ctx.build.scrap.count() >= scrap_before + Posts.SET_SCRAP - 2, "%d pieces against %d" % [_game.ctx.build.scrap.count(), scrap_before])
	# The fall is an idle-time tween: step drawn frames until it has run (or a generous count has passed).
	var flat := false
	for i in 3000:
		await process_frame
		flat = row["posts"].all(func(post: Node3D) -> bool: return post.global_transform.basis.y.y < 0.3)
		if flat:
			break
	_t.check("the posts lie flat", flat, "up %.2f" % row["posts"][0].global_transform.basis.y.y)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	_measure(2)
	_t.check("the next stage stands its own rows", not posts.standing.is_empty() and not is_instance_valid(row["posts"][0]) or row["posts"][0].is_queued_for_deletion(), "%d rows" % posts.standing.size())
	quit(_t.verdict())
