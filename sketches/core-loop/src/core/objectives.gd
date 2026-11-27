extends RefCounted


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
	"ride_sheet": {"glyph": "cat_defense", "words": "Ride the water sheet up"},
	"line_fight": {"glyph": "cat_defense", "words": "Hook, shoot, smash core"},
	"shoot_magnets": {"glyph": "fac_fleet", "words": "Shoot magnets, then cockpit"},
	"slam_caps": {"glyph": "fac_fleet", "words": "Slam caps, then cockpit"},
	"bait_charge": {"glyph": "fac_fleet", "words": "Bait into walls, then cockpit"},
	"ram_scooter": {"glyph": "fac_fleet", "words": "Ram the Admiral's scooter"},
}

const ACTIVITY_WORDS := {
	"enemy_camp": "Clear the camp",
	"ambush_altar": "Break the ambush",
	"cracked_cache": "Crack open the cache",
	"hold_the_relay": "Hold the relay",
	"surge_run": "Outrun the surge",
	"hauler_bounty": "Break the bounty hauler",
	"stocktake_yard": "Survive the stocktake",
	"stocktake_muster": "Survive the stocktake",
	"trade_risk": "The keeper's gamble",
	"curse": "The keeper's gamble",
	"sacrifice": "The keeper's gamble",
	"trade_safe": "The foreman's kindness",
}

const DONE_WORDS := {
	"enemy_camp": "Camp cleared",
	"ambush_altar": "Ambush broken",
	"cracked_cache": "Cache cracked",
	"hold_the_relay": "Relay held",
	"surge_run": "Surge outrun",
	"hauler_bounty": "Bounty hauler broken",
	"stocktake_yard": "Stocktake banked",
	"stocktake_muster": "Stocktake banked",
	"trade_risk": "Gamble taken",
	"curse": "Gamble taken",
	"sacrifice": "Gamble taken",
	"trade_safe": "Kindness taken",
	"yard": "Yard open",
	"clamp": "Clamp open",
	"warden": "Warden broken",
}

const LOST_WORDS := {
	"hold_the_relay": "Relay lost",
	"surge_run": "Surge lost",
	"stocktake_yard": "Stocktake forfeit",
	"stocktake_muster": "Stocktake forfeit",
}

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

const EMPTY_READING := {"state": "", "sealed": false, "engaged": false, "fight": "plating", "staggered": false,
	"struggling": false, "distance": INF, "card": false, "site_at_hand": false, "yard_locked": false, "clamp_shut": false,
	"mount": "", "phase": 0, "open": false}


static func glyph(id: String) -> String:
	return ROWS[id]["glyph"] if ROWS.has(id) else ""


static func words(id: String) -> String:
	return ROWS[id]["words"] if ROWS.has(id) else ""


static func activity_words(kind: String, called := "") -> String:
	if ACTIVITY_WORDS.has(kind):
		return String(ACTIVITY_WORDS[kind])
	return called if called != "" else String(ROWS["find_activity"]["words"])


static func done_words(kind: String, called := "") -> String:
	if DONE_WORDS.has(kind):
		return String(DONE_WORDS[kind])
	return called + " done" if called != "" else "Activity done"


static func lost_words(kind: String) -> String:
	return String(LOST_WORDS.get(kind, ""))


const STEPS := {
	"line_fight": ["latch", "shoot", "core"],
	"shoot_magnets": ["magnet", "cockpit"],
	"slam_caps": ["cap", "cockpit"],
	"bait_charge": ["wall", "cockpit"],
}
const COCKPIT_GLYPH := "cat_damage"


static func live_step(id: String, what: String) -> int:
	return maxi(0, STEPS.get(id, []).find(what))


static func tag(what: String) -> String:
	return String(TAGS.get(what, ""))


const DETOUR_UNDER := ["find_warden"]
const CAGE_WORDS := "Free the caged pilot"


static func detour_shown(id: String) -> bool:
	return id in DETOUR_UNDER


static func detour_site_matches(site, id: String, good: bool, already_ticked = null) -> bool:
	if site == null or not is_instance_valid(site) or String(site.id) != id:
		return false
	if good:
		if already_ticked != null and site == already_ticked:
			return false
		if "done" in site and not bool(site.done):
			return false
	elif "done" in site and bool(site.done):
		return false
	return true


static func cage_words(prompt: String) -> String:
	if prompt == "" or prompt.split(" ", false).size() > MAX_WORDS:
		return CAGE_WORDS
	return prompt.left(1).to_upper() + prompt.substr(1)


static func choose(reading: Dictionary) -> String:
	var r: Dictionary = EMPTY_READING.duplicate()
	r.merge(reading, true)
	match r["state"]:
		"stage", "beacon":
			if r["yard_locked"]:
				return "break_yard_crew"
			if not r["sealed"]:
				return "charge_beacon"
			if not r["engaged"] and r["site_at_hand"]:
				return "find_activity"
			if r["fight"] == "posture":
				if not r["engaged"]:
					return "find_warden"
				if r["clamp_shut"]:
					return "break_clamp_crews"
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


class Done:
	extends RefCounted

	const SECONDS := 1.6

	var words := ""
	var won := true
	var _left := 0.0
	var _under := ""
	var _seen := false

	func note(text: String, good := true, yields := false) -> void:
		if text == "" or (yields and showing()):
			return
		words = text
		won = good
		_left = SECONDS
		_seen = false

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
