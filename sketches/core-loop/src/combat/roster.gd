extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const Worlds := preload("res://src/core/worlds.gd")
const RosterDig := preload("res://src/combat/roster_dig.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const RosterSpecials := preload("res://src/combat/roster_specials.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# The enemy roster (DESIGN-V2 sections 10, 11 and 15): one row per spawnable kind, and
# the one source for what each enemy is. The spawner, the director's pack names, the
# hold rules, the telegraph voices and the no-reskins test all read it.
#
# - mechanic: what the player must do differently, owned by this row alone (Andrew's
#   no-reskins rule). `line` says it in one sentence.
#   A hard-tier director elite adds one behaviour and one non-health stat, named
#   together in elite_affixes.gd. It keeps its chassis and original mechanic.
# - faction: the timbre family and the arrival cue. Fleet crews clank and whistle; the
#   three ancient families hum.
# - role: what the director pairs. A controller holds or steers you; a punisher hurts a
#   ball that is held or off its line; a kill_first special makes its pack worse until it
#   is removed.
# - telegraph: the W2 attack type its warning draws with.
# - holds: whether it takes hold of the ball (through holds.gd and the CC door).
# - breaks: the player's own actions that end its hold, or for a unit that holds
#   nothing, the action that turns it into an opportunity.
# - tag: the warn layer over the type sound, unique per row, an existing sound id
#   standing in until W5 bakes `tag_next`. hold: the hold loop's stand-in.
# - tests: the build axis it tests, which the director weights against the player's
#   build ("air", "speed", "heft", "contact", "weapon", "steer", "habit").
# - script, world: a declared later-world kind's behaviour file and world (roster_dig.gd,
#   roster_highdraft.gd); a base row may name them too (the jolt layer). Such a kind is built,
#   so spawnable, once its script exists.
#   A kill-first special (roster_specials.gd) has a script and either a "world" or a "priority".

const FLEET := "fleet"
const REACTOR := "reactor"
const SWARM := "swarm"
const MIND := "mind"

# Existing baked cues, reserved as mechanic tags only for these three added attacks.
const AFFIX_TAGS := {"target_stamp": "klaxon", "rail_strike": "build_riser", "rear_blast": "shatter"}

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

# The Warden kinds, one ancient family per world, in world order (PARK.md section 7).
const WARDEN_FAMILIES := [REACTOR, SWARM, MIND]
# What a Warden is called on its plate and in the run summary: its family, and its variant when
# the stage row sets one (stage 2's flume Warden is "meltdown", which its card names). The one owner.
const WARDEN_NAMES := {REACTOR: {"": "Reactor Warden", "meltdown": "Meltdown Warden"}, SWARM: {"": "Hive Warden", "brood": "Brood Warden"}, MIND: {"": "Mind Warden", "choir": "Crown Warden"}}

const T_INSTANT := Threat.Type.INSTANT
const T_WAVE := Threat.Type.WAVE
const T_PROJECTILE := Threat.Type.PROJECTILE
const T_LANE := Threat.Type.LANE

const BASE_ROWS := {
	# The first cut's roster, kept: each already owns its mechanic.
	"chaser": {"faction": FLEET, "role": "punisher", "mechanic": "lunge_lane", "telegraph": T_LANE, "holds": false,
		"breaks": [], "tag": "", "tests": "speed",
		"job": "Was a pipe pig that scraped the penstocks clear.",
		"line": "Runs you down and lunges along a committed lane; a hard hit in the wind-up breaks the lunge."},
	"lobber": {"faction": FLEET, "role": "punisher", "mechanic": "batted_shell", "telegraph": T_PROJECTILE, "holds": false,
		"breaks": [], "tag": "", "tests": "weapon",
		"job": "Was a leak plugger that threw bungs at a breach.",
		"line": "Lobs a shell at where you will be; roll into it fast and you bat it home."},
	"miniboss": {"name": "Drop Hammer", "faction": FLEET, "role": "punisher", "mechanic": "vented_window", "telegraph": T_INSTANT, "holds": false,
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
		"breaks": ["jump", "smash", "hook"], "tag": "hold_pit", "tag_next": "tag_mag_pit", "hold": "hold_pit", "tests": "heft",
		"job": "Was the rack magnet that lifted scrap off the intake.",
		"line": "Throws a magnetic pit disc that drags a ball lighter than its rating; heft rolls through it."},
	# The Spillway's own crew (design-v3/SPILLWAY-ROSTER.md): re-admitted in wave 19, reworked around Flow.
	"hooker": {"faction": FLEET, "role": "controller", "mechanic": "anchor_tether", "telegraph": T_LANE, "holds": true,
		"breaks": ["boost", "speed", "hook"], "tag": "hold_tether", "tag_next": "tag_tether_crack", "hold": "hold_tether", "tests": "speed",
		"world": 1,
		"job": "Was a mooring winch that hauled barges in.",
		"line": "Harpoons you to its anchor post; outrun the line, boost, or bite another post and it snaps and slings you."},
	"netcaster": {"faction": FLEET, "role": "controller", "mechanic": "air_net", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "glide", "smash"], "tag": "hold_net", "tag_next": "tag_net_crackle", "hold": "zap_hum", "tests": "air",
		"line": "Raises an electric net that grabs only an airborne ball; double jump, glide or smash tears it."},
	"bola_thrower": {"faction": FLEET, "role": "punisher", "mechanic": "bola_wrap", "telegraph": T_PROJECTILE, "holds": true,
		"breaks": ["jump", "boost", "smash", "hook"], "tag": "hold_bola", "tag_next": "tag_bola_whoop", "hold": "hold_bola", "tests": "air",
		"line": "Throws a slow arcing bola at where you will be; it wraps you, stings, and drags you down out of the air."},
	"plated_brute": {"faction": FLEET, "role": "punisher", "mechanic": "extra_plate", "telegraph": T_INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "womp", "tag_next": "tag_plate_clang", "tests": "contact",
		"job": "Was a stoplog setter that shut bays with steel.",
		"line": "A mini-Warden: its plate takes one extra breaking hit before the body does, and it slams the ground."},
	"deflector": {"faction": FLEET, "role": "controller", "mechanic": "reflect_shield", "telegraph": T_LANE, "holds": false,
		"breaks": ["jump"], "tag": "vault_drop", "tag_next": "tag_shield_boing", "tests": "contact",
		"line": "Braces a dish shield that throws you back at restitution 0.9; jump off the rebound for a x1.8 vault."},
	"winch_drone": {"faction": FLEET, "role": "controller", "mechanic": "winch_pull", "telegraph": T_LANE, "holds": true,
		"breaks": ["jump", "boost", "smash", "hook"], "tag": "scrap_rip", "tag_next": "tag_winch_ratchet", "hold": "scrap_rip", "tests": "weapon",
		"line": "Hovers out of ramming reach and winches you toward its pack; shoot it or break the cable."},
	# The anti-ball set (DESIGN-V2 section 15): gear evolved to beat balls, unlocked as
	# the difficulty clock climbs.
	"gyro_jammer": {"faction": FLEET, "role": "controller", "mechanic": "gyro_drift", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "boost", "smash", "hook"], "tag": "hold_riser", "tag_next": "tag_gyro_warble", "hold": "hold_riser", "tests": "steer",
		"line": "Throws your gyroscope off inside its field: steering drifts side to side until you move out or break it."},
	# The Spillway's field crew (design-v3/FIELDS-AND-CASTS.md section 2.3), in Spillway packs from
	# wave 19 (design-v3/SPILLWAY-ROSTER.md).
	"jolt_layer": {"faction": FLEET, "role": "controller", "mechanic": "static_jam", "telegraph": T_INSTANT, "holds": false,
		"breaks": ["speed", "jump"], "tag": "", "tests": "speed", "script": "res://src/combat/jolt_layer.gd", "world": 1,
		"job": "Was the fish fence layer.",
		"line": "Unrolls a live cable mat that jolts a slow ball: charges and casts drop and specials jam; roll fast, jump or hook out."},
	"swatter": {"faction": FLEET, "role": "punisher", "mechanic": "paddle_bat", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump", "boost"], "tag": "hit_thwack", "tag_next": "tag_paddle_swat", "hold": "", "tests": "steer",
		"line": "Swings a low paddle arm that bats you along its sweep; jump the paddle, or boost to ride the knock."},
	"ramp_flipper": {"faction": FLEET, "role": "controller", "mechanic": "tilt_fling", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["jump"], "tag": "vault_rise", "tag_next": "tag_ramp_creak", "hold": "", "tests": "steer", "world": 1,
		"job": "Was a flap tender that tipped the overflow.",
		"line": "A sluice flap that tilts to fling a slow ball off course; hit it fast, or jump the tilt, and it launches you instead."},
	# Boom Tender No. 22 (design-v3/SPILLWAY-ROSTER.md): the Spillway's own body, a bowling exam.
	"boom_tender": {"faction": FLEET, "role": "controller", "mechanic": "boom_pin", "telegraph": T_LANE, "holds": true,
		"breaks": ["boost", "jump", "hook"], "tag": "", "hold": "", "tests": "speed", "script": "res://src/combat/boom_tender.gd", "world": 1,
		"job": "Was a boom tender that strung floats to catch drift.",
		"line": "Swings a debris boom of five floats across your lane and pins a slow ball to its hull; bowl through fast and the floats pop like pins."},
	"catch_trap": {"faction": FLEET, "role": "controller", "mechanic": "cup_hold", "telegraph": T_INSTANT, "holds": true,
		"breaks": ["boost", "smash", "hook"], "tag": "ice_form", "tag_next": "tag_cup_snap", "hold": "ice_form", "tests": "speed",
		"job": "Was the fish lift.",
		"line": "A cup that closes over a ball rolling onto it and holds it dead still; boost or smash out, or break it first."},

	# Kill-first specials (design-v3/ENEMY-PRIORITY.md 4): each makes its pack worse until it
	# is removed, and never attacks, so it takes no attacker budget.
	"linker": {"faction": FLEET, "role": "kill_first", "mechanic": "dish_guard", "telegraph": -1, "holds": false,
		"breaks": [], "tag": "", "tests": "air", "script": "res://src/combat/linker.gd",
		"job": "Was a shield tender that kept the weather off a weld.",
		"line": "Holds a dish over a partner that shrugs off hits through it; cut the cable, come over the top or kill the Linker."},

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

