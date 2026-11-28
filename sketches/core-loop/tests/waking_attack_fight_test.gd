# smoke: solo (world two's arena: a real ball carving the rim bank, then the Waking fought floor by floor)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Waking := preload("res://src/boss/waking.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const T := preload("res://tests/support/t.gd")

# The Waking's own attacks in world two's arena, on the real rigid ball.
#   bank   the ball is set rolling round the rim bank at 28 m/s and must carve it (waking.gd
#          carving_now). A ring laid over the whole bank goes live on it and lands nothing:
#          the Dig floor rule spares a carving ball.
#   floor  the same ring over a ball parked on the floor lands once, for its family's damage.
#   fight  the Waking's own clock: the ball waits on each floor until that floor's new family
#          is telegraphed (burrow on the Spoil, cave-in on the Seam, bore on Bedrock), and on
#          Bedrock until the bore jams the drill and halves the plating; then the chunk is
#          struck through the harness until it shatters. No two warnings in the fight, floor
#          drops included, start within the warning gap, and the fight ends in victory.
#
# Evidence limit: the carve is one launch on one bank; fight hits are TARGET calls, not ball
# contacts; the ball sits still through the fight, so it says nothing about dodging or feel.

const FLOOR_WAIT := 90 * 20
const CHUNK_CAP := 90 * 20
const REST_FRAMES := int(Waking.FLOOR_WARN * 90.0) + 30
const CARVE_SPEED := 28.0

