extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("pilot_reactions_slam_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	await process_frame
	var seen: Array = []
	game.events.drop_landed.connect(func(hits: int): seen.append(["drop_landed", hits]))
	game.events.missed_drop.connect(func(): seen.append(["missed_drop", 0]))
	game.events.evolution_fired.connect(func(id: String): seen.append(["evolution_fired", id]))
	var player = game.player
	var far: Vector3 = player.ball_position() + Vector3(500, 0, 500)
	player._on_slammed(far, 30.0, 1.0)
	_t.eq("a slam on nothing emits missed_drop", seen, [["missed_drop", 0]])
	seen.clear()
	var enemy = game.combat.spawn_enemy("chaser", far + Vector3(2, 0, 0))
	player._on_slammed(far, 30.0, 1.0)
	_t.eq("a slam with an enemy in reach emits drop_landed(1)", seen, [["drop_landed", 1]])
	seen.clear()
	player._on_slammed(far, 30.0, 0.0)
	_t.eq("a slam into a launch emits neither", seen, [])
	enemy.free()
	game.free()
	quit(_t.verdict())
