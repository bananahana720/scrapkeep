extends SceneTree

const Game := preload("res://src/game.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const T := preload("res://tests/support/t.gd")

# The pilot cards level their wrapped text one frame after they are built. Opened from this
# script's _process, the frame signal that levels them comes before the containers' first sort,
# the order a key press takes in the game on a frame with no physics tick. A wrapped line then
# measured one letter wide, the row pinned that height, and every card's fantasy line and key
# rows fell off the card's floor. L1: opened that way, every card's column fits its card. L2: the
# fantasy line keeps a two-line height. L3: every key cell ends inside its card.

const LINE_MAX := 90.0

var _t := T.new("ui_class_card_level_test")
var _game
var _open_at := -1
var _frame := 0
var _checked := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	_frame += 1
	if _game.flow == null or _checked:
		return false
	if _open_at < 0 and _frame > 8:
		_game.flow.open_class_select()
		_open_at = _frame
	elif _open_at >= 0 and _frame - _open_at == 30:
		_checked = true
		_check()
	return false


func _check() -> void:
	var cards: Array = _game.screens.class_cards()
	_t.check("the pilot cards are built", cards.size() >= 3, "%d cards" % cards.size())
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
	_t.check("L1 every card's column fits its card", is_zero_approx(spill), "overflow %.1f px" % spill)
	_t.check("L2 the fantasy line keeps a two-line height", tallest > 0.0 and tallest <= LINE_MAX, "tallest %.1f px" % tallest)
	_t.check("L3 every key cell ends inside its card", inside and not cards.is_empty(), worst)
	quit(_t.verdict())
