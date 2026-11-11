extends RefCounted

# The in-run flourishes (world 1 plan, units 3 and 4): short comic beats laid over play, each a
# row of timed pieces that flourish_player.gd draws. Nothing here touches a node.
#
# A row plays in full until a profile has seen most of it (seen key SEEN_PREFIX + id;
# flourish_player.gd SEEN_SHARE) and in its short form after.
# It never stops time and never takes the controls: play goes on under it (TONE-BIBLE guardrails),
# so `held` stays 0 unless a caller holds the run itself. Two ruled world beats bend that for a
# hand on the controls only (flourish_cues.gd): a glance turns the camera to the subject (bv)
# and a close-up slows the world while its panel is up (cf).
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
#   inset        a comic panel with a live close-up in it (flourish_inset.gd), on the right of
#                the play view: anchor (the subject), home (the anchor it comes to rest at) and
#                toward (the anchor its camera stands toward), all names in play()'s anchors
#
# TONE-READ: world 1 stage beats (unit 4), crew-log captions and card stats; every line awaits
# Andrew's read.
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
const KINDS := ["card", "stamp", "caption", "panels", "sfx_word", "speed_lines", "inset"]

const ROWS := {
	# Stage 1 entry, first stage of a run: the pump crew's card punches in at dawn.
	"cold_open": {"priority": 1,
		"full": [
			{"kind": "caption", "at": 0.0, "for": 2.0, "slot": "left_low",
				"text": ["Spillway Works. Dawn. Probably a Tuesday.", "Spillway Works. Dawn. Definitely a Wednesday.", "Spillway Works. Dawn. The kettle is on."]},
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
	# Rivet's cage gives way (rescue_completed "rivet").
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
			{"kind": "stamp", "at": 0.4, "for": 2.4, "text": "SHIFT COMPLETE", "colour": "AMBER"},
			{"kind": "caption", "at": 2.4, "for": 3.0, "slot": "left_low", "text": [
				"Shift log: seals checked. Admiral routed. Kettle still warm.",
				"Shift log: dam held. Flume drained. One badger, filed under weather.",
				"Shift log: pumps running. Nobody clocked the overtime."]},
		],
		"short": [
			{"kind": "stamp", "at": 0.0, "for": 2.0, "text": "SHIFT COMPLETE", "colour": "AMBER"},
			{"kind": "caption", "at": 0.2, "for": 1.8, "slot": "left_low", "text": [
				"Shift log: seals checked. Admiral routed. Kettle still warm.",
				"Shift log: dam held. Flume drained. One badger, filed under weather.",
				"Shift log: pumps running. Nobody clocked the overtime."]},
		]},
	# --- Brindle's beats (world 1 plan, unit 3). flourish_cues.gd starts them from the trigger
	# fields on, boss, phases and earned, and runs their "world" beats in the bowl. Arrival plays
	# inside BossRules.INTRO_SECONDS (3.0 s, no attack lands); phase panels inside the 2.0 s
	# transition beat (fight_phases.gd); rout and sign-on share the victory window.
	"brindle_arrival": {"priority": 3, "on": "arrival", "boss": "brindle",
		# The close-up (ruling cf): a low camera under the Requisition as it comes over the rim, in
		# a comic panel beside his card, and the world slowed to SLOW for as long as the panel is
		# up. Seconds here are the row's, which slow with the world: the panel's 0.7 s is about
		# 2.3 s on the wall clock.
		"world": {"full": [{"kind": "rise", "at": 0.0, "seconds": 1.4}, {"kind": "glance", "anchor": "ship", "seconds": 0.9},
				{"kind": "slow", "at": 0.15, "for": 0.7, "scale": 0.3}],
			"short": [{"kind": "glance", "anchor": "ship", "seconds": 0.7}]},
		"full": [
			{"kind": "speed_lines", "at": 0.0, "for": 0.9},
			{"kind": "sfx_word", "at": 0.1, "for": 1.0, "text": "HONK", "anchor": "ship"},
			{"kind": "inset", "at": 0.15, "for": 0.7, "anchor": "ship_body", "home": "ship", "toward": "arena"},
			# left_low: Moss's bubble carries Brindle's per-pilot threat line in the column's top
			# at the same moment (moss_bubble.gd, lore_rows intro), and the card sits under it.
			{"kind": "card", "at": 0.2, "for": 2.7, "slot": "left_low",
				"card": ["ADMIRAL BRINDLE", "Badger · Furnace Fleet", "Height", "two paws", "Iron", "twelve hundred tons (rounded up)", "Voice", "never raised"]},
			{"kind": "sfx_word", "at": 1.4, "for": 0.9, "text": "CHUNK", "anchor": "ship"},
		],
		"short": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.9, "text": "HONK", "anchor": "ship"},
			{"kind": "card", "at": 0.1, "for": 1.3, "slot": "left_low", "card": ["ADMIRAL BRINDLE", "Back. On schedule."]},
		]},
	# Phases two and three: one comic panel each, a beat shorter than the transition beat. The
	# stamp goes centre, clear of a taunt bubble up the column: the transition beat (#391) commits
	# no attack while it shows.
	"brindle_phase_2": {"priority": 3, "on": "phase", "boss": "brindle", "phases": [2],
		"world": {"full": [{"kind": "glance", "anchor": "ship", "seconds": 0.7}], "short": [{"kind": "glance", "anchor": "ship", "seconds": 0.6}]},
		"full": [
			{"kind": "caption", "at": 0.0, "for": 1.5, "slot": "left_low",
				"text": ["Brindle revises the arithmetic.", "Brindle carries the one.", "The figures were optimistic."]},
			{"kind": "stamp", "at": 0.1, "for": 1.4, "text": "FURNACE LIT", "colour": "AMBER", "slot": "centre"},
		],
		"short": [
			{"kind": "caption", "at": 0.0, "for": 1.2, "slot": "left_low", "text": ["Brindle revises the arithmetic.", "Brindle carries the one.", "The figures were optimistic."]},
			{"kind": "stamp", "at": 0.1, "for": 1.1, "text": "FURNACE LIT", "colour": "AMBER", "slot": "centre"},
		]},
	"brindle_phase_3": {"priority": 3, "on": "phase", "boss": "brindle", "phases": [3],
		"world": {"full": [{"kind": "glance", "anchor": "ship", "seconds": 0.7}], "short": [{"kind": "glance", "anchor": "ship", "seconds": 0.6}]},
		"full": [
			{"kind": "caption", "at": 0.0, "for": 1.5, "slot": "left_low",
				"text": ["Dignity: optional.", "Brindle rounds down. Once.", "Plan C. There was no plan B."]},
			{"kind": "stamp", "at": 0.1, "for": 1.4, "text": "ARMOUR OFF", "colour": "AMBER", "slot": "centre"},
		],
		"short": [
			{"kind": "caption", "at": 0.0, "for": 1.2, "slot": "left_low", "text": ["Dignity: optional.", "Brindle rounds down. Once.", "Plan C. There was no plan B."]},
			{"kind": "stamp", "at": 0.1, "for": 1.1, "text": "ARMOUR OFF", "colour": "AMBER", "slot": "centre"},
		]},
	# The catch: the scooter sails over the rim in slow motion while the crew cheer. The victory
	# card waits for it, then stamps BRINDLE ROUTED.
	"brindle_rout": {"priority": 3, "on": "rout", "boss": "brindle",
		"world": {"full": [{"kind": "eject", "at": 0.0, "seconds": 1.8}], "short": [{"kind": "eject", "at": 0.0, "seconds": 1.1}]},
		"full": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.9, "text": "FWOOMP", "anchor": "scooter"},
			{"kind": "stamp", "at": 0.9, "for": 1.5, "text": "ROUTED", "colour": "AMBER", "slot": "centre"},
			{"kind": "caption", "at": 1.2, "for": 1.2, "slot": "left_low",
				"text": ["A tactical withdrawal. (Rounded up.)", "Brindle: \"Noted.\"", "The Admiral departs. On schedule."]},
		],
		"short": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.8, "text": "FWOOMP", "anchor": "scooter"},
			{"kind": "stamp", "at": 0.3, "for": 0.9, "text": "ROUTED", "colour": "AMBER", "slot": "centre"},
		]},
	# Tarn signs on the day Brindle falls (achievement brindle_routed pays Tarn). Plays once, over
	# the victory card; the card is the walk-in, the stamp is the contract.
	"tarn_sign_on": {"priority": 3, "on": "sign_on", "boss": "brindle", "earned": "brindle_routed",
		"full": [
			{"kind": "sfx_word", "at": 0.0, "for": 0.8, "text": "CLANK", "at_share": Vector2(0.50, 0.40)},
			{"kind": "card", "at": 0.0, "for": 2.0, "slot": "left_top",
				"card": ["TARN", "Tiger · claw bruiser", "Temperament", "gentle", "Machine", "is not", "Claws issued", "none"]},
			{"kind": "stamp", "at": 0.7, "for": 1.3, "text": "HIRED", "colour": "AMBER"},
			{"kind": "caption", "at": 0.9, "for": 1.1, "slot": "left_low", "text": ["Start date: today. Claw: own.", "Paperwork: one claw, unissued.", "Shift starts now. Gloves optional."]},
		],
		"short": [
			{"kind": "card", "at": 0.0, "for": 1.6, "slot": "left_top", "card": ["TARN", "Signed on"]},
			{"kind": "stamp", "at": 0.3, "for": 1.3, "text": "HIRED", "colour": "AMBER"},
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
