extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const Worlds := preload("res://src/core/worlds.gd")

# The enemy roster (DESIGN-V2 sections 10, 11 and 15): one row per spawnable kind, and
# the one source for what each enemy is. The spawner, the director's pack names, the
# hold rules, the telegraph voices and the no-reskins test all read it.
#
# - mechanic: what the player must do differently, owned by this row alone (Andrew's
#   no-reskins rule). `line` says it in one sentence.
# - faction: the timbre family and the arrival cue. Fleet crews clank and whistle; the
#   three ancient families hum.
# - role: what the director pairs. A controller holds or steers you; a punisher hurts a
#   ball that is held or off its line.
# - telegraph: the W2 attack type its warning draws with.
# - holds: whether it takes hold of the ball (through holds.gd and the CC door).
# - breaks: the player's own actions that end its hold, or for a unit that holds
#   nothing, the action that turns it into an opportunity.
# - tag: the warn layer over the type sound, unique per row, an existing sound id
#   standing in until W5 bakes `tag_next`. hold: the hold loop's stand-in.
# - tests: the build axis it tests, which the director weights against the player's
#   build ("air", "speed", "heft", "contact", "weapon", "steer", "habit").

const FLEET := "fleet"
const REACTOR := "reactor"
const SWARM := "swarm"
const MIND := "mind"

# Cherenkov blue, the ancients' light (DESIGN-V2 section 11). Palette has no ANCIENT
# constant yet; this is the stand-in until the spine adds one.
const ANCIENT_LIGHT := Palette.ANCIENT
# Ancient enamel, dull petrol under the enamel cap (VISUAL-LANGUAGE section 11).
const ANCIENT_ENAMEL := Palette.VERDIGRIS

# voice: the owner timbre layered on every telegraph ("mind_quote" resolves to the
# player's class motif, inverted). arrival: the pack_arrived cue's stand-in (the Fleet
# stamp, or the family's sound). The fac_ icon is EventKinds.faction_icon(faction).
const FACTIONS := {
	FLEET: {"era": "fleet", "voice": "clank", "arrival": "fleet_motif"},
	REACTOR: {"era": "ancient", "voice": "reactor_tick", "arrival": "reactor_tick"},
	SWARM: {"era": "ancient", "voice": "swarm_buzz", "arrival": "swarm_lock"},
	MIND: {"era": "ancient", "voice": "mind_quote", "arrival": "mind_quote"},
}

# The stage Wardens, one ancient family per stage (DESIGN-V2 section 11).
const WARDEN_FAMILIES := [REACTOR, SWARM, MIND]

const T_INSTANT := Threat.Type.INSTANT
const T_WAVE := Threat.Type.WAVE
const T_PROJECTILE := Threat.Type.PROJECTILE
const T_LANE := Threat.Type.LANE

