extends SceneTree

# Wave 36 unit unslop-codex (ruling cx, no slop in anything the player meets). Every codex
# entry (combat and world), every field note the Tab page keeps (the tester notes, the
# questions, the first-run tips, the key list and the screen keys), every achievement line, every
# companion piece and every ending credit line reads as plain sentences in the game's one set
# of names: no typed key letter, no label-colon, no exclamation mark, no retired name, no
# sentence over the limit, and one name for each codex card. The checker is run first on the
# strings the base drew; it must flag each of them, or its zero below means nothing.

const T := preload("res://tests/support/t.gd")
const CombatEntries := preload("res://src/combat/codex_entries.gd")
const CodexWorld := preload("res://src/world/codex_world.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Companion := preload("res://src/core/companion.gd")
const EndingSequence := preload("res://src/ui/ending_sequence.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")

const SENTENCE_WORDS := 30
# Lower case; matched as substrings of each shown text.
const BANNED := ["set piece", "rebound", "grapple", "rivet plating", "cracked plating", "stockpile", "press q", "press e",
	"restart the run", " · "]
# Whole words, lower case, punctuation stripped.
const BANNED_WORDS := ["foe", "foes", "enemy", "enemies", "mass", "combo", "latch", "slot", "slots"]
# Key letters a rebindable key could carry; "A" and "I" are words.
const KEY_LETTERS := ["Q", "E", "F", "V", "P", "R", "H", "J", "K", "X", "C", "Z", "N", "T"]
# What the base drew, line for line. Every one must be flagged by the checker.
const PLANTED := [
	"a full ultimate meter + Q", "Fill the meter and press Q. The ball rides a drawn path.", "Set Piece",
	"Never attacks: it braces a dish over a partner.", "Jump the instant a deflector's dish throws you back and the rebound becomes a vault",
	"Growth is heft: scrap you roll up becomes mass, parts add more", "As Sable, hit a steep face at speed, press E, fire with left mouse",
	"Get scrapped on purpose, then hold R: a new run", "Ram hits shove foes out of their wind-up.", "Strike!",
	"Spillway crews come out of the channel soaked: arc hits them for 150% (ZZAP!).", "Hook an enemy, swing off a wall",
	"Perched on a mast, it reaches you by grapple", "Godot · Blender",
]

var t := T.new("codex_notes_words_test")


func _initialize() -> void:
	_planted()
	_codex()
	_notes()
	_achievements()
	_companion_and_credits()
	quit(t.verdict())


# The problems in one shown text. `rules` texts also refuse a label-colon; a long sentence fails any text.
func hits(text: String, rules := true, vocab := true) -> Array:
	var out := []
	var lower := text.to_lower()
	for word in BANNED:
		if lower.contains(word):
			out.append(word.strip_edges())
	for token in text.split(" ", false):
		var bare := token.strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix(";")
		if bare in KEY_LETTERS:
			out.append("typed key %s" % bare)
		if vocab and bare.to_lower() in BANNED_WORDS:
			out.append(bare.to_lower())
	if text.contains("!"):
		out.append("exclamation")
	if rules and text.contains(": "):
		out.append("label-colon")
	for sentence in text.replace("; ", ". ").split(". ", false):
		if sentence.split(" ", false).size() > SENTENCE_WORDS:
			out.append("sentence over %d words" % SENTENCE_WORDS)
			break
	return out


func _planted() -> void:
	for text in PLANTED:
		t.check("planted base text is flagged: %s" % text, not hits(text).is_empty(), str(hits(text)))
	t.check("a plain line is not flagged", hits("Pick 3 and click while a line stands. You whip round the anchor.").is_empty())
	var long_line := " ".join(range(SENTENCE_WORDS + 1).map(func(i): return "word"))
	t.check("planted: a sentence of %d words is flagged" % (SENTENCE_WORDS + 1), not hits(long_line).is_empty())


func _check(label: String, text: String, rules := true) -> void:
	var found := hits(text, rules)
	t.check("%s is plain: %s" % [label, text.left(60)], found.is_empty(), str(found))


func _codex() -> void:
	var names := {}
	var rows := 0
	for entry in CombatEntries.all() + CodexWorld.ENTRIES:
		rows += 1
		var id: String = entry["id"]
		for field in ["name", "hint", "clue", "text"]:
			_check("codex %s %s" % [id, field], String(entry.get(field, "")), true)
		var shown := FieldNotes.hint_card_text("◆", String(entry["hint"]), String(entry["clue"]))
		t.check("codex %s undiscovered card has no label-colon" % id, not shown.contains(": "), shown)
		var card_name := String(entry["name"])
		t.check("codex %s: the name '%s' is on one card" % [id, card_name], not names.has(card_name), String(names.get(card_name, "")))
		names[card_name] = id
	t.check("read a full codex", rows >= 60, str(rows))
	# A clue that opens with "+" follows its hint as it is; any other clue is led by "Try".
	var plus_card := FieldNotes.hint_card_text("◆", "Knocked machines", "+ three down from one knock")
	t.check("a plus clue is not led by Try", not plus_card.contains("Try +") and plus_card.ends_with("+ three down from one knock"), plus_card)
	var plain_card := FieldNotes.hint_card_text("◆", "A hint", "a slingshot + a kill")
	t.check("a plain clue is led by Try", plain_card.ends_with("Try a slingshot + a kill"), plain_card)


func _notes() -> void:
	var count := 0
	for group in [FieldNotes.TESTING, FieldNotes.QUESTIONS, FieldNotes.TRY_FIRST]:
		for line in group:
			count += 1
			_check("field note", String(line))
	for row in FieldNotes.VERB_ROWS:
		count += 1
		_check("key list %s" % row[0], String(row[1]))
	# The menu rows are the key table itself: their keys column holds the letters, so only the shape rules apply.
	for row in FieldNotes.MENU_ROWS + FieldNotes.SCREEN_KEYS:
		count += 1
		var found := hits(String(row["does"]))
		found = found.filter(func(h): return not String(h).begins_with("typed key"))
		t.check("menu row %s is plain" % row["keys"], found.is_empty(), str(found))
	t.check("read the field notes", count >= 30, str(count))
	var lore := 0
	for row in LoreRows.ROWS:
		if row["kind"] == "field_note":
			lore += 1
			# The lore notes are the world's own voice ("Slot canyon tag", "latch"): only the retired names and typed keys apply.
			var found := hits(String(row["text"]), false, false).filter(func(h): return h != "exclamation" and not String(h).begins_with("sentence"))
			t.check("lore field note %s keeps names" % row["id"], found.is_empty(), str(found))
	t.check("read the lore field notes", lore >= 1, str(lore))


func _achievements() -> void:
	for id in Achievements.ids():
		var row := Achievements.row(id)
		_check("achievement %s name" % id, String(row["name"]))
		_check("achievement %s text" % id, String(row["text"]))
		# A pilot's beat is the crew's voice: it keeps its voice, so only the retired names and keys are refused.
		if row.has("beat"):
			var found := hits(String(row["beat"]), false).filter(func(h): return h != "exclamation" and not String(h).begins_with("sentence"))
			t.check("achievement %s beat keeps names" % id, found.is_empty(), str(found))


func _companion_and_credits() -> void:
	for piece in Companion.PIECES:
		_check("companion %s name" % piece["id"], String(piece["name"]))
		_check("companion %s effect" % piece["id"], String(piece["effect"]))
	_check("credits", EndingSequence.CREDITS.replace("\n", ". "), false)
