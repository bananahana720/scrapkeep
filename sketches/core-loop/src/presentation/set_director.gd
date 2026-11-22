extends RefCounted

# The set director: the DJ behind the band (design-v3/SOUND-BIBLE.md, "The set"; Andrew, 12
# November 2026: "it should feel like there is a backend dj that mixes things and orchestrates
# things perfectly with the player's experience"). Arlo at the decks reads the room once a bar
# and plans the next bar: the room's mood, one move, and June's sax answer at the end of each
# phrase. audio.gd applies the plan on the bar line; this file only decides.
#
# The rules it keeps:
#   - one read a bar, one plan a bar, and nothing changes off the bar line;
#   - a mood climbs on the next bar but falls only after it has been low for MOOD_HOLD_BARS,
#     so a room that hovers at a line never flutters, and a fall from the peak passes
#     through release;
#   - trims only pull a stem down, never push it over the recording, and every pulled stem
#     is back by the next plan unless the move holds it;
#   - one melody at a time: June answers only on the phrase's last bar, only when no warning,
#     no other melodic cue and no fight section owns the lead, and the recorded lead steps
#     back for her bar;
#   - her answers walk a phrase book in order (statement, variation, development, home), so
#     the melody progresses, and the same answer never plays twice in a row;
#   - melody first: at least MIN_GAP_BARS between any two moves, so the song carries and each
#     move is an event (about two a minute at most, fights included); a phrase June does not
#     answer may end on a breakdown, which keeps the melody; the band's own directed sections
#     and boss and set-piece songs play as written;
#   - no randomness: the same rooms give the same set, in bots and in play.

const PHRASE_BARS := 8
const MOOD_HOLD_BARS := 2
const RELEASE_BARS := 2
# The energy lines between moods, climbing and falling.
const BUILD_UP := 0.3
const BUILD_DOWN := 0.18
const PEAK_UP := 0.62
const PEAK_DOWN := 0.48
# How close below the peak line, and rising, a room counts as about to peak.
const PEAK_NEAR := 0.1
# The recorded lead under June's answer.
const LEAD_SPACE := 0.35
# How deep a filter roll sweeps the band (the low-pass's wet share at the end of its bar).
const SWEEP_DEPTH := 0.85
# Melody first (Andrew, 13 November 2026, on the whole-stretch page: "it sounds really chaotic
# and I can't really follow the song"): at least MIN_GAP_BARS between any two moves, across
# records, so the song carries and a move is an event. About two moves a minute at most.
const MIN_GAP_BARS := 16
# The turnaround move when June is not answering: the drums step out for a breakdown, which
# keeps the melody and only takes sound away, so it never masks a warning. The filter roll is
# kept for a real change (a climb into the peak, a set piece landing) and the lead never drops.
const TURNS := ["breakdown"]
# Fight words whose own form is the move, where the director holds: the Warden's breath and
# drop, a directed piece, "directed" (a section the band directs itself: its pivot, break,
# return and home) and "anthem" (a boss or set-piece song, which plays as written).
const OWN_FORM := ["open", "drop", "piece", "directed", "anthem"]
# Heat's band (redline.gd: 0 cool, 1 a quarter, 2 hot, 3 redline) from which answers run hot.
const HOT_BAND := 2
# Armour fraction under which the room is hanging on (the band strips its lead there too).
const HANGING := 0.3
# Plans kept for a recording across every band of a run (about 25 minutes of bars).
const PLANS_KEPT := 1024

# The room's floor in each fight word (INTEGRATION section 7): the guard holding is a build,
# the guard cracking and the drop are the peak, the breath and the break are release.
# A flat pack's anthem (a miniboss, Brindle or a set-piece tune) is a fight at the build's top.
const FIGHT_FLOOR := {"closed": 0.45, "telegraph": 0.75, "drop": 0.9, "anthem": 0.55}
const FIGHT_RELEASE := ["open", "piece"]
# Fight sections that own the lead: June never answers over them.
const LEAD_OWNED := ["open", "drop", "piece", "anthem"]

