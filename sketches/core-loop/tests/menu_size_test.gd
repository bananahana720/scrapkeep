extends SceneTree

const Screens := preload("res://tests/support/menu_screens.gd")
const T := preload("res://tests/support/t.gd")

# UA-09 (principle P7): on every menu screen, every visible button or focusable control is at least
# 44 px wide and tall at the project's base resolution (1600x900, no scaling). A planted 30 px button must
# be flagged, so a clean result is not a blind scan. tools/ui_capture.gd holds the same rule on stills.

const MIN := 44.0

var _t := T.new("menu_size_test")
var _kit := Screens.new()
var _screens_seen := 0
var _controls_seen := 0


func _initialize() -> void:
	_run.call_deferred()


# Controls under `scope` smaller than MIN in either direction, on the screen (global transform applied).
func _small(scope: Node) -> Array:
	var out := []
	for c in Screens.targets(scope):
		var size: Vector2 = c.get_global_transform_with_canvas().get_scale() * c.size
		if size.x < MIN or size.y < MIN:
			out.append("%s %.0fx%.0f" % [Screens.label(c), size.x, size.y])
	return out


func _check(name: String, scope: Node, showing: bool) -> void:
	_screens_seen += 1
	if not _t.check("%s: is the screen showing" % name, showing):
		return
	var all := Screens.targets(scope)
	_controls_seen += all.size()
	var small := _small(scope)
	_t.check("%s: all %d buttons and focusable controls are %d px or more" % [name, all.size(), int(MIN)], small.is_empty(), "too small: %s" % str(small))


func _run() -> void:
	await _kit.start(self)

	var holder := Control.new()
	root.add_child(holder)
	var plant := Button.new()
	plant.name = "Tiny"
	plant.custom_minimum_size = Vector2(30, 30)
	plant.size = Vector2(30, 30)
	holder.add_child(plant)
	var big := Button.new()
	big.text = "Big"
	big.position = Vector2(100, 0)
	big.size = Vector2(60, 60)
	holder.add_child(big)
	await process_frame
	var flagged := _small(holder)
	_t.check("planted: the 30 px button is flagged and the 60 px one is not", flagged.size() == 1 and flagged[0].contains("Tiny"), str(flagged))
	# Plant 2: a plain Control that takes clicks through its own _gui_input, 20 px square, neither a button
	# nor focusable (the shape of the pilot card's paint swatch). The scan must see and flag it.
	var hand := Control.new()
	hand.name = "HandMade"
	hand.set_script(preload("res://tests/support/click_plant.gd"))
	holder.add_child(hand)
	hand.position = Vector2(200, 0)
	hand.size = Vector2(20, 20)
	await process_frame
	var flagged2 := _small(holder)
	_t.check("planted: a 20 px control that takes clicks by hand is flagged", flagged2.size() == 2 and str(flagged2).contains("HandMade"), str(flagged2))
	holder.free()

	var count: int = await _kit.visit(_check)
	_t.check("covered %d screens and %d buttons or focusable controls" % [_screens_seen, _controls_seen], _screens_seen > 0 and _controls_seen > 0 and count == _screens_seen)
	print("menu_size_test: covered %d screens, %d controls" % [_screens_seen, _controls_seen])
	await _kit.finish()
	quit(_t.verdict())
