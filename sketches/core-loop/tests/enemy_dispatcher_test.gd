extends SceneTree

# The Dispatcher (src/combat/dispatcher.gd; ENEMY-PRIORITY.md lever 4): its perch is 6 to 10 m up
# and a world collider; a drop asks the attacker budget, commits a PROJECTILE ring with the tell
# signal on that frame, hurts a ball the ring holds on the strike frame and lands a scrapless
# chaser; a slam in the suck-up breaks the drop; it stops dropping at ADD_CAP standing chasers.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Dispatcher := preload("res://src/combat/dispatcher.gd")
const T := preload("res://tests/support/t.gd")
const WAIT_FRAMES := 900

var game
var t := T.new("enemy_dispatcher_test")
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
	_clear()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)


func _spawn(rest := 0.0):
	game.player.reset_to(ball)
	var at := Vector3(ball.x + 14.0, 0.0, ball.z + 4.0)
	at.y = game.ctx.terrain.height(at.x, at.z)
	var rig = game.combat.spawn_enemy("dispatcher", at)
	rig._rest = rest
	return rig


func _until(cond: Callable) -> bool:
	for frame in WAIT_FRAMES:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _run() -> void:
	await _boot()
	t.check("the roster builds the dispatcher", game.combat.fleet.makes("dispatcher"))

	# The perch: its own mast in the design's band, a world collider under the body.
	var rig = _spawn(1000.0)
	await _frames(2)
	t.check("perched 6 to 10 m up", rig.perch_height() >= Dispatcher.PERCH_MIN and rig.perch_height() <= Dispatcher.PERCH_MAX,
		str(rig.perch_height()))
	t.check("the mast stands", rig.mast != null and rig.mast.get_collision_layer_value(1))
	var y: float = rig.global_position.y
	rig.knock(Vector3.RIGHT, 500.0)
	await _frames(10)
	t.near("a knock never moves it off its perch", rig.global_position.y, y, 0.01)
	rig.free()

	# A drop: the tell on the commit frame, a PROJECTILE ring, a hit on a ball inside it, and a chaser.
	_clear()
	rig = _spawn()
	var tells := []
	var facts := []
	var hits := []
	var adds := []
	rig.special_tell.connect(func(moment: String): tells.append([moment, rig.telegraph() != null]))
	rig.attack_phase.connect(func(f: Dictionary): facts.append(f))
	rig.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	rig.dispatched.connect(func(add: Node3D): adds.append(add))
	await _until(func(): return rig.phase == rig.Phase.WARN)
	t.eq("the drop commits a wind-up", rig.phase, rig.Phase.WARN)
	t.check("it holds an attacker slot", rig.is_in_group(AttackBudget.ATTACKING))
	t.eq("one tell, on the frame the ring is up", tells, [["tell", true]])
	if not facts.is_empty():
		t.eq("first fact row", facts[0]["row"], "E26")
	var ring = rig.telegraph()
	t.check("a ring is up", ring != null)
	if ring != null:
		t.eq("the ring is PROJECTILE", ring.type, Threat.Type.PROJECTILE)
		t.near("the ring radius", ring.radius, Dispatcher.DROP_RADIUS)
		t.check("the ring sits on the ball", ring.contains(game.player.ball_position()))
	await _until(func(): return rig.drops > 0)
	await _frames(12)
	t.eq("one drop", rig.drops, 1)
	t.eq("the drop hit the ball once", hits, [Dispatcher.DROP_DAMAGE])
	t.eq("one chaser landed", adds.size(), 1)
	if not adds.is_empty():
		t.eq("it is a chaser", adds[0].kind, "chaser")
		t.eq("it carries no scrap", adds[0].scrap_value, 0)
	t.check("the slot went back", not rig.is_in_group(AttackBudget.ATTACKING))
	# Escalate: an unanswered drop climbs a step (the next pod is a hooker, sooner); each hit steps it down.
	t.eq("an unanswered drop climbs a step", rig.escalation, 1)
	t.near("the next drop comes sooner", rig.rest_seconds, float(Dispatcher.ESCALATION[1]["every"]) - Dispatcher.WARN - rig.live_seconds)
	game.player.reset_to(ball)
	await _until(func(): return rig.drops > 1)
	await _frames(2)
	t.eq("the second pod opens into a hooker", adds.size() > 1 and adds[1].kind == "hooker", true)
	t.eq("it climbs again", rig.escalation, 2)
	rig.take_damage(1.0)
	t.eq("a hit steps it down one", rig.escalation, 1)
	rig.take_damage(1.0)
	t.eq("a second hit answers it", rig.escalation, 0)
	# Answered between drops: one hit, then the next landing does not climb.
	rig.take_damage(1.0)
	var landed: int = rig.drops
	game.player.reset_to(ball)
	await _until(func(): return rig.drops > landed)
	await _frames(2)
	t.eq("a drop after a hit does not climb", rig.escalation, 0)
	t.near("back to the start cadence", rig.rest_seconds, Dispatcher.DROP_EVERY - Dispatcher.WARN - rig.live_seconds)
	_clear()

	# A slam in the suck-up breaks the drop: no pod lands.
	rig = _spawn()
	rig.hp = 1.0e6
	await _until(func(): return rig.phase == rig.Phase.WARN)
	game.combat.deal_hit(rig, "ram", 1.0, Vector3.RIGHT, 60.0, "", "", "ram")
	await _frames(2)
	t.eq("a slam in the wind-up breaks the drop", rig.phase, rig.Phase.ROAM)
	await _frames(120)
	t.eq("no drop happened", rig.drops, 0)
	_clear()

	# At ADD_CAP standing chasers it holds fire.
	rig = _spawn()
	for i in Dispatcher.ADD_CAP:
		rig.adds.append(game.combat.spawn_enemy("chaser", ball + Vector3(-30.0, 2.0, 4.0 * i)))
	await _frames(240)
	t.eq("no drop while the cap stands", rig.drops, 0)
	rig.adds[0].take_damage(1.0e6)
	game.player.reset_to(ball)
	await _until(func(): return rig.phase == rig.Phase.WARN)
	t.eq("a fallen chaser frees the next drop", rig.phase, rig.Phase.WARN)
	_clear()

	# The director card: cost 4, one per purchase, and the kind is placeable.
	var Cards := preload("res://src/core/director_cards.gd")
	var Director := preload("res://src/world/director.gd")
	t.eq("the dispatcher card costs 4", Cards.cost(["dispatcher"]), 4.0)
	t.eq("its stage cap is 1", Cards.cost(["dispatcher", "dispatcher"]), INF)
	t.check("the director names it", Director.KIND_NAMES.has("dispatcher"))
	# Planted negative control: a kind with no card is INF, as the dispatcher was before its card.
	t.eq("negative control: an unknown kind has no card", Cards.cost(["dispatcher_missing"]), INF)

	# A park perch from the spec: the body stands on it, builds no mast, and the perch is not the fallback's.
	var at := Vector3(ball.x + 14.0, 0.0, ball.z + 4.0)
	at.y = game.ctx.terrain.height(at.x, at.z)
	var top := Vector3(at.x + 20.0, at.y + 9.0, at.z)
	var fallback = game.combat.spawn_enemy("dispatcher", at)
	var perched = game.combat.spawn_enemy("dispatcher", at, "", top)
	var infinite = game.combat.spawn_enemy("dispatcher", at, "", Vector3.INF)
	await _frames(2)
	t.eq("a spec perch is the perch top", perched.perch_top, top)
	t.check("it builds no mast of its own", perched.mast == null)
	t.near("its body stands on the perch", perched.global_position.y, top.y + Dispatcher.FLOOR_DROP, 0.01)
	t.check("negative control: the fallback differs from the perch", fallback.perch_top != perched.perch_top)
	t.check("no perch: its own mast, where it spawned", fallback.mast != null and is_equal_approx(fallback.perch_top.x, at.x))
	t.check("an INF perch is no perch", infinite.mast != null and infinite.perch_top != top)
	_clear()

	quit(t.verdict())
