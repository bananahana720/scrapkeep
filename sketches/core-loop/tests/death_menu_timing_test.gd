extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

# The death menu after "No free retry" (wave 19), and how fast a new run is rolling again.
#   (a) the dead screen (a flow with no run store keeps it) has no R and no Retry button; New run
#       (N) is the first button and the pad's A; C (choose class) stays; R does nothing; N enters
#       world 1 stage 1 as the same pilot.
#   (b) timing, on the real game's path (a run store on, so a death goes straight to the summary):
#       from player_died to the first physics frame where the new run is in play and the ball is not
#       frozen, N pressed the first physics frame the summary takes keys (nothing held, so no latch).
#       The number is printed in physics ticks and game seconds (sketch-lint L1 bans wall-clock
#       reads in tests, so wall ms was measured once outside the committed test) and asserted
#       against BAR_S of game time, and N to rolling against PRESS_BAR_S.
#       The dead-menu path is timed the same way.
#   (c) the input latch, on the same store path: Space, the fire button (left mouse) and N held
#       from before the death keep the summary shut for over a second (the old 0.75 s lock would
#       have lapsed), no key starts a run; after the release a fresh N rolls within PRESS_BAR_S. A warm-up run comes first on the
#       store path; the game's own first world build is not the restart. The headless run logs a
#       set_dressing "instantiate on null" script error (a missing kit asset), in other tests too.

const DIR := "user://death_menu_timing_test/"
const PATH := DIR + "run.json"
# The bars, game seconds: death to rolling in a new run, and a fresh press of N to rolling.
const BAR_S := 1.0
const PRESS_BAR_S := 0.1
const HELD_S := 1.2

var _t := T.new("death_menu_timing_test")
var _game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_run.call_deferred()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _boot(with_store: bool):
	var game := Game.new()
	game.test_mode = true
	if with_store:
		game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start_run(class_index: int) -> void:
	_game.flow.press_start()
	_game.flow.choose_class(class_index)
	await _frames(5)


func _rolling() -> bool:
	return _game.flow.in_play() and not _game.player.frozen() and not _game.run.over


# Dies, then presses N on the first physics frame its screen takes keys; returns the numbers.
func _time_new_run(screen: String) -> Dictionary:
	var ticks_hz: float = float(Engine.physics_ticks_per_second)
	var old_run: String = _game.run.run_id
	var at := {"tick": 0}
	var on_death := func():
		at["tick"] = Engine.get_physics_frames()
	_game.events.player_died.connect(on_death)
	var ended := [false]
	_game.events.run_ended.connect(func(_won: bool): ended[0] = true)
	_game.run.damage(9999.0, "test")
	await physics_frame
	var pressed_tick := -1
	var rolling_tick := -1
	var cap: int = int(ticks_hz * 6.0)
	for i in cap:
		var state: String = _game.flow.state_name()
		if pressed_tick < 0 and state == screen and not _game.summary_latched:
			pressed_tick = Engine.get_physics_frames()
			_game._screen_key(KEY_N)
		elif pressed_tick >= 0 and _game.run.run_id != old_run and _rolling():
			rolling_tick = Engine.get_physics_frames()
			break
		await physics_frame
	_game.events.player_died.disconnect(on_death)
	return {"death_to_press_ticks": pressed_tick - at["tick"], "press_to_rolling_ticks": rolling_tick - pressed_tick,
		"total_ticks": rolling_tick - at["tick"], "total_s": float(rolling_tick - at["tick"]) / ticks_hz, "hz": ticks_hz, "ok": rolling_tick >= 0 and pressed_tick >= 0, "ended": ended[0]}


