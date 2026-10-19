extends SceneTree

const AmbientHomes := preload("res://src/presentation/ambient_homes.gd")
const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const AmbientPool := preload("res://src/presentation/ambient_pool.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

# Ambient life's pure pool (ambient_pool.gd): the cap while the player sweeps every park, flee
# direction, the three combat reactions, the boss lock, the calm return, the hush under a telegraph
# and determinism. No nodes and no GLBs: the pool is logic only.

const SEED := 20261019
const DT := 0.1
const FAR := Vector3(100.0, 0.0, 0.0)

var _t := T.new("ambient_pool_test")


func _initialize() -> void:
	_main()


func _main() -> void:
	await process_frame
	_run()
	quit(_t.verdict())


func _ground(x: float, z: float) -> float:
	return sin(x * 0.05) * 2.0 + cos(z * 0.04)


func _input(player: Vector3, threats := [], telegraphs := [], boss := false, reduced := false) -> Dictionary:
	return {"player": player, "threats": threats, "telegraphs": telegraphs, "boss": boss, "reduced": reduced, "ground": _ground}


func _home(kind: String, at := Vector2.ZERO, count := 1) -> Dictionary:
	var offsets: Array[Vector2] = []
	for i in count:
		offsets.append(Vector2(float(i) * 1.5, 0.0))
	return {"kind": kind, "at": at, "perch": AmbientKinds.row(kind)["homes"]["perch"], "group": 0, "members": offsets}


func _pool(homes: Array, seed_number := SEED) -> AmbientPool:
	var pool := AmbientPool.new()
	pool.setup(homes, seed_number)
	return pool


func _run_for(pool: AmbientPool, seconds: float, input: Dictionary) -> void:
	for i in int(seconds / DT + 0.5):
		pool.step(DT, input)


func _run() -> void:
	_cap()
	_flee()
	_react()
	_boss()
	_return()
	_hush()
	_reduced()
	_determinism()


# Cap: all six parks, every kind, a player sweeping the play rect; and a crowd of 60 on the player.
func _cap() -> void:
	for map_id in ParkSchema.MAP_STAGE:
		if map_id == "park_test":
			continue
		var park: Dictionary = ParkSchema.load_park("res://src/world/park/%s.json" % map_id)["data"]
		var homes := AmbientHomes.plan(park, AmbientKinds.for_park(map_id), SEED)
		var rect: Array = park["play_rect"]
		for reduced in [false, true]:
			var pool := _pool(homes)
			var peak := 0
			var peak_drawn := 0
			var steps := 900
			for i in steps:
				var f := float(i) / float(steps)
				var player := Vector3(lerpf(float(rect[0]), float(rect[0]) + float(rect[2]), f), 0.0, float(rect[1]) + float(rect[3]) * (0.5 + 0.45 * sin(f * TAU * 3.0)))
				pool.step(DT, _input(player, [], [], false, reduced))
				peak = maxi(peak, pool.live_count())
				peak_drawn = maxi(peak_drawn, pool.drawn().size())
			var limit := 12 if reduced else 24
			_t.check("%s cap reduced=%s live %d drawn %d" % [map_id, reduced, peak, peak_drawn], peak <= limit and peak_drawn <= peak and peak > 0)
	for reduced in [false, true]:
		var crowd := []
		for i in 20:
			crowd.append(_home("dusk_quail", Vector2(float(i), 3.0), 3))
		var pool := _pool(crowd)
		_run_for(pool, 5.0, _input(Vector3.ZERO, [], [], false, reduced))
		var limit := 12 if reduced else 24
		_t.eq("crowd of 60 holds the cap reduced=%s" % reduced, pool.live_count(), limit)


func _flee() -> void:
	for kind in ["dusk_quail", "pit_burro", "puddle_toad", "dam_swift"]:
		var row: Dictionary = AmbientKinds.row(kind)
		var pool := _pool([_home(kind)])
		_run_for(pool, 3.0, _input(FAR))
		var m: AmbientPool.Member = pool.members[0]
		var player := Vector3(float(row["flee_m"]) * 0.6, 0.0, 0.0)
		var before := Vector2(m.pos.x, m.pos.z).distance_to(Vector2(player.x, player.z))
		var toward := 0
		var fleeing := 0
		for i in 10:
			pool.step(DT, _input(player))
			if m.state == "flee":
				fleeing += 1
				var to_ball := Vector2(player.x - m.pos.x, player.z - m.pos.z)
				if Vector2(m.vel.x, m.vel.z).dot(to_ball) > 0.0:
					toward += 1
		var after := Vector2(m.pos.x, m.pos.z).distance_to(Vector2(player.x, player.z))
		_t.check("%s flees: %.1f -> %.1f m, %d flee steps, %d toward" % [kind, before, after, fleeing, toward], after > before and toward == 0 and fleeing > 0)
	# A ground kind stops at 2.5 leashes and hides.
	var toad := _pool([_home("puddle_toad")])
	_run_for(toad, 3.0, _input(FAR))
	var leash := float(AmbientKinds.row("puddle_toad")["wander_m"]) * 2.5
	var worst := 0.0
	for i in 400:
		var m: AmbientPool.Member = toad.members[0]
		toad.step(DT, _input(Vector3(m.pos.x - 3.0, 0.0, m.pos.z)))
		worst = maxf(worst, m.home.distance_to(Vector2(m.pos.x, m.pos.z)))
	_t.check("puddle_toad never passes 2.5 leashes (%.1f of %.1f m)" % [worst, leash], worst <= leash + 1.0 and toad.members[0].state != "flee")
	# A local has no flee speed: the ball beside it moves nothing.
	var keeper := _pool([_home("weir_keeper")])
	_run_for(keeper, 3.0, _input(FAR))
	var spot := Vector2(keeper.members[0].pos.x, keeper.members[0].pos.z)
	_run_for(keeper, 2.0, _input(Vector3(2.0, 0.0, 0.0)))
	_t.check("weir_keeper stays put with the ball beside it", spot.distance_to(Vector2(keeper.members[0].pos.x, keeper.members[0].pos.z)) < 0.01)


func _react() -> void:
	var threat := [Vector3(18.0, 0.0, 0.0)]
	var swift := _pool([_home("dam_swift")])
	_run_for(swift, 3.0, _input(Vector3(0.0, 0.0, 100.0)))
	var m: AmbientPool.Member = swift.members[0]
	var rest := m.pos.y - _ground(m.pos.x, m.pos.z)
	var sound := false
	var peak := 0.0
	for i in 40:
		swift.step(DT, _input(Vector3(0.0, 0.0, 100.0), threat))
		sound = sound or m.wants_react_sound
		peak = maxf(peak, m.pos.y - _ground(m.pos.x, m.pos.z))
	_t.check("scatter kind gains height %.1f -> %.1f m and is still seen" % [rest, peak], peak - rest >= 11.0 and m.fade > 0.9 and m.state == "react")
	_t.check("scatter wants one react sound", sound)
	# A row of swifts never wheels in unison: once circling, no two share a radius and a turn rate.
	var row := _pool([_home("dam_swift", Vector2.ZERO, 4)])
	_run_for(row, 3.0, _input(Vector3(0.0, 0.0, 100.0)))
	_run_for(row, 6.0, _input(Vector3(0.0, 0.0, 100.0), threat))
	var orbits := {}
	for member: AmbientPool.Member in row.members:
		if member.orbit != Vector3.ZERO:
			orbits["%.3f/%.3f" % [member.orbit_r, member.orbit_rate]] = true
	_t.check("a scattered row of 4 circles on 4 different orbits (%d)" % orbits.size(), orbits.size() == 4)
	var quail := _pool([_home("dusk_quail")])
	_run_for(quail, 3.0, _input(Vector3(0.0, 0.0, 100.0)))
	_run_for(quail, 4.0, _input(Vector3(0.0, 0.0, 100.0), threat))
	_t.check("hide kind is hidden", quail.members[0].state == "hidden" and quail.members[0].fade <= 0.001 and quail.drawn().is_empty())
	var keeper := _pool([_home("weir_keeper")])
	_run_for(keeper, 3.0, _input(Vector3(0.0, 0.0, 100.0)))
	var spot := Vector2(keeper.members[0].pos.x, keeper.members[0].pos.z)
	_run_for(keeper, 3.0, _input(Vector3(0.0, 0.0, 100.0), threat))
	var after := Vector2(keeper.members[0].pos.x, keeper.members[0].pos.z)
	_t.check("duck kind stays put and hides", spot.distance_to(after) < 0.01 and keeper.members[0].state == "hidden" and keeper.drawn().is_empty())
	# A hide run never heads at the ball, even with the threat beyond the member (the run from it points at the ball).
	for kind in ["dusk_quail", "puddle_toad"]:
		var runner := _pool([_home(kind)])
		_run_for(runner, 3.0, _input(Vector3(0.0, 0.0, 100.0)))
		var r: AmbientPool.Member = runner.members[0]
		var ball := r.pos + Vector3(-14.0, 0.0, 0.0)
		var start := Vector2(r.pos.x, r.pos.z).distance_to(Vector2(ball.x, ball.z))
		var toward := 0
		var moved := 0
		for i in 15:
			runner.step(DT, _input(ball, [r.pos + Vector3(8.0, 0.0, 0.0)]))
			if Vector2(r.vel.x, r.vel.z).length() > 0.01:
				moved += 1
				if Vector2(r.vel.x, r.vel.z).dot(Vector2(ball.x - r.pos.x, ball.z - r.pos.z)) > 0.0:
					toward += 1
		var end := Vector2(r.pos.x, r.pos.z).distance_to(Vector2(ball.x, ball.z))
		_t.check("%s hides away from the ball with the threat beyond it: %.1f -> %.1f m, %d moving steps, %d toward" % [kind, start, end, moved, toward],
			moved > 0 and toward == 0 and end > start)
	# A threat beyond COMBAT_M changes nothing.
	var calm := _pool([_home("dusk_quail")])
	_run_for(calm, 3.0, _input(Vector3(0.0, 0.0, 100.0)))
	_run_for(calm, 2.0, _input(Vector3(0.0, 0.0, 100.0), [Vector3(AmbientKinds.COMBAT_M + 5.0, 0.0, 0.0)]))
	_t.check("a threat past COMBAT_M is ignored", calm.members[0].state != "react" and calm.members[0].state != "hidden")


func _boss() -> void:
	var pool := _pool([_home("dusk_quail", Vector2.ZERO, 3), _home("dam_swift", Vector2(10.0, 0.0), 3)])
	_run_for(pool, 3.0, _input(Vector3(0.0, 0.0, 30.0)))
	_t.check("boss: members are drawn first", pool.drawn().size() == 6)
	var seconds := 0.0
	while not pool.drawn().is_empty() and seconds < 2.0:
		pool.step(DT, _input(Vector3(0.0, 0.0, 30.0), [], [], true))
		seconds += DT
	_t.check("boss hides all in %.1f s" % seconds, pool.drawn().is_empty() and seconds <= 0.5 + DT)
	_run_for(pool, 20.0, _input(Vector3(0.0, 0.0, 30.0)))
	_t.check("boss over, no reset: still hidden", pool.drawn().is_empty())
	pool.reset()
	_run_for(pool, 3.0, _input(Vector3(0.0, 0.0, 30.0)))
	_t.check("reset brings them back", pool.drawn().size() == 6)


func _return() -> void:
	var pool := _pool([_home("dusk_quail")])
	var away := Vector3(0.0, 0.0, 100.0)
	_run_for(pool, 3.0, _input(away))
	_run_for(pool, 4.0, _input(away, [Vector3(15.0, 0.0, 0.0)]))
	var m: AmbientPool.Member = pool.members[0]
	_t.check("hidden before the calm", m.state == "hidden")
	var calm := 0.0
	while m.state == "hidden" and calm < 15.0:
		pool.step(DT, _input(away))
		calm += DT
	_t.check("calm returns it after %.1f s (6-10)" % calm, calm >= 6.0 - DT and calm <= 10.0 + DT * 2.0)
	_run_for(pool, 2.0, _input(away))
	_t.check("and it is back, seen at home", m.fade > 0.95 and m.state != "hidden" and m.state != "react")
	# A scatter kind flies home.
	var swift := _pool([_home("dam_swift")])
	_run_for(swift, 3.0, _input(away))
	_run_for(swift, 3.0, _input(away, [Vector3(15.0, 0.0, 0.0)]))
	_run_for(swift, 24.0, _input(away))
	var s: AmbientPool.Member = swift.members[0]
	var gap := Vector2(s.pos.x, s.pos.z).distance_to(s.spot)
	_t.check("scatter kind re-perched (%.1f m from home, %s)" % [gap, s.state], (s.state == "perch" or s.state == "sleep") and gap < 6.0)


func _hush() -> void:
	var pool := _pool([_home("dusk_quail", Vector2.ZERO, 3), _home("dam_swift", Vector2(6.0, 0.0), 3)])
	var near := [Vector3(30.0, 0.0, 0.0)]
	var heard := 0
	for i in 600:
		pool.step(DT, _input(Vector3(0.0, 0.0, 100.0), [], [Vector3(0.0, 0.0, 100.0 - AmbientKinds.HUSH_M + 1.0)]))
		for m in pool.members:
			heard += int(m.wants_call) + int(m.wants_react_sound)
	_t.eq("no call while a telegraph is within HUSH_M", heard, 0)
	var calls := 0
	for i in 400:
		pool.step(DT, _input(Vector3(0.0, 0.0, 100.0), [], [Vector3(0.0, 0.0, 100.0 - AmbientKinds.HUSH_M - 5.0)]))
		for m in pool.members:
			calls += int(m.wants_call)
	_t.check("calls resume once it is gone (%d)" % calls, calls > 0)
	# Reaction sound: once per kind per 2 s, none while hushed.
	var crowd := _pool([_home("dusk_quail", Vector2.ZERO, 5)])
	_run_for(crowd, 3.0, _input(FAR))
	var sounds := 0
	for i in 15:
		crowd.step(DT, _input(FAR, near))
		for m in crowd.members:
			sounds += int(m.wants_react_sound)
	_t.eq("five reacting quail sound once", sounds, 1)
	var hushed := _pool([_home("dusk_quail", Vector2.ZERO, 2)])
	_run_for(hushed, 3.0, _input(FAR))
	var quiet := 0
	for i in 15:
		hushed.step(DT, _input(FAR, near, [Vector3(100.0, 0.0, 10.0)]))
		for m in hushed.members:
			quiet += int(m.wants_react_sound) + int(m.wants_call)
	_t.eq("react sound is hushed too", quiet, 0)


func _reduced() -> void:
	var pool := _pool([_home("dam_swift"), _home("dusk_quail", Vector2(5.0, 0.0)), _home("weir_keeper", Vector2(9.0, 0.0))])
	_run_for(pool, 3.0, _input(Vector3(0.0, 0.0, 100.0), [], [], false, true))
	var speeds_ok := true
	for m in pool.members:
		speeds_ok = speeds_ok and (absf(m.loop_speed - 0.6) < 0.001 or m.state == "sleep")
	_t.check("reduced: loop speed 0.6", speeds_ok)
	var spots := pool.members.map(func(m): return m.pos)
	var peak := 0.0
	for i in 8:
		pool.step(DT, _input(Vector3(0.0, 0.0, 100.0), [Vector3(15.0, 0.0, 0.0)], [], false, true))
		for k in pool.members.size():
			peak = maxf(peak, pool.members[k].pos.distance_to(spots[k]))
	_t.check("reduced: react fades in place in 0.4 s, no arc (moved %.2f m)" % peak, peak < 0.6 and pool.drawn().is_empty())


func _determinism() -> void:
	var park: Dictionary = ParkSchema.load_park("res://src/world/park/park_pit.json")["data"]
	var homes := AmbientHomes.plan(park, AmbientKinds.for_park("park_pit"), SEED)
	var logs := []
	for run in 2:
		var pool := _pool(homes)
		var log := ""
		for i in 400:
			var f := float(i) / 400.0
			var a: Vector2 = homes[0]["at"]
			var b: Vector2 = homes[homes.size() - 1]["at"]
			var player := Vector3(lerpf(a.x, b.x, f), 0.0, lerpf(a.y, b.y, f))
			var threats := [player + Vector3(12.0, 0.0, 0.0)] if i % 80 > 60 else []
			pool.step(DT, _input(player, threats))
			if i % 20 == 0:
				for m in pool.drawn():
					log += "%d %s %s %.3f|" % [m.id, m.state, m.pos, m.fade]
		logs.append(log)
	_t.check("same seed, same life (%d chars)" % logs[0].length(), logs[0] == logs[1] and logs[0].length() > 0)
