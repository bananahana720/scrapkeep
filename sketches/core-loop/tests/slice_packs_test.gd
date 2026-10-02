# smoke: solo (its simulated span runs at wall pace, about 88 s, and a loaded batch pushes it toward the 120 s limit)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Holds := preload("res://src/combat/holds.gd")

# The slice's packs and holds on a live slice game (EN):
# - 72 simulated seconds spawn only the six slice kinds (the stage's
#   Warden aside); no event starts, no vault and no miniboss appear;
# - a ball driven at 20 m/s through a live mag pit leaves no slower than the same line with
#   no pit, within 0.1 m/s: the pit bends the path and never bleeds the ball;
# - a ball caught by the winch drone and then driven past 19 m/s snaps free with a forward
#   kick, and strain() read above 0.9 on the tick before.
# Every wait is counted in physics frames; none reads the wall clock.

# A headless run is paced by the wall clock at the physics rate, so the simulated span is
# kept to the shortest that shows the elite third and one arrival after it. The spawning part runs at
# SPAWN_RATE; the director schedules in seconds and every wait counts physics ticks.
const SEED := 11
const SPAWN_RATE := 120
const SIM_SECONDS := 72.0
const SLICE_KINDS := ["chaser", "lobber", "mag_trapper", "deflector", "plated_brute", "winch_drone"]
const STAGE_KINDS := ["warden"]
const ENTRY_SPEED := 20.0
const PIT_RADIUS := 4.5
const AHEAD := 40.0

var _game
var _failures := 0
var _source := Intent.Scripted.new()
var _events_started := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot(seed_value: int, calm: bool) -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = seed_value
	_game.ctx.calm = calm
	_game.player.source = _source
	_events_started = 0
	_game.events.event_started.connect(func(_id: String): _events_started += 1)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	await _frames(10)


