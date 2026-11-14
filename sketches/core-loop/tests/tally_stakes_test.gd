extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Stakes := preload("res://src/world/tally_stakes.gd")

# Tally stakes (BACKLOG W1-103, src/world/tally_stakes.gd).
# (a) rows(): on a long flat line a kept slot is a row of five stakes, one a beat, alternating sides; the same seed
#     gives the same rows and another seed other rows; no row within CLEAR_M of a site, on a ramp's gap or on ground
#     steeper than SLOPE;
# (b) on the real dam and flume, with their real ground, over 40 run seeds: most runs have a row, and the longest
#     stretch of the floor line with no site and no row is printed before and after (the pull request's measure);
# (c) in the real game the flag off builds nothing; on, the stage's rows stand on its ground; a ball through all
#     five knocks them flat and scrap lands ahead; a slow ball knocks nothing.

const SEEDS := 40

var _game
var _t := preload("res://tests/support/t.gd").new("tally_stakes_test")


func _initialize() -> void:
	_pure()
	_run()


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _pure() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(0, 1500)])
	var all := []
	for seed_value in 12:
		all.append(Stakes.rows(line, 9.8, [], [], _flat, seed_value))
	var rows: Array = all[0]
	_t.check("a long flat line holds rows", not rows.is_empty() and rows.size() <= 6, "%d rows" % rows.size())
	var shaped := true
	for row in rows:
		var stakes: Array = row["stakes"]
		shaped = shaped and stakes.size() == Stakes.STAKES
		for i in stakes.size():
			shaped = shaped and is_equal_approx(absf(stakes[i].x), Stakes.SIDE_M)
			if i > 0:
				shaped = shaped and is_equal_approx(stakes[i].z - stakes[i - 1].z, 9.8) and stakes[i].x * stakes[i - 1].x < 0.0
	_t.check("a row is five stakes, one a beat, alternating sides", shaped, str(rows[0]["stakes"]) if not rows.is_empty() else "none")
	_t.check("the same seed gives the same rows", Stakes.rows(line, 9.8, [], [], _flat, 0) == rows, "seed 0 twice")
	_t.check("other seeds give other rows", all.any(func(other): return other != rows), "12 seeds")
	var kept := 0
	for other in all:
		kept += other.size()
	_t.check("about two slots in three stand", kept > 12 * 5 * 0.45 and kept < 12 * 6 * 0.9, "%d rows over 12 seeds of 5 or 6 slots" % kept)
	var site := Vector2(0, 150)
	var clear := true
	for other in all:
		for row in Stakes.rows(line, 9.8, [], [site], _flat, all.find(other)):
			for stake in row["stakes"]:
				clear = clear and Vector2(stake.x, stake.z).distance_to(site) >= Stakes.CLEAR_M - Stakes.SIDE_M
	_t.check("no row stands near a site", clear, "site at 150 m")
	var ramped := true
	for seed_value in 12:
		for row in Stakes.rows(line, 9.8, [[0.0, 1500.0]], [], _flat, seed_value):
			ramped = false
	_t.check("no row stands on a ramp's stretch", ramped, "the whole line a gap")
	var steep := func(_x: float, z: float) -> float: return z * 0.8
	var none := true
	for seed_value in 12:
		none = none and Stakes.rows(line, 9.8, [], [], steep, seed_value).is_empty()
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
			busy = busy or rows.any(func(row: Dictionary) -> bool: return Vector2(row["stakes"][2].x, row["stakes"][2].z).distance_to(p) <= 25.0)
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
	var sites: Array = [map.beacon]
	for site in map.activity_sites + map.rescue_sites + map.survival_sites:
		sites.append(_game.world.tally_stakes._plan(site["at"]))
	var ground := func(x: float, z: float) -> float: return _game.ctx.terrain.height(x, z)
	var before := _longest(trail["points"], sites, [])
	var after := []
	var counts := []
	for seed_value in SEEDS:
		var rows := Stakes.rows(trail["points"], float(trail["spacing_m"]), trail["gaps"], sites, ground, seed_value)
		counts.append(rows.size())
		after.append(_longest(trail["points"], sites, rows))
	after.sort()
	counts.sort()
	print("tally_stakes_test measure %s: rows a run %d to %d, median %d; longest empty stretch of the floor line %.1f s -> median %.1f s, worst %.1f s (%d run seeds, real ground)" % [
		id, counts[0], counts[-1], counts[SEEDS >> 1], before, after[SEEDS >> 1], after[-1], SEEDS])
	_t.check("%s: most runs have a row" % id, counts[SEEDS >> 2] >= 1, "lower quartile %d" % counts[SEEDS >> 2])
	_t.check("%s: the floor line's longest empty stretch is no longer on most runs" % id, after[SEEDS >> 1] <= before, "%.1f s against %.1f s" % [after[SEEDS >> 1], before])


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
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)
	var stakes = _game.world.tally_stakes
	_measure(1)
	_t.check("with the flag off nothing stands", stakes.standing.is_empty() and stakes.get_child_count() == 0, "%d rows" % stakes.standing.size())
	_game.ctx.tuning.set_option("stakes", "on")
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)
	if not _t.check("with the flag on the dam's rows stand", not stakes.standing.is_empty(), "%d rows" % stakes.standing.size()):
		quit(_t.verdict())
		return
	var row: Dictionary = stakes.standing[0]
	var seated := true
	for stake in row["stakes"]:
		var at: Vector3 = stake.global_position
		seated = seated and absf(at.y - _game.ctx.terrain.height(at.x, at.z)) < 0.05
	_t.check("each stake stands on the ground", seated, str(row["stakes"][0].global_position))
	# A slow ball knocks nothing.
	var first: Vector3 = row["stakes"][0].global_position
	_game.player.reset_to(first + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await _frames(3)
	_t.eq("a ball at rest knocks nothing", row["hit"], 0)
	# Through all five at speed.
	var scrap_before: int = _game.ctx.build.scrap.count()
	for i in Stakes.STAKES:
		var at: Vector3 = row["stakes"][i].global_position
		var heading: Vector3 = (row["stakes"][mini(i + 1, Stakes.STAKES - 1)].global_position - row["stakes"][maxi(i - 1, 0)].global_position).normalized()
		_game.player.reset_to(at + Vector3.UP * 1.0, Vector3.ZERO)
		_game.player.set_velocity_now(heading * 14.0)
		await _frames(2)
	_t.eq("a ball through all five knocks all five", row["hit"], Stakes.STAKES)
	_t.check("the set throws scrap ahead", stakes.sets_paid == 1 and _game.ctx.build.scrap.count() >= scrap_before + Stakes.SET_SCRAP - 2, "%d pieces against %d" % [_game.ctx.build.scrap.count(), scrap_before])
	await _frames(30)
	var flat: bool = row["stakes"].all(func(stake: Node3D) -> bool: return stake.global_transform.basis.y.y < 0.3)
	_t.check("the stakes lie flat", flat, "up %.2f" % row["stakes"][0].global_transform.basis.y.y)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	_measure(2)
	_t.check("the next stage stands its own rows", not stakes.standing.is_empty() and not is_instance_valid(row["stakes"][0]) or row["stakes"][0].is_queued_for_deletion(), "%d rows" % stakes.standing.size())
	quit(_t.verdict())