const ROWS := {
	# The first cut's roster, kept: each already owns its mechanic.
	"chaser": {"faction": FLEET, "role": "punisher", "mechanic": "lunge_lane", "telegraph": T_LANE, "holds": false,
		"breaks": [], "tag": "", "tests": "speed",
		"line": "Runs you down and lunges along a committed lane; a hard hit in the wind-up breaks the lunge."},
	"lobber": {"faction": FLEET, "role": "punisher", "mechanic": "batted_shell", "telegraph": T_PROJECTILE, "holds": false,
		"breaks": [], "tag": "", "tests": "weapon",
		"line": "Lobs a shell at where you will be; roll into it fast and you bat it home."},
	"miniboss": {"faction": FLEET, "role": "punisher", "mechanic": "vented_window", "telegraph": T_INSTANT, "holds": false,
		"breaks": [], "tag": "", "tests": "contact",
		"line": "Leaps and charges, then sticks vented with its plating off: dodge, then punish the window."},
	"vault": {"faction": FLEET, "role": "cache", "mechanic": "next_stage_plating", "telegraph": -1, "holds": false,
		"breaks": [], "tag": "", "tests": "contact",
		"line": "Never fights; its plating is the next Warden's, so cracking it says your build is ahead."},
	"warden": {"faction": REACTOR, "role": "warden", "mechanic": "beacon_seal", "telegraph": T_INSTANT, "holds": false,
		"breaks": [], "tag": "", "tests": "contact",
		"line": "Seals the beacon: break it anywhere with enough punch, or through its family's weak point."},

	# Fleet reinforcements (DESIGN-V2 section 10): engineered anti-ball gear.
	"mag_trapper": {"faction": FLEET, "role": "controller", "mechanic": "mag_pit", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "smash"], "tag": "hold_pit", "tag_next": "tag_mag_pit", "hold": "hold_pit", "tests": "heft",
		"line": "Throws a magnetic pit disc that drags a ball lighter than its rating; heft rolls through it."},
	"hooker": {"faction": FLEET, "role": "controller", "mechanic": "anchor_tether", "telegraph": T_LANE, "holds": true,
		"breaks": ["boost", "speed"], "tag": "hold_tether", "tag_next": "tag_tether_crack", "hold": "hold_tether", "tests": "speed",
		"line": "Harpoons you to its anchor post; outrun the line's rating or boost and it snaps and slings you."},
	"netcaster": {"faction": FLEET, "role": "controller", "mechanic": "air_net", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "glide", "smash"], "tag": "hold_net", "tag_next": "tag_net_crackle", "hold": "zap_hum", "tests": "air",
		"line": "Raises an electric net that grabs only an airborne ball; double jump, glide or smash tears it."},
	"bola_thrower": {"faction": FLEET, "role": "punisher", "mechanic": "bola_wrap", "telegraph": T_PROJECTILE, "holds": true,
		"breaks": ["jump", "boost", "smash"], "tag": "hold_bola", "tag_next": "tag_bola_whoop", "hold": "hold_bola", "tests": "air",
		"line": "Throws a slow arcing bola at where you will be; it wraps you, stings, and drags you down out of the air."},
	"plated_brute": {"faction": FLEET, "role": "punisher", "mechanic": "extra_plate", "telegraph": T_INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "womp", "tag_next": "tag_plate_clang", "tests": "contact",
		"line": "A mini-Warden: its plate takes one extra breaking hit before the body does, and it slams the ground."},
	"deflector": {"faction": FLEET, "role": "controller", "mechanic": "reflect_shield", "telegraph": T_LANE, "holds": false,
		"breaks": ["jump"], "tag": "vault_drop", "tag_next": "tag_shield_boing", "tests": "contact",
		"line": "Braces a dish shield that throws you back at restitution 0.9; jump off the rebound for a x1.8 vault."},
	"winch_drone": {"faction": FLEET, "role": "controller", "mechanic": "winch_pull", "telegraph": T_LANE, "holds": true,
		"breaks": ["jump", "boost", "smash"], "tag": "scrap_rip", "tag_next": "tag_winch_ratchet", "hold": "scrap_rip", "tests": "weapon",
		"line": "Hovers out of ramming reach and winches you toward its pack; shoot it or break the cable."},
	# The anti-ball set (DESIGN-V2 section 15): gear evolved to beat balls, unlocked as
	# the difficulty clock climbs.
	"gyro_jammer": {"faction": FLEET, "role": "controller", "mechanic": "gyro_drift", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "boost", "smash"], "tag": "hold_riser", "tag_next": "tag_gyro_warble", "hold": "hold_riser", "tests": "steer",
		"line": "Throws your gyroscope off inside its field: steering drifts side to side until you move out or break it."},
	"swatter": {"faction": FLEET, "role": "punisher", "mechanic": "paddle_bat", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "boost"], "tag": "hit_thwack", "tag_next": "tag_paddle_swat", "hold": "", "tests": "steer",
		"line": "Swings a low paddle arm that bats you along its sweep; jump the paddle, or boost to ride the knock."},
	"ramp_flipper": {"faction": FLEET, "role": "controller", "mechanic": "tilt_fling", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump"], "tag": "vault_rise", "tag_next": "tag_ramp_creak", "hold": "", "tests": "steer",
		"line": "A floor plate that tilts to fling a grounded ball up and off course; jump on the tilt to ride it as a ramp."},
	"catch_trap": {"faction": FLEET, "role": "controller", "mechanic": "cup_hold", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["boost", "smash"], "tag": "ice_form", "tag_next": "tag_cup_snap", "hold": "ice_form", "tests": "speed",
		"line": "A cup that closes over a ball rolling onto it and holds it dead still; boost or smash out, or break it first."},

	# Awakened ancients (DESIGN-V2 section 10): one per family, each its cause's mechanic.
	"reactor_relic": {"faction": REACTOR, "role": "punisher", "mechanic": "meltdown_vent", "telegraph": T_INSTANT, "holds": false,
		"breaks": [], "tag": "reactor_erupt", "tag_next": "reactor_erupt", "tests": "speed",
		"line": "Opens meltdown vents that charge to a Geiger tick and erupt, leaving a fallout crater that burns for seconds."},
	"swarm_remnant": {"faction": SWARM, "role": "punisher", "mechanic": "formation_dive", "telegraph": T_LANE, "holds": false,
		"breaks": [], "tag": "swarm_lock", "tag_next": "swarm_lock", "tests": "contact",
		"line": "Weak drones that lock into a formation and dive; bowl through it and they scatter and follow you."},
	"mind_hand": {"faction": MIND, "role": "punisher", "mechanic": "habit_brace", "telegraph": T_LANE, "holds": false,
		"breaks": [], "tag": "mind_quote", "tag_next": "mind_quote", "tests": "habit",
		"line": "Reads the habit you use most this run, quotes your tune back wrong, then braces against that one verb."},
}

