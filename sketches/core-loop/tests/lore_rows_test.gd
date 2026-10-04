extends SceneTree

const LoreRows := preload("res://src/core/lore_rows.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# World-one lore has unique line ids, capped words, one skippable 2-4-line
# Moss/crew exchange and 6-8 scraps per zone, and Warden and Brindle intros.
# This pure data check does not instantiate the game or approve the writing's tone.
const ZONES := ["1-1", "1-2"]
const CAPS := {"exchange": 14, "field_note": 40, "intro": 12}

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_report("exchange cap", LoreRows.EXCHANGE_LINE_WORD_CAP == CAPS["exchange"], "14 words per line")
	_report("note cap", LoreRows.FIELD_NOTE_WORD_CAP == CAPS["field_note"], "40 words per scrap")
	_report("intro cap", LoreRows.INTRO_LINE_WORD_CAP == CAPS["intro"], "12 words per line")
	var ids := {}
	var notes := {"1-1": 0, "1-2": 0}
	var exchanges := {"1-1": {}, "1-2": {}}
	var intros := {"1-1": {"warden": 0, "brindle": 0}, "1-2": {"warden": 0, "brindle": 0}}
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
				if intros[zone].has(subject):
					intros[zone][subject] += 1
	for zone in ZONES:
		_report(zone + " notes", notes[zone] >= 6 and notes[zone] <= 8, "%d notes; need 6-8" % notes[zone])
		_report(zone + " one exchange", exchanges[zone].size() == 1, "%d exchanges" % exchanges[zone].size())
		for exchange in exchanges[zone]:
			var speakers: Array = exchanges[zone][exchange]
			_report(exchange + " length", speakers.size() >= 2 and speakers.size() <= 4, "%d lines; need 2-4" % speakers.size())
			_report(exchange + " Moss and crew", speakers.has("Moss") and speakers.any(func(speaker): return speaker.ends_with("crew")), str(speakers))
		for subject in intros[zone]:
			_report(zone + " " + subject + " intro", intros[zone][subject] == 1, "%d intros; need one" % intros[zone][subject])
	print("lore_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