func _run() -> void:
	# (a) the dead screen, no store.
	_game = _boot(false)
	await _frames(2)
	await _start_run(1)
	var pilot: String = _game.run.class_id()
	_game.run.damage(9999.0, "test")
	await _frames(2)
	var screens = _game.screens
	var text: String = screens.body_text()
	var actions: Array = screens._actions.get_children()
	var first_id := String(actions[0].action) if not actions.is_empty() else ""
	_t.check("dead screen is up", _game.flow.state_name() == "dead", "flow %s" % _game.flow.state_name())
	_t.check("no retry button and no R in the text", screens.button_for("retry") == null and not text.contains("retry") and not text.contains("R   "),
		text.replace("\n", " | "))
	_t.check("New run is the first button, on N", first_id == "new" and String(actions[0].key) == "key_n", "first button '%s'" % first_id)
	_t.check("Choose class stays", screens.button_for("class") != null, text.replace("\n", " | "))
	_t.eq("a pad A on the dead screen is N", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_N)
	# A stick player who has moved the highlight presses what is highlighted: A is left to the focused button.
	var chosen: Control = screens.button_for("class")
	chosen.grab_focus()
	_t.eq("a pad A with a button highlighted is left to that button", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_NONE)
	chosen.release_focus()
	_t.eq("a pad A with nothing highlighted is N again", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_N)
	_t.check("R does nothing on the dead screen", not _game._screen_key(KEY_R) and _game.flow.state_name() == "dead", "flow %s" % _game.flow.state_name())
	_game._screen_key(KEY_N)
	await _frames(3)
	var stages = _game.ctx.stages
	_t.check("N enters world 1 stage 1 as the same pilot", _game.flow.state_name() == "stage" and _game.run.stage == stages.first_of(1) and _game.run.world == 1 \
			and _game.run.class_id() == pilot and not _game.run.over and _game.run.hp == _game.run.max_hp,
		"flow %s stage %d world %d pilot %s (was %s) hp %.0f of %.0f" % [_game.flow.state_name(), _game.run.stage, _game.run.world, _game.run.class_id(), pilot, _game.run.hp, _game.run.max_hp])

	# (b) timing, the dead menu (no guard).
	await _frames(20)
	var dead_path: Dictionary = await _time_new_run("dead")
	print("TIMING dead menu: death to N %d ticks, N to rolling %d ticks, total %d ticks = %.3f s game time (%d Hz)" \
		% [dead_path["death_to_press_ticks"], dead_path["press_to_rolling_ticks"], dead_path["total_ticks"], dead_path["total_s"], int(dead_path["hz"])])
	_t.check("dead menu: death to rolling within %.2f s of game time" % BAR_S, dead_path["ok"] and dead_path["total_s"] <= BAR_S,
		"%.3f s (%d ticks)" % [dead_path["total_s"], dead_path["total_ticks"]])
	_game.free()

	# (b) timing, the summary on the real game's path (a store on: death ends the run).
	_game = _boot(true)
	await _frames(2)
	await _start_run(1)
	# One warm-up death and new run first, so the world's first build is not what is timed.
	_game.run.damage(9999.0, "test")
	await _frames(2)
	_game.flow.new_run()
	await _frames(20)
	var summary_path: Dictionary = await _time_new_run("summary")
	var rest_s: float = float(summary_path["press_to_rolling_ticks"]) / float(summary_path["hz"])
	print("TIMING summary: death to N %d ticks, N to rolling %d ticks = %.3f s, total %d ticks = %.3f s game time (%d Hz)" \
		% [summary_path["death_to_press_ticks"], summary_path["press_to_rolling_ticks"], rest_s, summary_path["total_ticks"], summary_path["total_s"], int(summary_path["hz"])])
	_t.check("summary: the death ended the run", summary_path["ended"], "run_ended %s" % summary_path["ended"])
	_t.check("summary: a fresh press of N to rolling within %.2f s" % PRESS_BAR_S, summary_path["ok"] and rest_s <= PRESS_BAR_S, "%.3f s (%d ticks)" % [rest_s, summary_path["press_to_rolling_ticks"]])
	_t.check("summary: nothing held, so no latch and the first frame takes N", summary_path["death_to_press_ticks"] <= 1, "%d ticks" % summary_path["death_to_press_ticks"])
	_t.check("summary: death to rolling within %.2f s" % BAR_S, summary_path["ok"] and summary_path["total_s"] <= BAR_S,
		"%.3f s (%d ticks)" % [summary_path["total_s"], summary_path["total_ticks"]])
	await _held_case()
	await _hold_r_case()
	_game.free()
	_clean()
	DirAccess.remove_absolute(DIR)
	quit(_t.verdict())


