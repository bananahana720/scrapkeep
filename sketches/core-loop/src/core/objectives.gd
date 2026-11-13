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
	"grow_return": {"glyph": "res_heft", "words": "Get heavy, then return"},
	"break_warden": {"glyph": "obj_warden", "words": "Break the Warden"},
	"charge_beacon": {"glyph": "obj_beacon", "words": "Charge the beacon"},
	"roll_gate": {"glyph": "obj_gate", "words": "Roll through a gate"},
	"hold_line": {"glyph": "obj_gate", "words": "Hold your line"},
	"break_brindle": {"glyph": "fac_fleet", "words": "Break Brindle's Requisition"},
	"break_yard_crew": {"glyph": "cat_damage", "words": "Break the yard crew"},
	"break_clamp_crews": {"glyph": "cat_defense", "words": "Break the clamp crews"},
	# A mounted reactor Warden's own road to its core (warden_reactor.gd): the dam's sheet ram,
	# the flume's line fight. They stand where "Break its guard" stands on any other Warden.
	"ride_sheet": {"glyph": "cat_defense", "words": "Ride the water sheet up"},
	"line_fight": {"glyph": "cat_defense", "words": "Hook, shoot, smash core"},
	# Brindle's fight by phase (boss.gd plate_reading; objective_text() is the long readout). A phase's
	# row names its whole loop and holds for the phase (see choose()).
	"shoot_magnets": {"glyph": "fac_fleet", "words": "Shoot magnets, then cockpit"},
	"slam_caps": {"glyph": "fac_fleet", "words": "Slam caps, then cockpit"},
	"bait_charge": {"glyph": "fac_fleet", "words": "Bait into walls, then cockpit"},
	"ram_scooter": {"glyph": "fac_fleet", "words": "Ram the Admiral's scooter"},
}

# What "find_activity" says for the site at hand (activities.gd at_hand): the site's kind
# (EventKinds.ACTIVITY_ROWS) and the verb that finishes it (activities.gd RULES `finishes`).
const ACTIVITY_WORDS := {
	"enemy_camp": "Clear the camp",
	"ambush_altar": "Break the ambush",
	"cracked_cache": "Crack open the cache",
	"hold_the_relay": "Hold the relay",
	"surge_run": "Outrun the surge",
	"hauler_bounty": "Break the bounty hauler",
	"stocktake_yard": "Clear the count",
	# The trade spots by their ruled names (ruling ci): the risky ones are the keeper's gamble, the
	# safe one the foreman's kindness. The site's own label says the same.
	"trade_risk": "The keeper's gamble",
	"curse": "The keeper's gamble",
	"sacrifice": "The keeper's gamble",
	"trade_safe": "The foreman's kindness",
}

# What the plate says for Done.SECONDS when a goal is finished, in the goal's own place: a site by
# its kind, and the stage's own steps (the yard, the Warden's clamp, the Warden).
const DONE_WORDS := {
	"enemy_camp": "Camp cleared",
	"ambush_altar": "Ambush broken",
	"cracked_cache": "Cache cracked",
	"hold_the_relay": "Relay held",
	"surge_run": "Surge outrun",
	"hauler_bounty": "Bounty hauler broken",
	"stocktake_yard": "Count banked",
	"trade_risk": "Gamble taken",
	"curse": "Gamble taken",
	"sacrifice": "Gamble taken",
	"trade_safe": "Kindness taken",
	"yard": "Yard open",
	"clamp": "Clamp open",
	"warden": "Warden broken",
}

# And when a site that can be lost is lost (it re-arms; activities.gd `retry_s`).
const LOST_WORDS := {
	"hold_the_relay": "Relay lost",
	"surge_run": "Surge lost",
	"stocktake_yard": "Count forfeit",
}

# The one or two words a mark wears on the thing the plate's row sends the player at
# (ui/edge_markers.gd), by what the thing or the move there is (boss.gd and warden_reactor.gd
# plate_targets). The plate is the plan; the mark is the next move, on the thing itself.
const TAGS := {
	"magnet": "MAGNET",
	"cap": "VENT CAP",
	"cockpit": "COCKPIT",
	"scooter": "SCOOTER",
	"sheet": "RIDE UP",
	"sheet_soon": "WATER SOON",
	"latch": "HOOK",
	"shoot": "SHOOT",
	"core": "CORE",
}

# What choose() reads. state is flow.state_name(); card is true while the stage card owns
# the launch moment; distance is the ball's metres to the Warden; site_at_hand is true while the
# ball is at a side site it has started (activities.gd at_hand); yard_locked and clamp_shut
# are the stage locks' yard and Warden clamp holding (stage_locks.gd lock_active(), locked()).
const EMPTY_READING := {"state": "", "sealed": false, "engaged": false, "fight": "plating", "staggered": false,
	"struggling": false, "distance": INF, "card": false, "site_at_hand": false, "yard_locked": false, "clamp_shut": false,
	"mount": "", "phase": 0, "open": false}


static func glyph(id: String) -> String:
	return ROWS[id]["glyph"] if ROWS.has(id) else ""


static func words(id: String) -> String:
	return ROWS[id]["words"] if ROWS.has(id) else ""


