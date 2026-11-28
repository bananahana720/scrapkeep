extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

# The pilot cards level their wrapped text one frame after they are built. Opened from this
# script's _process, the frame signal that levels them comes before the containers' first sort,
# the order a key press takes in the game on a frame with no physics tick. A wrapped line then
# measured one letter wide, the row pinned that height, and every card's fantasy line and key
# rows fell off the card's floor. Two ways in: a first Start, whose prologue hides the row until
# it ends, and a plain open. For each, L1: every card's column fits its card. L2: the fantasy
# line keeps a two-line height. L3: every key cell ends inside its card. L4: with the line as the heading
# (the title row is hidden since wave 36; screens.PILOT_LINE, pinned here as LINE so new words are measured again) the line,
# the cards and the key hints row stack in that order without touching, all on the
# screen with a margin under the key row.

const LINE_MAX := 90.0
const SETTLE := 30
const WAYS := ["prologue", "open"]
const LINE := "Loose cannons, all of them. Pick one."
const EDGE := 8.0

var _t := T.new("ui_class_card_level_test")
var _game
var _way := -1
var _frame := 0
var _step := 0
var _mark := 0


func _initialize() -> void:
	_next_way()


func _next_way() -> void:
	if _game != null:
		_game.free()
		_game = null
	_way += 1
	if _way >= WAYS.size():
		quit(_t.verdict())
		return
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_frame = 0
	_step = 0


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frame += 1
	match _step:
		0:
			if _frame > 8:
				_game.screens.prologue_enabled = WAYS[_way] == "prologue"
				if WAYS[_way] == "prologue":
					_game.flow.press_start()
				else:
					_game.flow.open_class_select()
				_mark = _frame
				_step = 1
		1:
			if _frame - _mark == 4:
				if WAYS[_way] == "prologue":
					_t.check("prologue: a first Start shows it over the cards", _game.screens.prologue_showing(), "")
					var next: Button = _game.screens.button_for("prologue_next")
					_t.check("prologue: its Next button is on the screen (pilot select hides the action row, the prologue shows it)",
						next != null and next.is_visible_in_tree(), "next %s" % (next != null))
					_game.screens.end_prologue()
				_t.check("%s: the screen shows the pilot line it was measured with" % WAYS[_way], _game.screens.said_body() == LINE and _game.screens.PILOT_LINE == LINE,
					"body \"%s\"" % _game.screens.said_body())
				_mark = _frame
				_step = 2
		2:
			if _frame - _mark == SETTLE:
				_check(WAYS[_way])
				_next_way()
	return false


func _check(way: String) -> void:
	var cards: Array = _game.screens.class_cards()
	_t.check("%s: the pilot cards are built" % way, cards.size() >= 3, "%d cards" % cards.size())
	var spill := 0.0
	var tallest := 0.0
	var inside := true
	var worst := ""
	for card in cards:
		spill = maxf(spill, card.overflow())
		tallest = maxf(tallest, card.fantasy_label().size.y)
		var floor_y: float = card.get_global_rect().end.y + 0.5
		for cell in card.key_cells():
			if cell.get_global_rect().end.y > floor_y:
				inside = false
				worst = "%s cell ends at %.1f, card floor %.1f" % [card.def.id, cell.get_global_rect().end.y, floor_y]
	_t.check("%s: L1 every card's column fits its card" % way, is_zero_approx(spill), "overflow %.1f px" % spill)
	_t.check("%s: L2 the fantasy line keeps a two-line height" % way, tallest > 0.0 and tallest <= LINE_MAX, "tallest %.1f px" % tallest)
	_t.check("%s: L3 every key cell ends inside its card" % way, inside and not cards.is_empty(), worst)
	var screens = _game.screens
	var line: Rect2 = screens._body.get_global_rect()
	var keys: Rect2 = screens._footer.get_global_rect()
	var top := INF
	var bottom := 0.0
	for card in cards:
		top = minf(top, card.get_global_rect().position.y)
		bottom = maxf(bottom, card.get_global_rect().end.y)
	var floor_y: float = screens._screen().y - EDGE
	var stacked: bool = screens._body.visible and screens._footer.visible and not screens._title.visible and line.position.y >= 0.0
	stacked = stacked and line.end.y <= top and bottom <= keys.position.y and keys.end.y <= floor_y
	_t.check("%s: L4 line, cards and key hints stack on the screen" % way, stacked and not cards.is_empty(),
		"line %.0f-%.0f, cards %.0f-%.0f, keys %.0f-%.0f, floor %.0f" % [line.position.y, line.end.y, top, bottom,
			keys.position.y, keys.end.y, floor_y])