# The chassis column (SQ4; comps/roboquest/enemy-design-grammar.md, "a family is a chassis
# class plus a movement class plus one read"). Every row, base or declared, names:
# - chassis: its body class, one of CHASSIS_CLASSES;
# - move_class: how it gets about, one of MOVE_CLASSES (fixed holds its ground, ground
#   travels or lunges on the floor, airborne hovers or dives);
# - threat_feature: the one visible part that is also its warning, what a still at game
#   camera distance must show. Unique per row, so no two silhouettes share a read.
# The table sits here, beside the rows, so a declared later-world row (roster_dig.gd,
# roster_highdraft.gd) gets its columns without those files changing; _all_rows merges it in.
const CHASSIS_CLASSES := ["crawler", "emplacement", "heavy", "hover", "swarm", "burrower", "cache"]
const MOVE_CLASSES := ["fixed", "ground", "airborne"]

# Start values from comps/roboquest/movement-and-feel.md (run about 2.35x the median enemy
# and 1.2x the p90 enemy). The speed table in tests/roster_speed_ratio_test.gd reports against
# them and gates from a later unit; nothing in play reads them.
const RUN_TO_MEDIAN_RATIO := 2.35
const FAST_ENEMY_RATIO := 1.2

const CHASSIS := {
	"chaser": {"chassis": "crawler", "move_class": "ground", "threat_feature": "Lance snout that levels before the lunge"},
	"lobber": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Mortar tube tipping up toward the ball"},
	"miniboss": {"chassis": "heavy", "move_class": "ground", "threat_feature": "Plating that lifts off before the charge"},
	"vault": {"chassis": "cache", "move_class": "fixed", "threat_feature": "Cracked panel showing the next Warden's plating"},
	"warden": {"chassis": "heavy", "move_class": "fixed", "threat_feature": "Beacon seal lens at its core"},
	"mag_trapper": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Disc launcher spinning up on its boom"},
	"hooker": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Harpoon barrel aimed along its lane"},
	"netcaster": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Net mast whose crown crackles"},
	"bola_thrower": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Whirling bola arm at full swing"},
	"plated_brute": {"chassis": "heavy", "move_class": "fixed", "threat_feature": "Slab plate raised overhead before the slam"},
	"deflector": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Dish shield braced face-on to the ball"},
	"winch_drone": {"chassis": "hover", "move_class": "airborne", "threat_feature": "Winch drum hanging under the hull"},
	"gyro_jammer": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Gyro ring wobbling around its field"},
	"swatter": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Low paddle arm cocked at the sweep edge"},
	"ramp_flipper": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Floor plate tilting on its hinge"},
	"catch_trap": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Cup petals opening over the floor"},
	"linker": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Dish on a long sideways boom braced over another enemy"},
	"reactor_relic": {"chassis": "heavy", "move_class": "fixed", "threat_feature": "Vent slits glowing before the eruption"},
	"swarm_remnant": {"chassis": "swarm", "move_class": "airborne", "threat_feature": "Drones snapping into one lined-up formation"},
	"mind_hand": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Raised arm whose lens locks on the ball"},
	"burrower": {"chassis": "burrower", "move_class": "ground", "threat_feature": "Floor ring swelling under a ball on the floor"},
	"drill_crew": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Drill bit lowered over the bore point"},
	"lamp_swarm": {"chassis": "swarm", "move_class": "airborne", "threat_feature": "Floodlight heads opening their shutters in a ring"},
	"line_cutter": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Cutter ring spinning up at its rim"},
	"anchor_crew": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Winch post with the line paid out along its lane"},
	"kite_drone": {"chassis": "hover", "move_class": "airborne", "threat_feature": "Mark lamp painting the dive spot below"},
	"dispatcher": {"chassis": "cache", "move_class": "fixed", "threat_feature": "Pneumatic tube curling down off a box on a mast"},
	"foreman": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Steam-horn mast over a punch clock, tethered to its crew"},
	"prop_crew": {"chassis": "crawler", "move_class": "ground", "threat_feature": "Timber prop holding a cracked roof frame over its pack"},
	"pit_jaw": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Toothed jaw ring flush with the floor, its lips parting"},
	"splitter": {"chassis": "crawler", "move_class": "ground", "threat_feature": "Three welded pods whose seams flare white as one buds off"},
	"splitter_pod": {"chassis": "crawler", "move_class": "ground", "threat_feature": "Lit seams blinking faster as the fuse burns"},
	"jolt_layer": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Cable spool under a coil that swells before each jolt"},
	"boom_tender": {"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Float lamps lighting one by one out along the boom"},
}

