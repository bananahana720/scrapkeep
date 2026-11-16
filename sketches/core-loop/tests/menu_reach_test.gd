extends SceneTree

const Screens := preload("res://tests/support/menu_screens.gd")
const T := preload("res://tests/support/t.gd")

# UA-05 (principle P6): on every menu screen, every focusable control can be reached with the stick
# from the control the game focuses when the screen opens. The walk pushes the left stick up, down, left
# and right through the viewport (so the game's own row handlers and the engine's focus search both
# answer, as for a player), reads the focus owner after each push, and explores from every control it
# reaches until no new one turns up. A control it never meets is named. Two plants must be found missing:
# a button with no neighbours (the engine path) and a focusable control put in a settings page but left
# out of the page's row list (the custom path). Tab is not followed: a stick has no Tab.

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


func _run() -> void:
	await _kit.start(self)

	# Plant 1: a button with no neighbours, off to one side of two linked buttons.
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

	# Plant 2: a focusable control in the title settings page's box that its row list does not hold.
	# The page's own handler steps through that list, so the engine's nearest-control search is not used.
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
	_t.check("covered %d screens and %d focusable controls" % [_screens_seen, _controls_seen], _screens_seen > 0 and _controls_seen > 0 and count == _screens_seen)
	print("menu_reach_test: covered %d screens, %d focusable controls" % [_screens_seen, _controls_seen])
	print("menu_reach_test: not covered: %s" % str(_kit.uncovered))
	await _kit.finish()
	quit(_t.verdict())
