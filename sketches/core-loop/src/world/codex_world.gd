extends RefCounted

# The world's codex entries (category "world"): terrain and element tricks the player
# can find, declared as data and detected here. The detector is pure: the world feeds
# it what just happened, already read against the terrain and the ball, and it answers
# with the entries that fired. The codex owns saving, the burst and the bus fact.
#
# Notes the world sends, with the fields each needs:
#   "element"  {"behaviour", "material", "at"}   an element resolved on a surface
#   "kill"     {"at", "in_water"}                  an enemy died
#   "gate"     {"id", "at", "tier"}                an event gate was taken at a speed tier
#   "airborne" {"at", "off_kicker"}                the ball left the ground
#   "slam"     {"at"}                              a slam landed
#   "jump"     {"at", "tailwind"}                  a jump with the squall at the ball's back
#   "grounded" {"at", "over_water"}                the ball is rolling on something over the flood
#   "footing"  {"at", "on"}                        each grounded tick on a map with a net deck:
#                                                  "deck", "island" (stone tops, bridges, ramps) or "barge"
#   "thermal"  {"at"}                              a thermal column is lifting the ball this tick

const ENTRIES := [
	{"id": "live_wire_flood", "category": "world", "name": "Live Wire",
		"hint": "Water carries a charge, and so do crowds that wade in.",
		"clue": "Arc + flood water + machines in it",
		"text": "Machines lured into the flood die when you electrify the water under them."},
	{"id": "surge_slingshot", "category": "world", "name": "Surge Slingshot",
		"hint": "The surge is a tailwind if you stay ahead of it.",
		"clue": "Surge Run gate + blazing speed",
		"text": "Riding the surge front through a gate at blazing speed."},
	{"id": "sluice_hammer", "category": "world", "name": "Sluice Hammer",
		"hint": "A kicker throws you high. What comes down hardest?",
		"clue": "Kicker + slam",
		"text": "Launching off a kicker and slamming before you land."},
	{"id": "squall_sail", "category": "world", "name": "Squall Sail",
		"hint": "The wind never brakes you. It only pushes.",
		"clue": "Dust squall at your back + a jump",
		"text": "Jumping with the squall behind you and letting it carry you."},
	{"id": "ice_bridge", "category": "world", "name": "Ice Bridge",
		"hint": "The flood can hold you up, briefly, if it is cold enough.",
		"clue": "Frost + flood water + rolling across",
		"text": "Freezing the flood and using the ice as a shortcut across it."},
	# v2 W6 world: callbacks that ride the gorge's contraptions and Moss's barge.
	{"id": "steam_thermal", "category": "world", "name": "Thermal",
		"hint": "Warm air rises. So does anything gliding in it.",
		"clue": "Glide + steam vent",
		"text": "Gliding into a steam vent and riding it upward like a thermal."},
	{"id": "sprint_through", "category": "world", "name": "Through the Crack",
		"hint": "Some walls only need a runner who will not stop.",
		"clue": "Overdrive sprint + cracked wall",
		"text": "Sprinting into a cracked tunnel wall and coming out the other side."},
	{"id": "do_not_open_until_clear", "category": "world", "name": "Do Not Open Until Clear",
		"hint": "A valve beside an old reactor vent. Stand outside the ring.",
		"clue": "Pressure valve + reactor vent, from outside its ring",
		"text": "Smashing the valve beside a dug-up reactor vent from outside its ring, venting it early."},
	{"id": "pit_stop_lap", "category": "world", "name": "Pit Stop",
		"hint": "The barge's rim is a track. There is a par.",
		"clue": "Moss's rim track under par",
		"text": "A lap of the workshop barge's rim under par. The nomads build every camp as a marble run, with streets banked and tiers joined by chutes."},
	# The Reach's secret cache (SC2): map_reach.gd's valve spec carries this row.
	{"id": "reach_pressure_cache", "category": "world", "name": "Pressure keeps the change",
		"hint": "A cracked wheel beside a copper door.",
		"clue": "Ram the valve on the Reach's west shelf + the copper door",
		"text": "A rolling ram turns the old valve. Behind the sinking door, the crew's spare parts wait."},
	# The Dig's breach plate fires from world.gd when a slam opens one; the three Highdraft
	# rows fire from note() on the "footing" and "thermal" notes world.gd sends.
	{"id": "breach_plate", "category": "world", "name": "Down Payment",
		"hint": "Some floors are waiting for a heavier answer.",
		"clue": "The Dig's marked breach plate + a slam through to the floor below",
		"text": "Slam a marked breach plate in the Dig to break through and open the route below."},
	{"id": "net_deck", "category": "world", "name": "The Safety Net",
		"hint": "The sky has a basement. It catches its visitors.",
		"clue": "A fall from a Highdraft island + landing on the net deck",
		"text": "A missed island landing ends on the Highdraft's net deck, giving you a route back up."},
	{"id": "thermal_lift", "category": "world", "name": "Updraft Fare",
		"hint": "An invisible staircase carries the patient traveller.",
		"clue": "Ride a Highdraft thermal + reach an island above",
		"text": "Ride the Highdraft's rising air to an island above. This is an island crossing, separate from gliding in a steam vent."},
	{"id": "moving_island", "category": "world", "name": "All Aboard",
		"hint": "Some destinations come to meet you.",
		"clue": "Board a moving Highdraft island + ride it to a crossing",
		"text": "Let a moving island carry you across the Highdraft to your next crossing."},
]


