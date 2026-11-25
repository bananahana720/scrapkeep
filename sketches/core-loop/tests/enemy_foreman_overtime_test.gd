extends SceneTree

# W47-E3 foreman (Shift Boss) secondary: Overtime Sync Whistle (0.90 s twin steam blasts when
# tethered ally drops < 50% HP) -> interrupting whistle shatters plating across entire tethered squad.
# Verifies tell floor >= 0.60 s, Palette.HAZARD, AttackBudget + 0.2 s gap, priming injured ally on
# completion, and full-squad plating + outer-plate shatter on interrupt (damage, knock, or kill).

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Palette := preload("res://src/core/palette.gd")
const Foreman := preload("res://src/combat/foreman.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_foreman_overtime_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
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
	await _frames(4)
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


func _run() -> void:
	await _boot()

	# 1. Tell floor invariant >= 0.60 s.
	t.check("Overtime Sync Whistle warn >= 0.60 s", Foreman.OVERTIME_WARN >= 0.60, str(Foreman.OVERTIME_WARN))
	t.near("Overtime Sync Whistle warn is 0.90 s", Foreman.OVERTIME_WARN, 0.90, 0.001)

	# 2. Full-HP squad never triggers Overtime Sync Whistle.
	_clear()
	var b1 = game.combat.spawn_enemy("plated_brute", _at(28.0, -3.0))
	var b2 = game.combat.spawn_enemy("plated_brute", _at(28.0, 3.0))
	var chaser = game.combat.spawn_enemy("chaser", _at(24.0, 0.0))
	var boss = game.combat.spawn_enemy("foreman", _at(34.0, 0.0))
	await _frames(10)
	t.eq("full-HP squad starts zero overtime whistles", [boss.overtime_whistles, boss.telegraph() != null], [0, false])

	# 3. Ally drops < 50% HP -> obeys AttackBudget + 0.2 s gap, then starts 0.90 s Palette.HAZARD whistle.
	chaser.hp = chaser.max_hp * 0.4
	# Block inside 0.2 s gap first.
	root.set_meta(AttackBudget.LAST_META, Engine.get_physics_frames())
	root.set_meta(AttackBudget.VOLLEY_META, [-1, -999])
	await _frames(2)
	t.eq("overtime whistle waits while 0.2 s inter-warning gap is closed", boss.overtime_whistles, 0)
	root.remove_meta(AttackBudget.LAST_META)
	var started_allies := []
	var shattered_lists := []
	boss.overtime_started.connect(func(ally: Node3D): started_allies.append(ally))
	boss.overtime_interrupted.connect(func(list: Array): shattered_lists.append(list.duplicate()))
	await _frames(5)
	var tele = boss.telegraph()
	t.check("injured ally triggers Overtime Sync Whistle", boss.overtime_whistles == 1 and started_allies == [chaser],
		"whistles=%d started=%d" % [boss.overtime_whistles, started_allies.size()])
	t.check("whistle holds AttackBudget slot", boss.is_in_group(AttackBudget.ATTACKING))
	t.check("whistle commits 0.90 s Palette.HAZARD ring",
		tele != null and tele.color.is_equal_approx(Palette.HAZARD) and is_equal_approx(tele.warn_seconds, Foreman.OVERTIME_WARN))

	# 4. Practiced payoff: interrupting whistle shatters plating & outer plates across ENTIRE tethered squad!
	t.check("both brutes start plated with outer plates", b1.plating > 0.0 and b2.plating > 0.0 and b1.plates > 0 and b2.plates > 0)
	boss.take_damage(Foreman.OVERTIME_INTERRUPT_DAMAGE)
	t.eq("interrupt records once and releases AttackBudget",
		[boss.overtime_interrupts, boss.telegraph() == null, boss.is_in_group(AttackBudget.ATTACKING)],
		[1, true, false])
	t.eq("shatters plating and outer plates on ALL tethered squad members",
		[b1.plating, b1.plates, b2.plating, b2.plates, boss.overtime_shattered],
		[0.0, 0, 0.0, 0, 2])
	t.check("combat.plating_of reads 0 for shattered squad", game.combat.plating_of(b1) == 0.0 and game.combat.plating_of(b2) == 0.0)
	t.eq("overtime_interrupted reports full crew", shattered_lists.size() == 1 and shattered_lists[0].size() == 3, true)
	_clear()

	# 5. Uninterrupted 0.90 s whistle completes and primes the injured ally for an immediate strike.
	var injured = game.combat.spawn_enemy("chaser", _at(28.0, 0.0))
	injured._rest = 5.0
	var lead = game.combat.spawn_enemy("foreman", _at(34.0, 0.0))
	await _frames(3)
	injured.hp = injured.max_hp * 0.35
	var primed := []
	lead.overtime_primed.connect(func(ally: Node3D): primed.append(ally))
	await _frames(int(ceil((Foreman.OVERTIME_WARN + 0.15) * Engine.physics_ticks_per_second)))
	t.check("uninterrupted whistle completes and primes injured ally", lead.overtime_completes == 1 and primed == [injured],
		"completes=%d primed=%d" % [lead.overtime_completes, primed.size()])
	t.check("primed ally rest cleared and marked boosted", injured._rest <= 0.1 and bool(injured.get_meta("overtime_boosted", false)))
	t.check("slot released after completion", not lead.is_in_group(AttackBudget.ATTACKING))

	_clear()
	game.free()
	quit(t.verdict())
