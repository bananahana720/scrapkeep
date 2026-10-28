# smoke: solo timeout=360s
extends SceneTree

const T := preload("res://tests/support/t.gd")
const Affixes := preload("res://src/combat/elite_affixes.gd")
const Director := preload("res://src/world/director.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Roster := preload("res://src/combat/roster.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Brute := preload("res://src/combat/plated_brute.gd")
const SPAWNS := 50
const TICK := 1.0 / 90.0
const EDGE_STEP := 0.05
const EXPECTED_GEOMETRY := {
	"stamp": {"shape": Telegraph.Shape.RING, "radius": 2.8, "reach": 2.2},
	"rail": {"shape": Telegraph.Shape.LANE, "length": 14.0, "width": 2.4, "reach": 2.2},
	"rearblast": {"shape": Telegraph.Shape.RING, "radius": 4.0, "offset": 5.0, "reach": 2.2},
}
# Independent oracle for the stat changed by each affix.
const EXPECTED := {
	"stamp": ["walk_speed", [3.8, 4.4, 5.0], 5.0, "target_stamp", "Target-stamp Fast Plated Brute"],
	"rail": ["rest_seconds", [2.4, 2.1, 1.8], 2.4, "rail_strike", "Rail-strike Quick-rest Plated Brute"],
	"rearblast": ["slam_shove", [11.0, 13.0, 15.0], 15.0, "rear_blast", "Rear-blast Heavy-shove Plated Brute"],
}
var t := T.new("elite_affix_test")
var game
var ball_at := Vector3.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_records()
	_schedules()
	await _boot()
	_stats()
	await _rear_above()
	if not OS.get_cmdline_user_args().has("--records-only"):
		for id in EXPECTED:
			for world in range(1, 4):
				await _solo(id, world)
	game.free()
	quit(t.verdict())

func _records() -> void:
	t.eq("exactly three affixes", Affixes.ROWS.size(), 3)
	t.check("tier-0 row unchanged", not RunTier.row(0).has("elite_stats"))
	t.eq("hard flat elite stat row", RunTier.row(1).get("elite_stats"), {"plating": 30.0})
	var tags := []
	var behaviours := []
	for id in EXPECTED:
		var row: Dictionary = Affixes.row(id)
		var want: Array = EXPECTED[id]
		t.eq("one-behaviour-one-stat " + id, row.stats.keys(), [want[0]])
		t.eq("behaviour " + id, row.behaviour, want[3])
		t.eq("stat id " + id, row.stat, want[0])
		t.eq("three published values " + id, row.stats[want[0]], want[1])
		t.eq("cap " + id, row.cap, want[2])
		var values: Array = row.stats[want[0]]
		t.check("monotone below cap " + id, values.size() == 3 and values.max() <= row.cap and
			((values[0] < values[1] and values[1] < values[2]) or (values[0] > values[1] and values[1] > values[2])))
		t.check("0.4 s lead " + id, float(row.warn_seconds) >= 0.4)
		t.eq("name lists behaviour and stat " + id, row.name, want[4])
		t.eq("registered tag " + id, Roster.AFFIX_TAGS.get(row.behaviour), row.mechanic_tag)
		t.check("baked tell recipe " + id, SfxBank.has_recipe(row.mechanic_tag))
		t.check("unique added behaviour " + id, not row.behaviour in behaviours and not Roster.mechanic_owners().has(row.behaviour))
		t.check("unique mechanic tag " + id, not row.mechanic_tag in tags and Roster.ROWS.values().all(
			func(r: Dictionary): return r.get("tag", "") != row.mechanic_tag))
		tags.append(row.mechanic_tag)
		behaviours.append(row.behaviour)
		print("AFFIX %s %s" % [id, JSON.stringify(row)])

func _schedules() -> void:
	for mode in ["interval", "credit"]:
		for tier_value in [0, 1]:
			_pack_affixes(mode, tier_value)
			var d := Director.new(71)
			d.mode = mode
			d.set_run_tier_reader(func(): return tier_value)
			d.authored = [{"id": "ordinary", "kinds": ["plated_brute", "winch_drone"]}]
			d.elite = {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
			d.elite_arrival = 3
			var seen := []
			var drones := 0
			for step in 1800:
				for arrival in d.advance(0.5, 0):
					if arrival.has("affix"):
						t.eq("affix bearer " + mode, Director.KIND_NAMES[arrival.kind], "plated_brute")
						seen.append(arrival.affix)
					if Director.KIND_NAMES[arrival.kind] == "winch_drone":
						t.check("scheduled partner drone remains unmarked " + mode, not arrival.has("affix"))
						drones += 1
			if tier_value == 0:
				t.eq("tier-0 no arrival affix " + mode, seen, [])
			else:
				t.check("all three rotate in director " + mode, seen.size() >= 3 and seen.slice(0, 3) == ["stamp", "rail", "rearblast"], str(seen))
			t.check("scheduled partner drones exist " + mode, drones > 0)

func _pack_affixes(mode: String, tier_value: int) -> void:
	var d := Director.new(71)
	d.mode = mode
	d.set_run_tier_reader(func(): return tier_value)
	var expected_affixes := ["stamp", "rail", "rearblast"]
	for serial in expected_affixes.size():
		for is_elite in [false, true]:
			var label := "%s tier %d pack %d %s" % [mode, tier_value, serial, "elite" if is_elite else "ordinary"]
			var start := d.arrivals.size()
			t.eq("pack has both arrivals " + label,
				d._place_pack(Vector2(20.0, 0.0), ["plated_brute", "winch_drone"], Vector2.ZERO, is_elite), 2)
			var brutes := 0
			var drones := 0
			for arrival in d.arrivals.slice(start):
				t.eq("arrival belongs to expected pack " + label, arrival.pack, serial * 2 + int(is_elite))
				match Director.KIND_NAMES[arrival.kind]:
					"plated_brute":
						brutes += 1
						if not is_elite:
							t.check("ordinary plated_brute remains unmarked " + label, not arrival.has("affix"))
						elif tier_value == 0:
							t.check("tier-0 elite plated_brute remains unmarked " + label, not arrival.has("affix"))
						else:
							t.eq("elite plated_brute expected affix " + label, arrival.get("affix", ""), expected_affixes[serial])
					"winch_drone":
						drones += 1
						t.check("pack winch_drone remains unmarked " + label, not arrival.has("affix"))
			t.eq("ordinary or elite plated_brute exists " + label, brutes, 1)
			t.eq("ordinary or elite winch_drone exists " + label, drones, 1)

func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.ctx.profile = Profile.new("user://elite_affix_test/unused.json")
	game.ctx.profile.can_save = false
	game.ctx.profile.earn("first_win", 1.0)
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_s: float): pass
	for node in [game.presentation, game.hud, game.screens, game.notes, game.panel, game.camera, game.world,
		game.build, game.boss, game.beacon, game.run_log, game.codex, game.progress]:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	_clear()
	ball_at = game.ctx.terrain.drop_point(game.ctx.terrain.spawn_point(1).x, game.ctx.terrain.spawn_point(1).z, 1.05)
	Engine.physics_ticks_per_second = 720
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = 8.0
	await physics_frame
	t.near("real physics tick 1/90 s", root.get_physics_process_delta_time(), TICK, 0.000001)

func _clear() -> void:
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_nodes_in_group(group):
			node.free()

func _spawn(id: String):
	game.player.reset_to(ball_at)
	return game.combat.spawn_enemy("plated_brute", game.ctx.terrain.drop_point(ball_at.x + 3.0, ball_at.z, 1.8), id)

func _stats() -> void:
	var d = game.world.director
	for tier_value in [0, 1]:
		game.run.run_tier = tier_value
		for world in range(1, 4):
			d.world = world
			var base = _spawn("")
			for id in EXPECTED:
				var enemy = _spawn(id)
				var want: Array = EXPECTED[id]
				var changed := []
				for key in ["walk_speed", "rest_seconds", "slam_shove", "plates", "weight", "max_hp"]:
					if enemy.get(key) != base.get(key):
						changed.append(key)
				t.eq("one-behaviour-one-stat runtime %s tier %d world %d" % [id, tier_value, world], changed, [want[0]] if tier_value == 1 else [])
				t.eq("flat plating hard elite only", enemy.plating, 30.0 if tier_value == 1 else base.plating)
				t.eq("metadata gate", enemy.has_meta("elite_affix"), tier_value == 1)
				if tier_value == 1:
					t.eq("published value delivered", enemy.get(want[0]), want[1][world - 1])
					t.eq("name delivered", enemy.get_meta("enemy_name"), want[4])
				enemy.free()
			base.free()
		var drone = game.combat.spawn_enemy("winch_drone", ball_at, "stamp")
		t.check("partner never carries affix", not drone.has_meta("elite_affix"))
		drone.free()
	game.run.run_tier = 1

func _rear_above() -> void:
	var enemy = _spawn("rearblast")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.rotation.y = PI * 0.5
	enemy._warn(Vector3.ZERO)
	var tele = enemy.telegraph()
	var delta := Vector2(tele.center.x - enemy.global_position.x, tele.center.z - enemy.global_position.z)
	t.near("rear blast stays 5 m behind with the ball directly above", delta.x, -5.0)
	t.near("rear blast follows the brute's facing", delta.y, 0.0)
	await process_frame
	await process_frame
	enemy.free()


func _solo(id: String, world: int) -> void:
	game.world.director.world = world
	var shortest := INF
	var misses := 0
	var hits := 0
	var unchanged := 0
	var boundary_misses := 0
	var nearby_hits := 0
	for spawn_index in SPAWNS:
		_clear()
		var enemy = _spawn(id)
		enemy.rotation.y = float(spawn_index % 4) * PI * 0.5
		enemy._rest = 0.0
		var sample := {}
		enemy.attack_phase.connect(func(fact: Dictionary):
			if fact.phase == "windup" and enemy._affix_attack:
				sample["target"] = enemy.target.ball_position()
				sample["origin"] = enemy.global_position
				sample["facing"] = enemy.global_basis.z)
		var damage := []
		enemy.hit_player.connect(func(amount: float, shove: Vector3): damage.append([amount, shove]))
		var start := -1
		var tele = null
		var descriptor := {}
		var onset := false
		for frame in 360:
			if start < 0 and enemy.phase == enemy.Phase.ROAM:
				var aim: Vector3 = enemy.target.ball_position() - enemy.global_position
				aim.y = 0.0
				sample["aim"] = aim.normalized()
			await physics_frame
			if start < 0 and enemy.phase == enemy.Phase.WARN:
				start = Engine.get_physics_frames()
				tele = enemy.telegraph()
				descriptor = tele.descriptor()
				t.eq("added tell tag", tele.mechanic_tag, Affixes.row(id).mechanic_tag)
				t.eq("added tell type", tele.type, Affixes.row(id).telegraph)
				_geometry(id, tele, sample)
				# Leave the original target while the committed warning runs.
				game.player.reset_to(ball_at + Vector3.RIGHT * 60.0)
			if start >= 0 and enemy.phase == enemy.Phase.LIVE:
				enemy.process_mode = Node.PROCESS_MODE_DISABLED
				onset = true
				shortest = minf(shortest, float(Engine.get_physics_frames() - start) * TICK)
				var current: Dictionary = tele.descriptor()
				current.progress = descriptor.progress
				current.live = descriptor.live
				if current == descriptor and enemy.telegraph() == tele:
					unchanged += 1
				if damage.is_empty():
					misses += 1
				var inside: Vector3 = tele.center
				if tele.shape == Telegraph.Shape.LANE:
					inside += tele.dir * tele.length * 0.5
				inside.y = Telegraph.ground_under(game.combat.ground, inside) + 1.05
				game.player.reset_to(inside)
				game.player._rigid.global_position = inside
				enemy._go_live()
				if damage.size() == 1 and damage[0][0] == Affixes.row(id).damage and tele.contains(inside):
					hits += 1
				var probes := _boundaries(id, world, spawn_index, enemy, tele, damage)
				boundary_misses += probes[0]
				nearby_hits += probes[1]
				break
		t.check("solo attack happened " + id, onset)
		# The next attack remains the original slam.
		enemy._end()
		enemy._warn(Vector3.LEFT * 3.0)
		t.check("original slam retained", not enemy._affix_attack and enemy.telegraph().radius == Brute.SLAM_RADIUS)
		await process_frame
		await process_frame
		enemy.free()
	t.check("0.4 s lead measured %s world %d" % [id, world], shortest >= 0.4 and is_finite(shortest), str(shortest))
	t.eq("outside committed shape cannot hit", misses, SPAWNS)
	t.eq("inside committed shape delivers damage", hits, SPAWNS)
	t.eq("committed shape never retargets", unchanged, SPAWNS)
	var probes_per_spawn := 6 if id == "stamp" else 5
	t.eq("all boundary misses %s world %d" % [id, world], boundary_misses, SPAWNS * probes_per_spawn)
	t.eq("all nearby positive hits %s world %d" % [id, world], nearby_hits, SPAWNS * probes_per_spawn)
	print("SOLO affix=%s world=%d spawns=%d min_lead=%.6f outside_misses=%d inside_hits=%d same_geometry=%d boundary_misses=%d nearby_hits=%d" % [id, world, SPAWNS, shortest, misses, hits, unchanged, boundary_misses, nearby_hits])


func _geometry(id: String, tele, sample: Dictionary) -> void:
	var row: Dictionary = Affixes.row(id)
	var want: Dictionary = EXPECTED_GEOMETRY[id]
	t.eq("committed shape " + id, tele.shape, want.shape)
	for key in ["radius", "length", "width", "reach", "offset"]:
		if not want.has(key):
			continue
		t.near("published geometry %s %s" % [id, key], row[key], want[key])
		if key != "offset":
			t.near("committed geometry %s %s" % [id, key], tele.get("reach_up" if key == "reach" else key), want[key])
	var centre: Vector3 = sample.target if id == "stamp" else sample.origin
	if id == "rearblast":
		centre -= sample.facing * want.offset
	centre.y = game.combat.ground.height_at(centre)
	t.near("committed centre x " + id, tele.center.x, centre.x)
	t.near("committed centre y " + id, tele.center.y, centre.y)
	t.near("committed centre z " + id, tele.center.z, centre.z)
	if id == "rail":
		t.near("sampled lane heading x", tele.dir.x, sample.aim.x)
		t.near("sampled lane heading z", tele.dir.z, sample.aim.z)


func _boundaries(id: String, world: int, spawn_index: int, enemy, tele, damage: Array) -> Array:
	var pairs := []
	var inside: Vector3 = tele.center
	if tele.shape == Telegraph.Shape.RING:
		for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			pairs.append(["ring " + str(dir), tele.center + dir * (tele.radius + EDGE_STEP),
				tele.center + dir * (tele.radius - EDGE_STEP)])
		if id == "stamp":
			var toward: Vector3 = enemy.global_position - tele.center
			toward.y = 0.0
			toward = toward.normalized()
			var beyond: Vector3 = tele.center + toward * (tele.radius + EDGE_STEP)
			var from_brute := Vector2(beyond.x - enemy.global_position.x, beyond.z - enemy.global_position.z)
			t.check("stamp boundary probe inside original slam", from_brute.length() < Brute.SLAM_RADIUS)
			pairs.append(["stamp outside ring inside original slam", beyond,
				tele.center + toward * (tele.radius - EDGE_STEP)])
	else:
		var side: Vector3 = tele.dir.cross(Vector3.UP)
		inside += tele.dir * tele.length * 0.5
		for sign_value in [-1.0, 1.0]:
			pairs.append(["lane side " + str(sign_value), inside + side * sign_value * (tele.width * 0.5 + EDGE_STEP),
				inside + side * sign_value * (tele.width * 0.5 - EDGE_STEP)])
		pairs.append(["lane back end", tele.center - tele.dir * EDGE_STEP, tele.center + tele.dir * EDGE_STEP])
		pairs.append(["lane front end", tele.center + tele.dir * (tele.length + EDGE_STEP),
			tele.center + tele.dir * (tele.length - EDGE_STEP)])
	for pair in pairs:
		for index in [1, 2]:
			var point: Vector3 = pair[index]
			point.y = game.combat.ground.height_at(point) + 1.05
			pair[index] = point
	var ground: float = game.combat.ground.height_at(inside)
	pairs.append(["above reach_up", Vector3(inside.x, ground + tele.reach_up + EDGE_STEP, inside.z),
		Vector3(inside.x, ground + tele.reach_up - EDGE_STEP, inside.z)])
	var misses := 0
	var hits := 0
	for pair in pairs:
		var label := "%s world %d spawn %d %s" % [id, world, spawn_index, pair[0]]
		var outside: Vector3 = pair[1]
		var nearby: Vector3 = pair[2]
		t.check("negative probe outside tele.contains " + label, not tele.contains(outside))
		game.player.reset_to(outside)
		game.player._rigid.global_position = outside
		var before := damage.size()
		enemy._go_live()
		if t.eq("boundary no damage " + label, damage.size(), before):
			misses += 1
		t.check("nearby positive inside tele.contains " + label, tele.contains(nearby))
		game.player.reset_to(nearby)
		game.player._rigid.global_position = nearby
		before = damage.size()
		enemy._go_live()
		if t.check("nearby positive damage " + label, damage.size() == before + 1 and damage[before][0] == 10.0):
			hits += 1
	return [misses, hits]
