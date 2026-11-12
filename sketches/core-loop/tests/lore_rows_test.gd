extends SceneTree

const LoreRows := preload("res://src/core/lore_rows.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

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
	_report("an unlisted caller has no voice", LoreRows.voice_of({"kind": "exchange", "speaker": "Deck crew", "text": "x"}) == ""
			and LoreRows.voice_of({"kind": "intro", "zone": "2-1", "subject": "warden", "text": "Pit Warden. x"}) == "", "Deck crew and the pit Warden's line stay silent")
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
