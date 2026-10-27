extends SceneTree

# Brindle's boss entry (park seed 1: 143 ms): enter_arena loaded and dressed the Requisition's GLB
# (31 ms profiled), read the bowl's foundry and Spillway kits (10 ms) and drew its checkers. While
# the world's last stage runs, flow now steps arena.gd's warm_ahead a tick at a time, as it does a
# row module's warm_arena. Checked: the gates instance the fortress and the scooter, read every
# kit, draw the checkers and build the bowl itself before the entry, one step a tick; the entry
# takes that bowl and dresses the ship with the fortress read ahead; the game's exit frees what is
# still held.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BowlDress := preload("res://src/presentation/arena_bowl_dress.gd")
const T := preload("res://tests/support/t.gd")

const WORLD := 1
const WAIT_TICKS_MAX := 600

var _t := T.new("brindle_arena_ahead_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	var flow = _game.flow
	flow.enter_stage(_game.ctx.stages.last_of(WORLD), Vector3.ZERO, false)
	_t.eq("Brindle's row names the scene's own script", String(flow.boss_row(WORLD).get("script", "")), flow.SCENE_BOSS)
	flow._set_state(flow.GATES)
	var counts := [_held()]
	var waited := 0
	while not (Arena._ahead_bowl != null and Arena._ahead_bowl.built()) and waited < WAIT_TICKS_MAX:
		await physics_frame
		counts.append(_held())
		waited += 1
	var steps := range(1, counts.size()).map(func(i): return counts[i] - counts[i - 1])
	# 2026-10-24 (#416 Slag Bowl dressing): the yard is a third kit, so every kit in _kits() is read ahead.
	# 2026-10-27 (world 1 hitches): the bowl is built ahead from those kits, so they are taken by then.
	var bowl: Node3D = Arena._ahead_bowl
	_t.check("the gates instance both models and build the bowl from every kit, at most one step a tick",
		Requisition._ahead.size() == 2 and bowl != null and bowl.built() and BowlDress._ahead.is_empty() and steps.all(func(d): return d <= 1),
		"%d ticks, counts %s" % [waited, counts.slice(-8)])
	_t.check("every model read ahead is whole and the bowl is dressed", not Requisition._ahead.values().has(null)
		and bowl.get_node_or_null("ArenaBowlDress") != null and not bowl.is_inside_tree())
	_t.check("the gates draw the bowl's checkers", Arena._looks_warm)
	_t.check("the bowl built ahead stays built on later ticks", Arena.warm_ahead() and BowlDress._ahead.is_empty())
	var fortress: Node3D = Requisition._ahead.get(Requisition.model_path)
	flow.enter_boss(Vector3.ZERO)
	var boss = _game.ctx.boss
	_t.check("the entry takes the bowl built ahead", boss.arena == bowl and bowl.is_inside_tree() and Arena._ahead_bowl == null)
	var yard = bowl.get_node_or_null("ArenaBowlDress/FleetYard")
	_t.check("the yard built ahead is on the game bus once the bowl enters", yard != null
		and _game.events.fight_phase_changed.is_connected(yard._on_fight_phase) and _game.events.boss_defeated.is_connected(yard._on_rout))
	_t.check("the entry dresses the ship with the fortress read ahead",
		boss.ship != null and boss.ship.model == fortress and fortress.get_parent() == boss.ship)
	_t.check("the entry took the fortress; the scooter waits for its phase",
		not Requisition._ahead.has(Requisition.model_path) and Requisition._ahead.has(Requisition.scooter_path) and BowlDress._ahead.is_empty())
	var scooter: Node3D = Requisition._ahead.get(Requisition.scooter_path)
	_game.queue_free()
	await physics_frame
	_t.check("the game's exit frees what is still held", Requisition._ahead.is_empty() and not is_instance_valid(scooter))
	quit(_t.verdict())


func _held() -> int:
	return Requisition._ahead_reads.size() + Requisition._ahead.size() + BowlDress._ahead.size()