# The Fleet counters in the order the director unlocks them, and the ancients.
const COUNTERS := ["mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster", "deflector", "winch_drone",
	"gyro_jammer", "swatter", "ramp_flipper", "catch_trap"]
const ANCIENTS := ["reactor_relic", "swarm_remnant", "mind_hand"]
# The kill-first specials (ENEMY-PRIORITY.md 4): rows in this file plus roster_specials.gd; they arrive in packs too.
static var SPECIALS: Array = ["linker"] + RosterSpecials.ROWS.keys().filter(func(id): return RosterSpecials.ROWS[id].get("priority", "") != "spawned")
# The family ancient per Warden family.
const FAMILY_ANCIENT := {REACTOR: "reactor_relic", SWARM: "swarm_remnant", MIND: "mind_hand"}

# Every row: the base roster, the declared world 2 and 3 kinds and the kill-first specials.
static var ROWS: Dictionary = _all_rows()


static func _all_rows() -> Dictionary:
	var rows := BASE_ROWS.duplicate()
	for table in [RosterDig.ROWS, RosterHighdraft.ROWS, RosterSpecials.ROWS]:
		for id in table:
			assert(not rows.has(id), "roster id declared twice: %s" % id)
			rows[id] = table[id]
	for id in rows:
		rows[id] = rows[id].merged(CHASSIS.get(id, {}))
	return rows


