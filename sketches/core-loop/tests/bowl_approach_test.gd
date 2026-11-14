extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Approach := preload("res://src/world/bowl_approach.gd")
const Posts := preload("res://src/world/survey_posts.gd")

# The approach to the boss's bowl (BACKLOG W1-104, src/world/bowl_approach.gd).
# (a) plan(): on a long flat line the bridge stands at the line's end and three racks behind it, each three crates
#     across the line; all inside the line's last LAST_M; nothing near a site, on a ramp's stretch or on a steep run;
#     no piece over a ledge; the furnace's stand-in keeps it inside a far eye's far plane; pay() rises with heft
#     and is capped;
# (b) in the real game the flag off builds nothing on any stage; on, only the map that names an approach gets one,
#     standing on its ground beside its floor line, off every grapple anchor; survey posts keep off it; a ball at speed bursts a crate and
#     scrap lands ahead, all three pay the cluster, a ball at rest or falling bursts nothing; crossing the plate at
#     speed weighs the ball once and flips the board; the furnace stands where the map says and its smoke is in view from most
#     of the line from the tally fields on (the measure is printed).

const RUN_SEED := 7
const EYE_M := 3.0
const EXPECTED_CHECKS := 39

var _game
var _t := preload("res://tests/support/t.gd").new("bowl_approach_test")


func _initialize() -> void:
	_pure()
	_run()


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _pure() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(0, 1000)])
	var plan: Dictionary = Approach.plan(line, [], [], _flat)
	var bridge: Dictionary = plan["bridge"]
	_t.check("a long flat line has a bridge at its end", not bridge.is_empty() and bridge["at"].z >= 1000.0 - 2.0 * Approach.STEP_M, str(bridge.get("at")))
	_t.eq("and three racks behind it", plan["racks"].size(), Approach.RACKS)
	var shaped := true
	var inside := true
	for rack in plan["racks"]:
		var crates: Array = rack["crates"]
		shaped = shaped and crates.size() == Approach.CRATES and is_equal_approx(crates[1].x, 0.0) \
			and is_equal_approx(absf(crates[0].x), Approach.CRATE_SIDE_M) and crates[0].x * crates[2].x < 0.0 \
			and is_equal_approx(crates[1].z - crates[0].z, Approach.CRATE_STEP_M) and is_equal_approx(absf(rack["rack"].x), Approach.RACK_SIDE_M)
		inside = inside and crates[0].z >= 1000.0 - Approach.LAST_M and crates[2].z < bridge["at"].z
	_t.check("a rack is three crates across the line, a beat apart, the rack beside them", shaped, str(plan["racks"][0]["crates"]) if not plan["racks"].is_empty() else "none")
	_t.check("everything stands on the line's last stretch, behind the bridge", inside, "last %d m" % int(Approach.LAST_M))
	_t.check("the same line plans the same approach", Approach.plan(line, [], [], _flat) == plan, "twice")
	var site := {"at": Vector2(0, 990), "r": 70.0}
	var kept: Dictionary = Approach.plan(line, [], [site], _flat)
	var clear: bool = not kept["bridge"].is_empty() and Vector2(kept["bridge"]["at"].x, kept["bridge"]["at"].z).distance_to(site["at"]) >= 70.0
	for rack in kept["racks"]:
		for crate in rack["crates"]:
			clear = clear and Vector2(crate.x, crate.z).distance_to(site["at"]) >= 70.0
	_t.check("nothing stands near a site", clear, str(kept["bridge"].get("at")))
	var ramped: Dictionary = Approach.plan(line, [[0.0, 1000.0]], [], _flat)
	_t.check("nothing stands on a ramp's stretch", ramped["bridge"].is_empty() and ramped["racks"].is_empty(), "the whole line a gap")
	var steep := func(_x: float, z: float) -> float: return z * 0.8
	var none: Dictionary = Approach.plan(line, [], [], steep)
	_t.check("nothing stands on a steep run", none["bridge"].is_empty() and none["racks"].is_empty(), "0.8 m a metre")
	var tilted := func(x: float, _z: float) -> float: return x * 0.8
	var off: Dictionary = Approach.plan(line, [], [], tilted)
	_t.check("nothing stands on ground that falls away to the side", off["bridge"].is_empty() and off["racks"].is_empty(), "0.8 m a metre across")
	# A 2.2 m ledge across the line: no piece stands over it.
	var ledge := func(_x: float, z: float) -> float: return 2.2 if z >= 950.0 else 0.0
	var stepped: Dictionary = Approach.plan(line, [], [], ledge)
	var over := false
	for rack in stepped["racks"]:
		over = over or (rack["crates"][0].z < 950.0 and rack["crates"][2].z >= 950.0)
	over = over or (not stepped["bridge"].is_empty() and absf(stepped["bridge"]["at"].z - 950.0) <= Approach.PLATE_DEEP_M)
	_t.check("no piece stands over a ledge", not over and stepped["racks"].size() == Approach.RACKS, "%d racks" % stepped["racks"].size())
	# The furnace's stand-in: its own place for a near eye; for a far eye, on the same ray and inside the far plane.
	var home := Vector3(900, 0, 480)
	var near_eye: Transform3D = Approach.stand_in(home, Approach.FURNACE_REACH_M, Vector3(860, 3, 480), 700.0)
	var eye := Vector3(-242, 5, 65)
	var far_eye: Transform3D = Approach.stand_in(home, Approach.FURNACE_REACH_M, eye, 700.0)
	var k := far_eye.basis.get_scale().x
	_t.check("the furnace stands in its own place for a near eye", near_eye.origin.is_equal_approx(home) and is_equal_approx(near_eye.basis.get_scale().x, 1.0), str(near_eye.origin))
	_t.check("for a far eye it is drawn on the same ray, inside the far plane", k < 1.0 and far_eye.origin.distance_to(eye) + Approach.FURNACE_REACH_M * k <= 700.0
		and (far_eye.origin - eye).normalized().is_equal_approx((home - eye).normalized()), "scale %.2f at %.0f m" % [k, far_eye.origin.distance_to(eye)])
	_t.check("the bridge pays more for a heavier ball, to a cap", Approach.pay(1.0) == Approach.WEIGH_SCRAP and Approach.pay(3.0) > Approach.pay(1.0)
		and Approach.pay(500.0) == Approach.WEIGH_SCRAP_MAX, "%d, %d, %d" % [Approach.pay(1.0), Approach.pay(3.0), Approach.pay(500.0)])


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


