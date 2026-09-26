extends RefCounted

const SpawnerDouble := preload("res://tests/doubles/boss_spawner_double.gd")

# Shared setup for the boss tests: the spawner double in place of combat, a run started,
# and the ball put into the arena through the spine's own seam (flow.enter_boss), so
# the boss module under test is the one game.gd set up.


static func install(game) -> Node:
	var double := SpawnerDouble.new()
	game.add_child(double)
	double.setup(game.ctx)
	game.ctx.spawner = double
	return double


static func start_run(game) -> void:
	game.flow.press_start()
	game.flow.choose_class(0)


static func enter(game, velocity: Vector3) -> void:
	game.flow.enter_boss(velocity)


static func put_ball(game, at: Vector3, velocity := Vector3.ZERO) -> void:
	game.player.body().global_position = at
	game.player.reset_to(at, velocity)


# The ball resting on the bowl's ground at an arena bearing and radius.
static func ground_spot(boss, angle: float, r: float, lift := 1.0) -> Vector3:
	return boss.arena.point_at(angle, r, lift)


static func planar(game) -> float:
	return game.player.planar_velocity().length()