# June's phrase book. Each answer is one bar of [sixteenth, midi, sixteenths], with an optional
# fourth field naming the voice ("lead", the synth sax, when absent). Every pitch is in D Dorian
# or a C# leading home, never on the threat notes Eb, Ab, Bb (SOUND-STORY registers), so an
# answer is never heard as a warning. Each book is ordered statement, variation, development,
# home: walked in order, the answers tell a short story and end where they began.
const BOOK := {
	"lull": [
		{"id": "lull_a", "cells": [[2, 69, 2], [4, 72, 2], [7, 74, 5]]},
		{"id": "lull_b", "cells": [[2, 69, 2], [4, 72, 2], [6, 71, 1], [7, 69, 5]]},
		{"id": "lull_c", "cells": [[0, 74, 2], [3, 72, 1], [4, 71, 2], [6, 69, 2], [8, 67, 4]]},
		{"id": "lull_d", "cells": [[2, 65, 2], [4, 67, 2], [6, 69, 2], [8, 62, 6]]},
	],
	"build": [
		{"id": "build_a", "cells": [[0, 74, 2], [2, 76, 2], [4, 77, 2], [6, 79, 2], [8, 81, 4]]},
		{"id": "build_b", "cells": [[0, 81, 2], [2, 79, 2], [4, 77, 1], [5, 76, 1], [6, 74, 2], [8, 76, 4]]},
		{"id": "build_c", "cells": [[0, 74, 1], [2, 77, 1], [3, 79, 1], [5, 81, 3], [8, 83, 2], [10, 81, 4]]},
		{"id": "build_d", "cells": [[0, 79, 2], [2, 77, 2], [4, 76, 2], [6, 74, 6]]},
	],
	"peak": [
		{"id": "peak_a", "cells": [[0, 86, 1], [1, 86, 1], [3, 84, 2], [6, 81, 2], [8, 86, 4]]},
		{"id": "peak_b", "cells": [[0, 81, 1], [2, 84, 1], [3, 86, 1], [6, 88, 2], [8, 89, 2], [10, 86, 4]]},
		{"id": "peak_c", "cells": [[0, 86, 2], [3, 89, 1], [4, 88, 2], [6, 86, 1], [7, 84, 1], [8, 81, 6]]},
		{"id": "peak_d", "cells": [[0, 74, 1], [2, 81, 1], [4, 86, 2], [6, 84, 1], [7, 86, 7]]},
	],
	"release": [
		{"id": "release_a", "cells": [[0, 76, 2], [2, 79, 2], [4, 77, 1], [5, 76, 1], [6, 74, 6]]},
		{"id": "release_b", "cells": [[0, 81, 1], [1, 79, 1], [2, 77, 1], [3, 76, 1], [4, 74, 4], [8, 86, 2, "bell"]]},
	],
	# Heat: the shell running hot climbs the ladder and ends high.
	"hot": [
		{"id": "hot_a", "cells": [[0, 74, 1], [1, 76, 1], [2, 77, 1], [3, 79, 1], [4, 81, 1], [5, 83, 1], [6, 84, 1], [7, 86, 5]]},
		{"id": "hot_b", "cells": [[0, 81, 1], [1, 83, 1], [2, 84, 1], [3, 85, 1], [4, 86, 2], [6, 88, 1], [7, 89, 1], [8, 91, 4]]},
	],
	# Overtime: the keeper's bell rang, so the brass calls the shift and the sax signs it.
	"overtime": [
		{"id": "overtime_a", "cells": [[0, 62, 2, "brass"], [2, 62, 1, "brass"], [4, 69, 2, "brass"], [6, 74, 4]]},
		{"id": "overtime_b", "cells": [[0, 74, 2, "brass"], [2, 72, 1, "brass"], [3, 74, 1, "brass"], [4, 77, 2], [6, 74, 6]]},
	],
	# Hanging on: a fall that winks (the tone bible's sad-but-corny): down home, then a bell.
	"hanging": [
		{"id": "hanging_a", "cells": [[0, 81, 2], [2, 79, 2], [4, 77, 2], [6, 76, 1], [7, 74, 5], [12, 86, 2, "bell"]]},
		{"id": "hanging_b", "cells": [[0, 77, 1], [1, 76, 1], [2, 74, 2], [4, 73, 2], [6, 74, 6]]},
	],
}
const THREAT_PITCH_CLASSES := [3, 8, 10]

var bar := -1
var mood := "lull"
var energy := 0.0
var _low_bars := 0
var _release_left := 0
var _rising := false
var _turn_move := 0
# Bars since the last move, kept across records so a change of record never doubles a move.
var _since_move := MIN_GAP_BARS
var _turns := {}
var _last_answer := ""
var _swap_armed := true
var _landing_swapped := false
# Every plan of the run, kept across band changes up to PLANS_KEPT, for the recorder and the tests:
# [bar, mood, move, answer, transport sample of the bar or -1, why a turnaround held or "", fight word].
var plans: Array = []


func reset() -> void:
	bar = -1
	mood = "lull"
	energy = 0.0
	_low_bars = 0
	_release_left = 0
	_rising = false
	_turns = {}
	_last_answer = ""
	_swap_armed = true
	_landing_swapped = false


