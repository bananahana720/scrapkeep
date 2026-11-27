extends SceneTree

# Wave 36 unit unslop-tips (ruling cx, no slop in anything the player meets). Every first-meet
# tip, plate objective, death tip, place name, shift-board line, synergy line and bowling entry a
# player can be shown in world 1 is read through the game's own tables: no typed key letter, no
# bracketed key, no label colon, no semicolon, no retired name, no word only the code uses.
# The checker is run first on the strings the base held; it must flag every one of them, or its
# zero below means nothing. Tips are toasts (a plain Label), so a tip cannot draw a keycap: a
# tip that needs a key points at the mark that already draws it (the mast's prompt, the bar
# slot, the notes), and the second check below holds that no tip names a key at all.

const T := preload("res://tests/support/t.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const FieldTips := preload("res://src/ui/field_tips.gd")
const Lanes := preload("res://src/build/lanes.gd")
const Objectives := preload("res://src/core/objectives.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Profile := preload("res://src/core/profile.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Worlds := preload("res://src/core/worlds.gd")

# Lower case, matched as whole words or phrases.
const BANNED := ["stake", "slot", "miniboss", "latch on", "enemy", "enemies", "grow,", "rebound", "pin chain", "foes", "class",
	"set piece", "grapple", "the gauge", "locked:", "shut:"]
# Key letters a rebindable key could carry; "A" and "I" are words.
const KEY_LETTERS := ["Q", "E", "F", "V", "P", "R", "H", "J", "K", "X", "C", "Z", "Tab", "Esc"]
# What the base held, line for line. Every one must be flagged.
const PLANTED := ["Wall grip: stay fast and walls hold you.", "Radio: [.] next station, [,] back, [/] skip the track.",
	"Relay stake: hold E at the mast to raise the fight and the parts.", "F fires your active.",
	"Dunk: an air slam stores its hit; reel into a hooked body to cash it.", "Yard locked: break the crew",
	"Latch on, shoot, smash core", "The miniboss lands on its ring.", "Spillway: the top shelf",
	"Grow, then return", "Hard landings freeze enemies near you.", "A pin chain", "Time card full: First Card pays X.",
	"You clocked in: your first shift is on the shift board."]
const PLAIN := ["Hold at the mast to raise the fight.", "Break the yard crew", "Spillway, the top shelf", "Get heavy, then return",
	"Hook, shoot, smash core"]


func _initialize() -> void:
	var t := T.new("tips_words_test")
	_planted(t)
	var all := _strings()
	t.check("the tables hold tips, objectives, death tips, names and board lines", all.size() >= 90, str(all.size()))
	for entry in all:
		var found := hits(String(entry[1]))
		t.check("%s: '%s' is plain" % [entry[0], entry[1]], found.is_empty(), str(found))
	for id in FieldTips.TIPS:
		t.check("tip %s names no key" % id, not _names_key(String(FieldTips.TIPS[id])), String(FieldTips.TIPS[id]))
	for id in Objectives.ROWS:
		var words := String(Objectives.words(id))
		t.check("objective %s is one plain imperative of at most %d words" % [id, Objectives.MAX_WORDS],
			words.split(" ", false).size() <= Objectives.MAX_WORDS and not words.contains(":"), words)
	for tip in DeathTips.ROWS.values() + DeathTips.BY_THREAT.values() + [DeathTips.DRAWN]:
		t.check("death tip fits %d characters: %s" % [DeathTips.MAX_CHARS, tip], String(tip).length() <= DeathTips.MAX_CHARS)
	var gap := DeathTips.line("warden", "", {"who": "Meltdown Warden", "punch": 120, "plating": 300})
	t.check("the short-build tip fits %d characters: %s" % [DeathTips.MAX_CHARS, gap], gap.length() <= DeathTips.MAX_CHARS and gap != "")
	_names(t)
	quit(t.verdict())


func _names_key(text: String) -> bool:
	return _key_hits(text) != []


func _key_hits(text: String) -> Array:
	var out := []
	if RegEx.create_from_string("\\[[^\\]\\sA-Za-z]{1,2}\\]").search(text) != null:
		out.append("bracketed key")
	for token in text.split(" ", false):
		var bare := token.strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix(":")
		if bare in KEY_LETTERS:
			out.append("typed key %s" % bare)
	return out


# The words of one drawn text that a first-time player has not been taught, or a form that is slop.
func hits(text: String) -> Array:
	var out := _key_hits(text)
	var lower := text.to_lower()
	for word in BANNED:
		if lower.contains(word):
			out.append(word)
	if text.contains(": "):
		out.append("label colon")
	if text.contains("; "):
		out.append("semicolon")
	return out


func _planted(t) -> void:
	for text in PLANTED:
		t.check("planted base text is flagged: %s" % text, not hits(text).is_empty(), str(hits(text)))
	for text in PLAIN:
		t.check("a plain line is not flagged: %s" % text, hits(text).is_empty(), str(hits(text)))


# [where, string] for every line the tables can show in world 1.
func _strings() -> Array:
	var out := []
	for id in FieldTips.TIPS:
		out.append(["tip " + id, FieldTips.TIPS[id]])
	for id in Objectives.ROWS:
		out.append(["objective " + id, Objectives.words(id)])
	for table in [Objectives.ACTIVITY_WORDS, Objectives.DONE_WORDS, Objectives.LOST_WORDS, Objectives.TAGS]:
		for id in table:
			out.append(["objective word " + id, table[id]])
	for id in DeathTips.ROWS:
		out.append(["death tip " + id, DeathTips.ROWS[id]])
	for id in DeathTips.BY_THREAT:
		out.append(["death tip " + id, DeathTips.BY_THREAT[id]])
	out.append(["death tip drawn", DeathTips.DRAWN])
	out.append(["death tip gap", DeathTips.GAP % [120, "the Warden", 300]])
	# The alpha table keeps its names as its maps' titles (alpha_table_test pins them equal, and a map title is a
	# lookup key for lock rows and the radio cache), so only the park table's names are read here.
	for d in ParkDefs.DEFS:
		out.append(["place name stage %d" % d["stage"], d["name"]])
	for defs in [ParkDefs.DEFS, AlphaDefs.DEFS]:
		for d in defs:
			out.append(["warden hint stage %d" % d["stage"], d.get("warden_hint", "")])
	for row in Worlds.ROWS:
		out.append(["world name " + str(row["id"]), row["name"]])
	for id in Worlds.BOSSES:
		out.append(["victory title " + id, Worlds.BOSSES[id]["title"]])
	for id in ShiftBoard.RUNGS:
		out.append(["board rung " + id, ShiftBoard.RUNGS[id]["text"]])
	for id in ShiftBoard.SEEDS:
		out.append(["board seed " + id, ShiftBoard.SEEDS[id]["text"]])
	for punches in [3, 4, 10]:
		var profile := Profile.new("user://tips-words-%d-%d.json" % [OS.get_process_id(), punches])
		profile.set_stat(ShiftBoard.PUNCH_STAT, float(punches))
		out.append(["board run line %d" % punches, ShiftBoard.run_line([], profile, true)])
	var clocked := Profile.new("user://tips-words-clock-%d.json" % OS.get_process_id())
	clocked.earn("ach_d7_salt_skip", 1.0)
	out.append(["board run line clocked in", ShiftBoard.run_line([], clocked, false)])
	out.append(["board run line short shift next rung", ShiftBoard.run_line(["clock_in"], clocked, false)])
	var all_done := Profile.new("user://tips-words-done-%d.json" % OS.get_process_id())
	for id in ShiftBoard.RUNGS:
		var when: Dictionary = ShiftBoard.RUNGS[id]["when"]
		if when.has("earned"):
			all_done.earn(String(when["earned"]), 1.0)
		else:
			all_done.hear_tune(String(when["tune"]))
	out.append(["board run line short shift all stamped", ShiftBoard.run_line(ShiftBoard.stamped_ids(all_done), all_done, false)])
	for id in ["item", "pilot", "cosmetic", "tune", "option"]:
		out.append(["board pays " + id, ShiftBoard.pays_words({id: "spring_hull"})])
	for id in Synergies.ROWS:
		out.append(["synergy " + id, Synergies.ROWS[id]["text"]])
	for entry in Lanes.ENTRIES:
		out.append(["bowling " + entry["id"], "%s. %s. %s" % [entry["hint"], entry["clue"], entry["text"]]])
	return out


# The park table's place names carry no colon: a name and its tagline read "Name, the tagline".
func _names(t) -> void:
	for d in ParkDefs.DEFS:
		t.check("stage %d name '%s' has no colon" % [d["stage"], d["name"]], not String(d["name"]).contains(":"))
		t.check("stage %d name '%s' names its world first" % [d["stage"], d["name"]],
			String(d["name"]).split(",")[0] in ["Spillway", "Dig", "Highdraft"])
