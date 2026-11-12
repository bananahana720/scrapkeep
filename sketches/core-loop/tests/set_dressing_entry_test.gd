# smoke: solo timeout=300s (verdict reads wall time: the set dressing's main-thread ms on two stage entries)
extends SceneTree

# MUSIC-SKIP-ENTRY (wave 38, 12 Nov 2026): the music skipped about 2,100 times in one burst on the
# PC just after a bot's run ended, and the main thread was what stopped. A stage entry the set
# dressing had no plan for drew its plan on the main thread: 0.54 s on a New run back on stage 1
# after a death on stage 2, and 3.5 s of a 4.6 s frozen frame entering the Dig (stage 3) after
# Brindle (cloud, 4 vCPU, headless). Now a New run builds from the plan it kept for stage 1, and
# an entry with no plan draws it on a worker and builds the frame it is done.
#
# Checked on the default table through the real flow, with the played game's threaded stage builds:
#   - a New run after a death on stage 2: the dressing's stage_entered handler stays within
#     NEW_DRESSING_MS (stage_entry_budget_test's budget for a new stage) and stage 1 is dressed;
#   - the Dig after Brindle's defeat: the handler stays within NEW_DRESSING_MS, the build is
#     deferred, and the Dig is dressed within DRESSING_FRAMES_MAX frames, from its own map.
# Evidence limit: wall time on a loaded box; the pre-fix handler took 540 ms and 3,500 ms here.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const NEW_DRESSING_MS := 15.0
# The Dig's plan takes about 3.5 s on a cloud worker; headless frames run unthrottled.
const DRESSING_FRAMES_MAX := 6000
const WAIT_FRAMES_MAX := 3600
const VICTORY_FRAMES_MAX := 1200

var _game
var _t := T.new("set_dressing_entry_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(1)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	await process_frame
	await process_frame
	_game.presentation.audio.bake_now()
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var dressing = _game.presentation.set_dressing
	if not _t.check("the default preset has a set dressing", dressing != null):
		_end()
		return
	await _frames(30)
	var terrain = _game.ctx.terrain
	terrain.prepare(2)
	var waited := 0
	while not terrain.is_ready(2) and waited < WAIT_FRAMES_MAX:
		await process_frame
		waited += 1
	_game.flow._finish_stage()
	await _frames(30)
	_t.eq("the run is on stage 2", _game.flow.stage(), 2)

	_game.events.player_died.emit()
	await _frames(5)
	_t.eq("the death ends the run", _game.flow.state_name(), "dead")
	_game.flow.new_run()
	var new_run_ms: float = dressing.last_entry_usec / 1000.0
	_t.eq("New run is back on stage 1", _game.flow.stage(), 1)
	_t.check("New run: the dressing's entry within %.0f ms" % NEW_DRESSING_MS, new_run_ms <= NEW_DRESSING_MS, "%.1f ms" % new_run_ms)
	var frames := await _dressed(dressing)
	_t.check("New run: stage 1 is dressed", frames >= 0 and dressing.map_id == String(_game.ctx.stages.of(1).map), "%d frames, map %s" % [frames, dressing.map_id])

	# Back to stage 2 and through Brindle into the Dig.
	_game.flow._finish_stage()
	await _frames(30)
	_game.flow._finish_stage()
	await _frames(30)
	_t.eq("stage 2's exit enters the boss", _game.flow.state_name(), "boss")
	_game.flow._on_boss_defeated()
	waited = 0
	while _game.flow.stage() != 3 and waited < VICTORY_FRAMES_MAX:
		await process_frame
		waited += 1
	_t.eq("the victory hands over to stage 3", _game.flow.stage(), 3)
	var dig_ms: float = dressing.last_entry_usec / 1000.0
	_t.check("the Dig: the dressing's entry within %.0f ms" % NEW_DRESSING_MS, dig_ms <= NEW_DRESSING_MS, "%.1f ms" % dig_ms)
	_t.check("the Dig: the build waits for a worker's plan", dressing.entry_deferred)
	frames = await _dressed(dressing)
	_t.check("the Dig is dressed from its own map", frames >= 0 and dressing.map_id == String(_game.ctx.stages.of(3).map) and dressing.built_from_worker,
		"%d frames, map %s" % [frames, dressing.map_id])
	print("set_dressing_entry_test: New run %.1f ms, the Dig %.1f ms, dressed %d frames later" % [new_run_ms, dig_ms, frames])
	_end()


# Frames until the dressing stands, or -1.
func _dressed(dressing) -> int:
	for i in DRESSING_FRAMES_MAX:
		if dressing.get_child_count() > 0 and not dressing._dress_when_planned:
			return i
		await process_frame
	return -1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _end() -> void:
	_game.queue_free()
	await process_frame
	quit(_t.verdict())