# Hold R mid-stage with a store: a new run in world 1 stage 1, the same pilot, no stage retry,
# no death (the save stays unspent, no run_ended, the old run is not a loss).
func _hold_r_case() -> void:
	_game.flow.new_run()
	await _frames(5)
	var pilot: String = _game.run.class_id()
	var old_run: String = _game.run.run_id
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 14.0), false)
	var retried := [0]
	var ended := [false]
	_game.events.stage_entered.connect(func(_s: int, retry: bool): retried[0] += 1 if retry else 0)
	_game.events.run_ended.connect(func(_w: bool): ended[0] = true)
	_game.step_restart_hold(0.1, true)
	_t.check("a short hold of R restarts nothing", _game.run.run_id == old_run and _game.run.stage == 3, "stage %d" % _game.run.stage)
	_game.step_restart_hold(_game.RESTART_HOLD, true)
	await _frames(3)
	var stages = _game.ctx.stages
	_t.check("hold R mid-stage starts a new run in world 1 stage 1, same pilot, no stage retry",
		_game.run.run_id != old_run and _game.run.stage == stages.first_of(1) and _game.run.world == 1 and _game.run.class_id() == pilot \
			and retried[0] == 0 and _game.flow.state_name() == "stage" and not _game.run.death_save_spent and not ended[0],
		"run %s to %s, stage %d world %d, pilot %s, stage retries %d, run_ended %s" % [old_run, _game.run.run_id, _game.run.stage, _game.run.world, _game.run.class_id(), retried[0], ended[0]])
	# The victory lap: a held R does not abandon the credits.
	_game.step_restart_hold(0.0, false)
	var lap_run: String = _game.run.run_id
	_game.flow._set_state(_game.flow.LAP)
	_game.step_restart_hold(_game.RESTART_HOLD, true)
	_t.check("hold R during the victory lap restarts nothing", _game.run.run_id == lap_run and _game.flow.state_name() == "lap",
		"flow %s, run %s (was %s)" % [_game.flow.state_name(), _game.run.run_id, lap_run])


# Holds or releases Space, the fire button and N in the Input singleton.
func _hold(down: bool) -> void:
	for code in [KEY_SPACE, KEY_N]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(click)
	Input.flush_buffered_events()


# Input held through the death keeps the summary shut for HELD_S; a fresh N after the release rolls.
func _held_case() -> void:
	_game.flow.new_run()
	await _frames(20)
	var ticks_hz: float = float(Engine.physics_ticks_per_second)
	var old_run: String = _game.run.run_id
	_hold(true)
	_game.run.damage(9999.0, "test")
	await physics_frame
	var skipped := false
	var ticks_held := int(ticks_hz * HELD_S)
	for i in ticks_held:
		for key in [KEY_N, KEY_SPACE, KEY_ENTER, KEY_K]:
			_game._screen_key(key)
		if _game.run.run_id != old_run or _game.flow.state_name() != "summary":
			skipped = true
			break
		await physics_frame
	_t.check("held Space, fire and N through the death: %.1f s later the summary is still up, no run started" % HELD_S,
		not skipped and _game.flow.state_name() == "summary" and _game.run.run_id == old_run and _game.summary_latched,
		"flow %s latched %s after %d ticks" % [_game.flow.state_name(), _game.summary_latched, ticks_held])
	_hold(false)
	await _frames(2)
	_t.check("after the release the latch is open", not _game.summary_latched, "latched %s" % _game.summary_latched)
	var pressed := Engine.get_physics_frames()
	_game._screen_key(KEY_N)
	var rolling := -1
	for i in int(ticks_hz * 2.0):
		if _game.run.run_id != old_run and _rolling():
			rolling = Engine.get_physics_frames() - pressed
			break
		await physics_frame
	print("TIMING held case: fresh N after release to rolling %d ticks = %.3f s (%d Hz), held %d ticks" % [rolling, float(rolling) / ticks_hz, int(ticks_hz), ticks_held])
	_t.check("after the release a fresh N rolls within %.2f s" % PRESS_BAR_S, rolling >= 0 and float(rolling) / ticks_hz <= PRESS_BAR_S, "%d ticks" % rolling)


func _pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e
