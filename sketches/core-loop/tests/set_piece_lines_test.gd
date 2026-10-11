extends SceneTree

const Cards := preload("res://src/core/trees/world_one_cards.gd")
const T := preload("res://tests/support/t.gd")

# The depth-3 and depth-4 card line reader (SKILL-BAR section 12, item 5), wave P-B unit B6
# fix round, 2026-10-11. The shipped table is empty until the P-C units fill it, so the reader
# is exercised on a stand-in table. Evidence limit: the lookup, not the tree card drawing it.

const PILOTS := ["Sable", "Rivet", "Kest", "Tarn", "Tally", "Cannon"]


func _initialize() -> void:
	var t := T.new("set_piece_lines_test")
	var src := FileAccess.get_file_as_string("res://src/core/trees/world_one_cards.gd")
	var rows_at := src.find("const ROWS")
	var table_at := src.find("const SET_PIECE_LINES")
	t.check("1 SET_PIECE_LINES follows ROWS", table_at > rows_at and rows_at >= 0, "")
	for p in PILOTS:
		var marker := "# --- end %s ---" % p
		var at := src.find(marker)
		t.check("2 %s has a marked block inside SET_PIECE_LINES" % p, at > table_at, "")
		t.check("3 %s has no marked block in ROWS" % p, src.substr(rows_at, table_at - rows_at).find(marker) == -1, "")
	var table := {"stand_in": "Lands a second shockwave.", "ult_pins": "Pins last longer."}
	var by_swap := {"id": "x_a", "effect": "own", "swap": {"ultimate": "stand_in"}}
	var by_knob := {"id": "x_b", "effect": "own", "knob": {"ult_pins": 2.0}}
	var plain := {"id": "x_c", "effect": "own", "swap": {"smash": "stand_in"}, "knob": {"blast_pull": true}}
	t.eq("4 a swap to a seeded ultimate reads its line", Cards.set_piece_line(by_swap, table), "Lands a second shockwave.")
	t.eq("5 an ult_ knob reads its line", Cards.set_piece_line(by_knob, table), "Pins last longer.")
	t.eq("6 a node with neither reads empty", Cards.set_piece_line(plain, table), "")
	t.eq("7 the shipped table reads empty for an unseeded node", Cards.set_piece_line(by_swap), "")
	t.eq("8 the reader takes no flag; the node's own effect shows on or off",
		[Cards.effect_line(by_swap, true, true), Cards.effect_line(by_swap, false, true)], ["own", "own"])
	quit(t.verdict())
