extends SceneTree

const Screens := preload("res://tests/support/menu_screens.gd")
const T := preload("res://tests/support/t.gd")

# UA-05 (principle P6): on every menu screen, every focusable control can be reached with the stick
# from the control that takes first focus. The walk follows the focus neighbour in each of the four
# stick directions (the engine's own pick, which honours a neighbour a screen sets) until no new control
# turns up. A control it never meets is named. A planted button with no neighbours must be found missing,
# so a clean result is not a blind walk. Tab (next/previous) is not followed: a stick has no Tab.

var _t := T.new("menu_reach_test")
var _kit := Screens.new()
var _screens_seen := 0
var _controls_seen := 0


func _initialize() -> void:
	_run.call_deferred()


# The control that takes first focus: what the screen focused, else (the title, where a pad's first push
# lands on the first button) the first focusable control in tree order.
func _first(scope: Node, all: Array) -> Control:
	var owner = scope.get_viewport().gui_get_focus_owner()
	if owner != null and all.has(owner):
		return owner
	return all[0] if not all.is_empty() else null


# Controls in `all` that the stick walk from `start` never meets.
func _unreached(start: Control, all: Array) -> Array:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var at: Control = queue.pop_front()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var next := at.find_valid_focus_neighbor(side)
			if next != null and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return all.filter(func(c): return not seen.has(c))


func _check(name: String, scope: Node) -> void:
	var all := Screens.focusables(scope)
	_screens_seen += 1
	_controls_seen += all.size()
	if all.is_empty():
		_t.check("%s: holds a focusable control" % name, false, "no enabled focusable control on this screen")
		return
	var start := _first(scope, all)
	var missed := _unreached(start, all).map(func(c): return Screens.label(c))
	_t.check("%s: all %d focusable controls reached from %s" % [name, all.size(), Screens.label(start)], missed.is_empty(), "not reached: %s" % str(missed))


func _run() -> void:
	await _kit.start(self)

	# Planted: a button with no neighbours, off to one side of two linked buttons, must be reported.
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
	a.set_focus_neighbor(SIDE_BOTTOM, b.get_path())
	b.set_focus_neighbor(SIDE_TOP, a.get_path())
	a.set_focus_neighbor(SIDE_RIGHT, a.get_path())
	a.set_focus_neighbor(SIDE_LEFT, a.get_path())
	a.set_focus_neighbor(SIDE_TOP, a.get_path())
	b.set_focus_neighbor(SIDE_LEFT, b.get_path())
	b.set_focus_neighbor(SIDE_RIGHT, b.get_path())
	b.set_focus_neighbor(SIDE_BOTTOM, b.get_path())
	await _kit_frames(2)
	var planted := _unreached(a, Screens.focusables(holder))
	_t.check("planted: the walk reports the button with no neighbours", planted == [lost], str(planted))
	holder.free()

	var count: int = await _kit.visit(_check)
	_t.check("covered %d screens and %d focusable controls" % [_screens_seen, _controls_seen], _screens_seen > 0 and _controls_seen > 0 and count == _screens_seen)
	print("menu_reach_test: covered %d screens, %d focusable controls" % [_screens_seen, _controls_seen])
	await _kit.finish()
	quit(_t.verdict())


func _kit_frames(n: int) -> void:
	for i in n:
		await process_frame
