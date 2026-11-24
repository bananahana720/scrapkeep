extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const MossBubble := preload("res://src/ui/moss_bubble.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# The speech bubble with a caller on the line (moss_bubble.gd, caller_tile.gd): the caller's
# plate stands at the bubble's left with the name on its tag, and the bubble holds the words.
#   B1  a call brings the caller's plate up; the bubble shows the words alone, and `text` keeps
#       the whole line, name and all.
#   B2  the words start clear of the plate and under the name tag, and the card is on the screen.
#   B3  the bubble's edge takes the caller's colour.
#   B4  a pilot's call wears the pilot's screen colour (Sable's is not mint), by the name the row uses.
#   B5  a speaker nobody drew keeps the plain "Name: words" bubble.
#   B6  a site crew's hello line and a boss's intro line get their plate too.
#   B7  Moss's counter talk after a call is his own bubble again: no plate, the tail to the edge.
#   B8  clearing the line takes the plate with it.
#   B9  a hushed call's plate stops babbling at once, and nobody is on the line once it is down.
# smoke: timeout=120s

var _t := preload("res://tests/support/t.gd").new("ui_caller_bubble_test")
var _game
var _bubble


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_bubble = _game.get_node("Workshop").bubble
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 4:
		await physics_frame
	_bubble._clear_line()
	var tile = _bubble.get_node("Caller")
	var label: Label = _bubble._label

	_bubble._present("pump_crew", "Camp's quiet.", 2.0)
	await process_frame
	_t.check("B1 a call brings its caller's plate up and the bubble holds the words alone", _bubble.caller() == "pump_crew" and tile.visible
			and tile.talking() and label.text == "Camp's quiet." and _bubble.text == "Pump crew: Camp's quiet.",
		"caller '%s', label '%s', text '%s'" % [_bubble.caller(), label.text, _bubble.text])
	var plate_right: float = tile.position.x + CallerTile.SIDE
	var tag_bottom: float = tile.position.y - CallerTile.TAG_H * 0.55 + CallerTile.TAG_H
	var card := Rect2(_bubble.global_position, _bubble.size)
	var screen: Rect2 = _bubble.get_viewport().get_visible_rect()
	_t.check("B2 the words start clear of the plate and under its name tag, on the screen", label.position.x >= plate_right
			and label.position.y >= tag_bottom and screen.encloses(Rect2(card.position, Vector2(card.size.x, _bubble._body.y))),
		"label at %s, plate to %.0f, tag to %.0f, card %s" % [label.position, plate_right, tag_bottom, card])
	_t.check("B3 the bubble's edge is the caller's colour", tile.tint() == CallerTile.CALLERS["pump_crew"]["color"], str(tile.tint()))

	var sable = null
	for def in _game.flow.classes:
		if String(def.display_name) == "Sable":
			sable = def
	_bubble._present("sable", "Three at once. Show-off.", 1.0)
	_t.check("B4 a pilot's call wears the pilot's colour", sable != null and _bubble.caller() == "sable" and tile.hands() == "keeper"
			and tile.tint() == ClassDef.screen_color(sable.color) and tile.tint() != sable.color and label.text == "Three at once. Show-off.", "caller '%s', label '%s'" % [_bubble.caller(), label.text])

	_bubble._present("nobody_drew_this", "Hello.", 0.0)
	_t.check("B5 a speaker nobody drew keeps the plain bubble", _bubble.caller() == "" and not tile.visible and label.text == "nobody_drew_this: Hello."
			and is_zero_approx(_bubble._lead), "caller '%s', label '%s', lead %.0f" % [_bubble.caller(), label.text, _bubble._lead])

	_bubble._exchange = [{"speaker": "Flume crew", "text": "Morning. Mind the sluice."}]
	_bubble._exchange_index = 0
	_bubble._show_exchange_line()
	var crew_ok: bool = _bubble.caller() == "flume_crew" and label.text == "Morning. Mind the sluice." and _bubble.text == "Flume crew: Morning. Mind the sluice."
	_bubble._exchange = []
	_bubble._intro_queue = [{"intro_key": "test.brindle", "text": "Brindle: On schedule."}]
	_bubble._clear_line()
	# The run's own hello is still waiting for the cold open's card, and an intro waits behind
	# a waiting hello (bubble_gives_way_test B2). The plate is this check's subject.
	_bubble._hello_due = 0
	_bubble._flush_intro()
	_t.check("B6 a crew's hello line and a boss's intro line get their plate", crew_ok and _bubble.caller() == "brindle" and tile.hands() == "fleet"
			and label.text == "On schedule." and _bubble.text == "Brindle: On schedule.", "crew %s, caller '%s', label '%s', text '%s'" % [crew_ok, _bubble.caller(), label.text, _bubble.text])
	_bubble._end_intro()

	_bubble._present("mind", "A sensible choice.", 1.0)
	_bubble.bark({"line_id": "test", "text": "Not for sale.", "root": ""}, "shop_refused")
	_t.check("B7 Moss's counter talk after a call is his own bubble again", _bubble.caller() == "" and not tile.visible and label.text == "Not for sale."
			and is_zero_approx(_bubble._lead) and is_zero_approx(_bubble._head) and is_equal_approx(label.position.x, MossBubble.TAIL + MossBubble.PAD.x),
		"caller '%s', label '%s' at %s" % [_bubble.caller(), label.text, label.position])

	_bubble._present("moss", "I packed for either way.", 1.0)
	var moss_up: bool = tile.visible and tile.hands() == "hatch"
	_bubble._clear_line()
	_t.check("B8 clearing the line takes the plate with it", moss_up and not tile.visible and _bubble.caller() == "", "moss up %s, plate %s" % [moss_up, tile.visible])

	_bubble._present("flume_crew", "Mind the sluice.", 3.0)
	var babbling: bool = tile.talking()
	_bubble.hush()
	var still: bool = not tile.talking()
	# The fade is timed, not counted in frames: step its tween past the end, whatever the frame rate.
	_bubble._tween.custom_step(1.0)
	_t.check("B9 a hushed call's plate stops babbling at once and the line is free once it is down", babbling and still and not _bubble.visible
			and _bubble.caller() == "", "babbling %s, still %s, bubble up %s, caller '%s'" % [babbling, still, _bubble.visible, _bubble.caller()])
	_game.free()
	quit(_t.verdict())