# The room's energy, 0 to 1, from the read audio.gd gathers (every key optional):
#   pressure, threat, chain, approach, speed: 0 to 1 (the band's own faders);
#   heat: redline band 0 to 3; overtime: bool; armour: fraction of the run's peak;
#   fight: "" outside a fight, else the band's fight word (closed, telegraph, open, drop, piece).
static func room_energy(room: Dictionary) -> float:
	var e := maxf(maxf(float(room.get("pressure", 0.0)), 0.85 * float(room.get("threat", 0.0))),
		maxf(0.9 * float(room.get("chain", 0.0)), 0.6 * float(room.get("approach", 0.0))))
	e += 0.15 * float(room.get("speed", 0.0)) + 0.08 * float(room.get("heat", 0))
	if bool(room.get("overtime", false)):
		e = maxf(e, 0.45)
	e = maxf(e, float(FIGHT_FLOOR.get(String(room.get("fight", "")), 0.0)))
	return clampf(e, 0.0, 1.0)


# The room's colour: what June's answer speaks to before the mood. Hanging on outranks the
# shift, which outranks heat.
static func colour(room: Dictionary) -> String:
	if room.has("armour") and float(room.armour) < HANGING:
		return "hanging"
	if bool(room.get("overtime", false)):
		return "overtime"
	if int(room.get("heat", 0)) >= HOT_BAND:
		return "hot"
	return ""


# Reads the room for the coming bar and returns its plan:
#   {bar, mood, move, trims: {stem: gain}, answer: phrase id or "", sweep: low-pass depth the
#   band rolls to across the bar}.
# room may also carry warning (a danger or telegraph cue is sounding or due inside the bar),
# busy (another melodic cue owns the bar) and incoming_bars (bars until a set piece the
# conductor has announced, 0 when none).
func read(room: Dictionary) -> Dictionary:
	bar += 1
	var was := mood
	var e := room_energy(room)
	_rising = e > energy
	energy = e
	mood = _next_mood(room, e)
	var at := bar % PHRASE_BARS
	var plan := {"bar": bar, "mood": mood, "move": "hold", "trims": {}, "answer": "", "sweep": 0.0}
	var fight := String(room.get("fight", ""))
	var turnaround := at == PHRASE_BARS - 1
	_since_move += 1
	var free := _since_move >= MIN_GAP_BARS
	var incoming := int(room.get("incoming_bars", 0))
	# The rise into a peak or a set piece: one per climb, re-armed when the room falls under the
	# peak's fall line (so a guard holding near it never rolls twice) or leaves build, and one per announcement. Outside a fight the bass steps
	# out for the bar and slams back on the downbeat; in a fight the band rolls under the filter.
	if mood != "build" or e < PEAK_DOWN - PEAK_NEAR:
		_swap_armed = true
	var climb := _swap_armed and mood == "build" and _rising and e >= PEAK_UP - PEAK_NEAR
	var landing := incoming == 1 and not _landing_swapped
	if incoming != 1:
		_landing_swapped = false
	if free and not fight in OWN_FORM and mood != "peak" and (climb or landing):
		_swap_armed = false
		_landing_swapped = incoming == 1
		if fight == "":
			plan.move = "bass_swap"
			plan.trims = {"bass": 0.0}
		else:
			plan.move = "filter_roll"
			plan.sweep = SWEEP_DEPTH
	elif free and turnaround and _answer_allowed(room, fight):
		plan.move = "answer"
		plan.answer = _pick(_book_for(room))
		plan.trims = {"other": LEAD_SPACE}
	elif free and turnaround and not fight in OWN_FORM:
		_turn(plan)
	elif free and mood == "release" and was != "release" and not bool(room.get("warning", false)) and not bool(room.get("busy", false)) and not fight in LEAD_OWNED:
		plan.move = "home"
		plan.answer = _pick("release")
		plan.trims = {"other": LEAD_SPACE}
	if plan.answer != "":
		_last_answer = plan.answer
	if plan.move != "hold":
		_since_move = 0
	# Why a turnaround passed without an answer, for the listening reads.
	var held := ""
	if turnaround and plan.answer == "":
		held = "gap" if not free else "warning" if bool(room.get("warning", false)) else "busy" if bool(room.get("busy", false)) else fight if fight in LEAD_OWNED else plan.move
	if plans.size() < PLANS_KEPT:
		plans.append([bar, mood, plan.move, plan.answer, int(room.get("sample", -1)), held, fight])
	return plan


# The next turnaround move in order.
func _turn(plan: Dictionary) -> void:
	plan.move = TURNS[_turn_move % TURNS.size()]
	_turn_move += 1
	match plan.move:
		"filter_roll":
			plan.sweep = SWEEP_DEPTH
		"dub":
			plan.trims = {"other": 0.0}
		"breakdown":
			plan.trims = {"drums": 0.0}