# The Fleet counters in the order the director unlocks them, and the ancients.
const COUNTERS := ["mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster", "deflector", "winch_drone",
	"gyro_jammer", "swatter", "ramp_flipper", "catch_trap"]
const ANCIENTS := ["reactor_relic", "swarm_remnant", "mind_hand"]
# The family ancient per Warden family.
const FAMILY_ANCIENT := {REACTOR: "reactor_relic", SWARM: "swarm_remnant", MIND: "mind_hand"}


static func has(id: String) -> bool:
	return ROWS.has(id)


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


static func faction_of(id: String) -> String:
	return String(row(id).get("faction", FLEET))


static func faction(name: String) -> Dictionary:
	return FACTIONS.get(name, FACTIONS[FLEET])


static func is_ancient(name: String) -> bool:
	return faction(name)["era"] == "ancient"


static func is_reinforcement(id: String) -> bool:
	return id in COUNTERS or id in ANCIENTS


static func warden_family(stage: int) -> String:
	return WARDEN_FAMILIES[clampi(stage, 1, WARDEN_FAMILIES.size()) - 1]


# A boss piece kind ("brindle_hull") begins with a Worlds.BOSSES row's kind plus "_".
static func is_boss_piece(kind: String) -> bool:
	for row in Worlds.BOSSES.values():
		if kind.begins_with(String(row["kind"]) + "_"):
			return true
	return false


# A sound id as the player hears it: "mind_quote" is the Mind playing your class motif
# back (mind_sable, mind_rivet, mind_kest); every other id is itself.
static func voiced(id: String, motif: String) -> String:
	if id == "mind_quote":
		return "mind_" + (motif if motif != "" else "sable")
	return id


# The mechanic tag each kind owns, for the no-reskins check: {mechanic: [ids]}.
static func mechanic_owners() -> Dictionary:
	var owners := {}
	for id in ROWS:
		var mechanic: String = ROWS[id]["mechanic"]
		if not owners.has(mechanic):
			owners[mechanic] = []
		owners[mechanic].append(id)
	return owners