# The share of the floor line, from the point nearest `from` on, with a clear ray over the ground to `top`.
func _seen(points: PackedVector2Array, from: Vector2, top: Vector3) -> float:
	var terrain = _game.ctx.terrain
	var start := 0
	for i in points.size():
		if points[i].distance_to(from) < points[start].distance_to(from):
			start = i
	var counted := 0
	var clear := 0
	for i in range(start + 1, points.size()):
		var leg := points[i] - points[i - 1]
		for s in maxi(1, int(leg.length() / 10.0)):
			var p := points[i - 1] + leg * (float(s) / maxi(1, int(leg.length() / 10.0)))
			var eye := Vector3(p.x, terrain.height(p.x, p.y) + EYE_M, p.y)
			counted += 1
			var open := true
			var reach := Vector2(top.x - eye.x, top.z - eye.z).length()
			var d := 10.0
			while d < reach and open:
				var at := eye.lerp(top, d / reach)
				if absf(at.x) < 790.0 and absf(at.z) < 790.0 and terrain.height(at.x, at.z) > at.y:
					open = false
				d += 10.0
			clear += int(open)
	return float(clear) / maxi(1, counted)


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
	_game.run.run_seed = RUN_SEED
	var approach = _game.world.bowl_approach
	var terrain = _game.ctx.terrain
	# Flag off: nothing on either stage. The stage whose map names an approach is found, not assumed.
	var named := 0
	var bare := true
	for stage in [1, 2]:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(4)
		bare = bare and approach.get_child_count() == 0 and approach.racks.is_empty() and approach.bridge.is_empty()
		if not terrain.map_for(stage).approach.is_empty():
			named = stage
	_t.check("with the flag off nothing stands on any stage", bare, "%d children" % approach.get_child_count())
	if not _t.check("one stage's map names an approach", named > 0, "stage %d" % named):
		quit(_t.verdict())
		return
	_game.ctx.tuning.set_option("approach", "on")
	var other := 3 - named
	_game.flow.enter_stage(other, Vector3.ZERO, false)
	await _frames(4)
	_t.check("with the flag on a map that names none still gets nothing", approach.get_child_count() == 0, "stage %d" % other)
	_game.flow.enter_stage(named, Vector3.ZERO, false)
	await _frames(4)
	var map = terrain.map_for(named)
	var trail: Dictionary = map.scrap_trail
	var total := 0.0
	for i in range(1, trail["points"].size()):
		total += trail["points"][i].distance_to(trail["points"][i - 1])
	var planned: Dictionary = Approach.plan_for(map, func(x: float, z: float) -> float: return terrain.height(x, z))
	print("bowl_approach_test measure %s: line %.0f m; bridge at %.0f m; racks at %s m (real ground)" % [map.park.map, total,
		float(planned["bridge"].get("along", -1.0)), str(planned["racks"].map(func(r: Dictionary) -> int: return int(r["along"])))])
	if not _t.check("the flume gets its bridge and at least two racks", not approach.bridge.is_empty() and approach.racks.size() >= 2, "%d racks" % approach.racks.size()):
		quit(_t.verdict())
		return
	var clear_of: Array = Posts.keep_clear(map)
	var kept := true
	var seated := true
	for row in approach.racks:
		for crate in row["crates"]:
			var at: Vector3 = crate.global_position
			kept = kept and clear_of.all(func(c: Dictionary) -> bool: return not Posts.near(c, Vector2(at.x, at.z)))
			seated = seated and absf(at.y - terrain.height(at.x, at.z)) < 0.05
	var plate: Vector3 = approach.bridge["at"]
	kept = kept and clear_of.all(func(c: Dictionary) -> bool: return not Posts.near(c, Vector2(plate.x, plate.z)))
	_t.check("nothing stands near a site or inside a fight's ground", kept, "%d places kept clear" % clear_of.size())
	_t.check("every crate sits on the ground", seated, str(approach.racks[0]["crates"][0].global_position))
	var always := 0
	var views: Array = approach.bridge["node"].find_children("*", "MeshInstance3D", true, false)
	for view in views:
		always += 1 if view.visibility_range_begin <= 0.0 else 0
	_t.check("the gantry gives way to an eye under it and only its plate stays", views.size() >= 2 and always == 1, "%d of %d views always drawn" % [always, views.size()])
	_t.check("the bridge is on the line's last stretch", float(planned["bridge"]["along"]) >= total - Approach.LAST_M, "%.0f of %.0f m" % [planned["bridge"]["along"], total])
	# Survey posts keep off the approach: a run seed whose rows would stand on it is found, then played with both
	# flags on, and the rows the game stands are off it.
	var taken: Array = Approach.taken(planned)
	var ground := func(x: float, z: float) -> float: return terrain.height(x, z)
	var on_it := func(rows: Array) -> bool:
		return rows.any(func(row) -> bool:
			return row["posts"].any(func(post) -> bool:
				var at: Vector3 = post if post is Vector3 else post.global_position
				return taken.any(func(c: Dictionary) -> bool: return Vector2(at.x, at.z).distance_to(c["at"]) < float(c["r"]) - Posts.SIDE_M - 0.5)))
	var clash := -1
	for run_seed in 200:
		var rows_seed := hash([_game.ctx.rng.seed, run_seed, named, "survey_posts"])
		if on_it.call(Posts.rows(trail["points"], float(trail["spacing_m"]), trail["gaps"], clear_of, ground, rows_seed)):
			clash = run_seed
			break
	if _t.check("some run seed's survey posts would stand on the approach", clash >= 0, "run seed %d" % clash):
		_game.run.run_seed = clash
		_game.ctx.tuning.set_option("posts", "on")
		_game.flow.enter_stage(named, Vector3.ZERO, false)
		await _frames(4)
		var stood: Array = _game.world.survey_posts.standing
		_t.check("with both on, the posts the game stands keep off it", not stood.is_empty() and not on_it.call(stood), "%d rows" % stood.size())
		_game.ctx.tuning.set_option("posts", "off")
		_game.run.run_seed = RUN_SEED
		_game.flow.enter_stage(named, Vector3.ZERO, false)
		await _frames(4)
	# No grapple anchor post of the map's own fields stands in a piece.
	var recipes = load("res://src/world/park/park_recipes.gd")
	var fields: Dictionary = recipes.field_posts(map.park["park_rows"], recipes.clear_zones(map.park))
	var anchored := 0
	for i in fields:
		for post in fields[i]:
			anchored += int(Vector2(plate.x, plate.z).distance_to(post) < Approach.GANTRY_WIDE_M * 0.5 + 1.0)
			for rack in planned["racks"]:
				for crate in rack["crates"]:
					anchored += int(Vector2(crate.x, crate.z).distance_to(post) < Approach.ANCHOR_CLEAR_M)
	_t.eq("no grapple anchor stands in a piece", anchored, 0)
	# The furnace.
	var smoke: Vector2 = map.approach["smoke"]
	var works: Vector3 = approach.furnace_home()
	_t.check("the furnace stands where the map says", approach.furnace != null and Vector2(works.x, works.z).distance_to(smoke) < 0.1, str(smoke))
	var stacks := _seen(trail["points"], Vector2(-242, 65), works + Vector3.UP * Approach.STACK_M)
	var share := _seen(trail["points"], Vector2(-242, 65), works + Vector3.UP * (Approach.STACK_M + Approach.SMOKE_RISE_M))
	print("bowl_approach_test measure: from the tally fields on, the smoke's top is in view from %.0f%% of the floor line and the stacks' top from %.0f%%" % [share * 100.0, stacks * 100.0])
	_t.check("the smoke is in view from most of the line from the tally fields on", share >= 0.85, "%.2f" % share)
	# A ball at rest, then a falling ball, burst nothing.
	var before: int = approach.get_child_count()
	var row: Dictionary = approach.racks[0]
	var first: Vector3 = row["crates"][0].global_position
	_game.player.reset_to(first + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await _frames(3)
	_t.eq("a ball at rest bursts nothing", row["hit"], 0)
	_game.player.reset_to(first + Vector3.UP * 2.5, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.DOWN * 12.0)
	await physics_frame
	_t.eq("a falling ball bursts nothing", row["hit"], 0)
	# One crate at speed, then the other two.
	var heading := Vector3(planned["racks"][0]["heading"].x, 0.0, planned["racks"][0]["heading"].y)
	var scrap_before: int = _game.ctx.build.scrap.count()
	_game.player.reset_to(first + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(heading * 14.0)
	await _frames(2)
	# Where the piece models are on the stage, the crate breaks into four of them on the hit.
	var pieces: int = approach.get_child_count() - before
	_t.check("a burst crate breaks into its four pieces", pieces == (4 if ResourceLoader.exists(Approach.PIECES % "a") else 0), "%d pieces" % pieces)
	_t.check("a ball at speed bursts one crate and scrap lands ahead", row["hit"] == 1 and approach.clusters_paid == 0
		and _game.ctx.build.scrap.count() >= scrap_before + Approach.CRATE_SCRAP, "%d hit, %d pieces against %d" % [row["hit"], _game.ctx.build.scrap.count(), scrap_before])
	scrap_before = _game.ctx.build.scrap.count()
	for i in [1, 2]:
		_game.player.reset_to(row["crates"][i].global_position + Vector3.UP * 1.0, Vector3.ZERO)
		_game.player.set_velocity_now(heading * 14.0)
		await _frames(2)
	_t.check("all three pay the cluster", row["hit"] == Approach.CRATES and approach.clusters_paid == 1
		and _game.ctx.build.scrap.count() >= scrap_before + Approach.CLUSTER_SCRAP, "%d pieces against %d" % [_game.ctx.build.scrap.count(), scrap_before])
	var gone := false
	for i in 3000:
		await process_frame
		gone = row["crates"].all(func(crate: Node3D) -> bool: return not crate.visible)
		if gone:
			break
	_t.check("the burst crates are gone", gone, "three crates")
	var tidy := false
	var until := Time.get_ticks_msec() + 20000
	while not tidy and Time.get_ticks_msec() < until:
		await process_frame
		tidy = approach.get_child_count() <= before
	_t.check("and their pieces leave nothing behind", tidy, "%d children against %d" % [approach.get_child_count(), before])
	# The weighbridge: a slow crossing weighs nothing; a fast one weighs once.
	var along := Vector3(approach.bridge["heading"].x, 0.0, approach.bridge["heading"].y)
	var board: Label3D = approach.bridge["board"]
	_game.player.reset_to(plate - along * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(along * 2.0)
	await _frames(2)
	_game.player.reset_to(plate + along * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(along * 2.0)
	await _frames(2)
	_t.check("a slow ball is not weighed", not approach.bridge["weighed"] and board.text == "0", board.text)
	scrap_before = _game.ctx.build.scrap.count()
	_game.player.reset_to(plate - along * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(along * 14.0)
	await _frames(2)
	_game.player.reset_to(plate + along * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(along * 14.0)
	await _frames(2)
	_t.check("a ball over the plate at speed is weighed and the board shows its heft", approach.bridge["weighed"]
		and board.text == str(roundi(_game.player.heft())) and approach.weighed > 0.0, "board %s, heft %.1f" % [board.text, _game.player.heft()])
	_t.check("and scrap lands ahead", _game.ctx.build.scrap.count() >= scrap_before + Approach.pay(approach.weighed) - 1, "%d pieces against %d" % [_game.ctx.build.scrap.count(), scrap_before])
	scrap_before = _game.ctx.build.scrap.count()
	_game.player.reset_to(plate - along * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
	_game.player.set_velocity_now(along * 14.0)
	await _frames(2)
	_game.player.reset_to(plate + along * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
	await _frames(2)
	_t.check("a second crossing pays nothing", _game.ctx.build.scrap.count() <= scrap_before, "%d pieces against %d" % [_game.ctx.build.scrap.count(), scrap_before])
	# Leaving the stage clears it.
	_game.flow.enter_stage(other, Vector3.ZERO, false)
	await _frames(4)
	_t.check("the next stage clears it", approach.racks.is_empty() and approach.bridge.is_empty() and approach.furnace == null, "%d racks" % approach.racks.size())
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())
