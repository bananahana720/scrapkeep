extends SceneTree

# The Highdraft roster's rules (design-v3/WORLD-ROSTERS.md) on the real stage 5 greybox: islands
# over the net deck at 10 m. The spawn island is (0, 120), radius 18, top 28; the middle island
# (0, 40), radius 16, top 26; the vault island (70, 40), radius 14, top 30, with open air between
# the middle and vault islands. Ring-out throws use PR #43's ram knock, the same call a ram makes.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Contact := preload("res://src/movement/contact.gd")
const Augments := preload("res://src/movement/augments.gd")
const Roster := preload("res://src/combat/roster.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const SPAWN_TOP := 28.0
const CRUISE := 14.0
const BLAZING := 27.0

var game
var t := T.new("highdraft_roster_test")
var deaths := {}


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	game.flow.enter_stage(5, Vector3.ZERO, false)
	await _frames(3)
	_clear()
	_park_ball(Vector3(0.0, 0.0, 128.0))


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _ground(x: float, z: float) -> float:
	return game.ctx.terrain.height(x, z)


# The ball's position reads back after the next physics frame; callers that spawn next await one.
func _park_ball(at: Vector3) -> void:
	game.player.reset_to(Vector3(at.x, _ground(at.x, at.z) + 1.05, at.z))
	game.player.set_velocity_now(Vector3.ZERO)


# World sets the director's heft class from the run every tick, so a test grows the run: mass
# enough for `heft` (class 3 starts at 2.2) on top of the parts already held.
func _grow(heft: float) -> void:
	var run = game.run
	run.mass = maxf(0.0, (heft - 1.0 - run.HEFT_PER_PART * run.parts.size()) / run.HEFT_PER_MASS)
	game.ctx.root.get_node("World").director.heft_class = run.heft_class()


func _spawn(kind: String, at: Vector3):
	var p := Vector3(at.x, _ground(at.x, at.z) + 1.2, at.z)
	var unit = game.combat.spawn_enemy(kind, p)
	var id: int = unit.get_instance_id()
	unit.died.connect(func(_where: Vector3, _scrap: int): deaths[id] = unit.last_damage_source)
	return unit


func _ram(unit, dir: Vector3, speed: float, heft: float) -> void:
	unit.knock(dir + Vector3.UP * 0.35, Contact.ram_knock(Augments.RAM_KNOCK, speed, heft))


func _until_dead(unit, frames: int) -> bool:
	var id: int = unit.get_instance_id() if is_instance_valid(unit) else 0
	for frame in frames:
		await physics_frame
		if deaths.has(id):
			return true
	return deaths.has(id)


func _post(unit, frames := 240) -> bool:
	for frame in frames:
		await physics_frame
		if unit.posted:
			return true
	return unit.posted


func _run() -> void:
	await _boot()
	_check_rows()
	_check_placement()
	await _ballast()
	await _ballast_grown()
	await _gap_net()
	await _kite()
	await _cutter()
	game.free()
	quit(t.verdict())


# The director stands a ballast heavy on a rim's post near its pack spot, and leaves a spot with
# no rim in reach (the open gap far from any island) alone.
func _check_placement() -> void:
	var director = game.ctx.root.get_node("World").director
	var spot: Vector2 = director.rim_spot(Vector2(-5.0, 120.0), Vector2(0.0, 60.0))
	var from_centre := spot.distance_to(Vector2(0.0, 120.0))
	t.check("HD-1 the director posts a ballast heavy on the island rim", from_centre > 12.0 and from_centre < 18.0
		and absf(_ground(spot.x, spot.y) - SPAWN_TOP) < 0.5, "spot %s, %.1f m from the island centre" % [spot, from_centre])
	var open := Vector2(-140.0, 140.0)
	t.check("HD-2 no rim in reach keeps the spot", director.rim_spot(open, Vector2.ZERO) == open, str(director.rim_spot(open, Vector2.ZERO)))


func _check_rows() -> void:
	for kind in ["ballast_heavy", "gap_net", "kite_drone", "line_cutter"]:
		t.check("HD-0 %s built with a grown remix" % kind, Roster.built(kind) and String(Roster.row(kind).get("grown", "")) != "",
			"built %s, grown '%s'" % [Roster.built(kind), Roster.row(kind).get("grown", "")])
	for table in [AlphaDefs, ParkDefs]:
		for stage in [5, 6]:
			var row: Dictionary = table.of(stage)
			var kinds := []
			for pack in row["packs"]:
				kinds.append_array(pack["kinds"])
			t.check("HD-0 stage %d packs drop the anchor crew (%s)" % [stage, table.resource_path.get_file()],
				not kinds.has("anchor_crew") and kinds.has("ballast_heavy") and kinds.has("gap_net"), str(kinds))
			t.check("HD-0 stage %d elite is the Highdraft's (%s)" % [stage, table.resource_path.get_file()],
				row["elite"]["kinds"] == ["ballast_heavy", "kite_drone", "kite_drone"], str(row["elite"]))
		t.check("HD-0 Spillway elite unchanged (%s)" % table.resource_path.get_file(), table.of(1)["elite"]["kinds"] == ["plated_brute", "winch_drone"])


func _ballast() -> void:
	_grow(1.0)
	var heavy = _spawn("ballast_heavy", Vector3(-10.0, 0.0, 120.0))
	heavy._rest = 99.0
	var posted: bool = await _post(heavy)
	var rim_dir: Vector3 = heavy.rim.get("dir", Vector3.ZERO)
	t.check("BH-1 walks to the west rim and posts up", posted and not heavy.beached and rim_dir.x < -0.9 and heavy.global_position.x < -12.0,
		"posted %s, beached %s, rim dir %s, at %s" % [posted, heavy.beached, rim_dir, heavy.global_position])

	var hp_before: float = heavy.hp
	var removed: float = heavy.take_damage(500.0)
	t.check("BH-2 damage barely touches it", absf(removed - 50.0) < 0.01 and not heavy.is_dead() and heavy.max_hp >= 900.0,
		"removed %.2f of 500, hp %.1f -> %.1f, max %.1f" % [removed, hp_before, heavy.hp, heavy.max_hp])

	# Planted, a small ball rebounds off it (contact.gd), so the ram lands only the rebound shove.
	var small_rebounds: bool = Contact.rebounds(heavy.PLANT_WEIGHT, 1.0, false)
	var start: Vector3 = heavy.global_position
	heavy.knock(rim_dir + Vector3.UP * 0.2, 6.0)
	await _frames(90)
	var moved := Vector2(heavy.global_position.x - start.x, heavy.global_position.z - start.z).length()
	t.check("BH-3 planted: a small ball rebounds and barely moves it", small_rebounds and moved < 1.0 and not heavy.is_dead(),
		"rebounds %s, moved %.2f m" % [small_rebounds, moved])

	# Braced: weight drops, a cruise ram from heft 1 throws it over the rim; that is the kill.
	heavy._warn(heavy._flat_to_ball())
	await physics_frame
	var braced_weight: float = heavy.weight
	var heavy_id: int = heavy.get_instance_id()
	_ram(heavy, rim_dir, CRUISE, 1.0)
	var rung: bool = await _until_dead(heavy, 180)
	t.check("BH-4 cruise ram in the brace rings it out", braced_weight < 1.0 and rung and deaths.get(heavy_id, "") == "ring_out"
		and game.combat.discovered.has("ring_out"),
		"weight in brace %.2f, dead %s by '%s', codex ring_out %s" % [braced_weight, rung, deaths.get(heavy_id, ""), game.combat.discovered.has("ring_out")])

	# A grown ball (heft 2.2, class 3) rams through a planted heavy from close to the rim.
	heavy = _spawn("ballast_heavy", Vector3(-10.0, 0.0, 120.0))
	heavy._rest = 99.0
	await _post(heavy)
	var grown_rams: bool = not Contact.rebounds(heavy.PLANT_WEIGHT, 2.2, false)
	_ram(heavy, heavy.rim["dir"], BLAZING, 2.2)
	rung = await _until_dead(heavy, 180)
	t.check("BH-5 a grown blazing ram rings out a planted heavy", grown_rams and rung,
		"ram lands %s, rung out %s" % [grown_rams, rung])

	# The slam shoves a ball inside its ring outward.
	heavy = _spawn("ballast_heavy", Vector3(-10.0, 0.0, 120.0))
	heavy._rest = 99.0
	await _post(heavy)
	var at: Vector3 = heavy.global_position - (heavy.rim["dir"] as Vector3) * 3.0
	_park_ball(at)
	game.combat.last_player_hit = {}
	heavy._rest = 0.0
	for frame in 180:
		game.player.reset_to(Vector3(at.x, _ground(at.x, at.z) + 1.05, at.z))
		await physics_frame
		if heavy.slams > 0:
			break
	var hit: Dictionary = game.combat.last_player_hit
	var shove: Vector3 = hit.get("shove", Vector3.ZERO)
	var away: Vector3 = game.player.ball_position() - heavy.global_position
	t.check("BH-6 the slam hits and shoves the ball away from the heavy", heavy.slams == 1 and hit.get("source", "") == "ballast_heavy"
		and Vector2(shove.x, shove.z).dot(Vector2(away.x, away.z)) > 0.0,
		"slams %d, hit %s" % [heavy.slams, hit])
	heavy.free()

	# On the net deck there is no rim to ring it over: it beaches and takes damage in full.
	var deck = _spawn("ballast_heavy", Vector3(40.0, 0.0, 110.0))
	await _frames(5)
	var full: float = deck.take_damage(30.0)
	t.check("BH-7 a heavy on the net deck beaches and is killable", deck.beached and deck.max_hp <= 140.0 * 1.5 and absf(full - 30.0) < 0.01,
		"beached %s, max hp %.1f, removed %.1f of 30" % [deck.beached, deck.max_hp, full])
	deck.free()

	# The real contact: a ball rolled at cruise into a braced heavy, through player_ball's ram.
	heavy = _spawn("ballast_heavy", Vector3(-10.0, 0.0, 120.0))
	heavy._rest = 99.0
	await _post(heavy)
	heavy_id = heavy.get_instance_id()
	var out: Vector3 = heavy.rim["dir"]
	var from: Vector3 = heavy.global_position - out * 5.0
	game.player.reset_to(Vector3(from.x, _ground(from.x, from.z) + 1.05, from.z), out * 17.0)
	heavy._warn(heavy._flat_to_ball())
	rung = await _until_dead(heavy, 150)
	t.check("BH-12 a real cruise ram into the brace rings it out", rung and deaths.get(heavy_id, "") == "ring_out",
		"rung %s by '%s'" % [rung, deaths.get(heavy_id, "")])
	_park_ball(Vector3(0.0, 0.0, 128.0))


func _ballast_grown() -> void:
	_grow(2.3)
	var heavy = _spawn("ballast_heavy", Vector3(-10.0, 0.0, 120.0))
	heavy._rest = 99.0
	await _post(heavy)
	await physics_frame
	t.check("BH-8 grown: it stakes a cable behind it, toward the island", is_instance_valid(heavy.stake)
		and heavy.stake.global_position.x > heavy.global_position.x, "stake %s" % [heavy.stake])
	var post: Vector3 = heavy.global_position
	_ram(heavy, heavy.rim["dir"], BLAZING, 2.2)
	await _frames(120)
	t.check("BH-9 grown: the cable reels it back from one ring-out and snaps", not heavy.is_dead() and heavy.reeled == 1
		and not is_instance_valid(heavy.stake) and heavy.global_position.distance_to(post) < 3.0,
		"dead %s, reeled %d, stake %s, %.2f m from its post" % [heavy.is_dead(), heavy.reeled, heavy.stake, heavy.global_position.distance_to(post)])
	await _post(heavy)
	_ram(heavy, heavy.rim["dir"], BLAZING, 2.2)
	var rung: bool = await _until_dead(heavy, 180)
	t.check("BH-10 grown: the second ring-out finishes it", rung)

	heavy = _spawn("ballast_heavy", Vector3(-10.0, 0.0, 120.0))
	heavy._rest = 99.0
	await _post(heavy)
	await physics_frame
	var stake_at: Vector3 = heavy.stake.global_position if is_instance_valid(heavy.stake) else Vector3.INF
	if stake_at != Vector3.INF:
		_park_ball(stake_at)
	await _frames(3)
	t.check("BH-11 grown: rolling over the stake cuts the cable", stake_at != Vector3.INF and not is_instance_valid(heavy.stake))
	heavy.free()
	_grow(1.0)
	_park_ball(Vector3(0.0, 0.0, 128.0))


func _gap_net() -> void:
	_grow(1.0)
	var net = _spawn("gap_net", Vector3(12.0, 0.0, 40.0))
	await _frames(2)
	t.check("GN-1 strings across the gap to the vault island", net.nets.size() == 1 and net.post_b != Vector3.INF
		and net.gap_length > 20.0 and net.gap_length < 50.0 and (net.nets[0]["normal"] as Vector3).x > 0.9,
		"nets %d, far post %s, gap %.1f m" % [net.nets.size(), net.post_b, net.gap_length])
	net.set_physics_process(false)
	var n: Dictionary = net.nets[0]
	# Four metres above rim height, inside the band: a barge works this gap and may pass under it.
	var c: Vector3 = (n["center"] as Vector3) + Vector3.UP * 4.0
	var normal: Vector3 = n["normal"]

	# Slow airborne crossing: slung back the way it came.
	net.phase = net.Phase.LIVE
	game.player.reset_to(c - normal * 1.0, normal * 12.0)
	await physics_frame
	net.nets[0]["last"] = net._side_of(net.nets[0], c - normal * 1.0)
	game.player.reset_to(c + normal * 0.3, normal * 12.0)
	await _frames(2)
	net._live(0.0)
	await physics_frame
	var v: Vector3 = game.player.state.velocity
	t.check("GN-2 a slow crossing is slung back the way it came", net.slung == 1 and v.dot(normal) < -5.0 and net.nets[0]["live"]
		and game.combat.discovered.has("gap_sling"),
		"slung %d, velocity %s (normal part %.2f)" % [net.slung, v, v.dot(normal)])

	# A grounded ball under the band passes, and a fast airborne crossing rips it.
	game.player.reset_to(c - normal * 1.0, normal * 26.0)
	await physics_frame
	net.nets[0]["last"] = net._side_of(net.nets[0], c - normal * 1.0)
	game.player.reset_to(c + normal * 0.3, normal * 26.0)
	await _frames(2)
	net.phase = net.Phase.LIVE
	var id: int = net.get_instance_id()
	net._live(0.0)
	await physics_frame
	t.check("GN-3 a crossing at tear speed rips the net and kills it", deaths.get(id, "") == "tear", "death '%s'" % deaths.get(id, ""))

	# The post stands on a rim: knocked off it, the net is down.
	net = _spawn("gap_net", Vector3(12.0, 0.0, 40.0))
	await _frames(2)
	id = net.get_instance_id()
	net.knock((net.nets[0]["normal"] as Vector3) + Vector3.UP * 0.3, 30.0)
	var down: bool = await _until_dead(net, 180)
	t.check("GN-4 a post knocked off its rim drops the net", down and deaths.get(id, "") == "ring_out", "death '%s'" % deaths.get(id, ""))

	_grow(2.3)
	net = _spawn("gap_net", Vector3(12.0, 0.0, 40.0))
	await _frames(2)
	t.check("GN-5 grown: two nets on a long gap", net.nets.size() == 2, "nets %d over %.1f m" % [net.nets.size(), net.gap_length])
	net.free()
	_grow(1.0)
	_park_ball(Vector3(0.0, 0.0, 128.0))


func _kite() -> void:
	# thermal_a stands at (-40, 60) between the spawn and west islands.
	_park_ball(Vector3(-20.0, 0.0, 52.0))
	await _frames(2)
	var kite = _spawn("kite_drone", Vector3(-30.0, 0.0, 58.0))
	kite.hp = kite.HP * 1.3
	kite._rest = 99.0
	await _frames(240)
	var flat: float = Vector2(kite.global_position.x + 40.0, kite.global_position.z - 60.0).length()
	t.check("KD-6 rides the nearest thermal at a fixed height", kite.riding == "thermal" and flat <= kite.CIRCLE + 2.0
		and absf(kite.global_position.y - kite.ride_y) < 1.5,
		"riding '%s', %.2f m from the column, y %.2f vs ride %.2f" % [kite.riding, flat, kite.global_position.y, kite.ride_y])
	var ride_y: float = kite.ride_y
	_park_ball(Vector3(-20.0, 0.0, 30.0))
	await _frames(30)
	t.check("KD-7 the ride height does not follow the ball", absf(kite.ride_y - ride_y) < 4.0, "ride %.2f -> %.2f" % [ride_y, kite.ride_y])

	# An airborne ball rising into it kills it outright.
	var id: int = kite.get_instance_id()
	game.player.reset_to(kite.global_position + Vector3(0.0, -1.5, 0.0), Vector3(0.0, 8.0, 0.0))
	await physics_frame
	await physics_frame
	t.check("KD-8 an air ram at the top kills it outright", deaths.get(id, "") == "air_ram", "death '%s'" % deaths.get(id, ""))

	# Well clear of class 3's 2.2, so speed wear over the ride cannot drop it a class.
	_grow(2.6)
	_park_ball(Vector3(-10.0, 0.0, 120.0))
	await _frames(2)
	kite = _spawn("kite_drone", Vector3(-12.0, 0.0, 116.0))
	kite._rest = 99.0
	await _frames(150)
	t.check("KD-9 grown: it circles over the gap instead", kite.riding == "gap"
		and _ground(kite.ride_at.x, kite.ride_at.z) < SPAWN_TOP - 6.0, "riding '%s' at %s" % [kite.riding, kite.ride_at])
	id = kite.get_instance_id()
	game.player.reset_to(kite.global_position + Vector3(0.0, -1.5, 0.0), Vector3(6.0, 2.0, 0.0))
	# Gravity alone leaves vy near zero after 6 frames; the drop kick takes it well below.
	await _frames(6)
	var vy: float = game.player.state.velocity.y
	t.check("KD-10 grown: the air-ram kill drops the ball", deaths.get(id, "") == "air_ram" and vy < -3.0, "death '%s', vy %.2f" % [deaths.get(id, ""), vy])
	_grow(1.0)
	_clear()
	_park_ball(Vector3(0.0, 0.0, 128.0))


func _cutter() -> void:
	var cutter = _spawn("line_cutter", Vector3(10.0, 0.0, 124.0))
	cutter.hp = 100000.0
	cutter.set_physics_process(false)
	var kit = game.player.kit
	# Over solid ground the cut only grazes.
	_park_ball(Vector3(0.0, 0.0, 128.0))
	await physics_frame
	kit.hooked = true
	cutter._commit_ring(cutter.Threat.Type.PROJECTILE, game.player.ball_position(), cutter.RING_RADIUS, cutter.RING_REACH)
	cutter.phase = cutter.Phase.LIVE
	cutter._t = cutter.FLIGHT
	cutter._landed = false
	cutter._live(0.0)
	t.check("LC-1 a cut over ground only grazes", cutter.grazed == 1 and cutter.cuts == 0 and kit.hooked, "grazed %d cuts %d" % [cutter.grazed, cutter.cuts])

	# Over the gap west of the spawn island the cut lands; a fresh bite in 0.5 s pays the kick.
	var air := Vector3(-26.0, SPAWN_TOP + 2.0, 120.0)
	game.player.reset_to(air, Vector3(-8.0, 0.0, 0.0))
	await physics_frame
	game.player.kit.hooked = true
	game.player.kit.gliding = false
	cutter._commit_ring(cutter.Threat.Type.PROJECTILE, game.player.ball_position(), cutter.RING_RADIUS, cutter.RING_REACH)
	cutter._t = cutter.FLIGHT
	cutter._landed = false
	cutter._live(0.0)
	var cut: bool = cutter.cuts == 1 and not game.player.kit.hooked
	var speed_before: float = game.player.planar_velocity().length()
	game.player.grapple_to(game.player.ball_position() + Vector3(-10.0, 6.0, 0.0))
	await _frames(2)
	var speed_after: float = game.player.planar_velocity().length()
	t.check("LC-2 a cut over a gap lands", cut, "cuts %d hooked %s" % [cutter.cuts, game.player.kit.hooked])
	t.check("LC-3 a re-bite within 0.5 s keeps a kick", cutter.rebites == 1 and speed_after > speed_before + 2.0,
		"rebites %d, planar %.2f -> %.2f m/s" % [cutter.rebites, speed_before, speed_after])

	# A late bite pays nothing.
	game.player.reset_to(air, Vector3(-8.0, 0.0, 0.0))
	await physics_frame
	game.player.kit.hooked = true
	cutter._commit_ring(cutter.Threat.Type.PROJECTILE, game.player.ball_position(), cutter.RING_RADIUS, cutter.RING_REACH)
	cutter._t = cutter.FLIGHT
	cutter._landed = false
	cutter._live(0.0)
	await _frames(80)
	game.player.reset_to(air, Vector3(-8.0, 0.0, 0.0))
	game.player.grapple_to(air + Vector3(-10.0, 6.0, 0.0))
	await physics_frame
	t.check("LC-4 a bite after the window pays nothing", cutter.cuts == 2 and cutter.rebites == 1, "cuts %d rebites %d" % [cutter.cuts, cutter.rebites])

	# Grown: odd throws aim at the landing.
	_grow(2.3)
	cutter.throws = 1
	cutter._commit(Vector3.ZERO)
	var odd: String = cutter.aim
	cutter.throws = 2
	cutter._commit(Vector3.ZERO)
	t.check("LC-5 grown: every other throw aims at the landing", odd == "landing" and cutter.aim == "line", "odd '%s', even '%s'" % [odd, cutter.aim])
	_grow(1.0)
	cutter.free()
