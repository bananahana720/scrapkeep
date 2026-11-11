extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const RunTier := preload("res://src/core/run_tier.gd")

# SG9, the run-start pick of three (comps gunfire/heroes-and-ascensions.md:23 and :75; W13
# memo 3, SG9). Each pilot has its own short list of small options. At run start three are
# drawn from the run seed alone, the player takes one, and may reroll once; the reroll shows
# the other three, so a reroll is always new and never a gamble on a repeat. Every option is
# a run-local grant through a RunState mutator (a common part, cogs or a bonus core), so a new
# run clears it with the rest of the run (BIBLE: no permanent stat boosts) and no option moves
# a movement knob: no mobility-family part, no cooldown_scale. RunState holds the offer; this
# file only says what is on each list, how three are drawn and what taking one does.

const OFFERED := 3
const REROLLS := 1
const KINDS := ["part", "cogs", "core"]
# Start value, not tuned: one and a half tier-1 fabricator parts (fabricators.gd part_base 10).
const START_COGS := 15
const SOURCE := "start_pick"
# What a tile says its option does, under its name: a part's own verb (parts.gd), and these
# for the two grants that are not parts. At most EFFECT_WORDS words.
const EFFECT_WORDS := 6
const COGS_EFFECT := "Spend at Moss's counter"
const CORE_EFFECT := "Rarer parts this stage"

# Pilot id to its list, in authored order. Each list holds OFFERED * (REROLLS + 1) rows, so
# the first draw and the reroll never share an option. Parts lean on the pilot's kit.
const LISTS := {
	"pylon_engineer": [{"do": "part", "part": "chain_arc"}, {"do": "part", "part": "hot_rivets"},
		{"do": "part", "part": "long_barrel"}, {"do": "part", "part": "rivet_plating"},
		{"do": "cogs"}, {"do": "core"}],
	"runner_gunner": [{"do": "part", "part": "loose_trigger"}, {"do": "part", "part": "double_feed"},
		{"do": "part", "part": "focus_lens"}, {"do": "part", "part": "hot_rivets"},
		{"do": "cogs"}, {"do": "core"}],
	"demolitions_caster": [{"do": "part", "part": "slag_rounds"}, {"do": "part", "part": "cross_split"},
		{"do": "part", "part": "hot_rivets"}, {"do": "part", "part": "magnet_spool"},
		{"do": "cogs"}, {"do": "core"}],
	"tarn": [{"do": "part", "part": "rivet_plating"}, {"do": "part", "part": "hot_rivets"},
		{"do": "part", "part": "slag_rounds"}, {"do": "part", "part": "magnet_spool"},
		{"do": "cogs"}, {"do": "core"}],
	"tally": [{"do": "part", "part": "chain_arc"}, {"do": "part", "part": "loose_trigger"},
		{"do": "part", "part": "magnet_spool"}, {"do": "part", "part": "spiral_wave"},
		{"do": "cogs"}, {"do": "core"}],
	"remembered_cannon": [{"do": "part", "part": "focus_lens"}, {"do": "part", "part": "long_barrel"},
		{"do": "part", "part": "slag_rounds"}, {"do": "part", "part": "rivet_plating"},
		{"do": "cogs"}, {"do": "core"}],
}


static func offered_tiers(profile) -> Array:
	return range(RunTier.top_unlocked(profile) + 1)


# The pilot's rows, resolved: {"id", "do", "name", "icon", "effect"} plus "part" or "amount". The id is
# the part id for a part, else the kind, so one list never holds two rows with one id.
static func list_for(pilot: String) -> Array:
	var out := []
	for spec in LISTS.get(pilot, []):
		out.append(_resolve(spec))
	return out


# The ids alone, read straight from LISTS: the draw runs at every run start and needs no names.
static func ids_for(pilot: String) -> Array:
	var out := []
	for spec in LISTS.get(pilot, []):
		out.append(spec["part"] if spec["do"] == "part" else spec["do"])
	return out


static func row(pilot: String, id: String) -> Dictionary:
	for r in list_for(pilot):
		if r["id"] == id:
			return r
	return {}


static func _resolve(spec: Dictionary) -> Dictionary:
	var r := spec.duplicate()
	match String(spec["do"]):
		"part":
			r["id"] = spec["part"]
			r["name"] = Parts.display_name(spec["part"])
			r["icon"] = Parts.icon_of(spec["part"])
			r["effect"] = String(Parts.row(spec["part"]).get("verb", ""))
		"cogs":
			r["id"] = "cogs"
			r["amount"] = START_COGS
			r["name"] = "%d Cogs" % START_COGS
			r["icon"] = "res_scrap"
			r["effect"] = COGS_EFFECT
		"core":
			r["id"] = "core"
			r["name"] = "Bonus Core"
			r["icon"] = "res_core"
			r["effect"] = CORE_EFFECT
	return r


# Three ids for draw number `roll` (0 the first offer, 1 the reroll). A function of the pilot
# and the run seed alone: one shuffle of the list, cut into consecutive threes, from its own
# generator, so nothing else in the run can move it and a replay from the entrance save shows
# the same three.
static func draw(pilot: String, run_seed: int, roll: int) -> Array:
	var ids := ids_for(pilot)
	if ids.size() < OFFERED * (roll + 1) or roll < 0:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [pilot, run_seed])
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	return ids.slice(roll * OFFERED, (roll + 1) * OFFERED)


# Grants the option to the run through its mutators; false for an id not on the list.
static func apply(run, pilot: String, id: String) -> bool:
	var r := row(pilot, id)
	if r.is_empty():
		return false
	match String(r["do"]):
		"part":
			run.add_part(String(r["part"]), SOURCE)
		"cogs":
			run.add_cogs(int(r["amount"]))
		"core":
			run.add_core(SOURCE, Vector3.ZERO)
	return true
