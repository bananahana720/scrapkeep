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
		t.eq("first fact row", facts[0]["row"], "E25")
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
	_clear()

	# A slam in the suck-up breaks the drop: no pod lands.
	rig = _spawn()
	rig.hp = 1.0e6
	await _until(func(): return rig.phase == rig.Phase.WARN)
	game.combat._hit(rig, "ram", 1.0, Vector3.RIGHT, 60.0, "", "", "ram")
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

	quit(t.verdict())
