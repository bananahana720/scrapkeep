extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")

# The enemy roster (DESIGN-V2 sections 10, 11 and 15): one row per spawnable kind, and
# the one source for what each enemy is. The spawner, the director's pack names, the
# hold rules, the telegraph voices and the no-reskins test all read it.
#
# Every row owns a `mechanic` no other row has (Andrew's no-reskins rule): a variant
# counts as a new enemy only if it changes what the player must do, and `line` says
# what that is in one sentence. `faction` picks the timbre family and the arrival cue:
# Fleet crews clank and whistle, the three ancient families hum. `telegraph` is the W2
# attack type its warning draws with. `breaks` lists the player's own actions that end
# its hold ("jump", "boost", "smash", "glide", "speed"); an empty list means it holds
# nothing. `tag` is the mechanic's warn layer, a sound id played over the type sound
# (a stand-in until W5 bakes `tag_next`). `role` is what the director pairs: a
# controller holds you, a punisher hurts you while you are held.

const FLEET := "fleet"
const REACTOR := "reactor"
const SWARM := "swarm"
const MIND := "mind"

# Cherenkov blue, the ancients' light (DESIGN-V2 section 11). Palette has no ANCIENT
# constant yet; this is the stand-in until the spine adds one.
const ANCIENT_LIGHT := Color("3d8bff")
# Ancient enamel, dull petrol under the enamel cap (VISUAL-LANGUAGE section 11).
const ANCIENT_ENAMEL := Palette.VERDIGRIS

# voice: the owner timbre layered on every telegraph. arrival: the pack_arrived cue's
# stand-in (the Fleet stamp, or the family's sound). icon: the faction's fac_ icon id.
const FACTIONS := {
	FLEET: {"era": "fleet", "voice": "clank", "arrival": "fleet_motif", "icon": "fac_fleet"},
	REACTOR: {"era": "ancient", "voice": "reactor_tick", "arrival": "reactor_tick", "icon": "fac_reactor"},
	SWARM: {"era": "ancient", "voice": "swarm_buzz", "arrival": "swarm_lock", "icon": "fac_swarm"},
	MIND: {"era": "ancient", "voice": "music_pressure", "arrival": "music_pressure", "icon": "fac_mind"},
}

# The stage Wardens, one ancient family per stage (DESIGN-V2 section 11).
const WARDEN_FAMILIES := [REACTOR, SWARM, MIND]

const T_INSTANT := Threat.Type.INSTANT
const T_WAVE := Threat.Type.WAVE
const T_PROJECTILE := Threat.Type.PROJECTILE
const T_LANE := Threat.Type.LANE

