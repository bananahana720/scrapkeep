extends SceneTree

const Game := preload("res://src/game.gd")
const Screens := preload("res://src/ui/screens.gd")
const T := preload("res://tests/support/t.gd")

# The main menu (decisions.tsv 2026-10-16 alpha-scope): a fresh title reads SCRAPKEEP and offers
# Play, Camp, Settings, Help, Achievements and Quit in that order; Play is the primary button and
# goes to pilot select; Quit sits on Esc; the name stamps in from a tilt and rests straight;
# reduced motion shows it at rest at once.

var _t := T.new("ui_main_menu_test")


func _initialize() -> void:
	_run.call_deferred()


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
	screens._on_flow_changed("title")
	_t.check("the name stamps in", screens._stamp_tween != null and screens._stamp_tween.is_valid())
	await _frames(2)
	var order: Array = screens._actions.get_children().map(func(b): return b.action)
	_t.eq("the fresh menu's buttons, in order", order, ["start", "camp", "settings", "help", "achievements", "quit"])
	_t.eq("the primary reads Play", screens.button_for("start").text, "Play")
	_t.check("Play is the primary button", screens.button_for("start").has_meta("primary"))
	var quit: Button = screens.button_for("quit")
	_t.check("Quit is on Esc", quit != null and quit.key == "key_esc" and quit.text == "Quit")
	_t.eq("the title reads SCRAPKEEP", screens._title.text, Screens.TITLE)
	# W1-47: the name is drawn art laid inside the label, which keeps the word for screen readers.
	_t.check("the title shows the drawn wordmark", screens._wordmark.visible and screens._wordmark.texture != null
		and screens._wordmark.get_parent() == screens._title)
	_t.eq("the label draws no glyphs of its own", screens._title.get_theme_color("font_color"), Color.TRANSPARENT)
	_t.check("the band starts below the wordmark", screens._veil.anchor_top > 0.0 and screens._veil.anchor_top < 0.5,
		str(screens._veil.anchor_top))
	_t.eq("the ready line names the launch set and the open pilots", screens.ready_line(1234),
		"SCRAPKEEP_MENU_READY ms=1234 profile=default pilots=1/6")

	# Steps the stamp past its end on the tween's own clock, not the wall clock.
	screens._stamp_tween.custom_step(Screens.STAMP_TIME + 0.2)
	await _frames(1)
	_t.near("the name rests straight", screens._title.rotation, 0.0, 0.001)
	_t.near("the name rests at full size", screens._title.scale.x, 1.0, 0.001)

	game.flow.press_start()
	await _frames(3)
	_t.eq("Play opens pilot select", game.flow.state_name(), "class_select")

	game.camera.reduced_motion = true
	game.flow.show_title()
	await _frames(2)
	_t.check("reduced motion shows the name at rest at once", screens._title.scale == Vector2.ONE and screens._title.rotation == 0.0,
		"rotation %s scale %s" % [screens._title.rotation, screens._title.scale])
	game.free()
	quit(_t.verdict())