# The "find_activity" row's words for a site of this kind. A kind with no words here is named by
# what its own marker calls it (called: a drawn pocket's cue word); with neither, the row's own words.
static func activity_words(kind: String, called := "") -> String:
	if ACTIVITY_WORDS.has(kind):
		return String(ACTIVITY_WORDS[kind])
	return called if called != "" else String(ROWS["find_activity"]["words"])


# The done row's words for a finished goal of this kind: its own, else what its marker calls it.
static func done_words(kind: String, called := "") -> String:
	if DONE_WORDS.has(kind):
		return String(DONE_WORDS[kind])
	return called + " done" if called != "" else "Activity done"


static func lost_words(kind: String) -> String:
	return String(LOST_WORDS.get(kind, ""))


# The steps of a loop row, in the order of its words (the parts between its commas), each by the
# name the fight's driver gives the thing that step asks for (plate_targets "what").
const STEPS := {
	"line_fight": ["latch", "shoot", "core"],
	"shoot_magnets": ["magnet", "cockpit"],
	"slam_caps": ["cap", "cockpit"],
	"bait_charge": ["wall", "cockpit"],
}
# The glyph a Brindle row wears while its last step, the open cockpit, is live.
const COCKPIT_GLYPH := "cat_damage"


# Which step of the row is live while the fight asks for `what`: the plate dims the steps before
# it, so a row that holds through its loop still says where in the loop the fight is.
static func live_step(id: String, what: String) -> int:
	return maxi(0, STEPS.get(id, []).find(what))


static func tag(what: String) -> String:
	return String(TAGS.get(what, ""))


# The detour row: a dim second row under the goal that names a detour the run pays for, so the
# plate never reads as a hallway to the Warden (gameplay critique finding 8). It names the stage's
# caged pilot while one waits, by the cage's own prompt, else the nearest side site not yet started,
# by what finishes it (activity_words); its edge marker is the cage's or the site's own. It stands
# only under the rows in DETOUR_UNDER: once the Warden is engaged the fight's plate takes the room.
const DETOUR_UNDER := ["find_warden"]
const CAGE_WORDS := "Free the caged pilot"


static func detour_shown(id: String) -> bool:
	return id in DETOUR_UNDER


# The cage's row, from the prompt its own label shows ("free the runner"), capitalised.
static func cage_words(prompt: String) -> String:
	if prompt == "" or prompt.split(" ", false).size() > MAX_WORDS:
		return CAGE_WORDS
	return prompt.left(1).to_upper() + prompt.substr(1)


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
			# The Warden is the stage's goal from the drop. A side site is on offer at the site, and
			# takes the row only while the ball is at one it has started.
			if not r["engaged"] and r["site_at_hand"]:
				return "find_activity"
			if r["fight"] == "posture":
				if not r["engaged"]:
					return "find_warden"
				if r["clamp_shut"]:
					return "break_clamp_crews"
				# The flume's line fight is one row: its steps turn over faster than a row can be read,
				# so the row names the loop and the mark on the Warden says which step is next.
				if r["mount"] == "flume" and (r["staggered"] or not r["struggling"]):
					return "line_fight"
				if r["staggered"]:
					return "smash_core"
				if r["struggling"]:
					return "grow_return"
				if r["mount"] == "dam_face":
					return "ride_sheet"
				return "break_guard"
			return "break_warden"
		"gates":
			return "roll_gate"
		"launch":
			return "" if r["card"] else "hold_line"
		"boss":
			# One row a phase, naming the phase's whole loop: the cockpit opens and shuts faster than
			# a row can be read (0.2 s in the Requisition, 1.1 s in the Scuttle on the film's bot), so
			# the row holds, the plate dims the step that is done (STEPS) and the mark moves to the
			# cockpit.
			match int(r["phase"]):
				1:
					return "shoot_magnets"
				2:
					return "slam_caps"
				3:
					return "bait_charge"
				4:
					return "ram_scooter"
			return "break_brindle"
	return ""


# The plate's done row: a finished goal ticked in the goal's own place for SECONDS, before the next
# goal shows. Nothing on the screen said a goal was finished (second first-timer film, PF-23), so
# every change of goal read as a goal dropped. It gives way at once when the goal under it changes
# again, so it never holds back a lock or a fight that starts while it is up.
class Done:
	extends RefCounted

	const SECONDS := 1.6

	var words := ""
	var won := true
	var _left := 0.0
	var _under := ""
	var _seen := false

	# A goal was finished (or, won false, lost). A note that yields is dropped while another
	# shows: what the player's act opened (the yard, the clamp) never covers the act itself.
	func note(text: String, good := true, yields := false) -> void:
		if text == "" or (yields and showing()):
			return
		words = text
		won = good
		_left = SECONDS
		_seen = false

	# under is the words of the goal the plate would show now.
	func step(delta: float, under: String) -> void:
		if _left <= 0.0:
			return
		if not _seen:
			_seen = true
			_under = under
		elif under != _under:
			_left = 0.0
			return
		_left -= delta

	func showing() -> bool:
		return _left > 0.0

	func clear() -> void:
		_left = 0.0


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
