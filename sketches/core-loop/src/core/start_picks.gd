extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const RunTier := preload("res://src/core/run_tier.gd")


const OFFERED := 3
const REROLLS := 1
const KINDS := ["part", "cogs", "core"]
const START_COGS := 60
const SOURCE := "start_pick"
const EFFECT_WORDS := 6
const COGS_EFFECT := "Spend at Moss's counter"
const CORE_EFFECT := "Rarer parts this stage"

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


static func _static_init() -> void:
	for pilot in LISTS:
		var rows: Array = LISTS[pilot]
		assert(rows.size() == OFFERED * (REROLLS + 1), "StartPicks row count mismatch for " + pilot)
		var ids := {}
		for spec in rows:
			var id: String = spec["part"] if spec["do"] == "part" else spec["do"]
			assert(not ids.has(id), "Duplicate StartPicks id %s for %s" % [id, pilot])
			ids[id] = true


static func offered_tiers(profile) -> Array:
	return range(RunTier.top_unlocked(profile) + 1)


static func list_for(pilot: String) -> Array:
	var out := []
	for spec in LISTS.get(pilot, []):
		out.append(_resolve(spec))
	return out


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
