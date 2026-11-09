extends RefCounted

# The objective plate's one source (design-v3/LEGIBILITY.md, "A goal exists"): each row is a
# glyph and at most five words, and choose() picks the row from a reading of the game, so
# the plate, the edge marker and the tests all read the same table. flow.objective_text()
# and the long `objective` strings in event_kinds.gd stay the full readout the HUD does not show.

const MAX_WORDS := 5

const ROWS := {
	"find_activity": {"glyph": "obj_event", "words": "Find an activity"},
	"find_warden": {"glyph": "obj_warden", "words": "Find the Warden"},
	"break_guard": {"glyph": "cat_defense", "words": "Break its guard"},
	"smash_core": {"glyph": "cat_damage", "words": "Smash the core"},
	"grow_return": {"glyph": "res_heft", "words": "Grow, then return"},
	"break_warden": {"glyph": "obj_warden", "words": "Break the Warden"},
	"charge_beacon": {"glyph": "obj_beacon", "words": "Charge the beacon"},
	"roll_gate": {"glyph": "obj_gate", "words": "Roll through a gate"},
	"hold_line": {"glyph": "obj_gate", "words": "Hold your line"},
	"break_brindle": {"glyph": "fac_fleet", "words": "Break Brindle's Requisition"},
	"break_yard_crew": {"glyph": "cat_damage", "words": "Yard locked: break the crew"},
	"break_clamp_crews": {"glyph": "cat_defense", "words": "Clamp shut: break the crews"},
	# A mounted reactor Warden's own road to its core (warden_reactor.gd): the dam's sheet ram,
	# the flume's line fight. They stand where "Break its guard" stands on any other Warden.
	"ride_sheet": {"glyph": "cat_defense", "words": "Ride the water sheet up"},
	"latch_warden": {"glyph": "cat_defense", "words": "Latch onto the Warden"},
	"fire_from_line": {"glyph": "cat_defense", "words": "Fire from the line"},
	# Brindle's fight by phase (boss.gd plate_reading; objective_text() is the long readout).
	"shoot_magnets": {"glyph": "fac_fleet", "words": "Shoot the crane magnets"},
	"slam_caps": {"glyph": "fac_fleet", "words": "Slam the vent caps"},
	"bait_charge": {"glyph": "fac_fleet", "words": "Bait his charge into walls"},
	"hit_cockpit": {"glyph": "cat_damage", "words": "Hit the open cockpit"},
	"ram_scooter": {"glyph": "fac_fleet", "words": "Ram the Admiral's scooter"},
}

# What "find_activity" says when the plate knows which site is nearest: the site's kind
# (EventKinds.ACTIVITY_ROWS) and the verb that finishes it (activities.gd RULES `finishes`).
const ACTIVITY_WORDS := {
	"enemy_camp": "Clear the camp",
	"ambush_altar": "Spring the ambush",
	"cracked_cache": "Crack open the cache",
	"hold_the_relay": "Hold the relay",
	"surge_run": "Outrun the surge",
	"hauler_bounty": "Break the bounty hauler",
}

# What choose() reads. state is flow.state_name(); card is true while the stage card owns
# the launch moment; distance is the ball's metres to the Warden; yard_locked and clamp_shut
# are the stage locks' yard and Warden clamp holding (stage_locks.gd lock_active(), locked()).
const EMPTY_READING := {"state": "", "sealed": false, "engaged": false, "fight": "plating", "staggered": false,
	"struggling": false, "distance": INF, "card": false, "activities_left": 0, "yard_locked": false, "clamp_shut": false,
	"mount": "", "latched": false, "phase": 0, "open": false}


static func glyph(id: String) -> String:
	return ROWS[id]["glyph"] if ROWS.has(id) else ""


static func words(id: String) -> String:
	return ROWS[id]["words"] if ROWS.has(id) else ""


# The "find_activity" row's words for a site of this kind; the row's own for a kind with none.
static func activity_words(kind: String) -> String:
	return String(ACTIVITY_WORDS.get(kind, ROWS["find_activity"]["words"]))


# The row id the plate shows for this reading, or "" when it shows nothing.
static func choose(reading: Dictionary) -> String:
	var r: Dictionary = EMPTY_READING.duplicate()
	r.merge(reading, true)
	match r["state"]:
		"stage", "beacon":
			if r["yard_locked"]:
				return "break_yard_crew"
			if not r["sealed"]:
				return "charge_beacon"
			if not r["engaged"] and int(r["activities_left"]) > 0:
				return "find_activity"
			if r["fight"] == "posture":
				if not r["engaged"]:
					return "find_warden"
				if r["clamp_shut"]:
					return "break_clamp_crews"
				if r["staggered"]:
					return "smash_core"
				if r["struggling"]:
					return "grow_return"
				match r["mount"]:
					"dam_face":
						return "ride_sheet"
					"flume":
						return "fire_from_line" if r["latched"] else "latch_warden"
				return "break_guard"
			return "break_warden"
		"gates":
			return "roll_gate"
		"launch":
			return "" if r["card"] else "hold_line"
		"boss":
			match int(r["phase"]):
				1:
					return "shoot_magnets"
				2:
					return "slam_caps"
				3:
					return "hit_cockpit" if r["open"] else "bait_charge"
				4:
					return "ram_scooter"
			return "break_brindle"
	return ""


# Counts the seconds a build spends trying against a posture Warden. A second counts while
# the posture gained within the last GAIN_WINDOW seconds; GAIN_WINDOW seconds with no gain
# drop the tally, so only sustained effort adds up. TRYING_SECONDS of it with posture never
# at CLEAR_AT is struggling. Reaching CLEAR_AT or a stagger clears it for the engagement,
# a gain after TRYING_SECONDS away (the player left, grew and came back) clears it and the
# tally, and begin() starts the next engagement. It is fed by posture_changed and simulated
# seconds, never a hit count or the wall clock.
class Struggle:
	extends RefCounted

	const GAIN_WINDOW := 3.0
	const TRYING_SECONDS := 10.0
	const CLEAR_AT := 50.0

	var tally := 0.0
	var struggling := false
	var _since_gain := INF
	var _posture := 0.0
	var _cleared := false

	func begin() -> void:
		tally = 0.0
		struggling = false
		_since_gain = INF
		_posture = 0.0
		_cleared = false

	# posture_changed's reading: the bar now and whether the Warden is staggered.
	func note_posture(posture: float, staggered: bool) -> void:
		if staggered or posture >= CLEAR_AT:
			_cleared = true
			tally = 0.0
			struggling = false
			return
		if posture > _posture:
			if _since_gain >= TRYING_SECONDS:
				tally = 0.0
				struggling = false
			_since_gain = 0.0
		_posture = posture

	func step(delta: float) -> void:
		if _cleared:
			return
		_since_gain += delta
		if struggling:
			return
		if _since_gain <= GAIN_WINDOW:
			tally += delta
		else:
			tally = 0.0
		if tally >= TRYING_SECONDS:
			struggling = true
