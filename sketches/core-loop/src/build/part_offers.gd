extends RefCounted

const PartDef := preload("res://src/build/part_def.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Relics := preload("res://src/build/relics.gd")
const MakerDefs := preload("res://src/build/maker_defs.gd")
const PartMutations := preload("res://src/build/part_mutations.gd")

const SOURCE_RARITIES := {
	"fabricator": ["common"],
	"vault": ["rare"],
	"milestone": ["relic"],
}

const WORLD_ESCALATION_STAGE_W2 := 3
const WORLD_ESCALATION_STAGE_W3 := 5

const SOURCE_RARITIES_BY_WORLD := {
	1: {"fabricator": ["common"], "vault": ["rare"], "milestone": ["relic"]},
	2: {"fabricator": ["common", "rare"], "vault": ["rare", "relic"], "milestone": ["relic"]},
	3: {"fabricator": ["common", "rare"], "vault": ["rare", "relic"], "milestone": ["relic"]},
}

const GATE_RARITIES_BY_WORLD := {
	1: [["common"], ["common", "rare"], ["rare", "relic"]],
	2: [["common", "rare"], ["rare"], ["rare", "relic"]],
	3: [["common", "rare"], ["rare", "relic"], ["rare", "relic"]],
}

const STAGE_RARE_MULT := {1: 1.0, 2: 2.8, 3: 5.5}

const VERB_EFFECTS := [
	"pike_fuse", "dash_wake", "reel_chain", "slam_crack", "second_bell", "line_leash",
	"boomerang_return", "orbital_satellites", "prism_refract", "coin_shot",
	"slag_zone", "pocket_aura", "seismic_cone", "air_static",
]

const WORLD_VERB_PARTS := [
	"slag_pike", "halo_rig", "backwash", "barbed_reel", "faultline_cap", "second_bell",
	"long_leash", "fan_spread", "helix_drill", "basalt_ram", "storm_capacitor",
	"boomerang_spool", "orbital_flywheel", "prism_splitter", "slag_furnace",
]

const ARCHETYPES := {
	"heavy_melee": {
		"makers": ["fleet_surplus", "waking", "moss"],
		"anchors": ["ram_plow", "basalt_ram", "drop_weight", "ballast_drum", "faultline_cap",
			"barbed_reel", "impact_driver", "winch_pawl", "ten_pin", "pin_setter",
			"warhead_slug", "orbital_flywheel", "brace_frame", "re_rack"],
		"grapple_muts": ["wrecking_flail", "tether_slam", "dragnet_siphon"],
	},
	"run_n_gun": {
		"makers": ["redjaw", "fleet_surplus", "highdraft_roosts"],
		"anchors": ["gatling_heart", "fan_spread", "helix_drill", "double_feed", "slag_pike",
			"halo_rig", "brass_drum", "heavy_breech", "cross_split", "spiral_wave",
			"chain_arc", "boomerang_spool", "prism_splitter", "slag_furnace", "runner_overclock"],
		"grapple_muts": ["det_cord", "sonic_snap_sling"],
	},
	"spell_cast": {
		"makers": ["spillway_works", "highdraft_roosts", "mind_glass"],
		"anchors": ["spare_cell", "storm_capacitor", "second_bell", "overcharge_coil",
			"echo_charge", "cap_relay", "quick_spool", "reserve_tank", "backwash",
			"long_leash", "galvanic_rounds", "rime_rounds", "arc_coil", "pylon_capacitor"],
		"grapple_muts": ["hot_wire", "live_bus"],
	},
}

const MILESTONE_FOR_EVENT := {
	"surge_run": "rime_heart",
	"hold_the_relay": "tempest_core",
}
const MILESTONE_ORDER := ["scrap_gravity", "tempest_core", "rime_heart"]

const SYNERGY_BAIT := 0.35
const HIGH_IMPACT_SYNERGY_BAIT := 0.50

const MAKER_NUDGE_AT := 2
const MAKER_NUDGE := 1.1
const ARCHETYPE_NUDGE_AT := 2
const ARCHETYPE_NUDGE := 1.45
const WORLD_VERB_NUDGE := 1.35
const WORLD_SIGNATURE_NUDGE := 1.6

const ANSWERS := {
	"long_barrel": ["range"], "focus_lens": ["range"], "horizon_optic": ["range"],
	"tracer_round": ["range", "fuse"],
	"cross_split": ["spread"], "spiral_wave": ["spread"], "chain_arc": ["spread"], "fan_spread": ["spread"],
	"helix_drill": ["spread"], "ring_wave": ["spread"], "tempest_core": ["spread"], "arc_coil": ["spread"],
	"static_burr": ["spread"],
	"loose_trigger": ["fuse"], "double_feed": ["fuse"], "gatling_heart": ["fuse"],
	"brace_frame": ["cc"],
	"hot_rivets": ["plating"], "slag_rounds": ["plating"], "sunforged_core": ["plating"], "ram_plow": ["plating"],
	"overpressure": ["plating"], "warhead_slug": ["plating"], "clean_break": ["plating"], "ballast_drum": ["plating"],
}

const PATTERN_PARTS := ["spiral_wave", "cross_split", "chain_arc"]
const PATTERN_GUARANTEE_STAGE := 2
const RUNG_FLOOR := 1

const GENERATED_SHARE := 0.25

const KITS := {
	"pylon_engineer": {"skill": ["arc", "anchor"], "defence": ["arc", "anchor", "kinetic"]},
	"runner_gunner": {"skill": ["speed"], "movement": ["speed"]},
	"demolitions_caster": {"weapon": ["arc", "chain", "frost", "spiral"], "movement": []},
	"tarn": {"weapon": ["kinetic"], "defence": ["kinetic", "anchor"]},
	"tally": {"weapon": ["split"], "defence": ["speed", "mass"]},
	"remembered_cannon": {"weapon": ["mass"], "skill": ["mass", "kinetic", "speed"]},
}
const KIT_SHARE := 0.7
const REST_OF_NEUTRAL := 0.15
const KIT_PART_CAP := 0.25
const MOVEMENT_SHARE := 0.12
const CLASS_MOVEMENT_SHARE := 0.06
const NEUTRAL_SHELF := ["hot_rivets", "loose_trigger", "long_barrel", "rivet_plating", "rivet_seam", "magnet_spool", "fast_hands"]
const NEUTRAL_LEAN := 4.0
const NEUTRAL_WEAPON_EASE := 0.1
const NEUTRAL_REPEAT_CAP := 2

static var maker_nudge_on := true
static var archetype_nudge_on := true
static var answer_nudge_on := true
static var _answering_by_class := {}


static func reset_for_tests() -> void:
	maker_nudge_on = true
	archetype_nudge_on = true
	answer_nudge_on = true
	_answering_by_class.clear()


static func _answering(class_id: String) -> Dictionary:
	if not _answering_by_class.has(class_id):
		var ids := {}
		for part_id in ANSWERS:
			if Nemesis.answers(class_id, ANSWERS[part_id]):
				ids[part_id] = true
		_answering_by_class[class_id] = ids
	return _answering_by_class[class_id]


static func pick_rarity_scaled(rng: RandomNumberGenerator, allowed: Array, rare_mult: float, active_tier: int) -> String:
	var tier_mult: float = float(RunTier.row(active_tier).rare_weight) if active_tier != 0 else 1.0
	var combined_rare := tier_mult * rare_mult
	if is_equal_approx(combined_rare, 1.0):
		return ItemGen.pick_rarity(rng, allowed)
	var total := 0.0
	var weights := {}
	for rarity in allowed:
		weights[rarity] = ItemGen.weight_of(rarity) * (combined_rare if rarity == "rare" else 1.0)
		total += weights[rarity]
	var x := rng.randf() * total
	for rarity in allowed:
		x -= weights[rarity]
		if x < 0.0:
			return rarity
	return allowed[-1]


static func world_for_stage(stage: int) -> int:
	return 1 if stage < WORLD_ESCALATION_STAGE_W2 else (2 if stage < WORLD_ESCALATION_STAGE_W3 else 3)


static func stage_rare_mult(stage: int) -> float:
	return float(STAGE_RARE_MULT.get(world_for_stage(stage), 1.0))


static func source_rarities(source: String, stage := 1) -> Array:
	var table: Dictionary = SOURCE_RARITIES_BY_WORLD.get(world_for_stage(stage), SOURCE_RARITIES)
	return (table.get(source, SOURCE_RARITIES.get(source, ["common"])) as Array).duplicate()


static func gate_rarities(bonus_cores: int, stage := 1) -> Array:
	var tiers: Array = GATE_RARITIES_BY_WORLD.get(world_for_stage(stage), GATE_RARITIES_BY_WORLD[1])
	return (tiers[clampi(bonus_cores, 0, tiers.size() - 1)] as Array).duplicate()


static func listed_only() -> bool:
	return Synergies.table != null and Synergies.table.parts_listed()


static func rung_of(part_id: String, def_fn: Callable) -> int:
	var d: Resource = def_fn.call(part_id)
	return maxi(0, PartDef.RARITIES.find(ItemGen.resolve_rarity(String(d.rarity)))) if d != null else 0


static func changes_behaviour(part_id: String, def_fn: Callable) -> bool:
	if PartMutations.is_grapple_mutation_part(part_id):
		return true
	var d: Resource = def_fn.call(part_id)
	if d == null:
		return false
	return d.changes_behaviour() or String(d.effect.get("do", "")) in VERB_EFFECTS


static func is_high_impact(part_id: String, def_fn: Callable) -> bool:
	if Relics.is_relic(part_id) or PartMutations.is_grapple_mutation_part(part_id) or changes_behaviour(part_id, def_fn):
		return true
	if Items.grapple_mutation_of(part_id) != "":
		return true
	var d: Resource = def_fn.call(part_id)
	return d != null and d.bits != 0 and rung_of(part_id, def_fn) >= RUNG_FLOOR


static func offer_pool(class_id: String, rarities: Array, ops: Dictionary) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var pool: Array = []
	var all: Dictionary = ops["all_rows"].call()
	var listed := listed_only()
	var opened: Dictionary = ops["opened_items"]
	var is_burden_fn: Callable = ops["is_burden"]
	var seam_met_fn: Callable = ops["seam_met"]
	for key in all:
		var r: Dictionary = all[key]
		if listed and not Synergies.table.part_in_play(key) and not opened.has(key):
			continue
		if is_burden_fn.call(key):
			continue
		if not r["rarity"] in rarities or r.get("shop_only", false) or not seam_met_fn.call(r.get("needs", "")):
			continue
		var only: String = r.get("class_id", "")
		if only != "" and only != class_id:
			continue
		pool.append(key)
	return pool


static func odds_for(rarities: Array, class_id: String, ops: Dictionary) -> Array:
	var live: Array = []
	for r in ItemGen.resolve_rarities(rarities):
		if not offer_pool(class_id, [r], ops).is_empty():
			live.append(r)
	return ItemGen.odds(live)


static func bucket_of(part_id: String, row_fn: Callable) -> String:
	var r: Dictionary = row_fn.call(part_id)
	var family := String(r.get("family", ""))
	var touches := String(r.get("touches", ""))
	if touches in ["haul", "special"] or family == "class":
		return "skill"
	if family in ["weapon", "pattern"] or touches == "fire":
		return "weapon"
	if family == "mobility" or r.get("mods", {}).has("cruise"):
		return "movement"
	var shown: String = r.get("icon", PartDef.ICON_FOR_FAMILY.get(family, "utility"))
	match shown:
		"defense":
			return "defence"
		"damage", "transform":
			return "weapon"
		"mobility":
			return "movement"
	return "skill"


static func in_kit(class_id: String, part_id: String, row_fn: Callable) -> bool:
	if not KITS.has(class_id):
		return false
	var r: Dictionary = row_fn.call(part_id)
	if String(r.get("class_id", "")) == class_id:
		return true
	var tags: Array = KITS[class_id].get(bucket_of(part_id, row_fn), [])
	return r.get("tags", []).any(func(tag): return tag in tags)


static func _neutral_slot(class_id: String, pool: Array, offered: Dictionary, row_fn: Callable) -> Array:
	return pool.filter(func(key): return key in NEUTRAL_SHELF and not in_kit(class_id, key, row_fn) \
		and int(offered.get(key, 0)) < NEUTRAL_REPEAT_CAP)


static func _uncapped(class_id: String, pool: Array, offered: Dictionary, row_fn: Callable) -> Array:
	return pool.filter(func(key): return not key in NEUTRAL_SHELF or in_kit(class_id, key, row_fn) \
		or int(offered.get(key, 0)) < NEUTRAL_REPEAT_CAP)


static func swap_stacked_out(rng: RandomNumberGenerator, class_id: String, held: Array, picks: Array, pool: Array,
		offered: Dictionary, ops: Dictionary) -> Array:
	var row_fn: Callable = ops["row"]
	var def_fn: Callable = ops["def"]
	var stacked_out_fn: Callable = ops["stacked_out"]
	var out: Array = []
	var left: Array = _uncapped(class_id, pool, offered, row_fn).filter(func(key): return not stacked_out_fn.call(key, held) and not key in picks)
	for key in picks:
		if not stacked_out_fn.call(key, held):
			out.append(key)
			continue
		var hard: bool = def_fn.call(key).hits_harder()
		var shelf: bool = key in NEUTRAL_SHELF
		var kept: Array = left.filter(func(k): return (not hard or def_fn.call(k).hits_harder()) and (not shelf or k in NEUTRAL_SHELF))
		if kept.is_empty():
			kept = left
		var bucket := bucket_of(key, row_fn)
		var kit := in_kit(class_id, key, row_fn)
		var same: Array = kept.filter(func(k): return bucket_of(k, row_fn) == bucket and in_kit(class_id, k, row_fn) == kit)
		if same.is_empty():
			same = kept.filter(func(k): return bucket_of(k, row_fn) == bucket)
		if same.is_empty():
			same = kept
		if same.is_empty():
			continue
		var swap: String = same[rng.randi_range(0, same.size() - 1)]
		out.append(swap)
		left.erase(swap)
	return out


static func _lean_slot(rng: RandomNumberGenerator, rarity: String, class_id: String, pool: Array,
		offered: Dictionary, picks: Array, exclude: Array, nudge: Dictionary, ops: Dictionary) -> String:
	if not listed_only() and rng.randf() < (1.0 - KIT_SHARE) * GENERATED_SHARE:
		var recipe := ItemGen.roll_id(rng, rarity)
		return "" if recipe in picks or recipe in exclude else recipe
	var slot := slot_weights(rarity, class_id, pool, offered, nudge, ops)
	if slot["candidates"].is_empty():
		return ""
	return pick_weight(rng, slot["candidates"], slot["weights"])


static func slot_weights(rarity: String, class_id: String, pool: Array, offered: Dictionary,
		nudge: Dictionary, ops: Dictionary) -> Dictionary:
	var row_fn: Callable = ops["row"]
	var kit: Dictionary = KITS[class_id]
	var open := _uncapped(class_id, pool, offered, row_fn)
	var all: Dictionary = ops["all_rows"].call()
	var candidates: Array = open.filter(func(key): return String(all.get(key, {}).get("rarity", "common")) == rarity)
	if candidates.is_empty():
		candidates = open
	if candidates.is_empty():
		return {"candidates": [], "weights": {}}
	var groups := {"moving": [], "still": [], "shelf": [], "rest": []}
	for key in candidates:
		if in_kit(class_id, key, row_fn):
			groups["moving" if bucket_of(key, row_fn) == "movement" else "still"].append(key)
		elif key in NEUTRAL_SHELF:
			groups["shelf"].append(key)
		else:
			groups["rest"].append(key)
	var moving := MOVEMENT_SHARE if kit.has("movement") \
		else minf(MOVEMENT_SHARE, CLASS_MOVEMENT_SHARE * groups["moving"].size())
	var neutral := 1.0 - KIT_SHARE
	var rest_share := neutral * REST_OF_NEUTRAL if not groups["rest"].is_empty() else 0.0
	var share := {"moving": moving, "still": KIT_SHARE - moving, "shelf": neutral - rest_share, "rest": rest_share}
	if groups["moving"].is_empty():
		share["still"] += share["moving"]
		share["moving"] = 0.0
	if groups["still"].is_empty():
		if not groups["shelf"].is_empty():
			share["shelf"] += share["still"]
		else:
			share["rest"] += share["still"]
		share["still"] = 0.0
	if groups["shelf"].is_empty():
		if not groups["still"].is_empty():
			share["still"] += share["shelf"]
		else:
			share["rest"] += share["shelf"]
		share["shelf"] = 0.0
	if groups["rest"].is_empty() and share["rest"] > 0.0:
		share["moving"] += share["rest"]
		share["rest"] = 0.0
	var weights := {}
	for name in groups:
		var raw := {}
		var sum := 0.0
		for key in groups[name]:
			var b := bucket_of(key, row_fn)
			var lean := 1.0
			if name == "shelf" and kit.has(b) and (b != "weapon" or kit.has("movement")):
				lean = NEUTRAL_LEAN
			elif (name == "shelf" or (name == "rest" and not groups["shelf"].is_empty())) and b == "weapon" and not kit.has("weapon"):
				lean = NEUTRAL_WEAPON_EASE
			raw[key] = lean / (1.0 + offered.get(key, 0))
			sum += raw[key]
		for key in raw:
			weights[key] = share[name] * raw[key] / sum
	var excess := 0.0
	for key in groups["moving"] + groups["still"]:
		if weights[key] > KIT_PART_CAP:
			excess += weights[key] - KIT_PART_CAP
			weights[key] = KIT_PART_CAP
	for name in ["shelf", "rest"]:
		if excess > 0.0 and not groups[name].is_empty():
			var room := 0.0
			for key in groups[name]:
				room += weights[key]
			for key in groups[name]:
				weights[key] += excess * (weights[key] / room if room > 0.0 else 1.0 / groups[name].size())
			excess = 0.0
	if not nudge.is_empty():
		for name in groups:
			var part: Dictionary = {}
			for key in groups[name]:
				part[key] = weights[key]
			part = nudged(part, nudge, row_fn)
			for key in part:
				weights[key] = part[key]
	return {"candidates": candidates, "weights": weights}


static func pick_weight(rng: RandomNumberGenerator, keys: Array, weights: Dictionary) -> String:
	var total := 0.0
	for key in keys:
		total += weights.get(key, 0.0)
	var x := rng.randf()
	if total <= 0.0:
		return keys[mini(int(x * keys.size()), keys.size() - 1)]
	x *= total
	for key in keys:
		x -= weights.get(key, 0.0)
		if x < 0.0:
			return key
	return keys[-1]


static func milestone_for(event_id: String, held: Array) -> String:
	if MILESTONE_FOR_EVENT.has(event_id):
		return MILESTONE_FOR_EVENT[event_id]
	for key in MILESTONE_ORDER:
		if not key in held:
			return key
	return MILESTONE_ORDER[0]


static func completing_part(held: Array, pool: Array, maker_counts_fn: Callable) -> String:
	var counted: Dictionary = maker_counts_fn.call(held)
	var wanted := {}
	for trick_id in Synergies.ROWS:
		var call := Synergies.callout(trick_id)
		if call.is_empty() or not Synergies.in_play(trick_id) or int(counted.get(Synergies.ROWS[trick_id]["maker"], 0)) != Synergies.AT - 1:
			continue
		if call["a"] in held and not call["b"] in held:
			wanted[call["b"]] = true
		elif call["b"] in held and not call["a"] in held:
			wanted[call["a"]] = true
	for key in pool:
		if wanted.has(key):
			return key
	return ""


static func floor_gate(rng: RandomNumberGenerator, picks: Array, class_id: String, held: Array,
		offered: Dictionary, count: int, ops: Dictionary) -> Array:
	var def_fn: Callable = ops["def"]
	if picks.is_empty() or picks.any(func(key): return rung_of(key, def_fn) >= RUNG_FLOOR and changes_behaviour(key, def_fn)):
		return picks
	var out := picks.duplicate()
	var slot := -1
	for i in out.size():
		if rung_of(out[i], def_fn) == RUNG_FLOOR:
			slot = i
			break
	if slot < 0:
		slot = 0
		while slot < out.size() and (out[slot] in PATTERN_PARTS or rung_of(out[slot], def_fn) > RUNG_FLOOR):
			slot += 1
	if slot >= out.size() and out.size() >= count:
		if out.any(func(key): return rung_of(key, def_fn) > RUNG_FLOOR):
			return picks
		slot = out.size()
		for i in range(out.size() - 1, -1, -1):
			if rung_of(out[i], def_fn) < RUNG_FLOOR:
				slot = i
				break
		if slot >= out.size():
			return picks
	var others: Array = out.filter(func(key): return key != out[slot]) if slot < out.size() else out
	var needs_hitter: bool = slot < out.size() and def_fn.call(out[slot]) != null and def_fn.call(out[slot]).hits_harder() \
		and not others.any(func(key): return def_fn.call(key) != null and def_fn.call(key).hits_harder())
	var plain: Array = offer_pool(class_id, ["rare"], ops).filter(func(key): return not changes_behaviour(key, def_fn) \
		or (needs_hitter and not def_fn.call(key).hits_harder()))
	var cobalt: Array = roll(rng, ["rare"], class_id, held, 1, picks + plain, offered, ops)
	if cobalt.is_empty():
		var soft: Array = offer_pool(class_id, ["rare"], ops).filter(func(key): return needs_hitter and not def_fn.call(key).hits_harder())
		cobalt = roll(rng, ["rare"], class_id, held, 1, picks + soft, offered, ops)
	if cobalt.is_empty():
		return picks
	if slot < out.size():
		out[slot] = cobalt[0]
	else:
		out.append(cobalt[0])
	return out


static func _draw_weighted(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		pool: Array, picks: Array, exclude: Array, offered: Dictionary, leans: bool, nudge: Dictionary,
		rare_mult: float, ops: Dictionary) -> void:
	var all: Dictionary = ops["all_rows"].call()
	var stacked_out_fn: Callable = ops["stacked_out"]
	var row_fn: Callable = ops["row"]
	var active_tier: int = ops["active_tier"].call()
	var tries := 0
	while picks.size() < count and not pool.is_empty() and tries < count * 8:
		tries += 1
		var rarity := pick_rarity_scaled(rng, rarities, rare_mult, active_tier)
		if leans:
			var slot := _lean_slot(rng, rarity, class_id, pool, offered, picks, exclude, nudge, ops)
			if slot != "":
				picks.append(slot)
				pool.erase(slot)
			continue
		if not listed_only() and rng.randf() < GENERATED_SHARE:
			var recipe := ItemGen.roll_id(rng, rarity)
			if not recipe in picks and not recipe in exclude and not stacked_out_fn.call(recipe, held):
				picks.append(recipe)
			continue
		var bucket: Array = pool.filter(func(key): return String(all.get(key, {}).get("rarity", "common")) == rarity)
		if bucket.is_empty():
			bucket = pool
		var chosen := weighted(rng, bucket, offered, {}, nudge, row_fn)
		picks.append(chosen)
		pool.erase(chosen)


static func _ensure_hitter(rng: RandomNumberGenerator, class_id: String, picks: Array, pool: Array,
		offered: Dictionary, leans: bool, bait: String, ops: Dictionary) -> void:
	var def_fn: Callable = ops["def"]
	var row_fn: Callable = ops["row"]
	if picks.size() < 2 or picks.any(func(key): return def_fn.call(key).hits_harder()):
		return
	var harder: Array = pool.filter(func(key): return def_fn.call(key).hits_harder())
	if leans:
		var kit: Array = harder.filter(func(key): return in_kit(class_id, key, row_fn))
		var still: Array = kit.filter(func(key): return bucket_of(key, row_fn) != "movement")
		var shelf: Array = _neutral_slot(class_id, harder, offered, row_fn)
		for side in [still, kit, shelf, _uncapped(class_id, harder, offered, row_fn)]:
			if not side.is_empty():
				harder = side
				break
	var at := picks.size() - 1
	if leans:
		var first := 1 if not picks.is_empty() and picks[0] == bait else 0
		var prefer_kit: bool = not (KITS[class_id] as Dictionary).has("weapon") and not harder.is_empty() and in_kit(class_id, harder[0], row_fn)
		var chosen := -1
		if prefer_kit:
			for i in range(picks.size() - 1, first - 1, -1):
				if in_kit(class_id, picks[i], row_fn) and bucket_of(picks[i], row_fn) != "movement":
					chosen = i
					break
		if chosen < 0:
			for i in range(picks.size() - 1, first - 1, -1):
				if not (in_kit(class_id, picks[i], row_fn) and bucket_of(picks[i], row_fn) == "movement"):
					chosen = i
					break
		if chosen >= 0:
			at = chosen
	if not harder.is_empty():
		picks[at] = harder[rng.randi_range(0, harder.size() - 1)]


static func roll(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array, offered: Dictionary, ops: Dictionary) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var maxed_fn: Callable = ops["maxed"]
	var pool: Array = offer_pool(class_id, rarities, ops).filter(func(key): return not key in exclude and not maxed_fn.call(key, held))
	var picks: Array = []
	var leans := KITS.has(class_id)
	var nudge := answer_nudge(class_id, pool, maker_nudge(held, pool, ops), ops)
	var bait_pick := bait(class_id, held, pool, offered, count, ops)
	if bait_pick != "" and rng.randf() < SYNERGY_BAIT:
		picks.append(bait_pick)
		pool.erase(bait_pick)
	_draw_weighted(rng, rarities, class_id, held, count, pool, picks, exclude, offered, leans, nudge, 1.0, ops)
	_ensure_hitter(rng, class_id, picks, pool, offered, leans, bait_pick, ops)
	if leans:
		keep_a_neutral(rng, class_id, picks, pool, offered, 1 if not picks.is_empty() and picks[0] == bait_pick else 0, ops)
	return swap_stacked_out(rng, class_id, held, picks, pool, offered, ops)


static func keep_a_neutral(rng: RandomNumberGenerator, class_id: String, picks: Array, pool: Array,
		offered: Dictionary, first: int, ops: Dictionary) -> void:
	var row_fn: Callable = ops["row"]
	var def_fn: Callable = ops["def"]
	var rarity_of_fn: Callable = ops["rarity_of"]
	if picks.size() < 2 or picks.any(func(key): return in_kit(class_id, key, row_fn) or key in NEUTRAL_SHELF):
		return
	var shelf := _neutral_slot(class_id, pool.filter(func(key): return not key in picks), offered, row_fn)
	if shelf.is_empty():
		return
	var hitters: Array = picks.filter(func(key): return def_fn.call(key).hits_harder())
	for i in range(first, picks.size()):
		if rarity_of_fn.call(picks[i]) != rarity_of_fn.call(shelf[0]):
			continue
		if picks.size() < 2 or hitters.size() != 1 or picks[i] != hitters[0]:
			picks[i] = shelf[rng.randi_range(0, shelf.size() - 1)]
			return


static func bait(class_id: String, held: Array, pool: Array, offered: Dictionary, count: int, ops: Dictionary) -> String:
	var maker_counts_fn: Callable = ops["maker_counts"]
	if not KITS.has(class_id):
		return completing_part(held, pool, maker_counts_fn)
	var row_fn: Callable = ops["row"]
	var open := _uncapped(class_id, pool, offered, row_fn)
	var near := completing_part(held, _near(class_id, open, row_fn), maker_counts_fn)
	return near if near != "" or count >= 2 else completing_part(held, open, maker_counts_fn)


static func _near(class_id: String, pool: Array, row_fn: Callable) -> Array:
	return pool.filter(func(key): return in_kit(class_id, key, row_fn) or key in NEUTRAL_SHELF)


static func maker_nudge(held: Array, pool: Array, ops: Dictionary) -> Dictionary:
	if not maker_nudge_on:
		return {}
	var pieces := {}
	var table: Dictionary = ops["all_rows"].call()
	for part_id in held:
		var maker := String(table.get(part_id, {}).get("maker", ""))
		if maker != "":
			if not pieces.has(maker):
				pieces[maker] = {}
			pieces[maker][part_id] = true
	var out := {}
	for part_id in pool:
		var maker := String(table.get(part_id, {}).get("maker", ""))
		if maker != "" and (pieces.get(maker, {}) as Dictionary).size() >= MAKER_NUDGE_AT and not part_id in held:
			out[part_id] = MAKER_NUDGE
	return out


static func answers_of(part_id: String) -> Array:
	return ANSWERS.get(part_id, [])


static func answer_nudge(class_id: String, pool: Array, nudge: Dictionary, _ops: Dictionary = {}) -> Dictionary:
	if not answer_nudge_on or Nemesis.of(class_id).is_empty():
		return nudge
	var answering: Dictionary = _answering(class_id)
	var out := nudge
	var copied := false
	for part_id in pool:
		if answering.has(part_id):
			if not copied:
				out = nudge.duplicate()
				copied = true
			out[part_id] = float(out.get(part_id, 1.0)) * Nemesis.OFFER_WEIGHT
	return out


static func nudged(raw: Dictionary, nudge: Dictionary, row_fn: Callable) -> Dictionary:
	if nudge.is_empty():
		return raw
	var touched := false
	for key in nudge:
		if raw.has(key):
			touched = true
			break
	if not touched:
		return raw
	var before := {}
	var after := {}
	var out := {}
	var buckets := {}
	for key in raw:
		var b := bucket_of(key, row_fn)
		buckets[key] = b
		out[key] = float(raw[key]) * float(nudge.get(key, 1.0))
		before[b] = float(before.get(b, 0.0)) + float(raw[key])
		after[b] = float(after.get(b, 0.0)) + out[key]
	for key in out:
		var b: String = buckets[key]
		if after[b] > 0.0:
			out[key] *= before[b] / after[b]
	return out


static func weighted(rng: RandomNumberGenerator, bucket: Array, offered: Dictionary, lean: Dictionary,
		nudge: Dictionary, row_fn: Callable) -> String:
	var raw := {}
	var total := 0.0
	for key in bucket:
		raw[key] = lean.get(key, 1.0) / (1.0 + offered.get(key, 0))
	raw = nudged(raw, nudge, row_fn)
	for key in bucket:
		total += raw[key]
	var x := rng.randf() * total
	for key in bucket:
		x -= raw[key]
		if x < 0.0:
			return key
	return bucket[-1]


static func holds_pattern(held: Array, def_fn: Callable) -> bool:
	return held.any(func(key): return def_fn.call(key) != null and not def_fn.call(key).patterns.is_empty())


static func dominant_archetype(held: Array, maker_of_fn: Callable) -> String:
	if held.is_empty():
		return ""
	var scores := {}
	var seen := {}
	for raw_id in held:
		var part_id := String(raw_id)
		if seen.has(part_id):
			continue
		seen[part_id] = true
		var gmut := PartMutations.grapple_mutation_id_of(part_id)
		var maker := String(maker_of_fn.call(part_id))
		for arch in ARCHETYPES:
			var spec: Dictionary = ARCHETYPES[arch]
			var pts := 0
			if part_id in (spec["anchors"] as Array):
				pts += 2
			elif gmut != "" and gmut in (spec["grapple_muts"] as Array):
				pts += 2
			elif Relics.is_relic(part_id) and maker in (spec["makers"] as Array):
				pts += 1
			if pts > 0:
				scores[arch] = int(scores.get(arch, 0)) + pts
	var best_arch := ""
	var best_score := 0
	for arch in ARCHETYPES:
		var sc := int(scores.get(arch, 0))
		if sc >= ARCHETYPE_NUDGE_AT * 2 and sc > best_score:
			best_score = sc
			best_arch = arch
	return best_arch


static func archetype_nudge(held: Array, pool: Array, ops: Dictionary) -> Dictionary:
	if not archetype_nudge_on:
		return {}
	var arch := dominant_archetype(held, ops["maker_of"])
	if arch == "":
		return {}
	var spec: Dictionary = ARCHETYPES[arch]
	var anchors: Array = spec["anchors"]
	var gmuts: Array = spec["grapple_muts"]
	var out := {}
	for part_id in pool:
		var pid := String(part_id)
		if pid in held:
			continue
		var gm := Items.grapple_mutation_of(pid)
		if pid in anchors or (gm != "" and gm in gmuts):
			out[pid] = ARCHETYPE_NUDGE
	return out


static func world_nudge(stage: int, pool: Array, ops: Dictionary) -> Dictionary:
	if stage < WORLD_ESCALATION_STAGE_W2:
		return {}
	var world := world_for_stage(stage)
	var table: Dictionary = ops["all_rows"].call()
	var def_fn: Callable = ops["def"]
	var out := {}
	for part_id in pool:
		var pid := String(part_id)
		var row_world := int(table.get(pid, {}).get("world", 0))
		if row_world == world:
			out[pid] = WORLD_SIGNATURE_NUDGE
		elif pid in WORLD_VERB_PARTS or changes_behaviour(pid, def_fn):
			out[pid] = WORLD_VERB_NUDGE
	return out


static func _merge_nudges(base: Dictionary, extra: Dictionary) -> Dictionary:
	if extra.is_empty():
		return base
	var out := base.duplicate()
	for key in extra:
		out[key] = float(out.get(key, 1.0)) * float(extra[key])
	return out


static func completing_archetype_part(held: Array, pool: Array, ops: Dictionary) -> String:
	var maker_counts_fn: Callable = ops["maker_counts"]
	var maker_of_fn: Callable = ops["maker_of"]
	var base := completing_part(held, pool, maker_counts_fn)
	if base != "":
		return base
	var evos := Synergies.all_evolutions()
	for evo_id in evos:
		if evo_id in held:
			continue
		var pair: Array = evos[evo_id]
		if pair.size() != 2:
			continue
		if pair[0] in held and not pair[1] in held and pair[1] in pool:
			return String(pair[1])
		if pair[1] in held and not pair[0] in held and pair[0] in pool:
			return String(pair[0])
	var counted: Dictionary = maker_counts_fn.call(held)
	for maker in MakerDefs.SETS:
		var need := int(MakerDefs.SETS[maker]["pieces"])
		if int(counted.get(maker, 0)) == need - 1:
			for key in pool:
				if not key in held and String(maker_of_fn.call(String(key))) == maker:
					return String(key)
	return ""


static func roll_for_stage(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage: int, exclude: Array, offered: Dictionary, high_impact: bool, ops: Dictionary) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var maxed_fn: Callable = ops["maxed"]
	var stacked_out_fn: Callable = ops["stacked_out"]
	var def_fn: Callable = ops["def"]
	var row_fn: Callable = ops["row"]
	var full_pool: Array = offer_pool(class_id, rarities, ops).filter(func(key): return not key in exclude and not maxed_fn.call(key, held) and not stacked_out_fn.call(key, held))
	if full_pool.is_empty():
		return []
	var pool := full_pool
	if high_impact:
		var impact_pool: Array = full_pool.filter(func(key): return is_high_impact(key, def_fn))
		if impact_pool.size() >= count:
			pool = impact_pool
		elif not impact_pool.is_empty():
			pool = impact_pool
	var picks: Array = []
	var leans := KITS.has(class_id)
	var nudge := maker_nudge(held, pool, ops)
	nudge = _merge_nudges(nudge, archetype_nudge(held, pool, ops))
	nudge = _merge_nudges(nudge, world_nudge(stage, pool, ops))
	nudge = answer_nudge(class_id, pool, nudge, ops)
	var bait_pool := _near(class_id, _uncapped(class_id, pool, offered, row_fn), row_fn) if leans else pool
	var bait := completing_archetype_part(held, bait_pool, ops)
	if bait == "" and not bait_pool.is_empty():
		bait = completing_archetype_part(held, pool, ops)
	var bait_chance := HIGH_IMPACT_SYNERGY_BAIT if high_impact else SYNERGY_BAIT
	if bait != "" and rng.randf() < bait_chance:
		picks.append(bait)
		pool.erase(bait)
	var rare_mult := stage_rare_mult(stage)
	_draw_weighted(rng, rarities, class_id, held, count, pool, picks, exclude, offered, leans, nudge, rare_mult, ops)
	if picks.size() < count and pool != full_pool:
		var rest: Array = full_pool.filter(func(key): return not key in picks)
		for extra in roll(rng, rarities, class_id, held, count - picks.size(), exclude + picks, offered, ops):
			if not extra in picks:
				picks.append(extra)
		if picks.size() < count and not rest.is_empty():
			for key in rest:
				if picks.size() >= count:
					break
				if not key in picks:
					picks.append(key)
	_ensure_hitter(rng, class_id, picks, pool, offered, leans, bait, ops)
	if leans and not high_impact:
		keep_a_neutral(rng, class_id, picks, pool, offered, 1 if not picks.is_empty() and picks[0] == bait else 0, ops)
	return swap_stacked_out(rng, class_id, held, picks, full_pool, offered, ops)


static func roll_high_impact(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array, offered: Dictionary, stage: int, allow_pilot_relic: bool, tree, ops: Dictionary) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var picks: Array = []
	var slice_locked: bool = listed_only() and not Synergies.table.part_in_play("slag_pike")
	if allow_pilot_relic and not slice_locked and "relic" in rarities and count >= 1 and class_id in Relics.pilots():
		var world := world_for_stage(stage)
		var relic_pool := Relics.eligible_swaps(class_id, Relics.held(held), tree, world, stage >= WORLD_ESCALATION_STAGE_W2)
		if relic_pool.is_empty():
			relic_pool = Relics.eligible(class_id, Relics.held(held), tree, world, true)
		relic_pool = relic_pool.filter(func(id): return not Relics.part_of(id) in exclude)
		if not relic_pool.is_empty():
			var has_other := not offer_pool(class_id, rarities.filter(func(r): return r != "relic"), ops).is_empty()
			var relic_chance := 0.45 if has_other else 1.0
			if rng.randf() < relic_chance:
				var chosen_relic := String(relic_pool[rng.randi_range(0, relic_pool.size() - 1)])
				picks.append(Relics.part_of(chosen_relic))
	var need := count - picks.size()
	if need > 0:
		var rolled := roll_for_stage(rng, rarities, class_id, held, need, stage, exclude + picks, offered, true, ops)
		picks.append_array(rolled)
	return picks


static func roll_gate(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage: int, offered: Dictionary, ops: Dictionary) -> Array:
	var def_fn: Callable = ops["def"]
	var row_fn: Callable = ops["row"]
	rarities = ItemGen.resolve_rarities(rarities)
	var picks: Array = roll(rng, rarities, class_id, held, count, [], offered, ops)
	if stage != PATTERN_GUARANTEE_STAGE or count < 1 or holds_pattern(held, def_fn) \
			or picks.any(func(key): return key in PATTERN_PARTS):
		return picks
	var eligible: Array = PATTERN_PARTS.filter(func(key): return def_fn.call(key).rarity in rarities)
	if eligible.is_empty():
		eligible = PATTERN_PARTS.duplicate()
	if KITS.has(class_id):
		var own: Array = eligible.filter(func(key): return in_kit(class_id, key, row_fn))
		eligible = own if not own.is_empty() else eligible
	var pattern: String = eligible[rng.randi_range(0, eligible.size() - 1)]
	if picks.size() < count:
		picks.append(pattern)
	elif picks.size() >= 2 or picks[0] != bait(class_id, held, offer_pool(class_id, rarities, ops), offered, count, ops):
		picks[picks.size() - 1] = pattern
	return picks
