extends SceneTree

# Replays one counterexample of the rule TakeNamesHeldPart on the real game, one model step per call:
#   GateTaken (a real part is taken, the swipe starts and names it), NewRun (flow.new_run, the call a held R
#   or the pause menu's Restart makes), TakeWind (the swipe closes).
# It prints REPRODUCED when the swipe closes naming a part the new run does not hold, NOT REPRODUCED otherwise.
# Copy it into sketches/core-loop/tests/ to run it (SKILL.md, "Read a result"); it is not a suite test.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")

const PART := "impact_driver"

var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	var take = _game.launch_take
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	flow.press_start()
	await _frames(2)
	_game._screen_key(KEY_1)
	await _frames(2)
	print("step 0: state %s stage %d parts %s" % [flow.state_name(), _game.run.stage, str(_game.run.parts)])
	# GateTaken: a hand on the controls, so the swipe is live.
	take.force_live = true
	flow._set_state(flow.GATES)
	_game.ctx.build._on_gate_chosen(PART)
	take.set_process(false)
	print("step GateTaken: state %s take phase %d word '%s' wordless %s parts %s" % [flow.state_name(), take.phase, take._word.text, take._wordless, str(_game.run.parts)])
	# NewRun during the wind.
	flow.new_run()
	print("step NewRun: state %s stage %d take phase %d word '%s' wordless %s parts %s" % [flow.state_name(), _game.run.stage, take.phase, take._word.text, take._wordless, str(_game.run.parts)])
	# TakeWind and the cover: step the swipe to full cover.
	var guard := 0
	while take.phase != LaunchTake.HOLD and take.busy() and guard < 600:
		take.advance(1.0 / 60.0)
		guard += 1
	take.advance(1.0 / 60.0)
	var named: bool = take._word.visible and take._word.text != LaunchTake.WORD
	var held: bool = PART in _game.run.parts
	print("step cover: take phase %d word '%s' visible %s, run holds the part: %s" % [take.phase, take._word.text, take._word.visible, held])
	if named and not held:
		print("new_run_under_swipe: REPRODUCED (the swipe names '%s', the run holds %s)" % [take._word.text, str(_game.run.parts)])
	else:
		print("new_run_under_swipe: NOT REPRODUCED")
	quit()
