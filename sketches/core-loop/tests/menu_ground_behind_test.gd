extends SceneTree

# MENU-READY (measured 2026-10-18 on main f9f58944, exported build, cloud headless): the main menu
# showed about 6 s after launch, 2 s of it stage 1's park ground and 0.5 s its set dressing, both
# built synchronously in setup. A played game now builds that ground on worker threads behind the
# menu, parks the title ball once it is built, and dresses the stage from a worker's plan.
#
# Checked with ground_behind_menu on: the menu shows before stage 1's ground is built; once built,
# the ball sits on its spawn point and the dressing came from a worker and equals a fresh plan.
# A run started before the ground is built enters stage 1 on it, its ball where it would start
# on ground built in setup.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const WAIT_TICKS_MAX := 1200

var _t := T.new("menu_ground_behind_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = _game()
	var terrain = game.ctx.terrain
	_t.check("the menu shows before stage 1's ground is built", game.flow.state_name() == "title" and not terrain.is_ready(1), game.flow.state_name())
	var waited := 0
	while not (terrain.is_ready(1) and game.presentation.set_dressing.get_child_count() > 0) and waited < WAIT_TICKS_MAX:
		await process_frame
		waited += 1
	_t.check("stage 1's ground and dressing are built behind the menu", terrain.is_ready(1) and game.presentation.set_dressing.get_child_count() > 0, "%d frames" % waited)
	_t.check("the title ball sits on stage 1's spawn point", game.player.body().global_position.is_equal_approx(terrain.spawn_point(1)), str(game.player.body().global_position))
	_check_dressing(game)
	game.free()

	# The same start with stage 1 built in setup, for where its ball should start.
	var want := await _start(false)
	var got := await _start(true)
	_t.check("a run started before the ground is built enters stage 1 on it", got.stage == 1 and got.ready, str(got))
	_t.check("its ball starts where a run on ground built in setup starts", got.ball.is_equal_approx(want.ball), "%s, want %s" % [got.ball, want.ball])
	await physics_frame
	quit(_t.verdict())


func _start(behind: bool) -> Dictionary:
	var game = _game(behind)
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	var out := {"stage": game.flow.stage(), "ready": game.ctx.terrain.is_ready(1), "ball": game.player.body().global_position}
	game.free()
	return out


func _game(behind := true):
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = behind
	root.add_child(game)
	return game


func _check_dressing(game) -> void:
	var dressing = game.presentation.set_dressing
	_t.check("the dressing was built from a worker's plan", dressing.built_from_worker == true)
	var terrain = game.ctx.terrain
	var map = terrain.map_for(1)
	var fresh: Dictionary = dressing.plan(dressing.map_rows(map), dressing.keepouts(map, 1), terrain.ground_callable(1),
		String(game.ctx.stages.of(1).map).hash(), dressing._flags())
	var want := {"BrokenRock": fresh.get("rock"), "DustMotes": fresh.get("dust"), "SandStreaks": fresh.get("streaks")}
	for kit in fresh.get("clutter", {}):
		want["Clutter_" + kit] = fresh.clutter[kit]
	var mismatches := PackedStringArray()
	for batch in dressing.batches:
		if want.get(batch.name) == null or batch.get_meta("instance_buffer") != want[batch.name]:
			mismatches.append(batch.name)
	_t.check("the dressing's instance buffers equal a fresh plan", not dressing.batches.is_empty() and mismatches.is_empty(), ", ".join(mismatches))