const ROWS := {
	# The first cut's roster, kept: each already owns its mechanic.
	"chaser": {"faction": FLEET, "role": "punisher", "mechanic": "lunge_lane", "telegraph": T_LANE, "breaks": [], "tag": "",
		"line": "Runs you down and lunges along a committed lane; a hard hit in the wind-up breaks the lunge."},
	"lobber": {"faction": FLEET, "role": "punisher", "mechanic": "batted_shell", "telegraph": T_PROJECTILE, "breaks": [], "tag": "",
		"line": "Lobs a shell at where you will be; roll into it fast and you bat it home."},
	"miniboss": {"faction": FLEET, "role": "punisher", "mechanic": "vented_window", "telegraph": T_INSTANT, "breaks": [], "tag": "",
		"line": "Leaps and charges, then sticks vented with its plating off: dodge, then punish the window."},
	"vault": {"faction": FLEET, "role": "cache", "mechanic": "next_stage_plating", "telegraph": -1, "breaks": [], "tag": "",
		"line": "Never fights; its plating is the next Warden's, so cracking it says your build is ahead."},
	"warden": {"faction": REACTOR, "role": "warden", "mechanic": "beacon_seal", "telegraph": T_INSTANT, "breaks": [], "tag": "",
		"line": "Seals the beacon: break it anywhere with enough punch, or through its family's weak point."},

	# Fleet reinforcements (DESIGN-V2 section 10): engineered anti-ball gear.
	"mag_trapper": {"faction": FLEET, "role": "controller", "mechanic": "mag_pit", "telegraph": T_INSTANT,
		"breaks": ["jump", "smash"], "tag": "hold_pit", "tag_next": "tag_mag_pit",
		"line": "Throws a magnetic pit disc that drags a ball lighter than its rating; heft rolls through it."},
	"hooker": {"faction": FLEET, "role": "controller", "mechanic": "anchor_tether", "telegraph": T_LANE,
		"breaks": ["boost", "speed"], "tag": "hold_tether", "tag_next": "tag_tether_crack",
		"line": "Harpoons you to its anchor post; outrun the line's rating or boost and it snaps and slings you."},
	"netcaster": {"faction": FLEET, "role": "controller", "mechanic": "air_net", "telegraph": T_INSTANT,
		"breaks": ["jump", "glide", "smash"], "tag": "hold_net", "tag_next": "tag_net_crackle",
		"line": "Raises an electric net that grabs only an airborne ball; double jump, glide or smash tears it."},
	"bola_thrower": {"faction": FLEET, "role": "controller", "mechanic": "bola_wrap", "telegraph": T_PROJECTILE,
		"breaks": ["jump", "boost", "smash"], "tag": "hold_bola", "tag_next": "tag_bola_whoop",
		"line": "Throws a slow arcing bola at where you will be; it wraps you and drags you down out of the air."},
	"plated_brute": {"faction": FLEET, "role": "punisher", "mechanic": "extra_plate", "telegraph": T_INSTANT, "breaks": [],
		"tag": "womp", "tag_next": "tag_plate_clang",
		"line": "A mini-Warden: its plate takes one extra breaking hit before the body does, and it slams the ground."},
	"deflector": {"faction": FLEET, "role": "controller", "mechanic": "reflect_shield", "telegraph": T_LANE,
		"breaks": ["jump", "smash"], "tag": "vault_drop", "tag_next": "tag_shield_boing",
		"line": "Braces a dish shield that throws you back at restitution 0.9; rebound off it for a x1.8 vault."},
	"winch_drone": {"faction": FLEET, "role": "controller", "mechanic": "winch_pull", "telegraph": T_LANE,
		"breaks": ["jump", "boost", "smash"], "tag": "scrap_rip", "tag_next": "tag_winch_ratchet",
		"line": "Hovers out of ramming reach and winches you toward its pack; shoot it or break the cable."},
	# The anti-ball set (DESIGN-V2 section 15): gear evolved to beat balls, unlocked as
	# the difficulty clock climbs.
	"gyro_jammer": {"faction": FLEET, "role": "controller", "mechanic": "gyro_drift", "telegraph": T_INSTANT,
		"breaks": ["jump", "boost", "smash"], "tag": "zap_hum", "tag_next": "tag_gyro_warble",
		"line": "Throws your gyroscope off inside its field: your steering drifts side to side until you move out of it."},
	"swatter": {"faction": FLEET, "role": "controller", "mechanic": "paddle_bat", "telegraph": T_INSTANT,
		"breaks": ["jump", "boost", "smash"], "tag": "hit_thwack", "tag_next": "tag_paddle_swat",
		"line": "Swings a low paddle arm that bats you sideways at speed; jump over the sweep or ride the knock."},
	"ramp_flipper": {"faction": FLEET, "role": "controller", "mechanic": "tilt_fling", "telegraph": T_INSTANT,
		"breaks": ["jump", "boost", "smash"], "tag": "vault_rise", "tag_next": "tag_ramp_creak",
		"line": "A floor plate that tilts to fling a grounded ball up and off course; jump on the tilt to ride it as a ramp."},
	"catch_trap": {"faction": FLEET, "role": "controller", "mechanic": "cup_hold", "telegraph": T_INSTANT,
		"breaks": ["boost"], "tag": "ice_form", "tag_next": "tag_cup_snap",
		"line": "A cup that closes over a ball rolling onto it and holds it dead still; ram it first, shoot it, or boost out."},

	# Awakened ancients (DESIGN-V2 section 10): one per family, each its cause's mechanic.
	"reactor_relic": {"faction": REACTOR, "role": "punisher", "mechanic": "meltdown_vent", "telegraph": T_INSTANT, "breaks": [],
		"tag": "reactor_erupt", "tag_next": "reactor_erupt",
		"line": "Opens meltdown vents that charge to a Geiger tick and erupt into a fallout crater that burns for seconds."},
	"swarm_remnant": {"faction": SWARM, "role": "punisher", "mechanic": "formation_dive", "telegraph": T_LANE, "breaks": [],
		"tag": "swarm_scatter", "tag_next": "swarm_lock",
		"line": "Weak drones that lock into a formation and dive; bowl through the formation and it scatters and follows you."},
	"mind_hand": {"faction": MIND, "role": "punisher", "mechanic": "habit_brace", "telegraph": T_LANE, "breaks": [],
		"tag": "beacon_hum", "tag_next": "mind_quote",
		"line": "Reads the habit you use most this run, quotes your tune back wrong, then braces against that one verb."},
}

# The Fleet counters in the order the director unlocks them, and the ancients.
const COUNTERS := ["mag_trapper", "hooker", "bola_thrower", "plated_brute", "netcaster", "deflector", "winch_drone",
	"gyro_jammer", "swatter", "ramp_flipper", "catch_trap"]
const ANCIENTS := ["reactor_relic", "swarm_remnant", "mind_hand"]


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


static func warden_family(stage: int) -> String:
	return WARDEN_FAMILIES[clampi(stage, 1, WARDEN_FAMILIES.size()) - 1]


# The mechanic tag each kind owns, for the no-reskins check: {mechanic: [ids]}.
static func mechanic_owners() -> Dictionary:
	var owners := {}
	for id in ROWS:
		var mechanic: String = ROWS[id]["mechanic"]
		if not owners.has(mechanic):
			owners[mechanic] = []
		owners[mechanic].append(id)
	return owners
