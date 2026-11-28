extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")
const BIG_FORCE := 100.0
const SECOND_FORCE := 20.0
const WAIT_FRAMES := 240

var game
var t := T.new("enemy_drill_crew_test")
var ball := Vector3.ZERO


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


func _spawn(rest := 0.0):
	var at := Vector3(ball.x + 10.0, 0.0, ball.z + 2.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	var rig = game.combat.spawn_enemy("drill_crew", at)
	rig._rest = rest
	return rig


func _until(cond: Callable) -> bool:
	for frame in WAIT_FRAMES:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _slam(rig, force: float) -> void:
	game.combat.deal_hit(rig, "slam", force, Vector3.RIGHT, 0.0, "", "", "slam")


func _run() -> void:
	await _boot()
	t.check("the roster builds the drill crew", game.combat.fleet.makes("drill_crew"))

	# Plate first, then the body: an idle rig, two slams.
	var rig = _spawn(1000.0)
	await _frames(2)
	var full: bool = game.combat.resolve(rig, "slam", BIG_FORCE)["full"]
	t.check("a slam of force 100 breaks the plating", full)
	var hp: float = rig.hp
	_slam(rig, BIG_FORCE)
	t.eq("the first full hit pops one plate", rig.plates_popped, 1)
	t.near("hp unchanged after the first full hit", rig.hp, hp)
	_slam(rig, SECOND_FORCE)
	t.check("the second hit reaches the body", rig.hp < hp, "hp %s of %s" % [rig.hp, hp])
	t.eq("only one plate popped", rig.plates_popped, 1)
	rig.free()

	# The wind-up: first fact is E20, the ring is INSTANT, a slam stops it.
	rig = _spawn()
	var facts := []
	rig.attack_phase.connect(func(f: Dictionary): facts.append(f))
	await _until(func(): return rig.phase == rig.Phase.WARN)
	t.eq("the rig commits a wind-up", rig.phase, rig.Phase.WARN)
	t.check("a fact opened", not facts.is_empty())
	if not facts.is_empty():
		t.eq("first fact row", facts[0]["row"], "E20")
		t.eq("first fact phase", facts[0]["phase"], "windup")
	var ring = rig.telegraph()
	t.check("a ring is up", ring != null)
	if ring != null:
		t.eq("the ring is INSTANT", ring.type, Threat.Type.INSTANT)
		t.near("the ring radius", ring.radius, rig.BORE_RADIUS)
	_slam(rig, BIG_FORCE)
	t.eq("a slam in the wind-up stops the bore", rig.stopped, 1)
	t.eq("the rig is back to roam", rig.phase, rig.Phase.ROAM)
	t.eq("the fact was cancelled", facts.back()["phase"], "cancelled")
	t.eq("no bore happened", rig.bores, 0)
	rig.free()

	# A bore with the ball inside the ring hits once.
	rig = _spawn()
	var hits := []
	rig.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	await _until(func(): return rig.bores > 0)
	await _frames(2)
	t.eq("one bore", rig.bores, 1)
	t.eq("the bore hit the ball once", hits.size(), 1)
	if not hits.is_empty():
		t.near("the bore damage", hits[0], rig.BORE_DAMAGE)
	t.check("last_bore reads the ring", rig.last_bore.has("at") and rig.last_bore["radius"] == rig.BORE_RADIUS)
	rig.free()

	# The floor rule: a cave-in under a ball that is off the floor (carving or airborne) misses.
	rig = _spawn()
	await _frames(2)
	rig.set_physics_process(false)
	var missed := []
	rig.hit_player.connect(func(amount: float, _shove: Vector3): missed.append(amount))
	rig._warn(rig._flat_to_ball())
	game.player.state.grounded = false
	rig.phase = rig.Phase.LIVE
	rig._go_live()
	t.eq("a bore under a ball off the floor misses", missed.size(), 0)
	t.eq("it still bored", rig.bores, 1)
	rig.free()

	# Death leaves the breach fact, readable inside a died handler.
	rig = _spawn(1000.0)
	await _frames(2)
	var seen := {}
	var at: Vector3 = rig.global_position
	rig.died.connect(func(_where: Vector3, _scrap: int): seen.merge(rig.bore_fact))
	t.check("no fact while alive", rig.bore_fact.is_empty())
	rig.take_damage(1.0e6)
	t.eq("the fact says breached", seen.get("breached"), true)
	t.eq("the fact kind", seen.get("kind"), "drill_crew")
	t.check("the fact id", String(seen.get("id", "")).begins_with("drill_"))
	t.check("the fact position", seen.has("at") and seen["at"].distance_to(at) < 0.01)
	t.near("the fact radius", float(seen.get("radius", 0.0)), 3.0)

	quit(t.verdict())