func _run() -> void:
	await _boot(SEED, false)
	await _sim_span(SEED)
	_game.ctx.calm = true
	await _mag_pit()
	await _winch()
	_game.free()
	print("slice_packs_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _sim_span(seed_value: int) -> void:
	var normal := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = SPAWN_RATE
	var rate := SPAWN_RATE
	var seen := {}
	var live := {}
	var miniboss := false
	var vault := false
	for tick in roundi(SIM_SECONDS * rate):
		await physics_frame
		for enemy in get_nodes_in_group("enemy"):
			var kind := String(enemy.get("kind"))
			seen[kind] = true
			vault = vault or kind == "vault"
			miniboss = miniboss or kind == "miniboss"
		var second := (tick + 1) / rate
		if (tick + 1) % rate == 0 and second in [24, 48, 72]:
			live[second] = get_nodes_in_group("enemy").size()
	Engine.physics_ticks_per_second = normal
	var director = _game.world.director
	var foreign: Array = []
	for kind in seen:
		if not kind in SLICE_KINDS and not kind in STAGE_KINDS:
			foreign.append(kind)
	var ids: Array = director.packs.map(func(p: Dictionary) -> String: return p["id"])
	_report("seed %d: only the six slice kinds spawn" % seed_value, foreign.is_empty() and not seen.is_empty(),
		"kinds seen %s, foreign %s" % [seen.keys(), foreign])
	_report("seed %d: packs arrive by the table" % seed_value, ids.size() >= 4 and ids[2] == "elite" and ids.count("elite") == 1,
		"%d packs in 72 s: %s; live enemies at 24/48/72 s: %s/%s/%s" % [ids.size(), ids, live.get(24), live.get(48), live.get(72)])
	_report("seed %d: no event, no vault, no miniboss" % seed_value, _events_started == 0 and not vault and not miniboss and _game.world.last_miniboss_at == Vector3.INF,
		"%d events started, vault %s, miniboss %s" % [_events_started, vault, miniboss])


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if enemy.get("kind") != "warden":
			enemy.queue_free()


# The ball is driven through the pit twice along the same line from the same speed: once
# with the pit live and once with it gone. Rolling at 20 m/s the ball sheds a little speed
# on its own (it is over cruise), so the pit must cost it nothing beyond that.
func _mag_pit() -> void:
	_clear_enemies()
	await physics_frame
	var ctx = _game.ctx
	var player = _game.player
	var holds = ctx.spawner.fleet.holds
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	heading.y = 0.0
	heading = heading.normalized()
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var ball: Vector3 = ctx.terrain.drop_point(spawn.x + heading.x * AHEAD, spawn.z + heading.z * AHEAD, 1.05)
	player.reset_to(ball)
	var trapper = ctx.spawner.spawn_enemy("mag_trapper", ctx.terrain.drop_point(ball.x + 9.0, ball.z + 3.0, 1.8))
	trapper._rest = 0.3
	var waited := 0
	while is_instance_valid(trapper) and trapper.phase != trapper.Phase.LIVE and waited < 1500:
		await physics_frame
		waited += 1
	var pit = trapper.telegraph()
	_report("mag pit goes live", pit != null and trapper.phase == trapper.Phase.LIVE, "live after %d frames" % waited)
	if pit == null or trapper.phase != trapper.Phase.LIVE:
		return
	var centre: Vector3 = pit.center
	var through: Dictionary = await _pass(centre, heading, holds, trapper, pit)
	trapper.queue_free()
	holds.clear()
	await _frames(5)
	var control: Dictionary = await _pass(centre, heading, holds, null, null)
	_report("mag pit holds the ball", through["held"], "the pit's hold started: %s" % through["held"])
	_report("a ball through a live mag pit leaves no slower than the same line with no pit, within 0.1 m/s", through["entry"] > 0.0 and through["exit"] >= through["entry"] - (control["entry"] - control["exit"]) - 0.1,
		"entered at %.2f m/s, lowest inside %.2f, left at %.2f; the same line with no pit entered at %.2f and left at %.2f"
			% [through["entry"], through["lowest"], through["exit"], control["entry"], control["exit"]])
	holds.clear()


func _pass(centre: Vector3, heading: Vector3, holds, trapper, pit) -> Dictionary:
	var player = _game.player
	var ctx = _game.ctx
	var start: Vector3 = centre - heading * 12.0
	start = ctx.terrain.drop_point(start.x, start.z, 1.05)
	player.reset_to(start, heading * ENTRY_SPEED)
	player.set_velocity_now(heading * ENTRY_SPEED)
	var row := {"entry": -1.0, "exit": -1.0, "lowest": INF, "held": false}
	for tick in 200:
		await physics_frame
		var speed: float = player.planar_velocity().length()
		var flat: Vector3 = player.ball_position() - centre
		flat.y = 0.0
		var inside := flat.length() <= PIT_RADIUS
		row["held"] = row["held"] or (trapper != null and is_instance_valid(trapper) and holds.held(trapper))
		if inside and row["entry"] < 0.0:
			row["entry"] = speed
		if row["entry"] >= 0.0 and inside:
			row["lowest"] = minf(row["lowest"], speed)
		if row["entry"] >= 0.0 and not inside:
			row["exit"] = speed
			break
	return row


func _winch() -> void:
	_clear_enemies()
	await physics_frame
	var ctx = _game.ctx
	var player = _game.player
	var holds = ctx.spawner.fleet.holds
	holds.clear()
	var ball: Vector3 = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	player.reset_to(ball)
	var drone = ctx.spawner.spawn_enemy("winch_drone", ctx.terrain.drop_point(ball.x + 9.0, ball.z + 3.0, 1.8))
	drone._rest = 0.3
	var waited := 0
	while is_instance_valid(drone) and not holds.held(drone) and waited < 1500:
		await physics_frame
		waited += 1
	_report("winch drone catches the ball", holds.held(drone), "held after %d frames" % waited)
	if not holds.held(drone):
		return
	var released := []
	holds.released.connect(func(_id: int, kind: String, reason: String): released.append([kind, reason]))
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	heading.y = 0.0
	heading = heading.normalized()
	player.set_velocity_now(heading * 18.0)
	await physics_frame
	var strain: float = drone.strain()
	var before: float = player.planar_velocity().length()
	player.set_velocity_now(heading * 19.5)
	await _frames(2)
	var after: float = player.planar_velocity().length()
	var forward: float = player.planar_velocity().dot(heading)
	await _frames(2)
	_report("strain reads above 0.9 before the snap", strain > 0.9 and strain < 1.0, "strain %.3f at %.2f m/s" % [strain, before])
	_report("the cable snaps on speed", released.size() >= 1 and released[0][1] == "speed" and not holds.held(drone),
		"released %s" % [released])
	_report("the snap kicks the ball forward", after > 19.5 + 3.0 and forward > 0.0,
		"planar speed %.2f m/s two ticks after the snap, from 19.5, %.2f of it forward" % [after, forward])
	_report("holds list the bound kinds", Holds.BOUNDED.has("mag_pit") and Holds.BOUNDED.has("winch_pull"), "bound kinds %s" % [Holds.BOUNDED])