# What is wrong with a row's chassis column: a missing or unknown chassis, a missing or
# unknown move class, a blank threat feature. Empty when the row is sound.
static func chassis_problems(entry: Dictionary) -> Array:
	var problems := []
	if not String(entry.get("chassis", "")) in CHASSIS_CLASSES:
		problems.append("chassis")
	if not String(entry.get("move_class", "")) in MOVE_CLASSES:
		problems.append("move_class")
	if String(entry.get("threat_feature", "")).strip_edges() == "":
		problems.append("threat_feature")
	return problems


# A kind is built when it needs no script of its own or its script file exists.
static func built(kind: String) -> bool:
	var path := String(row(kind).get("script", ""))
	return path == "" or ResourceLoader.exists(path)


# The kinds declared for a world, in declaration order.
static func world_kinds(world: int) -> Array:
	var kinds: Array = []
	for id in ROWS:
		if int(ROWS[id].get("world", 0)) == world:
			kinds.append(id)
	return kinds


# A world's own kind: a row the director composes into that world's authored packs.
static func is_world_kind(id: String) -> bool:
	return int(row(id).get("world", 0)) >= 1


static func has(id: String) -> bool:
	return ROWS.has(id)


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


# The name a screen shows: the row's own "name" (the Shift Boss, whose id stays foreman), else the id in words.
static func name_of(id: String) -> String:
	return String(row(id).get("name", id.replace("_", " ").capitalize()))


