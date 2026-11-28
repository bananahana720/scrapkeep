extends SceneTree

# The Foreman (src/combat/foreman.gd; ENEMY-PRIORITY.md lever 3): it claims its pack as crew (or,
# with no pack, the enemies in reach), horns one beat before each 5 s wipe with the tell signal on
# that frame, wipes its crew's plating shred, never takes an attacker slot or lays a warning, and
# its death clocks the standing crew out for 1.5 s and fires the shift_over trick.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Foreman := preload("res://src/combat/foreman.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_foreman_test")
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


func _at(dx: float, dz: float) -> Vector3:
	return game.ctx.terrain.drop_point(ball.x + dx, ball.z + dz, 2.0)


func _seconds(frames: int) -> float:
	return float(frames) / Engine.physics_ticks_per_second


func _run() -> void:
	await _boot()
	t.check("the roster builds the foreman", game.combat.fleet.makes("foreman"))

	# A crew in reach (no pack): claimed on the first tick; one far off is not.
	var brute = game.combat.spawn_enemy("plated_brute", _at(30.0, 0.0))
	var chaser = game.combat.spawn_enemy("chaser", _at(30.0, 6.0))
	var stranger = game.combat.spawn_enemy("chaser", _at(-60.0, 0.0))
	var boss = game.combat.spawn_enemy("foreman", _at(40.0, 3.0))
	var tells := []
	var wipes := []
	var frame := [0]
	boss.special_tell.connect(func(moment: String): tells.append([moment, frame[0]]))
	boss.wiped.connect(func(members: Array): wipes.append([members.size(), frame[0], game.combat.shred_of(brute)]))
	await _frames(2)
	t.eq("it claims the two in reach", boss.crew.size(), 2)
	t.check("not the one far off", stranger not in boss.crew)
	t.check("the brute has plating to shred", brute.plating > 0.0, str(brute.plating))
	# Hits keep landing on the brute right up to the wipe, so its shred never rests away.
	var shred_before := 0.0
	var slotted := false
	var warned := false
	for i in int(ceil((Foreman.WIPE_EVERY + 0.5) * Engine.physics_ticks_per_second)):
		if wipes.is_empty():
			game.combat.add_shred(brute, 200.0)
			shred_before = game.combat.shred_of(brute)
		frame[0] += 1
		await physics_frame
		game.player.reset_to(ball)
		slotted = slotted or boss.is_in_group(AttackBudget.ATTACKING) or boss.is_in_group(AttackBudget.WAITING)
		warned = warned or boss.telegraph() != null
	t.check("the brute's plating was shredded up to the wipe", shred_before > 0.0, str(shred_before))
	t.eq("one wipe in the first cycle", wipes.size(), 1)
	t.eq("one horn, the tell", tells.size(), 1)
	if tells.size() == 1 and wipes.size() == 1:
		t.eq("the horn is the special tell", tells[0][0], "tell")
		t.near("the horn leads the wipe by one beat", _seconds(wipes[0][1] - tells[0][1]), Foreman.HORN_LEAD, 0.05)
		t.near("the wipe lands about 5 s in", _seconds(wipes[0][1]), Foreman.WIPE_EVERY, 0.1)
		t.eq("the wipe reaches both of the crew", wipes[0][0], 2)
		t.near("the wipe closes the brute's plating", float(wipes[0][2]), 0.0, 0.001)
	t.check("it never asks the attacker budget", not slotted)
	t.check("it never lays a warning", not warned)

	# Killed with its crew standing: they clock out for 1.5 s and the trick fires.
	game.combat.discovered.erase("shift_over")
	boss.take_damage(1.0e6)
	t.check("the brute clocks out", AttackBudget.clocked_out(brute))
	t.check("the chaser clocks out", AttackBudget.clocked_out(chaser))
	t.check("a clocked-out unit is refused a slot", not AttackBudget.ask(brute))
	t.check("the stranger was never on shift", not AttackBudget.clocked_out(stranger))
	t.check("shift_over is discovered", game.combat.discovered.has("shift_over"))
	await _frames(int(ceil((Foreman.CLOCK_OUT - 0.1) * Engine.physics_ticks_per_second)))
	t.check("still out just before 1.5 s", AttackBudget.clocked_out(brute))
	await _frames(int(ceil(0.2 * Engine.physics_ticks_per_second)))
	t.check("back on after 1.5 s", not AttackBudget.clocked_out(brute))
	_clear()

	# In a director pack: only its pack mates, wherever they stand.
	var mate = game.combat.spawn_enemy("chaser", _at(70.0, 0.0))
	var other = game.combat.spawn_enemy("chaser", _at(31.0, 0.0))
	var lead = game.combat.spawn_enemy("foreman", _at(30.0, 0.0))
	for pair in [[mate, 7], [lead, 7], [other, 8]]:
		pair[0].set_meta(AttackBudget.PACK_META, pair[1])
	await _frames(2)
	t.check("a pack Foreman claims its pack mate only", lead.crew.size() == 1 and lead.crew[0] == mate, str(lead.crew.size()))
	# No crew left standing: no horn and no wipe.
	mate.take_damage(1.0e6)
	var horns: int = lead.horns
	await _frames(int(ceil((Foreman.WIPE_EVERY + 0.5) * Engine.physics_ticks_per_second)))
	t.eq("no horn with no crew", lead.horns, horns)
	t.eq("no wipe with no crew", lead.wipes, 0)
	lead.take_damage(1.0e6)
	t.check("a lone Foreman's death clocks nobody out", not AttackBudget.clocked_out(other))
	_clear()

	quit(t.verdict())