func _next_mood(room: Dictionary, e: float) -> String:
	if String(room.get("fight", "")) in FIGHT_RELEASE:
		_release_left = RELEASE_BARS
		_low_bars = 0
		return "release"
	var target := "lull"
	if e >= PEAK_UP or (mood == "peak" and e >= PEAK_DOWN):
		target = "peak"
	elif e >= BUILD_UP or (mood != "lull" and e >= BUILD_DOWN):
		target = "build"
	if mood == "release":
		_release_left -= 1
		if target == "peak" or _release_left <= 0:
			_release_left = 0
			return target
		return "release"
	if _rank(target) >= _rank(mood):
		_low_bars = 0
		return target
	_low_bars += 1
	if _low_bars < MOOD_HOLD_BARS:
		return mood
	_low_bars = 0
	if mood == "peak":
		_release_left = RELEASE_BARS
		return "release"
	return target


static func _rank(name: String) -> int:
	return {"lull": 0, "build": 1, "peak": 2}.get(name, 0)


func _answer_allowed(room: Dictionary, fight: String) -> bool:
	return not bool(room.get("warning", false)) and not bool(room.get("busy", false)) and not fight in LEAD_OWNED and not fight in OWN_FORM


func _book_for(room: Dictionary) -> String:
	var c := colour(room)
	return c if c != "" else mood


# The next answer in the book, in order; one that would repeat the last answer is passed over.
func _pick(book: String) -> String:
	var rows: Array = BOOK[book]
	var turn := int(_turns.get(book, 0))
	var row: Dictionary = rows[turn % rows.size()]
	if row.id == _last_answer and rows.size() > 1:
		turn += 1
		row = rows[turn % rows.size()]
	_turns[book] = turn + 1
	return row.id


static func has_answer(id: String) -> bool:
	return not _row(id).is_empty()


static func _row(id: String) -> Dictionary:
	for book in BOOK:
		for row in BOOK[book]:
			if row.id == id:
				return row
	return {}


# The answer's score for Synth.render_score: rows of [step, midi, steps, voice, gain] in
# sixteenths, the sax a little under the pilot's quote so the quote stays the bigger moment.
# Expressive phrasing shapes passing sixteenths lighter and sustained landings warmer, with
# an understated in-key harmonic cushion on the phrase's arrival (never on a threat note).
static func answer_score(id: String) -> Array:
	var book_name := _book_of(id)
	var cells: Array = _row(id).get("cells", [])
	if cells.is_empty():
		return []
	var score: Array = []
	var count := cells.size()
	var peak_midi := -1
	for cell in cells:
		peak_midi = maxi(peak_midi, int(cell[1]))
	for i in count:
		var cell: Array = cells[i]
		var step := int(cell[0])
		var midi := int(cell[1])
		var dur := int(cell[2])
		var voice: String = cell[3] if cell.size() > 3 else "lead"
		var base_gain := 0.55 if voice == "bell" else 0.7
		var phrase := 1.0
		if voice != "bell":
			if dur >= 4:
				phrase = 1.12
			elif midi == peak_midi:
				phrase = 1.08
			elif dur == 1 and step % 2 == 1:
				phrase = 0.86
		score.append([step, midi, dur, voice, base_gain * phrase])
	# Add a gentle harmonic cushion on the phrase's landing note, strictly within the 1-bar
	# grid (step < 16) and strictly off THREAT_PITCH_CLASSES (Eb, Ab, Bb).
	var land: Array = cells[count - 1]
	var land_step := int(land[0])
	var land_midi := int(land[1])
	var land_dur := maxi(2, mini(int(land[2]), 16 - land_step))
	if land_step < 16:
		match book_name:
			"lull", "release", "hanging":
				for chord_midi in [62, 69]:
					score.append([land_step, chord_midi, land_dur, "keys", 0.24])
			"build":
				for chord_midi in [62, 69]:
					score.append([land_step, chord_midi, land_dur, "keys", 0.26])
			"peak":
				score.append([land_step, land_midi - 12, land_dur, "brass", 0.28])
				if not posmod(land_midi + 12, 12) in THREAT_PITCH_CLASSES:
					score.append([land_step, land_midi + 12, mini(land_dur, 3), "bell", 0.22])
			"hot":
				score.append([land_step, 62, land_dur, "clav", 0.26])
				score.append([land_step, 69, land_dur, "keys", 0.22])
			"overtime":
				if not posmod(land_midi - 12, 12) in THREAT_PITCH_CLASSES:
					score.append([land_step, land_midi - 12, land_dur, "brass", 0.32])
	return score


static func _book_of(id: String) -> String:
	for book in BOOK:
		for row in BOOK[book]:
			if row.id == id:
				return book
	return ""
