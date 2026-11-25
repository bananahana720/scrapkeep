extends RefCounted

const SEEN_PREFIX := "flourish:"
const MAX_SECONDS := 6.0
const MAX_SHORT_SECONDS := 2.5
const PANEL_STEP := 0.6
const LINE_WORD_CAP := 14
const SLOTS := ["left_top", "left_low", "column", "centre"]
const KINDS := ["card", "stamp", "caption", "panels", "sfx_word", "speed_lines", "inset"]

const ROWS := {
	"cold_open": {"priority": 1,
		"full": [
			{"kind": "caption", "at": 0.0, "for": 2.0, "slot": "left_low",
				"text": ["Dawn. Probably a Tuesday.", "Dawn. Definitely a Wednesday.", "Dawn. The kettle is on."]},
			{"kind": "caption", "at": 2.0, "for": 2.0, "slot": "left_low",
				"text": ["Moss's shift note: bring the runner back up.", "Moss's shift note: seals first. Then the runner.",
					"Moss's shift note: nothing's out of place. Yet.", "Moss's shift note: very tidy out there. Boots on."]},
			{"kind": "card", "at": 0.6, "for": 4.4, "slot": "left_top",
				"card": ["PUMP CREW", "Card 0417 · Spillway shift", "Clocked in", "06:00", "Hands on shift", "all", "Runner", "not back yet"]},
			{"kind": "stamp", "at": 1.4, "for": 2.0, "text": "CLOCKED IN", "colour": "AMBER"},
			{"kind": "sfx_word", "at": 1.4, "for": 1.2, "text": "KA-CHUNK", "at_share": Vector2(0.62, 0.34)},
			{"kind": "caption", "at": 4.2, "for": 1.4, "slot": "left_low",
				"text": ["Moss packed a spare card.", "Moss packed a spare thermos.", "Moss packed two. Just in case.", "Moss packed a broom. For after."]},
		],
		"short": [
			{"kind": "stamp", "at": 0.0, "for": 1.8, "text": "CLOCKED IN", "colour": "AMBER"},
			{"kind": "sfx_word", "at": 0.0, "for": 1.0, "text": "KA-CHUNK", "at_share": Vector2(0.62, 0.34)},
		]},
	"rivet_freed": {"priority": 2,
		"full": [
			{"kind": "sfx_word", "at": 0.0, "for": 1.2, "text": "KLANG", "anchor": "cage"},
			{"kind": "panels", "at": 0.3, "for": 5.3,
				"texts": ["The cage. Opened from inside.", ["They measured the bars. Twice.", "Visor up. Tiny proud eyes."],
					["Moss packed spare lenses.", "Moss packed a spare visor.", "Moss had a feeling."]]},
			{"kind": "stamp", "at": 1.8, "for": 2.2, "text": "BACK ON SHIFT", "colour": "ARC"},
		],
		"short": [
			{"kind": "sfx_word", "at": 0.0, "for": 1.0, "text": "KLANG", "anchor": "cage"},
			{"kind": "stamp", "at": 0.2, "for": 1.4, "text": "BACK ON SHIFT", "colour": "ARC"},
		]},
	"flume_warden_reveal": {"priority": 2,
		"full": [
			{"kind": "card", "at": 0.0, "for": 4.2, "slot": "left_top",
				"card": ["MELTDOWN WARDEN", "Reactor · flume shift", "Core temp", "yes", "Slag lane", "hot. Jump it.", "Overtime", "unpaid"]},
			{"kind": "sfx_word", "at": 0.2, "for": 1.2, "text": "FWOOMP", "anchor": "warden"},
			{"kind": "caption", "at": 2.6, "for": 2.2, "slot": "left_low",
				"text": ["Nobody told it the shift ended.", "It runs hot. It means well.", "Reactor family. Never misses a shift."]},
		],
		"short": [
			{"kind": "card", "at": 0.0, "for": 1.4, "slot": "left_top", "card": ["MELTDOWN WARDEN", "Slag lane: jump it"]},
			{"kind": "sfx_word", "at": 0.0, "for": 1.0, "text": "FWOOMP", "anchor": "warden"},
		]},
	"bowl_handoff": {"priority": 1,
		"full": [
			{"kind": "stamp", "at": 0.0, "for": 1.6, "text": "GATES OPEN", "colour": "ARC"},
			{"kind": "caption", "at": 0.4, "for": 2.0, "slot": "left_low", "text": "Next stop: the Slag Bowl. Noon."},
			{"kind": "sfx_word", "at": 2.0, "for": 1.4, "text": "HONK", "at_share": Vector2(0.70, 0.32)},
			{"kind": "caption", "at": 2.4, "for": 2.2, "slot": "left_low",
				"text": ["Brindle is on the clock. He rounded it up.", "Somewhere, a badger clears his throat.", "The Fleet is on schedule. Early, in fact."]},
		],
		"short": [
			{"kind": "stamp", "at": 0.0, "for": 1.6, "text": "NEXT: SLAG BOWL", "colour": "ARC"},
			{"kind": "sfx_word", "at": 0.6, "for": 1.0, "text": "HONK", "at_share": Vector2(0.70, 0.32)},
		]},
	"spillway_clear": {"priority": 0,
		"full": [
			{"kind": "card", "at": 0.0, "for": 2.6, "slot": "left_top",
				"card": ["SPILLWAY WORKS", "World one · shift log", "Pumps", "running", "Seals", "holding", "Overtime", "logged, not paid"]},
			{"kind": "stamp", "at": 2.6, "for": 1.4, "text": "SHIFT COMPLETE", "colour": "AMBER"},
			{"kind": "caption", "at": 4.0, "for": 2.0, "slot": "left_low", "text": [
				"Shift log: seals checked. Gauges agree, for once.",
				"Shift log: dam held. Flume drained. Weather blamed.",
				"Shift log: pumps running. The river kept its side of it."]},
		],
		"short": [
			{"kind": "stamp", "at": 0.0, "for": 1.2, "text": "SHIFT COMPLETE", "colour": "AMBER"},
			{"kind": "caption", "at": 1.2, "for": 1.3, "slot": "left_low", "text": [
				"Shift log: seals checked. Gauges agree, for once.",
				"Shift log: dam held. Flume drained. Weather blamed.",
				"Shift log: pumps running. The river kept its side of it."]},
		]},
	"brindle_arrival": {"priority": 3, "on": "arrival", "boss": "brindle",
		"world": {"full": [{"kind": "rise", "at": 0.0, "seconds": 1.4}, {"kind": "glance", "anchor": "ship", "seconds": 0.9},
				{"kind": "slow", "at": 0.15, "for": 0.7, "scale": 0.3}],
			"short": [{"kind": "glance", "anchor": "ship", "seconds": 0.7}]},
		"full": [
			{"kind": "speed_lines", "at": 0.0, "for": 0.9},
			{"kind": "sfx_word", "at": 0.1, "for": 1.0, "text": "HONK", "anchor": "ship"},
			{"kind": "inset", "at": 0.15, "for": 0.7, "anchor": "ship_body", "home": "ship", "toward": "arena"},
			{"kind": "card", "at": 0.2, "for": 2.7, "slot": "left_low",
				"card": ["ADMIRAL BRINDLE", "Badger · Furnace Fleet", "Ship", "the Requisition", "Schedule", "kept to the minute", "Retreat", "filed in advance"]},
			{"kind": "sfx_word", "at": 1.4, "for": 0.9, "text": "CHUNK", "anchor": "ship"},
		],
		"short": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.9, "text": "HONK", "anchor": "ship"},
			{"kind": "card", "at": 0.1, "for": 1.3, "slot": "left_low", "card": ["ADMIRAL BRINDLE", "Back. On schedule."]},
		]},
	"brindle_phase_2": {"priority": 3, "on": "phase", "boss": "brindle", "phases": [2],
		"world": {"full": [{"kind": "glance", "anchor": "ship", "seconds": 0.7}], "short": [{"kind": "glance", "anchor": "ship", "seconds": 0.6}]},
		"full": [
			{"kind": "caption", "at": 0.0, "for": 1.5, "slot": "left_low",
				"text": ["Brindle revises the arithmetic.", "Brindle carries the one.", "The figures were optimistic."]},
		],
		"short": [
			{"kind": "caption", "at": 0.0, "for": 1.2, "slot": "left_low", "text": ["Brindle revises the arithmetic.", "Brindle carries the one.", "The figures were optimistic."]},
		]},
	"brindle_phase_3": {"priority": 3, "on": "phase", "boss": "brindle", "phases": [3],
		"world": {"full": [{"kind": "glance", "anchor": "ship", "seconds": 0.7}], "short": [{"kind": "glance", "anchor": "ship", "seconds": 0.6}]},
		"full": [
			{"kind": "caption", "at": 0.0, "for": 1.5, "slot": "left_low",
				"text": ["Dignity: optional.", "Brindle rounds down. Once.", "Plan C. There was no plan B."]},
		],
		"short": [
			{"kind": "caption", "at": 0.0, "for": 1.2, "slot": "left_low", "text": ["Dignity: optional.", "Brindle rounds down. Once.", "Plan C. There was no plan B."]},
		]},
	"brindle_chase": {"priority": 3, "on": "phase", "boss": "brindle", "phases": [4],
		"world": {"full": [{"kind": "glance", "anchor": "scooter", "at": 0.6, "seconds": 1.6}],
			"short": [{"kind": "glance", "anchor": "scooter", "at": 0.6, "seconds": 1.2}]},
		"full": [{"kind": "speed_lines", "at": 0.0, "for": 1.0}],
		"short": [{"kind": "speed_lines", "at": 0.0, "for": 0.8}]},
	"brindle_rout": {"priority": 3, "on": "rout", "boss": "brindle",
		"world": {"full": [{"kind": "eject", "at": 0.0, "seconds": 1.8}], "short": [{"kind": "eject", "at": 0.0, "seconds": 1.1}]},
		"full": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.9, "text": "FWOOMP", "anchor": "scooter"},
			{"kind": "stamp", "at": 0.0, "for": 1.5, "text": "ROUTED", "colour": "AMBER", "slot": "centre"},
			{"kind": "caption", "at": 0.3, "for": 2.1, "slot": "left_low",
				"text": ["A tactical withdrawal. (Rounded up.)", "Brindle: \"Noted.\"", "The Admiral departs. On schedule."]},
		],
		"short": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.8, "text": "FWOOMP", "anchor": "scooter"},
			{"kind": "stamp", "at": 0.3, "for": 0.9, "text": "ROUTED", "colour": "AMBER", "slot": "centre"},
		]},
	"tarn_sign_on": {"priority": 3, "on": "sign_on", "boss": "brindle", "earned": "brindle_routed",
		"full": [
			{"kind": "card", "at": 0.0, "for": 2.0, "slot": "left_top",
				"card": ["TARN", "New pilot, claw bruiser", "Temperament", "gentle", "Machine", "is not", "Claws issued", "none"]},
			{"kind": "stamp", "at": 0.0, "for": 2.0, "text": "HIRED", "colour": "AMBER"},
			{"kind": "caption", "at": 0.3, "for": 1.7, "slot": "left_low", "text": ["Start date: today. Claw: own.", "Paperwork: one claw, unissued.", "Shift starts now. Gloves optional."]},
		],
		"short": [
			{"kind": "card", "at": 0.0, "for": 1.6, "slot": "left_top", "card": ["TARN", "New pilot"]},
			{"kind": "stamp", "at": 0.0, "for": 1.6, "text": "HIRED", "colour": "AMBER"},
		]},
}