# A Warden's name by family and variant; a variant with no name of its own reads as its family's.
static func warden_name(family: String, variant := "") -> String:
	var names: Dictionary = WARDEN_NAMES.get(family, {})
	return String(names.get(variant, names.get("", "Warden")))


# What the machine did before the works were turned on you; "" for a kind with no job written yet.
static func job_of(id: String) -> String:
	return String(row(id).get("job", ""))


static func faction_of(id: String) -> String:
	return String(row(id).get("faction", FLEET))


static func faction(name: String) -> Dictionary:
	return FACTIONS.get(name, FACTIONS[FLEET])


static func is_ancient(name: String) -> bool:
	return faction(name)["era"] == "ancient"


# A kill-first special arrives inside a pack, so it counts as one too; what it spawns does not.
static func is_reinforcement(id: String) -> bool:
	return id in COUNTERS or id in ANCIENTS or id in SPECIALS


# A stage's Warden kind when its row names none: its world's family on the default table
# (KF0 2026-10-10; it indexed by stage before). A stage past the table clamps to the last world.
static func warden_family(stage: int) -> String:
	return world_warden_family(StageDefs.world_of(stage))


static func world_warden_family(world: int) -> String:
	return WARDEN_FAMILIES[clampi(world, 1, WARDEN_FAMILIES.size()) - 1]


# A boss piece kind ("brindle_hull") begins with a Worlds.BOSSES row's kind plus "_". A
# roster enemy is never a piece, even when it shares a boss's prefix (mind_hand and "mind").
static func is_boss_piece(kind: String) -> bool:
	if ROWS.has(kind):
		return false
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
