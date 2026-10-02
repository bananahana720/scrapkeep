extends RefCounted

# The worlds of a run and the boss that ends each one. A stage table (stage_defs.gd,
# slice_defs.gd) gives each stage row a `world`; this file names the worlds and holds
# the bosses. The stage index stays global across the run (per-run memory is keyed by it).
# The table helpers below take the table's DEFS so each table's statics stay one-liners.

# World one's display name is the Bible's region name (BIBLE.md, "Spillway Works"); the
# Spillway and the Cable Reach are its two stages today. The Dig and the Highdraft are
# the plan's names (ALPHA-PLAN M2 and M3).
const ROWS := [
	{"id": 1, "name": "Spillway Works", "boss": "brindle"},
	{"id": 2, "name": "The Dig", "boss": "waking"},
	{"id": 3, "name": "The Highdraft", "boss": "mind"},
]

# One row per boss. kind is the prefix of the boss's piece kinds ("brindle_hull"); music
# is the music engine's id. built false means the script does not exist yet.
const BOSSES := {
	"brindle": {"name": "Admiral Brindle", "script": "res://src/boss/boss.gd", "kind": "brindle", "music": "brindle",
		"built": true, "victory": "Brindle is routed.", "epitaph": "Brindle, routed in the Slag Bowl."},
	"waking": {"name": "The Waking", "script": "res://src/boss/waking.gd", "kind": "waking", "music": "waking",
		"built": false, "victory": "The Waking is stilled.", "epitaph": "The Waking, stilled in the Dig."},
	"mind": {"name": "The Mind", "script": "res://src/boss/mind.gd", "kind": "mind", "music": "mind",
		"built": false, "victory": "The Mind is quiet.", "epitaph": "The Mind, quieted in the Highdraft."},
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
