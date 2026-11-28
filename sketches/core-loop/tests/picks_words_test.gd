extends SceneTree

# Wave 36 unit unslop-picks (ruling cx, no slop in anything the player meets). Every line a pick
# card draws, for every pilot, with the world-one flag on and off and the Riveted Shell fitted
# and not: the name, the effect, the ultimate line, the Build hover and the "taken" toast. None
# may type a key letter, carry a "label: value" colon, use a retired name (NAMES.md) or the word
# "pin", and every sentence holds the word limit. The checker is run first on the strings the
# base drew; it must flag every one of them, or its zero below means nothing. A broken card is
# built through the real TreeCard path and the same read must flag it too.

const T := preload("res://tests/support/t.gd")
const TreeCard := preload("res://src/ui/tree_card.gd")
const TreePick := preload("res://src/ui/tree_pick.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const BuildReadout := preload("res://src/ui/build_readout.gd")
const Parts := preload("res://src/build/parts.gd")

# The longest sentence a card line may carry (pick_card_clarity_test holds the first sentence of a
# world-one row to the same eight).
const SENTENCE_WORDS := 8
# Lower case; matched as whole words or phrases in each drawn text.
const BANNED := ["set piece", "stockpile", "stockpiles", "stock", "hands back", "hand back", "give back", "gives back",
	"refund", "refunds", "recharge", "recharges", "rebound", "rebounds", "the gauge", "enemy", "enemies", "foes",
	"pin", "pins", "unknown stat", "kit depth", "grapple"]
# Key letters that a rebindable key could carry; "A" and "I" are words.
const KEY_LETTERS := ["Q", "E", "F", "V", "P", "R", "H", "J", "K", "X", "C", "Z"]
# What the base drew, line for line. Every one must be flagged.
const PLANTED := ["Third talon rakes wider. Q: Rake Run", "Set piece: Ball Lightning", "Planting throws enemies into pins",
	"Skids throw enemies into pins", "Stockpile two sticky throws", "Stock two clamps. Q: Vice Leap",
	"Slams spend F on a full discharge", "Each surge hands back your air jump", "Rebounds refill a detonation charge",
	"Pulls refund your air jump. Q: Vice Leap", "Kills recharge claw pulls. Q: Vice Leap", "The gauge fills twice as fast airborne",
	"Kit depth by world: 2 · 3 · 4", "Kit: Long Claw", "Fewer, bigger charges: two live", "Q lasts two beats longer.",
	"Audit Trail: stamp what you steer over.", "Unknown stat"]
const PLAIN := ["Third talon rakes wider. Ultimate becomes Rake Run.", "Ultimate becomes Ball Lightning.",
	"Planting throws machines twice as hard", "Bank two sticky throws", "Long Claw taken",
	"Picks go 2 deep in world 1, 3 in world 2, 4 in world 3.", "Two live charges, each bigger"]

var t := T.new("picks_words_test")


func _initialize() -> void:
	_planted()
	_broken_card()
	_every_card()
	_unknown_stat()
	quit(t.verdict())


# What a drawn text breaks: a retired word, a typed key, a label colon.
func hits(text: String) -> Array:
	var out := []
	var lower := text.to_lower()
	var tokens: Array = []
	for token in lower.split(" ", false):
		tokens.append(token.strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix(";"))
	for word in BANNED:
		var found: bool = word in tokens if not " " in word else lower.contains(word)
		if found:
			out.append(word)
	for token in text.split(" ", false):
		var bare := token.strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix(":").trim_suffix("'s")
		if bare in KEY_LETTERS:
			out.append("typed key %s" % bare)
	if ": " in text or text.ends_with(":"):
		out.append("label colon")
	return out


# The sentences of a line that run past the word limit.
func long_sentences(text: String) -> Array:
	var out := []
	for sentence in text.replace(";", ".").split(".", false):
		if WordBudget.words_in(sentence) > SENTENCE_WORDS:
			out.append(sentence.strip_edges())
	return out


func _planted() -> void:
	for text in PLANTED:
		t.check("planted base text is flagged: %s" % text, not hits(text).is_empty(), str(hits(text)))
	for text in PLAIN:
		t.check("a plain line is not flagged: %s" % text, hits(text).is_empty(), str(hits(text)))
	t.check("a sentence over the limit is flagged", not long_sentences("One two three four five six seven eight nine.").is_empty())
	t.check("a sentence at the limit is not", long_sentences("One two three four five six seven eight.").is_empty())


# The same read, through the real card, on a node whose effect is the base's wording.
func _broken_card() -> void:
	var node := {"id": "t_raking_claws", "name": "Raking Claws", "effect": "Third talon rakes wider. Q: Rake Run",
		"key": "weapon", "icon": "ab_tarn_weapon", "swap": {"ultimate": "rake_run"}}
	var card := TreeCard.new(node, "key_1", Color.WHITE, 3, false, false, WorldOneCards.SET_PIECE_LINES, "tarn")
	var found := hits(card.effect_text())
	t.check("a broken card is flagged through the card's own path", "label colon" in found and "typed key Q" in found, str(found))
	card.free()
	var piece := {"id": "s_x", "name": "X", "effect": "Fine", "key": "movement", "icon": "ab_sable_move", "swap": {"ultimate": "ball_lightning"}}
	var table := WorldOneCards.SET_PIECE_LINES.duplicate()
	table["ball_lightning"] = "Set piece: Ball Lightning"
	var broken := TreeCard.new(piece, "key_1", Color.WHITE, 3, false, false, table, "pylon_engineer")
	t.check("a broken ultimate line is flagged through the card's own path", not hits(broken.set_piece_text()).is_empty(), broken.set_piece_text())
	broken.free()


func _every_card() -> void:
	var seen := 0
	var lines := {}
	var swaps := 0
	for pilot in UpgradeTree.TREES:
		for world_one in [false, true]:
			for shell in [false, true]:
				var nodes: Array = UpgradeTree.nodes(pilot, world_one)
				t.check("%s world one %s: the tree has nodes" % [pilot, world_one], nodes.size() >= 6, str(nodes.size()))
				for n in nodes:
					var depth := 3 if n.has("swap") or n.has("knob") else 1
					if shell == false and world_one == false and WordBudget.words_in(String(n.get("effect", ""))) > UpgradeTree.EFFECT_WORDS:
						t.check("%s %s: the effect fits %d words" % [pilot, n["id"], UpgradeTree.EFFECT_WORDS], false, String(n["effect"]))
					var card := TreeCard.new(n, "key_1", Color.WHITE, depth, world_one, shell, WorldOneCards.SET_PIECE_LINES, pilot)
					for text in [String(n.get("name", "")), card.effect_text(), card.set_piece_text()]:
						if text == "" or lines.has(text):
							continue
						lines[text] = true
						seen += 1
						var found := hits(text)
						if not found.is_empty():
							t.check("%s %s: '%s' is plain" % [pilot, n["id"], text], false, str(found))
						var long := long_sentences(text)
						if not long.is_empty():
							t.check("%s %s: '%s' fits %d words a sentence" % [pilot, n["id"], text, SENTENCE_WORDS], false, str(long))
					if n.get("swap", {}).has("ultimate") and world_one == false and shell == false:
						swaps += 1
						t.check("%s %s: the card says the ultimate changes" % [pilot, n["id"]],
							card.effect_text().contains("Ultimate becomes") or card.set_piece_text() != "", card.effect_text())
					card.free()
	t.check("many distinct card lines were read", seen >= 300, "%d lines" % seen)
	t.check("the ultimate swaps were read", swaps >= 30, "%d swap cards" % swaps)
	# The hover is read on demand, not on the card face, so it is held to the plain-word checks and not the
	# sentence limit.
	var probe := TreeCard.new(UpgradeTree.nodes("tarn")[0], "key_1", Color.WHITE, 2)
	var hover := probe.depth_text()
	probe.free()
	t.check("the hover is plain", hits(hover).is_empty(), hover)
	t.check("the hover reads as one sentence", hover == "Picks go 2 deep in world 1, 3 in world 2, 4 in world 3.", hover)
	var toast := TreePick.TAKEN_TOAST % "Long Claw"
	t.check("the taken toast is plain", hits(toast).is_empty() and toast == "Long Claw taken", toast)


# "Unknown stat" is what the Build popup draws for a stat key the readout has no words for. It can
# show only for a part that gives a changed stat the table lacks; every part, at one copy and at
# three, is read here.
func _unknown_stat() -> void:
	var missing := {}
	var parts := 0
	for id in Parts.ids():
		var d: Resource = Parts.def(id)
		if d == null:
			continue
		parts += 1
		var pools: Array = []
		for copies in [1, 3]:
			pools.append_array(BuildReadout._bonuses(d, copies))
		if not d.levels.is_empty():
			for level in range(1, 4):
				var at: Resource = Parts.def_at(id, level)
				if at != null:
					pools.append_array(BuildReadout._level_bonuses(at, id))
		for pool in pools:
			if String(pool["change"]) != "" and not BuildReadout.STAT_WORDS.has(String(pool["key"])):
				missing[String(pool["key"])] = id
	t.check("parts were read for the unknown-stat check", parts >= 30, "%d parts" % parts)
	t.check("no part's changed stat falls to 'Unknown stat'", missing.is_empty(), str(missing))
	t.check("a missing key is the one way to 'Unknown stat'", not BuildReadout.STAT_WORDS.has("no_such_stat"))