# The script whose code fires each row. tests/codex_coverage_test.gd reads it: every row
# has one, and that script names the row's id where it fires.
const DETECTORS := {
	"live_wire_flood": "res://src/world/codex_world.gd",
	"surge_slingshot": "res://src/world/codex_world.gd",
	"sluice_hammer": "res://src/world/codex_world.gd",
	"squall_sail": "res://src/world/codex_world.gd",
	"ice_bridge": "res://src/world/codex_world.gd",
	"steam_thermal": "res://src/world/contraptions.gd",
	"sprint_through": "res://src/world/contraptions.gd",
	"do_not_open_until_clear": "res://src/world/contraptions.gd",
	"pit_stop_lap": "res://src/world/bay.gd",
	"reach_pressure_cache": "res://src/world/map_reach.gd",
	"breach_plate": "res://src/world/world.gd",
	"net_deck": "res://src/world/codex_world.gd",
	"thermal_lift": "res://src/world/codex_world.gd",
	"moving_island": "res://src/world/codex_world.gd",
}


static func entry(id: String) -> Dictionary:
	for row in ENTRIES:
		if row["id"] == id:
			return row
	return {}

const LIVE_WIRE_SECONDS := 4.0
const LIVE_WIRE_REACH := 16.0
const HAMMER_SECONDS := 3.0
const ICE_SECONDS := 12.0
const ICE_REACH := 10.0
const BLAZING := 3
# A fall off an island counts if the deck is reached this soon after the ball left the stone.
const NET_FALL_SECONDS := 6.0
# A thermal ride counts if an island is reached this soon after the column last lifted the
# ball, standing at least THERMAL_RISE above where the ride began.
const THERMAL_SECONDS := 8.0
const THERMAL_RISE := 2.0
# A barge ride counts if the ball steps onto an island within STEP_OFF_SECONDS of leaving the
# deck, at least CROSSING metres (planar) from where it boarded.
const STEP_OFF_SECONDS := 2.0
const CROSSING := 12.0

var time := 0.0
var fired: Array[String] = []

var _electrified: Array = []
var _frozen: Array = []
var _kicked_at := -INF
# The net deck: the last footing, and when the ball left an island top for the air.
var _footing := ""
var _left_island_at := -INF
# The thermal ride: the lowest point and the last tick of the current ride.
var _thermal_from := INF
var _thermal_at := -INF
# The barge ride: where the ball boarded, and the last tick it stood on the deck.
var _boarded_at := Vector3.INF
var _barge_at := -INF


func note(kind: String, data: Dictionary) -> Array:
	var out := []
	match kind:
		"element":
			if data.get("material", "") == "water":
				if data.get("behaviour", "") == "electrify":
					_electrified.append([time, data["at"]])
				elif data.get("behaviour", "") == "create_surface":
					_frozen.append([time, data["at"]])
		"kill":
			if data.get("in_water", false) and _recent(_electrified, LIVE_WIRE_SECONDS, data["at"], LIVE_WIRE_REACH):
				_fire("live_wire_flood", data["at"], out)
		"gate":
			if data.get("id", "") == "surge_run" and int(data.get("tier", 0)) >= BLAZING:
				_fire("surge_slingshot", data["at"], out)
		"airborne":
			if data.get("off_kicker", false):
				_kicked_at = time
			if _footing == "island":
				_left_island_at = time
			_footing = ""
		"thermal":
			_thermal_from = minf(_thermal_from, float(data["at"].y))
			_thermal_at = time
		"footing":
			_footing_note(String(data.get("on", "")), data["at"], out)
		"slam":
			if time - _kicked_at <= HAMMER_SECONDS:
				_fire("sluice_hammer", data["at"], out)
				_kicked_at = -INF
		"jump":
			if data.get("tailwind", false):
				_fire("squall_sail", data["at"], out)
		"grounded":
			if data.get("over_water", false) and _recent(_frozen, ICE_SECONDS, data["at"], ICE_REACH):
				_fire("ice_bridge", data["at"], out)
	return out


func _footing_note(on: String, at: Vector3, out: Array) -> void:
	match on:
		"deck":
			if time - _left_island_at <= NET_FALL_SECONDS:
				_fire("net_deck", at, out)
			_left_island_at = -INF
			_thermal_from = INF
			_boarded_at = Vector3.INF
		"island":
			if time - _thermal_at <= THERMAL_SECONDS and at.y >= _thermal_from + THERMAL_RISE:
				_fire("thermal_lift", at, out)
			if _boarded_at != Vector3.INF and time - _barge_at <= STEP_OFF_SECONDS \
					and Vector2(at.x - _boarded_at.x, at.z - _boarded_at.z).length() >= CROSSING:
				_fire("moving_island", at, out)
			_left_island_at = -INF
			_thermal_from = INF
			_boarded_at = Vector3.INF
		"barge":
			if _boarded_at == Vector3.INF:
				_boarded_at = at
			_barge_at = time
	_footing = on


func advance(delta: float) -> void:
	time += delta


func _recent(marks: Array, seconds: float, at: Vector3, reach: float) -> bool:
	for m in marks:
		if time - float(m[0]) <= seconds and Vector2(at.x - m[1].x, at.z - m[1].z).length() <= reach:
			return true
	return false


# Each entry fires once per stage attempt here; the codex decides what a repeat means.
func _fire(id: String, at: Vector3, out: Array) -> void:
	if id in fired:
		return
	fired.append(id)
	out.append({"id": id, "at": at})
