# 2026-10-12 FIXTURE-ADAPT: bd3e0ed added wrapping Tradeoff text; reserve a fixed-height slot above the keys.
extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Sequence := preload("res://src/ui/ending_sequence.gd")
const T := preload("res://tests/support/t.gd")

# The screens a player sees first and last (wave 11 UI1):
#   UI1-1 the title's Start is the one filled primary button and the title has no Breath
#         button; the settings page has one under the ACE music and none under the synth;
#   UI1-2 class select says how to choose and start, and all six cards share one text baseline;
#   UI1-3 the ending clears the achievement toasts, its letterbox bars are opaque, the copy is
#         off the establish frames, and the credits roll never enters the hint band.

var _t := T.new("screens_first_last_test")


func _initialize() -> void:
	_run.call_deferred()


func _primary(button: Button) -> bool:
	var box := button.get_theme_stylebox("normal") as StyleBoxFlat
	return button.has_meta("primary") or box.bg_color == Palette.AMBER


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await _frames(3)
	var screens = game.screens
	screens.prologue_enabled = false
	game.ctx.calm = true
	game.tuning.set_option(Tuning.MUSIC_KEY, "ace")
	screens._on_flow_changed("title")
	await _frames(2)
	var start: Button = screens.button_for("start")
	_t.check("UI1-1 Start is the primary button", start != null and start.has_meta("primary") and _primary(start)
		and (start.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Palette.AMBER)
	var others: Array = screens._actions.get_children().filter(func(b): return b != start)
	_t.check("UI1-1 no other title button is primary", not others.is_empty() and others.all(func(b): return not _primary(b)))
	_t.check("UI1-1 Start is taller than the rest", others.all(func(b): return start.custom_minimum_size.y > b.custom_minimum_size.y))
	_t.check("UI1-1 the title has no Breath button", screens.button_for("breath") == null)
	screens.toggle_settings()
	_t.check("UI1-1 the settings page has no Breath button outside --dev", screens.button_for("breath") == null)
	screens.toggle_settings()
	var was_dev: bool = game.dev
	game.dev = true
	screens.toggle_settings()
	_t.check("UI1-1 with --dev the settings page has a Breath button", screens.button_for("breath") != null
		and screens.button_for("breath").text == "Breath %s" % game.tuning.option(Tuning.BREATH_KEY))
	screens.toggle_settings()
	game.tuning.set_option(Tuning.MUSIC_KEY, "synth")
	screens.toggle_settings()
	_t.check("UI1-1 the synth hides the Breath button", screens.button_for("breath") == null)
	screens.toggle_settings()
	game.dev = was_dev

	game.flow.press_start()
	await _frames(4)
	var cards: Array = screens.class_cards()
	# The first unlocked card opens (PF-40); the baselines below are the cards at rest.
	root.gui_release_focus()
	for i in 40:
		await process_frame
	_t.eq("UI1-2 six cards", cards.size(), 6)
	_t.eq("UI1-2 the footer is the Enter cap and start", screens._footer.text(), "Enter start")
	_t.check("UI1-2 the footer shows", screens._footer.visible)
	for row in [["name", func(c): return c.name_label()], ["role", func(c): return c.role_label()],
			["words", func(c): return c.get_child(0).get_child(3)], ["keys", func(c): return c.key_cells()[0]]]:
		var ys: Array = cards.map(func(c): return snappedf(row[1].call(c).global_position.y - c.global_position.y, 0.5))
		_t.check("UI1-2 all six cards share one %s baseline" % row[0], ys.all(func(y): return y == ys[0]), str(ys))

	game.flow.choose_class(1)
	await _frames(2)
	# The cold open has the floor first (one voice at a time, ruling cf): a plate waits for its
	# card, so the run's opening flourish is ended before the plate is asked for.
	game.presentation.flourish.stop_all()
	game.events.achievement_earned.emit("first_win")
	game.hud._step_ach(0.1)
	_t.check("UI1-3 a toast is up before the ending", not game.hud.ach_toasts().is_empty())
	game.events.achievement_earned.emit("first_win")
	# test_mode sets bot_driven, and screens.gd closes a bot's ending after ENDING_HOLD (1 s of
	# frame time). The credits loop below waits 30 frames: under a second alone, over it on a
	# loaded box, where the roll was freed mid-loop and the next call on it crashed (signal 11).
	# This part plays the human, as the ending tests do.
	game.bot_driven = false
	screens.start_ending_sequence()
	var seq = screens.ending_sequence
	seq.set_process(false)
	_t.check("UI1-3 the toast queue is empty when the ending starts", game.hud.ach_toasts().is_empty() and game.hud.ach_waiting().is_empty())
	for bar in seq.letterbox_bars():
		_t.check("UI1-3 letterbox bars are opaque", bar.color.a == 1.0 and bar.modulate.a == 1.0, str(bar.color))
	for world in 3:
		for local in [0.0, 1.0, 1.4]:
			seq.elapsed = world * Sequence.WORLD_SECONDS + local
			seq.advance(0.0)
			_t.eq("UI1-3 world %d copy is off at %.1f s" % [world + 1, local], seq._copy.text, "")
	game.events.achievement_earned.emit("first_win")
	game.hud._step_ach(0.1)
	_t.check("UI1-3 no toast shows during the ending", game.hud.ach_toasts().is_empty() and game.hud.ach_waiting().is_empty())
	var band: Rect2 = seq.hint_band_rect()
	_t.check("UI1-3 the hint band is %d px at the bottom" % int(Sequence.HINT_BAND), band.size.y == Sequence.HINT_BAND and is_equal_approx(band.end.y, 900.0), str(band))
	var most := 0.0
	for step in 15:
		seq.elapsed = Sequence.WORLD_SECONDS * 3.0 + step * Sequence.CREDITS_SECONDS / 15.0
		seq.advance(0.0)
		await _frames(2)
		if not is_instance_valid(seq):
			_t.check("UI1-3 the ending stays open through credits step %d" % step, false, "the sequence was freed mid-roll")
			break
		var seen: Rect2 = seq.credits_rect()
		most = maxf(most, seen.end.y)
		_t.check("UI1-3 credits step %d stays out of the hint band" % step, not seen.intersects(band), "%s vs %s" % [seen, band])
	_t.check("UI1-3 the credits did scroll through the room above the band", most > 300.0 and most <= band.position.y, str(most))
	game.free()
	quit(_t.verdict())