static func has(id: String) -> bool:
	return ROWS.has(id)


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


static func priority(id: String) -> int:
	return int(row(id).get("priority", 0))


static func pieces(id: String, short: bool) -> Array:
	return row(id).get("short" if short else "full", [])


static func length(id: String, short: bool) -> float:
	var end := 0.0
	for piece in pieces(id, short):
		end = maxf(end, float(piece.at) + float(piece["for"]))
	return end


static func pick(value, run_seed: int, salt: String):
	if not value is Array:
		return value
	var options: Array = value
	if options.is_empty():
		return ""
	return options[absi(hash([run_seed, salt])) % options.size()]


static func resolve(id: String, short: bool, run_seed: int) -> Array:
	var out: Array = []
	var list := pieces(id, short)
	for i in list.size():
		var piece: Dictionary = list[i].duplicate(true)
		var salt := "%s:%d" % [id, i]
		if piece.has("text"):
			piece.text = String(pick(piece.text, run_seed, salt))
		if piece.has("texts"):
			var texts: Array = []
			for j in piece.texts.size():
				texts.append(String(pick(piece.texts[j], run_seed, "%s:%d" % [salt, j])))
			piece.texts = texts
		out.append(piece)
	return out


static func lines(id: String) -> Array:
	var out: Array = []
	for form in ["full", "short"]:
		for piece in row(id).get(form, []):
			for field in piece.get("card", []):
				out.append(field)
			for key in ["text", "texts"]:
				if not piece.has(key):
					continue
				var values: Array = piece[key] if piece[key] is Array else [piece[key]]
				for value in values:
					if value is Array:
						out.append_array(value)
					else:
						out.append(value)
	return out


static func words(text: String) -> int:
	return text.split(" ", false).size()
