extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")

# A charge hit shoves the ball through Brindle's hull and cuts away the hull parts over it. If the last chunk is
# caught inside the shove's grace, the cutaway must end with the fight: no hull part stays see-through over the ball.

var _t := T.new("brindle_defeat_cutaway_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await physics_frame
	game.player.source = Intent.Scripted.new()
	Harness.start_run(game)
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	var boss = game.boss
	var ship = boss.ship
	var hull := ship.model.find_child("Hull", true, false) as MeshInstance3D
	game.ctx.calm = false
	game.run.max_hp = 1000.0
	game.run.hp = 1000.0
	var at: Vector3 = ship.global_position + Vector3.UP * 2.0
	Harness.put_ball(game, at)
	boss._commit_charge(at)
	boss._charge_hit(boss._charge["hazard"], at)
	await physics_frame
	_t.check("D0 the shove cuts the hull away over the ball", hull.transparency > 0.8, "transparency %.2f" % hull.transparency)
	Harness.defeat(game)
	await physics_frame
	_t.check("D1 defeat inside the grace makes the hull opaque again", hull.transparency == 0.0, "transparency %.2f" % hull.transparency)
	game.free()
	quit(_t.verdict())
