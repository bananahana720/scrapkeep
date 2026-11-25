extends RefCounted

# The worlds of a run and the boss that ends each one. A stage table (stage_defs.gd,
# slice_defs.gd) gives each stage row a `world`; this file names the worlds and holds
# the bosses. The stage index stays global across the run (per-run memory is keyed by it).
# The table helpers below take the table's DEFS so each table's statics stay one-liners.

# World one's display name is the Bible's region name (BIBLE.md, "Spillway Works"); the
# Spillway and the Cable Reach are its two stages today. The Dig and the Highdraft are
# the plan's names (ALPHA-PLAN M2 and M3).
# Full-alpha progression unlocked (W49-COMBAT): Worlds 1->2->3 play end-to-end and Brindle's
# cobalt pick (ruling ap) returns when continuing into World 2.
const FULL_ALPHA := true
const BRINDLE_COBALT_PICK := true

const ROWS := [
	{"id": 1, "name": "Spillway Works", "boss": "brindle"},
	{"id": 2, "name": "The Dig", "boss": "waking"},
	{"id": 3, "name": "The Highdraft", "boss": "mind"},
]

# One row per boss. kind is the prefix of the boss's piece kinds ("brindle_hull"); music
# is the music engine's id. title is the victory screen's heading; victory its body. Brindle's rout
# already has its ROUTED stamp (flourish_rows.gd), so his heading names what was won (ruling cx); stamp, when set, is inked
# under the heading (the Mind's crew took you on: "All hands", Andrew 2026-10-18). built false means the script does not exist yet.
# script is the module flow runs for that world's arena. The Waking (waking.gd) and the Mind
# (mind.gd) have their own modules; each extends stub_boss.gd, one posture Warden on a flat
# pad, until its fight lands.
const BOSSES := {
	"brindle": {"name": "Admiral Brindle", "title": "SPILLWAY RECLAIMED", "script": "res://src/boss/boss.gd", "kind": "brindle", "music": "brindle",
		"built": true, "victory": "Back on the crew's books, kettle and all.", "epitaph": "Brindle, crane parked over the Slag Bowl. Anchors accounted for."},
	"waking": {"name": "The Waking", "title": "THE WAKING STILLED", "script": "res://src/boss/waking.gd", "kind": "waking", "music": "waking",
		"built": true, "victory": "The Waking is stilled.", "epitaph": "The Waking, stilled in the Dig. Fallen floors await pit inspection."},
	"mind": {"name": "The Mind", "title": "THE MIND QUIETED", "script": "res://src/boss/mind.gd", "kind": "mind", "music": "mind",
		"built": true, "victory": "The Mind is quiet.", "stamp": "HIRED", "finale_lift_semitones": 2,
		"epitaph": "The Mind, quieted in the Highdraft. Glove set by the empty place."},
}


static func boss_finale_lift(boss_id: String) -> int:
	return int(BOSSES.get(boss_id, {}).get("finale_lift_semitones", 0))


# The page shown once when the summary opens after a win over the final world's boss, before
# the stats (screens.gd). title is the heading. log holds two crew-log lines per world id, shown
# over that world's fly-over. close is shown over the start of the credits, then sign.
# TONE-READ: Crew-log ending, prog-G6; every line awaits Andrew's read.
const ENDING := {
	"title": "RETURN TRIP ENTERED",
	"log": {
		1: [
			"Shift log: Brindle routed. Head house drum turns without anyone on the handwheel.",
			"Intake clear. Old flood marks inside the housing are one hand higher.",
		],
		2: [
			"Shift board: the Waking is stilled. Nobody has knocked since.",
			"Pit inspected. Seven lamps back on the rack. We only issued six.",
		],
		3: [
			"Highdraft watch: the Mind is quiet. We hear a washer rolling across the deck.",
			"West cable holds its note. Nobody answers from the next island.",
		],
	},
	"close": [
		"Moss has a needle through my glove. Says supper won't mend it.",
		"Tally laid the three leaves beside the repair sheet. The torn edges fit.",
	],
	"sign": "Return trip entered. We filled in the time ourselves. Filed by the bay crew.",
}

static func row(world: int) -> Dictionary:
	for r in ROWS:
		if int(r["id"]) == world:
			return r
	return {}


static func boss_of(world: int) -> Dictionary:
	var r := row(world)
	if r.is_empty():
		return {}
	return BOSSES.get(String(r["boss"]), {})


# --- Helpers over a table's DEFS (rows sorted by stage, one row per stage) ---

static func world_of(defs: Array, stage: int) -> int:
	return int(defs[clampi(stage, 1, defs.size()) - 1].get("world", 1))


static func first_of(defs: Array, world: int) -> int:
	for d in defs:
		if int(d.get("world", 1)) == world:
			return int(d["stage"])
	return 0


static func last_of(defs: Array, world: int) -> int:
	var found := 0
	for d in defs:
		if int(d.get("world", 1)) == world:
			found = int(d["stage"])
	return found


static func local(defs: Array, stage: int) -> int:
	return clampi(stage, 1, defs.size()) - first_of(defs, world_of(defs, stage)) + 1


static func worlds(defs: Array) -> Array:
	var out := []
	for d in defs:
		var w := int(d.get("world", 1))
		if w not in out:
			out.append(w)
	return out


static func is_world_last(defs: Array, stage: int) -> bool:
	return stage >= last_of(defs, world_of(defs, stage))


static func is_run_last(defs: Array, stage: int) -> bool:
	return stage >= defs.size()
