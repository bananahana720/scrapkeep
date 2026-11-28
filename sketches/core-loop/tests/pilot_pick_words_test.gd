extends SceneTree

# Wave 36 unit unslop-pilot (ruling cx, no slop in anything the player meets). For every pilot,
# on a fresh profile and on a profile that owns paint and has a win, the open pilot card and
# Moss's start pick draw no word the game has not taught, no repeated sentence, no line over
# eight words, no typed key letter, and no empty paint row. The checker is run first on the
# strings the base drew; it must flag every one of them, or its zero below means nothing.

const T := preload("res://tests/support/t.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Profile := preload("res://src/core/profile.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const StartPickCard := preload("res://src/ui/start_pick_card.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

const LINE_WORDS := 8
# Lower case; matched as substrings of each drawn text.
const BANNED := ["set piece", " · ", " + ", "no paint", "boss-mirror", "linked payoff", "crowd control is fuel",
	"the gauge", "grapple", "rebound"]
# Key letters that a rebindable key could carry; "A" and "I" are words.
const KEY_LETTERS := ["Q", "E", "F", "V", "P", "R", "H", "J", "K", "X", "C", "Z"]
# What the base drew, line for line (card rows and tiles). Every one must be flagged.
const PLANTED := ["Boss-mirror cannon · rebuilt ancient", "glide + rocket", "set piece", "No paint",
	"Linked payoff, needs pressure from rolling.", "Unstoppable sprinter. Crowd control is fuel.",
	"arc discharge from the gauge", "Pull Q to fire"]

var t := T.new("pilot_pick_words_test")
var events := GameEvents.new()
var _serial := 0


func _initialize() -> void:
	_planted()
	for won in [false, true]:
		_pass(won)
	events.free()
	quit(t.verdict())


# The words of one drawn text that a first-time player has not been taught, or a line too long.
func hits(text: String) -> Array:
	var out := []
	var lower := text.to_lower()
	for word in BANNED:
		if lower.contains(word):
			out.append(word)
	for token in text.split(" ", false):
		var bare := token.strip_edges().trim_suffix(",").trim_suffix(".")
		if bare in KEY_LETTERS:
			out.append("typed key %s" % bare)
	return out


func _planted() -> void:
	for text in PLANTED:
		t.check("planted base text is flagged: %s" % text, not hits(text).is_empty(), str(hits(text)))
	t.check("a plain line is not flagged", hits("Fire faster").is_empty() and hits("A win opens harder runs").is_empty())
	# Kest's line keeps the name the relics use for it (relics.gd: "Detonation line recharges…",
	# "Stock a second detonation line"): one name for one thing.
	t.eq("Kest's line reads as the relics name it", ClassKit.WORDS["detonation_line"], "detonation line")
	# No tier has been shown to a profile with no win, so the unlock line names none.
	t.check("the unlock line names no tier", not StartPickCard.UNLOCK_WORDS.to_lower().contains("tier"), StartPickCard.UNLOCK_WORDS)


func _profile(won: bool) -> Profile:
	_serial += 1
	var profile := Profile.new("user://pilot-pick-words-%d-%d.json" % [OS.get_process_id(), _serial])
	profile.load_profile()
	if won:
		profile.earn("first_win", 1.0)
	return profile


func _owned_paint(def: Resource) -> String:
	for id in Cosmetics.for_slot("paint", def.id):
		if not Cosmetics.row(id)["starter"]:
			return id
	return ""


func _texts(node: Node, out: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Label and (node as Label).text != "":
		out.append((node as Label).text)
	elif node is Button and (node as Button).text != "":
		out.append((node as Button).text)
	for child in node.get_children():
		_texts(child, out)


func _pass(won: bool) -> void:
	var tag := "win and paint" if won else "fresh"
	var seen := {}
	var start_words := []
	for def in ClassDef.all():
		var profile := _profile(won)
		var paint := _owned_paint(def)
		if won:
			profile.unlock_cosmetic(paint)
		var card := ClassCard.new(def, "key_1", 420.0)
		root.add_child(card)
		card.bind_profile(profile)
		var texts := []
		_texts(card, texts)
		t.check("%s %s: the open card draws text" % [tag, def.id], texts.size() >= 6, str(texts))
		for text in texts:
			var found := hits(String(text))
			t.check("%s %s card: '%s' is plain" % [tag, def.id, text], found.is_empty(), str(found))
			t.check("%s %s card: '%s' fits %d words" % [tag, def.id, text, LINE_WORDS], WordBudget.words_in(String(text)) <= LINE_WORDS)
		# Sentences are the fantasy line's and the tradeoff's; none may stand on two cards.
		for text in [card.fantasy_label().text, card.tradeoff_text()]:
			for sentence in String(text).split(". ", false):
				var bare := sentence.strip_edges().trim_suffix(".")
				t.check("%s %s sentence '%s' is on one card" % [tag, def.id, bare], bare != "" and not seen.has(bare), str(seen.get(bare, "")))
				t.check("%s %s sentence '%s' fits %d words" % [tag, def.id, bare, LINE_WORDS], WordBudget.words_in(bare) <= LINE_WORDS)
				seen[bare] = def.id
		var row := card.get("_paint_row") as Control
		t.check("%s %s: the paint row is %s" % [tag, def.id, "drawn" if won else "absent"], row.visible == won)
		if won:
			t.check("%s %s: the swatch is there with no label while no paint is chosen" % [tag, def.id],
				paint != "" and card.paint_shown() == "" and not (card.get("_paint_label") as Label).visible)
			card.free()
		else:
			card.free()
		start_words.append(_start_pick(def, profile, won, tag))
	t.check("%s: start pick words per pilot %s" % [tag, start_words], true)


func _start_pick(def: Resource, profile: Profile, won: bool, tag: String) -> int:
	var run := RunState.new(events, 7)
	run.begin(def)
	run.enter_stage(1)
	var card := StartPickCard.new()
	root.add_child(card)
	card.set_interactive(true)
	card.set_briefing(true)
	card.show_picks(run, profile)
	var texts := []
	for word in card.drawn_words():
		texts.append(String(word))
	_texts(card, texts)
	t.check("%s %s start pick: three tiles and words" % [tag, def.id], card.tiles().size() == StartPicks.OFFERED and texts.size() >= 6, str(texts))
	for text in texts:
		var found := hits(String(text))
		t.check("%s %s start pick: '%s' is plain" % [tag, def.id, text], found.is_empty(), str(found))
		t.check("%s %s start pick: '%s' fits %d words" % [tag, def.id, text, LINE_WORDS], WordBudget.words_in(String(text)) <= LINE_WORDS)
	# No screen tells a first win that a tier opened, so the unlock line stays the one carrier of
	# that fact on a fresh profile (reported to the coordinator; the line is not removed).
	t.check("%s %s start pick: the unlock line is %s" % [tag, def.id, "gone with the ladder" if won else "the one carrier"],
		(StartPickCard.UNLOCK_WORDS in card.drawn_words()) == not won)
	var words := 0
	for text in card.drawn_words():
		words += WordBudget.words_in(String(text))
	card.free()
	return words