var _t := T.new("waking_attack_fight_test")
var _game
var _hits: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _walk()
	_game.free()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	Harness.boot(game)
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	if not _t.check("world 2 module is waking.gd", mod != null and String(mod.get_script().resource_path).ends_with("waking.gd")):
		return
	game.run.max_hp = 100000.0
	game.run.hp = 100000.0
	game.ctx.events.player_hit.connect(func(amount: float, source: String): _hits.append([source, amount]))
	var player = game.ctx.player
	_t.check("each floor carries a rim bank", mod._floor_bodies.values().all(func(b): return b.has_node("RimBank")) and mod.pad.has_node("RimBank"))

	# --- bank: a real carve under a live ring ---
	mod._attack_clock = 1.0e9
	var center: Vector3 = Vector3(mod._center.x, mod._top(), mod._center.z)
	var out := Vector3(1.0, 0.0, 0.0)
	var start := center + out * (Waking.PAD_RADIUS - 2.2) + Vector3.UP * 2.6
	player.reset_to(start, Vector3(0.0, 0.0, -CARVE_SPEED))
	player.body().global_position = start
	var carved := 0
	for i in 30:
		await physics_frame
		carved += 1 if mod.carving_now() else 0
	var ring := _ring(mod, "burrow", center, Vector2(Waking.BANK_IN - 1.0, Waking.PAD_RADIUS), 8.0)
	var live_frames := 0
	var live_carving := 0
	while not ring["hazards"][0].is_done():
		await physics_frame
		if ring["hazards"][0].is_live():
			live_frames += 1
			live_carving += 1 if mod.carving_now() else 0
	var r: float = Vector2(player.ball_position().x - center.x, player.ball_position().z - center.z).length()
	print("bank: carving %d/30 settle, %d/%d live; speed %.1f, r %.1f" % [carved, live_carving, live_frames, player.body().linear_velocity.length(), r])
	_t.check("the ball carves the bank while the ring is live", live_frames > 0 and live_carving >= live_frames * 0.8,
			"%d of %d live frames" % [live_carving, live_frames])
	_t.check("a carving ball is spared", not ring["landed"] and _hits.is_empty(), str(_hits))
	_t.check("the ride counts toward The Wall Is Home", mod._banked.has("burrow"), str(mod._banked))

	# --- floor: the same ring over a parked ball lands once ---
	_hits.clear()
	var parked := center + Vector3(0.0, 1.2, 18.0)
	player.reset_to(parked, Vector3.ZERO)
	player.body().global_position = parked
	for i in 20:
		await physics_frame
	var floor_ring := _ring(mod, "cave_in", center, Vector2(0.0, Waking.PAD_RADIUS), WakingAttacks.HEIGHT)
	while not floor_ring["hazards"][0].is_done():
		await physics_frame
	_t.check("a ball on the floor is hit once", floor_ring["landed"] and _hits.size() == 1, str(_hits))
	_t.check("for the family's damage", _hits.size() == 1 and _hits[0][0] == "waking_cave_in"
			and is_equal_approx(float(_hits[0][1]), WakingAttacks.DAMAGE["cave_in"]), str(_hits))
	mod._clear_attacks()
	mod._attack_clock = 0.0

	# --- fight: the Waking's own clock, floor by floor ---
	var seen: Array = []
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, _s: float): seen.append([id, mod.clock]))
	var base: float = mod._base_plating
	for k in 3:
		var family: String = WakingAttacks.newest(k + 1)
		var frames := 0
		while frames < FLOOR_WAIT and not seen.any(func(e): return String(e[0]).begins_with("waking_%s_" % family)):
			frames += 1
			await physics_frame
		_t.check("floor %d telegraphs %s" % [k + 1, family], frames < FLOOR_WAIT, "%d frames" % frames)
		if family == "bore":
			frames = 0
			while frames < FLOOR_WAIT and not mod.jammed():
				frames += 1
				await physics_frame
			_t.check("the bore jams the drill", mod.jammed(), "%d frames" % frames)
			_t.near("a jammed drill halves the plating", mod.warden.plating, base * Waking.EXPOSED_SCALE, 0.01)
			_t.check("the objective says so", mod.objective_text().contains("jammed"), mod.objective_text())
		elif family == "burrow":
			_t.check("the objective names what is incoming", mod.objective_text().contains("Incoming"), mod.objective_text())
		await _shatter(mod)
	await _shatter(mod)

	var gaps: Array = []
	for i in range(1, mod.warnings.size()):
		gaps.append(snappedf(mod.warnings[i]["at"] - mod.warnings[i - 1]["at"], 0.001))
	var tight := gaps.filter(func(g): return g < WakingAttacks.GAP - 0.001)
	print("fight: %d warnings, gaps under %.1f s: %s; landings %d; hits %s" % [mod.warnings.size(), WakingAttacks.GAP, str(tight),
			mod.landings.size(), str(_hits)])
	_t.check("several warnings in the fight", mod.warnings.size() >= 6, str(mod.warnings.size()))
	_t.eq("no two warnings within the gap", tight, [])
	var drops: Array = mod.warnings.filter(func(w): return String(w["id"]).begins_with("waking_floor_")).map(func(w): return w["id"])
	_t.eq("floors still drop in order", drops, ["waking_floor_1", "waking_floor_2", "waking_floor_3"])
	_t.check("the parked ball was hit by the Waking's own attacks", mod.landings.size() >= 1, str(mod.landings.size()))
	_t.check("defeated", not Harness._alive(Harness.target(mod)))
	var ledger: Dictionary = game.run.get_meta("boss_attacks", {})
	_t.check("the run ledger counts all three families", ledger.has("burrow") and ledger.has("cave_in") and ledger.has("bore"), str(ledger))


# Strikes the Warden until one chunk falls, then rests through the floor drop.
func _shatter(mod) -> void:
	var before: int = mod.warden.chunks_left() if is_instance_valid(mod.warden) else 0
	var frames := 0
	while frames < CHUNK_CAP and Harness._alive(Harness.target(mod)) and mod.warden.chunks_left() == before:
		Harness.hit(mod)
		frames += 1
		await physics_frame
	for i in REST_FRAMES:
		await physics_frame


# A test ring laid through the module's own attack list, so it lands by the module's rule.
func _ring(mod, family: String, center: Vector3, band: Vector2, height: float) -> Dictionary:
	var d := {"family": family, "family_index": 1, "id": "waking_test_ring", "shape": "annulus", "type": Threat.Type.INSTANT,
		"warn": 1.0, "live": 1.0, "height": height, "at": center, "band": band, "delay": 0.0}
	var h = Hazard.from_def(d)
	h.ground = Callable(mod, "ground_height_at")
	mod.ctx.root.add_child(h)
	var attack := {"hazards": [h], "family": family, "landed": false, "descs": [d]}
	mod.attacks.append(attack)
	return attack
