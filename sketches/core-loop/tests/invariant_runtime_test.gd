extends SceneTree

# Runtime guards from the invariants pass (2026-11-08), on the real dam stage of the park table:
# a NaN shove reads as rest, a ball whose position went non-finite goes back to the stage
# entry instead of being teleported to NaN every tick, and combat finds its stage director.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

var t := T.new("invariant_runtime_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	game.flow.enter_stage(1, Vector3.ZERO, false)
	for i in 30:
		await physics_frame
	var body = game.player.body()
	t.check("combat finds the stage director", game.ctx.spawner._director() != null)
	body.set_velocity_now(Vector3(NAN, 0.0, 0.0))
	for i in 3:
		await physics_frame
	t.check("a NaN velocity reads as rest", game.player.state.velocity.is_finite() and body.linear_velocity.is_finite(),
		"%s / %s" % [game.player.state.velocity, body.linear_velocity])
	game.flow._rescue_if_fallen(Vector3(NAN, NAN, NAN))
	for i in 3:
		await physics_frame
	var at: Vector3 = game.player.ball_position()
	var entry = game.ctx.run.snapshot_value("entry_position")
	t.check("a non-finite ball goes back to the stage entry", at.is_finite() and entry is Vector3 and at.distance_to(entry) < 6.0,
		"ball %s entry %s" % [at, entry])
	quit(t.verdict())
