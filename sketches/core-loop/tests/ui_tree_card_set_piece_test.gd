extends SceneTree

const TreeCard := preload("res://src/ui/tree_card.gd")
const Cards := preload("res://src/core/trees/world_one_cards.gd")
const T := preload("res://tests/support/t.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# The tree card's set-piece line (SKILL-BAR section 12, item 5), wave 13 unit b6b, 2026-10-11.
# The shipped SET_PIECE_LINES table is still empty until the P-C units fill it, so the card
# takes a table argument and this test feeds it a stand-in; one check reads the shipped table
# so it starts to bite when rows land. Evidence limit: label text, visibility and measured
# heights headless, not how the card looks on screen.

const TABLE := {
	"stand_in": "Lands a second shockwave.",
	"ult_pins": "Pins last longer.",
	"stand_long": "Each shockwave pins the crowd.",
}


func _initialize() -> void:
	var t := T.new("ui_tree_card_set_piece_test")
	var by_swap := {"id": "x_a", "name": "Aftershock", "effect": "own effect", "key": "ultimate", "swap": {"ultimate": "stand_in"}}
	var by_knob := {"id": "x_b", "name": "Longer pins", "effect": "own effect", "key": "ultimate", "knob": {"ult_pins": 2.0}}
	var plain := {"id": "x_c", "name": "Plain", "effect": "own effect", "key": "weapon", "knob": {"blast_pull": true}}
	for flag in [false, true]:
		for depth in [1, 2, 3, 4]:
			var tag := "flag %s depth %d" % [flag, depth]
			var card = TreeCard.new(by_swap, "key_1", Color.ORANGE, depth, flag, true, TABLE)
			root.add_child(card)
			t.eq("1 swap line at %s" % tag, card.set_piece_text(), TABLE["stand_in"])
			t.eq("2 effect line unchanged at %s" % tag, card.effect_text(), "own effect")
			card.queue_free()
			var knob_card = TreeCard.new(by_knob, "key_1", Color.ORANGE, depth, flag, true, TABLE)
			root.add_child(knob_card)
			t.eq("3 ult_ knob line at %s" % tag, knob_card.set_piece_text(), TABLE["ult_pins"])
			knob_card.queue_free()
			var plain_card = TreeCard.new(plain, "key_1", Color.ORANGE, depth, flag, true, TABLE)
			root.add_child(plain_card)
			t.eq("4 no line at %s" % tag, plain_card.set_piece_text(), "")
			t.check("5 label hidden at %s" % tag, not plain_card.set_piece_visible(), "")
			plain_card.queue_free()
	var shipped = TreeCard.new(by_swap, "key_1", Color.ORANGE, 3)
	root.add_child(shipped)
	t.eq("6 default table is the shipped one", shipped.set_piece_text(), Cards.set_piece_line(by_swap))
	shipped.queue_free()
	# Fit: the longest line, the table's own when it has rows, else the stand-in.
	var table: Dictionary = Cards.SET_PIECE_LINES if not Cards.SET_PIECE_LINES.is_empty() else TABLE
	var longest := ""
	var longest_id := ""
	for id in table:
		if String(table[id]).length() > longest.length():
			longest = String(table[id])
			longest_id = String(id)
	var long_node := {"id": "x_l", "name": "Aftershock Overload", "effect": "Smash scatters five payloads.", "key": "ultimate", "swap": {"ultimate": longest_id}}
	var fit = TreeCard.new(long_node, "key_1", Color.ORANGE, 4, true, true, table)
	root.add_child(fit)
	await process_frame
	await process_frame
	var box: Control = fit.get_child(0)
	var sum := 0.0
	var parts := []
	for label in box.get_children():
		if label.visible:
			sum += label.get_combined_minimum_size().y
			parts.append(snappedf(label.get_combined_minimum_size().y, 0.1))
	sum += 6.0 * (parts.size() - 1)
	var room: float = TreeCard.HEIGHT - 14.0 - (box.global_position.y - fit.global_position.y)
	t.check("7 three labels fit the card", sum <= room,
		"heights %s with separations = %.1f of %.1f px for \"%s\" (box %.1f)" % [parts, sum, room, longest, box.size.y])
	# The longest world-one effect line on a plain card (the run's first pick has no set piece line).
	var wordiest := ""
	var wordiest_id := ""
	for id in Cards.ROWS:
		if String(Cards.ROWS[id]).length() > wordiest.length():
			wordiest = String(Cards.ROWS[id])
			wordiest_id = String(id)
	var first = TreeCard.new({"id": wordiest_id, "name": "Aftershock Overload", "effect": "x", "key": "movement"}, "key_1", Color.ORANGE, 1, true, true, table)
	root.add_child(first)
	await process_frame
	await process_frame
	var first_box: Control = first.get_child(0)
	var first_sum := 0.0
	var first_parts := []
	for label in first_box.get_children():
		if label.visible:
			first_sum += label.get_combined_minimum_size().y
			first_parts.append(snappedf(label.get_combined_minimum_size().y, 0.1))
	first_sum += 6.0 * (first_parts.size() - 1)
	var first_room: float = TreeCard.HEIGHT - 14.0 - (first_box.global_position.y - first.global_position.y)
	t.check("7b the longest world-one line fits a plain card", first.effect_text() == wordiest and first_sum <= first_room,
		"heights %s with separations = %.1f of %.1f px for \"%s\"" % [first_parts, first_sum, first_room, wordiest])
	# The number key that takes the card is its only keycap; the slot's key is not drawn (PF-01).
	t.check("8 drawn_words counts the pick keycap only", fit.drawn_words() == Keycap.words("key_1"), "got %s" % [fit.drawn_words()])
	quit(t.verdict())
