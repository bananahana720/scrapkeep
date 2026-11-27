extends SceneTree

const Screens := preload("res://tests/support/menu_screens.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("menu_reach_test")
var _kit := Screens.new()
var _screens_seen := 0
var _controls_seen := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, scope: Node, showing: bool) -> void:
	_screens_seen += 1
	if not _t.check("%s: is the screen showing" % name, showing):
		return
	var all := Screens.focusables(scope)
	_controls_seen += all.size()
	if all.is_empty():
		_t.check("%s: holds a focusable control" % name, false, "no enabled focusable control on this screen")
		return
	var first := _kit.first_focus()
	var start: Control = first["start"]
	if start == null:
		_t.check("%s: a stick push puts focus on a control" % name, false, "nothing focused, even after ui_down")
		return
	if first["pushed"]:
		print("menu_reach_test: %s opens with nothing focused; one ui_down sent" % name)
	var missed := _kit.unreached(start, all).map(func(c): return Screens.label(c))
	_t.check("%s: all %d focusable controls reached by the stick from %s" % [name, all.size(), Screens.label(start)], missed.is_empty(), "not reached: %s" % str(missed))


func _visit_extended() -> int:
	var count := 0
	var screens = _kit.screens
	var game = _kit.game

	screens._on_flow_changed("title")
	await process_frame
	await process_frame
	screens._actions.visible = false
	screens._camp.set_walk(false)
	screens._camp.visible = true
	screens._camp.refresh(game)
	await process_frame
	await process_frame
	var camp_buttons := Screens.focusables(screens._camp)
	if not camp_buttons.is_empty():
		camp_buttons[0].grab_focus()
	await process_frame
	await _check("camp menu strip", screens._camp, screens._camp.visible and not screens._camp.walk)
	count += 1

	var customize = screens._camp.customize
	customize.reduced_motion = true
	customize._open_from_camp()
	await process_frame
	await process_frame
	var stray_custom := Button.new()
	stray_custom.text = "StrayCustom"
	customize._column.add_child(stray_custom)
	await process_frame
	await process_frame
	var custom_all := Screens.focusables(customize)
	var custom_start: Control = _kit.first_focus()["start"]
	var custom_missed: Array = _kit.unreached(custom_start, custom_all)
	_t.check("planted: customize page walk catches stray focusable outside ORDER", custom_missed == [stray_custom], str(custom_missed))
	stray_custom.free()
	await process_frame
	customize.focus("pilot")
	await process_frame
	await _check("customize page", customize, customize.visible)
	count += 1
	customize.close()
	screens._camp.visible = false
	screens._actions.visible = true
	await process_frame

	game.flow.show_title()
	game.flow.press_start()
	await process_frame
	game.pick_pilot(0)
	await process_frame
	await process_frame
	await process_frame
	var profile = game.ctx.profile
	profile.earn(RunTier.UNLOCK, 1.0)
	profile.set_stat(RunTier.BEST_STAT, float(RunTier.TOP))
	var card = game.flow.start_card
	card.set_interactive(true)
	card.set_briefing(true)
	card.show_picks(game.run, profile)
	await process_frame
	await process_frame
	if root.gui_get_focus_owner() != null:
		root.gui_get_focus_owner().release_focus()
	await process_frame
	await _check("start card", card, card.showing())
	count += 1
	card.hide_card()
	await process_frame
	return count


func _run() -> void:
	await _kit.start(self)

	var holder := Control.new()
	holder.size = Vector2(400, 300)
	root.add_child(holder)
	var a := Button.new()
	a.text = "A"
	a.position = Vector2(0, 0)
	a.size = Vector2(100, 50)
	var b := Button.new()
	b.text = "B"
	b.position = Vector2(0, 100)
	b.size = Vector2(100, 50)
	var lost := Button.new()
	lost.text = "Lost"
	lost.position = Vector2(300, 250)
	lost.size = Vector2(100, 50)
	for button in [a, b, lost]:
		holder.add_child(button)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		lost.set_focus_neighbor(side, lost.get_path())
		a.set_focus_neighbor(side, a.get_path())
		b.set_focus_neighbor(side, b.get_path())
	a.set_focus_neighbor(SIDE_BOTTOM, b.get_path())
	b.set_focus_neighbor(SIDE_TOP, a.get_path())
	await process_frame
	await process_frame
	var planted: Array = _kit.unreached(a, Screens.focusables(holder))
	_t.check("planted: the walk reports the button with no neighbours", planted == [lost], str(planted))
	holder.free()

	var pages = _kit.screens.settings_page()
	_kit.screens._on_flow_changed("title")
	_kit.screens.toggle_settings()
	await process_frame
	pages.show_page(0)
	pages.focus_first()
	var stray := Button.new()
	stray.text = "Stray"
	pages._boxes["display"].add_child(stray)
	await process_frame
	await process_frame
	var seen_all := Screens.focusables(_kit.screens)
	var start: Control = _kit.first_focus()["start"]
	var missed_plant: Array = _kit.unreached(start, seen_all)
	_t.check("planted: the walk reports the stray control left out of a page's row list", missed_plant == [stray], str(missed_plant))
	stray.free()
	_kit.screens.toggle_settings()
	await process_frame

	var count: int = await _kit.visit(_check)
	count += await _visit_extended()
	_t.check("covered %d screens and %d focusable controls" % [_screens_seen, _controls_seen], _screens_seen >= 20 and _controls_seen > 0 and count == _screens_seen)
	print("menu_reach_test: covered %d screens, %d focusable controls" % [_screens_seen, _controls_seen])
	await _kit.finish()
	quit(_t.verdict())
