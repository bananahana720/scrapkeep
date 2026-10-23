extends RefCounted

# The in-run flourishes (world 1 plan, units 3 and 4): short comic beats laid over play, each a
# row of timed pieces that flourish_player.gd draws. Nothing here touches a node.
#
# A row plays in full once per profile (seen key SEEN_PREFIX + id) and in its short form after.
# It never stops time and never takes the camera: play goes on under it (TONE-BIBLE guardrails),
# so `held` stays 0 unless a caller holds the run itself.
#
#   priority  a higher row ends a lower one that is showing; an equal or lower one waits its turn
#   full      the first-time pieces; short: the repeat pieces. Each piece is
#             {kind, at, for, ...}: at and for in seconds from the row's start.
#
# Piece kinds and their fields:
#   card         card: [title, subtitle, stat, value, ...] as the title openings' cards; slot
#   stamp        text, colour (Palette name), slot: "column" (default) or "centre"; an inked
#                word with three frames of overshoot
#   caption      text; slot: "left_top" or "left_low"
#   panels       texts: up to three comic panels, popping one every PANEL_STEP seconds
#   sfx_word     text; anchor (a name in play()'s anchors) or at: Vector2 screen share
#   speed_lines  no fields; reduced motion drops it
#
# Any text field may be an Array of variants: the run seed picks one (pick()), so a seed always
# shows the same line and a new run may show another (principle 21).

const SEEN_PREFIX := "flourish:"
const MAX_SECONDS := 6.0
const MAX_SHORT_SECONDS := 2.5
const PANEL_STEP := 0.6
# Lore lines keep the prologue's cap (prologue_rows.gd).
const LINE_WORD_CAP := 14
const SLOTS := ["left_top", "left_low", "column", "centre"]
const KINDS := ["card", "stamp", "caption", "panels", "sfx_word", "speed_lines"]

const ROWS := {
	# Stage 1 entry, first stage of a run: the pump crew's card punches in at dawn.
	"cold_open": {"priority": 1,
		"full": [
			{"kind": "caption", "at": 0.0, "for": 4.0, "slot": "left_low",
				"text": ["Spillway Works. Dawn. Probably a Tuesday.", "Spillway Works. Dawn. Definitely a Wednesday.", "Spillway Works. Dawn. The kettle is on."]},
			{"kind": "card", "at": 0.6, "for": 4.4, "slot": "left_top",
				"card": ["PUMP CREW", "Card 0417 · Spillway shift", "Clocked in", "06:00", "Hands on shift", "all", "Runner", "not back yet"]},
			{"kind": "stamp", "at": 1.4, "for": 2.0, "text": "CLOCKED IN", "colour": "HAZARD"},
			{"kind": "sfx_word", "at": 1.4, "for": 1.2, "text": "KA-CHUNK", "at_share": Vector2(0.62, 0.34)},
			{"kind": "caption", "at": 4.2, "for": 1.4, "slot": "left_low",
				"text": ["Moss packed a spare card.", "Moss packed a spare thermos.", "Moss packed two. Just in case."]},
		],
		"short": [
			{"kind": "stamp", "at": 0.0, "for": 1.8, "text": "CLOCKED IN", "colour": "HAZARD"},
			{"kind": "sfx_word", "at": 0.0, "for": 1.0, "text": "KA-CHUNK", "at_share": Vector2(0.62, 0.34)},
		]},
	# Rivet's cage gives way (rescue_completed "rivet").
	"rivet_freed": {"priority": 2,
		"full": [
			{"kind": "sfx_word", "at": 0.0, "for": 1.2, "text": "KLANG!", "anchor": "cage"},
			{"kind": "panels", "at": 0.3, "for": 5.3,
				"texts": ["The cage. Opened from inside.", ["He measured the bars. Twice.", "Visor up. Tiny proud eyes."],
					["Moss packed spare lenses.", "Moss packed a spare visor.", "Moss had a feeling."]]},
			{"kind": "stamp", "at": 1.8, "for": 2.2, "text": "BACK ON SHIFT", "colour": "ARC"},
		],
		"short": [
			{"kind": "sfx_word", "at": 0.0, "for": 1.0, "text": "KLANG!", "anchor": "cage"},
			{"kind": "stamp", "at": 0.2, "for": 1.4, "text": "BACK ON SHIFT", "colour": "ARC"},
		]},
	# The flume's meltdown Warden engages for the first time on a stage attempt.
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
	# World 1's last stage unseals: the hand-off into the Slag Bowl, before Brindle's arrival.
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
	# After Brindle's rout (boss_defeated in world 1); waits behind the rout's own row.
	"spillway_clear": {"priority": 0,
		"full": [
			{"kind": "card", "at": 0.0, "for": 4.2, "slot": "left_top",
				"card": ["SPILLWAY WORKS", "World one · shift log", "Pumps", "running", "Admiral", "routed (politely)", "Overtime", "logged, not paid"]},
			{"kind": "stamp", "at": 0.4, "for": 2.4, "text": "SHIFT COMPLETE", "colour": "HAZARD"},
			{"kind": "caption", "at": 2.4, "for": 3.0, "slot": "left_low", "text": [
				"Shift log: seals checked. Admiral routed. Kettle still warm.",
				"Shift log: dam held. Flume drained. One badger, filed under weather.",
				"Shift log: pumps running. Nobody clocked the overtime."]},
		],
		"short": [
			{"kind": "stamp", "at": 0.0, "for": 2.0, "text": "SHIFT COMPLETE", "colour": "HAZARD"},
			{"kind": "caption", "at": 0.2, "for": 1.8, "slot": "left_low", "text": [
				"Shift log: seals checked. Admiral routed. Kettle still warm.",
				"Shift log: dam held. Flume drained. One badger, filed under weather.",
				"Shift log: pumps running. Nobody clocked the overtime."]},
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


# Seconds the row stays on screen in that form.
static func length(id: String, short: bool) -> float:
	var end := 0.0
	for piece in pieces(id, short):
		end = maxf(end, float(piece.at) + float(piece["for"]))
	return end


# A variant field's value for this seed: a String stays as it is; an Array gives one entry,
# the same one every time for the same seed, row and field.
static func pick(value, run_seed: int, salt: String):
	if not value is Array:
		return value
	var options: Array = value
	if options.is_empty():
		return ""
	return options[absi(hash([run_seed, salt])) % options.size()]


# The row's pieces in that form with every variant field picked for the seed.
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


# Every line a row can show, for the word-cap and tone checks.
static func lines(id: String) -> Array:
	var out: Array = []
	for form in ["full", "short"]:
		for piece in row(id).get(form, []):
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
