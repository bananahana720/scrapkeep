extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")
const HOVER := 6.0

var game
var t := T.new("enemy_kite_drone_test")
var ball := Vector3.ZERO
var facts := []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _spawn(height: float, rest := 0.0):
	var at := Vector3(ball.x + 9.0, 0.0, ball.z + 3.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + height
	var drone = game.combat.spawn_enemy("kite_drone", at)
	drone._strafe = 1.0
	drone._rest = rest
	drone.hp = 100000.0
	facts = []
	drone.attack_phase.connect(func(f: Dictionary): facts.append(f))
	return drone


# Parks the ball each frame until the drone reaches the phase, within a frame budget.
func _until(drone, want: int, budget := 400) -> bool:
	for frame in budget:
		if drone.phase == want:
			return true
		game.player.reset_to(ball)
		await physics_frame
	return drone.phase == want


func _fast_ball(multiple: float) -> void:
	game.player.set_velocity_now(Vector3(multiple * game.player.tuning.f("cruise"), 0.0, 0.0))


# Waits for a live dive that has not landed, with the ball moving at `multiple` of cruise.
func _mid_dive(drone, multiple: float) -> bool:
	for frame in 400:
		if drone.phase == drone.Phase.LIVE and drone._t > 0.2:
			return true
		if multiple > 0.0:
			_fast_ball(multiple)
		await physics_frame
	return false


func _run() -> void:
	await _boot()

	# Hover: from 1 m up it climbs to the ball's height plus HOVER; the settle time is the first frame within 0.5 m.
	var drone = _spawn(1.0, 1000.0)
	var settled := -1
	for frame in 120:
		game.player.reset_to(ball)
		await physics_frame
		if settled < 0 and absf(drone.global_position.y - (ball.y + HOVER)) <= 0.5:
			settled = frame + 1
	var off := absf(drone.global_position.y - (ball.y + HOVER))
	t.check("KD-1 hover", settled >= 0 and settled <= 60 and off <= 1.0, "within 0.5 m of ball.y + %.1f after %d frames (%.2f s); %.3f m off after 120 frames" % [HOVER, settled, settled / 60.0, off])

	# The mark: an INSTANT ring at the ball's x,z (ball parked), then a dive that lands on it.
	game.combat.last_player_hit = {}
	drone._rest = 0.0
	var warned: bool = await _until(drone, drone.Phase.WARN)
	var first: Dictionary = facts[0] if not facts.is_empty() else {}
	var centre: Vector3 = first.get("geometry", {}).get("centre", Vector3(INF, INF, INF))
	var flat := Vector2(centre.x - ball.x, centre.z - ball.z).length()
	t.check("KD-2 mark", warned and first.get("row", "") == "E24" and first.get("phase", "") == "windup" \
		and first["geometry"]["type"] == Threat.Type.INSTANT and flat <= 0.5,
		"first fact %s %s, type %s, ring centre %.3f m from the ball in x,z" % [first.get("row", ""), first.get("phase", ""), first.get("geometry", {}).get("type", -1), flat])
	var dived: bool = await _until(drone, drone.Phase.LIVE)
	await _until(drone, drone.Phase.ROAM)
	var hit: Dictionary = game.combat.last_player_hit
	var struck := false
	for f in facts:
		struck = struck or f["phase"] == "strike"
	t.check("KD-3 dive lands", dived and drone.dives == 1 and hit.get("source", "") == "kite_drone" and struck,
		"dives %d, last_player_hit source '%s', strike fact %s" % [drone.dives, hit.get("source", ""), struck])
	drone.free()

	# A cruise-speed ball meeting the dive bats the drone back up and takes no hit.
	game.combat.last_player_hit = {}
	game.player.reset_to(ball)
	drone = _spawn(HOVER, 0.0)
	var live: bool = await _mid_dive(drone, 1.2)
	_fast_ball(1.2)
	await physics_frame
	var tier_ok: bool = game.player.speed_tier() >= 1
	var live_landed: bool = drone._landed
	game.combat.deal_hit(drone, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "ram")
	var batted_now: int = drone.batted
	await physics_frame
	t.check("KD-4 bat", live and tier_ok and not live_landed and batted_now == 1 and drone.phase == drone.Phase.ROAM and game.combat.last_player_hit.is_empty(),
		"live %s, tier ok %s, batted %d, phase %d next tick, hit %s" % [live, tier_ok, batted_now, drone.phase, game.combat.last_player_hit])
	drone.free()

	# A slow ball takes the dive: no bat, the dive completes.
	game.combat.last_player_hit = {}
	game.player.reset_to(ball)
	drone = _spawn(HOVER, 0.0)
	live = await _mid_dive(drone, 0.0)
	_fast_ball(0.5)
	await physics_frame
	var slow_tier: int = game.player.speed_tier()
	game.combat.deal_hit(drone, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "ram")
	var still_live: bool = drone.phase == drone.Phase.LIVE
	await _until(drone, drone.Phase.ROAM)
	t.check("KD-5 slow ball", live and slow_tier == 0 and drone.batted == 0 and still_live and drone.dives == 1 and drone._landed,
		"live %s, tier %d, batted %d, still live after the ram %s, landed %s" % [live, slow_tier, drone.batted, still_live, drone._landed])
	drone.free()
	quit(t.verdict())
