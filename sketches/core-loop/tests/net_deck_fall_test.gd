extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Deck := preload("res://tests/doubles/map_net_deck_double.gd")
const T := preload("res://tests/support/t.gd")

# A fall below a declared net deck puts the ball on the deck with half its horizontal speed
# and costs nothing: no player_died, no hp lost, the flow still in its stage. The control
# puts the stage's own map back and drops the ball under the ground: today's rescue_point
# rule still answers. Counted in physics frames; none reads the wall clock.

var _t := T.new("net_deck_fall_test")
var _game
var _deaths := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	Harness.start_run(_game)
	var waited := 0
	while _game.flow.state_name() != "stage" and waited < 600:
		await physics_frame
		waited += 1
	_t.eq("run is in stage 1", [_game.flow.state_name(), _game.run.stage], ["stage", 1])
	_game.ctx.events.player_died.connect(func() -> void: _deaths += 1)
	var original = _game.ctx.terrain.maps[_game.run.stage - 1]
	var hp: int = _game.run.hp
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)

	# Align with a physics_frame boundary before placing the ball so the next physics tick's
	# flow._physics_process() always runs before the following await physics_frame resumes.
	await physics_frame
	_game.ctx.terrain.maps[_game.run.stage - 1] = Deck.new()
	Harness.put_ball(_game, Vector3(spawn.x, Deck.NET_H - 10.0, spawn.z), Vector3(8.0, -20.0, 0.0))
	await physics_frame
	var ball: Vector3 = _game.player.ball_position()
	_t.near("deck: ball stands on the deck", ball.y, Deck.NET_H + Tuning.RADIUS, 0.5)
	_t.near("deck: horizontal speed damped to half", _game.player.planar_velocity().length(), 4.0, 0.5)
	_t.eq("deck: no player_died", _deaths, 0)
	_t.eq("deck: hp unchanged", _game.run.hp, hp)
	_t.eq("deck: flow still in stage", _game.flow.state_name(), "stage")

	_game.ctx.terrain.maps[_game.run.stage - 1] = original
	var ground: float = _game.ctx.terrain.height(spawn.x, spawn.z)
	Harness.put_ball(_game, Vector3(spawn.x, ground - 20.0, spawn.z), Vector3(8.0, -20.0, 0.0))
	var want: Vector3 = _game.ctx.terrain.rescue_point(Vector3(spawn.x, ground - 20.0, spawn.z))
	await physics_frame
	ball = _game.player.ball_position()
	_t.near("control: rescue_point height", ball.y, want.y, 1.5)
	_t.check("control: not on a deck", ball.y > ground - 5.0, "ball y %.2f, ground %.2f" % [ball.y, ground])
	_t.eq("control: no player_died", _deaths, 0)
	_game.free()
	quit(_t.verdict())
