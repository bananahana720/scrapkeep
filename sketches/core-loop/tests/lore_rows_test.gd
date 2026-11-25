extends SceneTree

const LoreRows := preload("res://src/core/lore_rows.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Every declared zone has unique ids, capped words, three skippable exchange
# lines, at least fourteen scraps, and Warden/world-boss intros. Per-pilot boss threat lines are
# extra intro rows, checked in intro_lines_test.
# This pure data check does not instantiate the game or approve the writing's tone.
const StageDefs := preload("res://src/core/stage_defs.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")

# SHA-256 of the 48 world 2/3 texts at 9b8a2a3, joined in ROWS order
# with one newline between texts and no trailing newline.
const OLD_DIGEST := "dc73b5d0ed3104f72f0dab51d1463144a320de10e061244daf1d2627a64aca14"
const REWRITTEN_ZONES := ["2-1", "2-2", "3-1", "3-2"]
const FORBIDDEN_TEXT := ["placeholder", "todo", "tone-pending"]
# LORE-REPLACE (decisions.tsv): the parks have no cableway, and the crown's notes leave
# the islands, bridges and barge to stage 5.
const REMOVED_PLACES := ["cableway", "cable reach"]
const CROWN_NOTE_REMOVED := ["island", "bridge", "barge"]

# Three worlds of two zones, independent of the live table's current COUNT.
class SixZones extends RefCounted:
	const COUNT := 6

	static func world_of(stage: int) -> int:
		return (stage - 1) / 2 + 1

	static func local(stage: int) -> int:
		return (stage - 1) % 2 + 1


var ZONES: Array = []
const CAPS := {"exchange": 14, "field_note": 40, "intro": 12}
const GameEvents := preload("res://src/core/game_events.gd")
const PILOT_SPEAKERS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	for table in [StageDefs, SixZones]:
		for stage in range(1, table.COUNT + 1):
			var zone := MusicRows.zone_id(stage, table)
			if not ZONES.has(zone):
				ZONES.append(zone)
	_report("exchange cap", LoreRows.EXCHANGE_LINE_WORD_CAP == CAPS["exchange"], "14 words per line")
	_report("note cap", LoreRows.FIELD_NOTE_WORD_CAP == CAPS["field_note"], "40 words per scrap")
	_report("intro cap", LoreRows.INTRO_LINE_WORD_CAP == CAPS["intro"], "12 words per line")
	var ids := {}
	var notes := {}
	var exchanges := {}
	var intros := {}
	var rewritten_texts := PackedStringArray()
	for zone in ZONES:
		notes[zone] = 0
		exchanges[zone] = {}
		var boss: String = {"1": "brindle", "2": "waking", "3": "mind"}[zone.split("-")[0]]
		intros[zone] = {"warden": 0, boss: 0}
	for value in LoreRows.ROWS:
		_report("row dictionary", value is Dictionary, str(value))
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var id := String(row.get("id", ""))
		_report("stable unique id", row.get("id") is String and id != "" and not ids.has(id), id)
		ids[id] = true
		var kind := String(row.get("kind", ""))
		var zone := String(row.get("zone", ""))
		_report(id + " kind", row.get("kind") is String and CAPS.has(kind), kind)
		_report(id + " zone", row.get("zone") is String and zone in ZONES, zone)
		var text := String(row.get("text", ""))
		_report(id + " text", row.get("text") is String and WordBudget.words_in(text) > 0, text)
		for marker in FORBIDDEN_TEXT:
			_report(id + " final text", not text.to_lower().contains(marker), "no " + marker)
		for place in REMOVED_PLACES:
			_report(id + " park place", not text.to_lower().contains(place), "no " + place)
		if zone == "3-2" and kind == "field_note":
			for place in CROWN_NOTE_REMOVED:
				_report(id + " crown place", not text.to_lower().contains(place), "no " + place)
		if zone in REWRITTEN_ZONES and not row.has("pilot"):
			rewritten_texts.append(text)
			_report(id + " final id", not id.to_lower().contains("placeholder"), "no placeholder")
		if CAPS.has(kind):
			var words := WordBudget.words_in(text)
			_report(id + " word cap", words <= int(CAPS[kind]), "%d / %d words" % [words, CAPS[kind]])
		if not zone in ZONES:
			continue
		match kind:
			"field_note":
				notes[zone] += 1
			"exchange":
				_report(id + " skippable", row.get("skippable") is bool and row.get("skippable") == true, "skippable: true required")
				var exchange := String(row.get("exchange", ""))
				_report(id + " exchange id", row.get("exchange") is String and exchange != "", exchange)
				var speaker := String(row.get("speaker", ""))
				_report(id + " speaker", row.get("speaker") is String and speaker != "", speaker)
				if not exchanges[zone].has(exchange):
					exchanges[zone][exchange] = []
				exchanges[zone][exchange].append(speaker)
			"intro":
				var subject := String(row.get("subject", ""))
				_report(id + " intro subject", row.get("subject") is String and intros[zone].has(subject), subject)
				if intros[zone].has(subject) and not row.has("pilot"):
					intros[zone][subject] += 1
	var live_digest := "\n".join(rewritten_texts).sha256_text()
	_report("rewritten text count", rewritten_texts.size() == 92, "%d texts; need 92" % rewritten_texts.size())
	_report("world 2/3 rewritten", live_digest != OLD_DIGEST, "old %s; live %s" % [OLD_DIGEST, live_digest])
	for zone in ZONES:
		_report(zone + " notes", notes[zone] >= 14, "%d notes; need at least 14" % notes[zone])
		_report(zone + " one exchange", exchanges[zone].size() == 1, "%d exchanges" % exchanges[zone].size())
		for exchange in exchanges[zone]:
			var speakers: Array = exchanges[zone][exchange]
			_report(exchange + " length", speakers.size() == 3, "%d lines; need 3" % speakers.size())
			_report(exchange + " Moss and crew", speakers.has("Moss") and speakers.any(func(speaker): return speaker.ends_with("crew")), str(speakers))
		for subject in intros[zone]:
			_report(zone + " " + subject + " intro", intros[zone][subject] == 1, "%d intros; need one" % intros[zone][subject])
	_calls()
	_camp_quips()
	_world_three()
	print("lore_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# Call-ins: unique ids, a known caller, a real bus signal with the argument its filter names,
# twelve words at most, and a pilot's row only for a pilot. One caller per signal and filter is
# reachable: an earlier row with the same cause and no pilot would shadow a later one.
func _calls() -> void:
	_report("call cap", LoreRows.CALL_LINE_WORD_CAP == 12, "12 words per call")
	var bus := GameEvents.new()
	var arity := {}
	for sig in bus.get_signal_list():
		arity[sig["name"]] = sig["args"].size()
	var ids := {}
	var causes := {}
	for row in LoreRows.CALLS:
		var id := String(row.get("id", ""))
		_report("call id", id.begins_with("call.") and not ids.has(id), id)
		ids[id] = true
		# W1-71: a world 1 call has two or three ways to say it, each its own line within the cap.
		var lines: Array = row.get("text", []) if row.get("text") is Array else [row.get("text", "")]
		_report(id + " variants", lines.size() >= 2 and lines.size() <= 3, "%d lines" % lines.size())
		var distinct := {}
		for line in lines:
			var text := String(line)
			distinct[text] = true
			var words := WordBudget.words_in(text)
			_report(id + " words", words > 0 and words <= LoreRows.CALL_LINE_WORD_CAP, "%d / %d words: %s" % [words, LoreRows.CALL_LINE_WORD_CAP, text])
			for marker in FORBIDDEN_TEXT:
				_report(id + " final text", not text.to_lower().contains(marker), "no " + marker)
		_report(id + " variants differ", distinct.size() == lines.size(), str(lines))
		# The seed picks one line, the same one every time, and enough seeds hear every line.
		var heard := {}
		for seed_n in 64:
			heard[LoreRows.call_text(row, seed_n)] = true
		_report(id + " seed picks a line", LoreRows.call_text(row, 41) == LoreRows.call_text(row, 41) and heard.keys().all(func(h): return distinct.has(h)), str(heard.keys()))
		_report(id + " every line is heard", heard.size() == lines.size(), "%d of %d over 64 seeds" % [heard.size(), lines.size()])
		_report(id + " speaker", LoreRows.SPEAKERS.has(row.get("speaker", "")), String(row.get("speaker", "")))
		_report(id + " world", int(row.get("world", 0)) == 1, "world 1 only until the sitting")
		var on := String(row.get("on", ""))
		_report(id + " signal", arity.has(on), on)
		for key in ["arg", "at_least"]:
			if row.has(key):
				_report(id + " " + key, int(row[key][0]) < int(arity.get(on, 0)), "argument %d of %s" % [row[key][0], on])
		_report(id + " when", String(row.get("when", "low_hull")) == "low_hull", String(row.get("when", "")))
		_report(id + " pilot", row.has("pilot") == (String(row.get("speaker", "")) in PILOT_SPEAKERS), "a pilot's row names the class; nobody else's does")
		var cause := "%s|%s|%s|%s" % [on, row.get("arg", ""), row.get("at_least", ""), row.get("when", "")]
		_report(id + " reachable", not causes.has(cause) or (row.has("pilot") and causes[cause]), "cause %s" % cause)
		causes[cause] = row.has("pilot")
	bus.free()
	var camp: Dictionary = LoreRows.CALLS[0]
	_report("call matches its cause", LoreRows.call_matches(camp, "activity_done", ["enemy_camp", Vector3.ZERO])
			and not LoreRows.call_matches(camp, "activity_done", ["hold_the_relay", Vector3.ZERO])
			and not LoreRows.call_matches(camp, "stage_cleared", [1]) and not LoreRows.call_matches(camp, "activity_done", []),
		"the camp call answers activity_done for a camp and nothing else")
	var drop: Dictionary = {}
	for row in LoreRows.CALLS:
		if row["on"] == "drop_landed":
			drop = row
			break
	_report("call floor", LoreRows.call_matches(drop, "drop_landed", [3]) and not LoreRows.call_matches(drop, "drop_landed", [2]),
		"a drop call needs three hits")
	# Who says the lines that are already in the game.
	var voices := {}
	for row in LoreRows.ROWS:
		if row["kind"] != "field_note":
			voices[row["id"]] = [LoreRows.voice_of(row), LoreRows.spoken(row)]
	_report("hello voices", voices["lore.spillway.moss.spare"][0] == "moss" and voices["lore.spillway.crew.leak"] == ["pump_crew", "We fixed that leak yesterday."],
		str(voices["lore.spillway.crew.leak"]))
	_report("intro voices", voices["lore.park_dam.intro.warden"][0] == "pump_crew" and voices["lore.park_flume.intro.warden"][0] == "flume_crew"
			and voices["lore.spillway.intro.brindle"] == ["brindle", "Your repair reserve is now Fleet inventory. Thank you."],
		str(voices["lore.spillway.intro.brindle"]))
	_report("an unlisted caller has no voice", LoreRows.voice_of({"kind": "exchange", "speaker": "Barge crew", "text": "x"}) == ""
			and LoreRows.voice_of({"kind": "intro", "zone": "9-9", "subject": "warden", "text": "Unknown Warden. x"}) == "", "unlisted crew and unknown zone stay silent")
	_report("a single-line call reads as itself", LoreRows.call_text({"id": "call.x", "text": "One line."}, 9) == "One line.", "string text")
	# Two rows on one seed do not all take the same place in their lists (the pick is salted by id).
	var places := {}
	for row in LoreRows.CALLS:
		var lines: Array = row["text"]
		places[lines.find(LoreRows.call_text(row, 5))] = true
	_report("rows on one seed spread over their lists", places.size() > 1, str(places.keys()))
	var signals: Array = LoreRows.call_signals()
	_report("call signals", signals.size() == 7 and signals.all(func(s): return signals.count(s) == 1 and LoreRows.CALLS.any(func(r): return r["on"] == s)),
		str(signals))



# Camp quips (W46-14): one row per pilot, each pilot's caller id a SPEAKERS id (so a voice can say it) and their class
# a real class; two or three distinct lines within the call cap, none of them unfinished, no exclamation mark (the
# tone bible's dry log); visits step through every line, and two pilots on one visit do not all open on line one.
func _camp_quips() -> void:
	var classes := {}
	for def in ClassDef.all():
		classes[String(def.id)] = def
	var pilots := {}
	for row in LoreRows.CAMP_QUIPS:
		var id := String(row.get("id", ""))
		var speaker := String(row.get("speaker", ""))
		var pilot := String(row.get("pilot", ""))
		_report(id + " caller", speaker in PILOT_SPEAKERS and LoreRows.SPEAKERS.has(speaker), speaker)
		_report(id + " class", classes.has(pilot) and String(classes[pilot].motif) == speaker and not pilots.has(pilot), pilot)
		pilots[pilot] = true
		_report(id + " is its class's", LoreRows.camp_quip(pilot) == row, pilot)
		var lines: Array = row.get("text", [])
		var distinct := {}
		for line in lines:
			var text := String(line)
			distinct[text] = true
			var words := WordBudget.words_in(text)
			_report(id + " words", words > 0 and words <= LoreRows.CALL_LINE_WORD_CAP and not text.contains("!"), "%d words: %s" % [words, text])
			for marker in FORBIDDEN_TEXT:
				_report(id + " final text", not text.to_lower().contains(marker), "no " + marker)
		_report(id + " lines", lines.size() >= 2 and lines.size() <= 3 and distinct.size() == lines.size(), str(lines))
		var heard := {}
		for visit in lines.size():
			heard[LoreRows.camp_quip_text(row, visit)] = true
		_report(id + " visits step through every line", heard.size() == lines.size(), str(heard.keys()))
	_report("every pilot has a quip", pilots.size() == classes.size(), str(pilots.keys()))
	_report("a class with no quip has none", LoreRows.camp_quip("nobody").is_empty(), "")
	var openers := {}
	for row in LoreRows.CAMP_QUIPS:
		openers[(row["text"] as Array).find(LoreRows.camp_quip_text(row, 1))] = true
	_report("pilots on one visit spread over their lists", openers.size() > 1, str(openers.keys()))


# W49-MAPS: World 3's cold opens and the Mind's two cards live outside ROWS, keyed by landmark kind;
# lines stay under the intro cap, skippable, with no em dash or exclamation mark (LEGIBILITY section 13, W6).
func _world_three() -> void:
	var row_ids := {}
	for row in LoreRows.ROWS:
		row_ids[row["id"]] = true
	var plain := func(text: String) -> bool: return not text.contains("\u2014") and not text.contains("!") and not text.contains(" - ")
	for kind in ["sky_island", "spire"]:
		var card := LoreRows.world_three_cold_open(kind)
		var line := String(card.get("line", ""))
		var words := line.split(" ", false).size()
		_report("world 3 cold open " + kind, card.get("zone") == ("3-1" if kind == "sky_island" else "3-2") and card.get("speaker") == "Moss"
			and card.get("skippable") == true and float(card.get("duration_s", 0.0)) > 0.0 and not row_ids.has(card.get("id")),
			"%s %s" % [card.get("id"), card.get("zone")])
		_report("world 3 cold open line " + kind, words > 0 and words <= LoreRows.INTRO_LINE_WORD_CAP and plain.call(line) and plain.call(String(card.get("title", ""))),
			"%d words: %s" % [words, line])
	_report("unknown landmark has no cold open", LoreRows.world_three_cold_open("headframe").is_empty(), "headframe")
	var call: Dictionary = LoreRows.FOREMAN_CALL_IN
	var call_words := String(call["line"]).split(" ", false).size()
	_report("foreman call-in card", call["title"] == "THE FOREMAN" and call["stats"].size() == 3 and call["likes"] == ["LIKES", "YOU"]
		and call["skippable"] == true and float(call["duration_s"]) >= 2.5 and float(call["duration_s"]) <= 4.0
		and String(call["cue"]) != "" and not row_ids.has(call["id"]), str(call["stats"]))
	_report("foreman call-in line", call_words <= LoreRows.INTRO_LINE_WORD_CAP and plain.call(String(call["line"])), "%d words" % call_words)
	var hired: Dictionary = LoreRows.HIRED_CEREMONY
	_report("hired ceremony card", hired["stamp"] == "HIRED" and hired["memo"] == "I am humbled to announce that I have accepted a position on the crew."
		and hired["skippable"] == true and float(hired["duration_s"]) >= 2.0 and float(hired["duration_s"]) <= 3.5 and not row_ids.has(hired["id"]), String(hired["memo"]))
