extends SceneTree

const PartDef := preload("res://src/build/part_def.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Synergies := preload("res://src/build/synergies.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")


const MAX_COPIES := 20
const COPIES_SHOWN := [1, 2, 3, 5, 10, 20]
const DUMMY_HP := 1000.0
const DUMMY_DPS := 100.0
const DEFAULT_SEED := 1
const COMPOSE_BUILDS := 10000
const BUILD_SIZE := 6
const OFFER_SIZE := 2
const SLOT_WORLDS := [1, 2, 3]
const SLOT_RARITIES := ["common", "rare", "relic"]
const SLOT_MARGIN_MIN := 0.0
const SLOT_MARGIN_MAX := 0.40
const SLOT_RATIO_MAX := 6.0
const TAG3_TARGET := 0.30
const REPEAT_TARGET_PER_10K := 1.0
const EPS := 1e-6
const INDEPENDENT_PAIRS := [
	["frost", "frost"], ["frost", "kinetic"], ["frost", "split"], ["frost", "spiral"],
	["frost", "chain"], ["frost", "anchor"], ["frost", "speed"],
	["arc", "arc"], ["arc", "kinetic"], ["arc", "split"], ["arc", "spiral"],
	["arc", "chain"], ["arc", "speed"],
	["kinetic", "kinetic"], ["kinetic", "spiral"], ["kinetic", "chain"],
	["kinetic", "anchor"], ["kinetic", "mass"],
	["split", "split"], ["split", "spiral"], ["split", "anchor"],
	["split", "speed"], ["split", "mass"],
	["spiral", "spiral"], ["spiral", "anchor"], ["spiral", "mass"],
	["chain", "chain"], ["chain", "anchor"], ["chain", "speed"], ["chain", "mass"],
	["anchor", "anchor"], ["anchor", "speed"], ["anchor", "mass"],
	["speed", "speed"], ["speed", "mass"], ["mass", "mass"],
]
const PROBES := {
	"probe_linear": {"stack": "linear", "cap": 0.0, "per": 0.1},
	"probe_hyperbolic": {"stack": "hyperbolic", "cap": 0.5, "per": 0.1},
	"probe_capped": {"stack": "capped", "cap": 3.0, "per": 0.1},
	"probe_spike": {"stack": "spike", "cap": 8.0, "per": 0.1},
}


func _initialize() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var arm: String = args.get("arm", "stack")
	var ok := false
	if arm == "stack":
		var rows := stack_arm()
		print_stack_table(rows)
		var bad: Array = []
		for row in rows:
			bad.append_array(row_problems(row))
		bad.append_array(PartDef.spike_problems(_pool_defs()))
		for line in bad:
			print("build_sweep problem: %s" % line)
		ok = rows.size() > 0 and bad.is_empty()
		print("build_sweep stack: %d rows, %d problems" % [rows.size(), bad.size()])
	elif arm == "compose":
		var stats := compose_arm(int(args.get("seed", str(DEFAULT_SEED))), int(args.get("builds", str(COMPOSE_BUILDS))))
		print_compose_table(stats)
		ok = stats["builds"] > 0 and compose_problems(stats).is_empty()
		print("build_sweep compose: %d builds, %d problems" % [stats["builds"], compose_problems(stats).size()])
	elif arm == "slot_growth":
		var srows := slot_growth_arm()
		print_slot_table(srows)
		var nul := slot_growth_null(UpgradeTree.DEPTHS)
		print("slot_growth null | row %s | partner %s | paired dps %.1f | partner missing dps %.1f | margin %.1f%%"
			% [nul["row"], nul["partner"], nul["paired_dps"], nul["unpaired_dps"], 100.0 * float(nul["margin"])])
		var sbad := slot_growth_problems(srows)
		for line in sbad:
			print("build_sweep problem: %s" % line)
		ok = srows.size() > 0 and sbad.is_empty()
		print("build_sweep slot_growth: %d rows, %d problems" % [srows.size(), sbad.size()])
	else:
		print("build_sweep: unknown --arm=%s (stack, compose or slot_growth)" % arm)
	quit(0 if ok else 1)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


static func _pool_defs() -> Array:
	var out: Array = []
	for part_id in Parts.ids():
		out.append(Parts.def(part_id))
	return out


static func stack_arm() -> Array:
	var rows: Array = []
	var seen := {}
	for part_id in Parts.ids():
		var d: Resource = Parts.def(part_id)
		var key := ItemEffects.stack_key(String(d.effect.get("do", "")))
		if key != "" and typeof(d.effect.get(key)) in [TYPE_FLOAT, TYPE_INT]:
			rows.append(_curve_row(part_id, d.stack_rule, key, float(d.effect[key]), d.stack_cap, true))
			seen[d.stack_rule] = true
		for slot in d.charges:
			rows.append(_curve_row(part_id, d.stack_rule, "charges." + slot, float(d.charges[slot]), d.stack_cap, true))
			seen[d.stack_rule] = true
		if key == "" and d.charges.is_empty() and not d.mods.is_empty():
			rows.append(_fold_row(part_id, d))
	for probe in PROBES:
		var spec: Dictionary = PROBES[probe]
		if not seen.has(spec["stack"]):
			rows.append(_curve_row(probe, spec["stack"], "per", spec["per"], spec["cap"], false))
	return rows


static func _curve_row(id: String, rule: String, key: String, per: float, cap: float, real: bool) -> Dictionary:
	var values: Array = []
	var ttk: Array = []
	for n in range(1, MAX_COPIES + 1):
		var v := PartDef.Stacking.value(rule, per, n, cap)
		values.append(v)
		ttk.append(DUMMY_HP / (DUMMY_DPS * (1.0 + maxf(v, 0.0))))
	return {"id": id, "family": rule, "key": key, "per": per, "cap": cap, "values": values, "ttk": ttk,
		"real": real, "model": "curve"}


static func _fold_row(id: String, d: Resource) -> Dictionary:
	var values: Array = []
	var ttk: Array = []
	var held: Array = []
	var base_power: float = BuildSheet.from_parts([]).power()
	for n in range(1, MAX_COPIES + 1):
		held.append(id)
		var sheet: RefCounted = BuildSheet.from_parts(held)
		var top := 1.0
		for knob in sheet.mods:
			top = maxf(top, float(sheet.mods[knob]))
		values.append(top)
		ttk.append(DUMMY_HP / (DUMMY_DPS * maxf(sheet.power() / base_power, EPS)))
	return {"id": id, "family": d.stack_rule, "key": "mods", "per": values[0], "cap": d.stack_cap,
		"values": values, "ttk": ttk, "real": true, "model": "fold"}


static func flat_from(row: Dictionary) -> int:
	var values: Array = row["values"]
	for i in range(1, values.size()):
		if absf(float(values[i]) - float(values[i - 1])) <= EPS:
			return i
	return 0


static func row_problems(row: Dictionary) -> Array:
	var out: Array = []
	var values: Array = row["values"]
	for v in values + row["ttk"]:
		if not is_finite(float(v)):
			return ["%s non-finite" % row["id"]]
	if row.get("model", "curve") == "fold":
		return out
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]) - EPS:
			out.append("%s falls at %d copies" % [row["id"], i + 1])
			break
	var family: String = row["family"]
	if family == "hyperbolic":
		var cap: float = row["cap"] if row["cap"] > 0.0 else 1.0
		if float(values[-1]) > cap + EPS:
			out.append("%s at %d copies %s over its cap %s" % [row["id"], values.size(), values[-1], cap])
		for i in range(2, values.size()):
			var step := float(values[i]) - float(values[i - 1])
			var before := float(values[i - 1]) - float(values[i - 2])
			if step > before + EPS:
				out.append("%s step grows at %d copies" % [row["id"], i + 1])
				break
	elif family == "spike":
		var ceiling := absf(float(row["per"])) * PartDef.SPIKE_MAX_MULTIPLE
		for v in values:
			if absf(float(v)) > ceiling + EPS:
				out.append("%s spike %s past %sx one copy" % [row["id"], v, PartDef.SPIKE_MAX_MULTIPLE])
				break
	elif family == "capped":
		var copies := int(row["cap"])
		if copies >= 1 and copies < values.size():
			for i in range(copies, values.size()):
				if absf(float(values[i]) - float(values[copies - 1])) > EPS:
					out.append("%s adds past its %d-copy cap" % [row["id"], copies])
					break
	return out


static func print_stack_table(rows: Array) -> void:
	var head := "build_sweep stack | id | family | key | per | cap"
	for n in COPIES_SHOWN:
		head += " | v%d" % n
	head += " | ttk1 s | ttk20 s | flat from | model"
	print(head)
	for row in rows:
		var line := "build_sweep stack | %s%s | %s | %s | %.4f | %.4f" % [row["id"], "" if row["real"] else " (probe)",
			row["family"], row["key"], row["per"], row["cap"]]
		for n in COPIES_SHOWN:
			line += " | %.4f" % float(row["values"][n - 1])
		line += " | %.2f | %.2f | %d | %s" % [row["ttk"][0], row["ttk"][-1], flat_from(row), row["model"]]
		if row["model"] == "fold" and float(row["values"][-1]) > PartDef.SPIKE_MAX_MULTIPLE:
			line += " | report: copies multiply past %sx" % PartDef.SPIKE_MAX_MULTIPLE
		print(line)


static func pair_outcome(a: String, b: String, independent_pairs: Array = INDEPENDENT_PAIRS) -> String:
	if not a in PartDef.TAGS or not b in PartDef.TAGS:
		return ""
	for key in Synergies.ROWS:
		var tags: Array = Synergies.ROWS[key]["tags"]
		if tags.size() < 2 or Synergies.told_on_wake(key):
			continue
		if (tags[0] == a and tags[1] == b) or (tags[0] == b and tags[1] == a):
			return "named:" + key
	for tags in independent_pairs:
		if (tags[0] == a and tags[1] == b) or (tags[0] == b and tags[1] == a):
			return "independent"
	return ""


static func unspecified_pairs(tag_sets: Array, independent_pairs: Array = INDEPENDENT_PAIRS) -> int:
	var count := 0
	for i in tag_sets.size():
		for j in range(i + 1, tag_sets.size()):
			for a in tag_sets[i]:
				for b in tag_sets[j]:
					if pair_outcome(String(a), String(b), independent_pairs) == "":
						count += 1
	return count


static func offer_repeats(offer: Array) -> int:
	var seen := {}
	var repeats := 0
	for key in offer:
		if seen.has(key):
			repeats += 1
		seen[key] = true
	return repeats


static func run_repeats(offered: Dictionary, offer: Array) -> int:
	var count := 0
	for key in offer:
		if offered.has(key):
			count += 1
	return count


static func compose_arm(run_seed: int, builds: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var classes := [Items.SABLE, Items.RIVET, Items.KEST]
	var draws := 0
	var tag3 := 0
	var unspecified := 0
	var repeats := 0
	var within_run := 0
	var held_copies := 0
	var empty_offers := 0
	var outcomes := {"named": 0, "rule": 0, "independent": 0}
	var tag_set_keys := {}
	var picks_hash := 0
	for b in builds:
		var class_id: String = classes[b % classes.size()]
		var held: Array = []
		var offered := {}
		for pick in BUILD_SIZE:
			var rarities: Array = Parts.gate_rarities(rng.randi_range(0, 2))
			var offer: Array = Parts.roll(rng, rarities, class_id, held, OFFER_SIZE, [], offered)
			draws += offer.size()
			repeats += offer_repeats(offer)
			within_run += run_repeats(offered, offer)
			if offer.is_empty():
				empty_offers += 1
				continue
			for key in offer:
				offered[key] = offered.get(key, 0) + 1
			var chosen: String = offer[rng.randi_range(0, offer.size() - 1)]
			if chosen in held:
				held_copies += 1
			held.append(chosen)
		picks_hash = hash([picks_hash, held])
		var sets: Array = Parts.tag_sets(held)
		var tags := {}
		for s in sets:
			for t in s:
				tags[t] = true
		if tags.size() >= 3:
			tag3 += 1
		var sorted_tags: Array = tags.keys()
		sorted_tags.sort()
		tag_set_keys[",".join(sorted_tags)] = true
		unspecified += unspecified_pairs(sets)
		for i in sets.size():
			for j in range(i + 1, sets.size()):
				for a in sets[i]:
					for t in sets[j]:
						var outcome := pair_outcome(String(a), String(t))
						if outcome != "":
							var kind := outcome.get_slice(":", 0)
							outcomes[kind] = outcomes.get(kind, 0) + 1
	return {
		"seed": run_seed, "builds": builds, "draws": draws,
		"tag3_share": float(tag3) / maxf(builds, 1),
		"distinct_tag_sets": tag_set_keys.size(),
		"unspecified_pairs": unspecified,
		"offer_repeats": repeats,
		"repeats_per_10k": 10000.0 * repeats / maxf(draws, 1),
		"run_repeats": within_run,
		"run_repeats_per_10k": 10000.0 * within_run / maxf(draws, 1),
		"held_copies": held_copies,
		"empty_offers": empty_offers,
		"outcomes": outcomes,
		"picks_hash": picks_hash,
	}


static func compose_problems(stats: Dictionary) -> Array:
	var out: Array = []
	if stats["tag3_share"] < TAG3_TARGET:
		out.append("%.1f%% of builds reach 3+ tags, under %d%%" % [100.0 * stats["tag3_share"], int(TAG3_TARGET * 100)])
	if stats["unspecified_pairs"] > 0:
		out.append("%d unspecified tag pairs" % stats["unspecified_pairs"])
	if stats["offer_repeats"] > 0:
		out.append("%d parts shown twice in one offer" % stats["offer_repeats"])
	return out


static func print_compose_table(stats: Dictionary) -> void:
	print("build_sweep compose | seed %d | builds %d | draws %d | 3+ tags %.1f%% (target %d%%) | distinct tag sets %d | unspecified pairs %d | offer repeats %d (%.2f per 10,000 draws) | within-run repeats %d (%.2f per 10,000 draws, target %.0f, %s, %s) | picks of a part already held %d | empty offers %d | pair outcomes %s"
		% [stats["seed"], stats["builds"], stats["draws"], 100.0 * stats["tag3_share"], int(TAG3_TARGET * 100),
			stats["distinct_tag_sets"], stats["unspecified_pairs"], stats["offer_repeats"], stats["repeats_per_10k"],
			stats["run_repeats"], stats["run_repeats_per_10k"], REPEAT_TARGET_PER_10K,
			"over target" if stats["run_repeats_per_10k"] > REPEAT_TARGET_PER_10K else "within target",
			"report-only by ruling",
			stats["held_copies"], stats["empty_offers"], stats["outcomes"]])


static func slot_growth_arm() -> Array:
	var pool := _legal_pool()
	var seeds := _pair_seeds(pool)
	var named := _named_pair_count(seeds)
	var rows: Array = []
	for world in SLOT_WORLDS:
		var slots: int = UpgradeTree.depth_cap(world)
		var best_paired := 0.0
		var paired_set: Array = []
		var pair_row := ""
		for seed_info in seeds:
			var found := _greedy(seed_info["seed"], pool, slots, false)
			var value := _power(found)
			if value > best_paired:
				best_paired = value
				paired_set = found
				pair_row = seed_info["row"]
		var unpaired_set := _partner_missing(paired_set, pair_row, pool, slots)
		var best_unpaired := _power(unpaired_set)
		var any_set := _greedy([], pool, slots, true)
		var any_power := _power(any_set)
		var pair_available := not seeds.is_empty() and slots >= 2
		var margin := -1.0
		if pair_available:
			margin = best_paired / maxf(best_unpaired, EPS) - 1.0
		rows.append({"world": world, "slots": slots, "pair_available": pair_available, "pair_row": pair_row,
			"named_pairs": named, "best_paired": best_paired, "best_unpaired": best_unpaired,
			"unpaired_any": any_power, "paired_set": paired_set, "unpaired_set": unpaired_set,
			"margin": margin, "best": maxf(best_paired, maxf(best_unpaired, any_power))})
	return rows


static func slot_growth_null(slots: int) -> Dictionary:
	var pool := _legal_pool()
	for key in Synergies.ROWS:
		var maker: String = Synergies.ROWS[key]["maker"]
		var call := Synergies.callout(key)
		var shown: String = call.get("a", "")
		if not shown in pool:
			continue
		for partner in pool:
			if partner == shown or Parts.maker_of(partner) != maker:
				continue
			if absf(_power([shown, partner]) - _power([shown])) > EPS:
				continue
			var paired := _greedy([shown, partner], pool, slots, false)
			var ablated := _partner_missing(paired, key, pool, slots)
			return {"row": key, "partner": partner, "paired_dps": DUMMY_DPS * _power(paired),
				"unpaired_dps": DUMMY_DPS * _power(ablated),
				"margin": _power(paired) / maxf(_power(ablated), EPS) - 1.0}
	return {"row": "", "partner": "", "paired_dps": 0.0, "unpaired_dps": 0.0, "margin": -1.0}


static func _partner_missing(paired: Array, row_key: String, pool: Array, slots: int) -> Array:
	if row_key == "" or paired.is_empty():
		return _greedy([], pool, slots, true)
	var maker: String = Synergies.ROWS[row_key]["maker"]
	var kept: Array = []
	for i in paired.size():
		if i == 0 or Parts.maker_of(paired[i]) != maker:
			kept.append(paired[i])
	return _substitute(kept, pool, paired.size(), row_key)


static func _substitute(seed: Array, pool: Array, size: int, row_key: String) -> Array:
	var held: Array = seed.duplicate()
	while held.size() < size:
		var pick := ""
		var best := -1.0
		for part_id in pool:
			if part_id in held:
				continue
			var cand: Array = held + [part_id]
			if row_key in Synergies.active(Parts.maker_counts(cand)):
				continue
			var value := _power(cand)
			if value > best + EPS:
				best = value
				pick = part_id
		if pick == "":
			break
		held.append(pick)
	return held


static func _legal_pool() -> Array:
	var milestone: Array = Parts.milestone_ids()
	var pool: Array = []
	for part_id in Parts.offer_pool("", SLOT_RARITIES):
		if not part_id in milestone:
			pool.append(part_id)
	pool.sort()
	return pool


static func _pair_seeds(pool: Array) -> Array:
	var seeds: Array = []
	for key in Synergies.ROWS:
		var maker: String = Synergies.ROWS[key]["maker"]
		var shown: String = Synergies.callout(key).get("a", "")
		if not shown in pool:
			continue
		for partner in pool:
			if partner != shown and Parts.maker_of(partner) == maker:
				seeds.append({"row": key, "seed": [shown, partner]})
	return seeds


static func _named_pair_count(seeds: Array) -> int:
	var rows := {}
	for seed_info in seeds:
		rows[seed_info["row"]] = true
	return rows.size()


static func _greedy(seed: Array, pool: Array, slots: int, unpaired: bool) -> Array:
	var held: Array = seed.duplicate()
	while held.size() < slots:
		var pick := ""
		var best := _power(held)
		for part_id in pool:
			if part_id in held:
				continue
			var cand: Array = held + [part_id]
			if unpaired and not Synergies.active(Parts.maker_counts(cand)).is_empty():
				continue
			var value := _power(cand)
			if value > best + EPS:
				best = value
				pick = part_id
		if pick == "":
			break
		held.append(pick)
	return held


static func _power(held: Array) -> float:
	return BuildSheet.from_parts(held).power()


static func slot_growth_problems(rows: Array) -> Array:
	var out: Array = []
	if rows.is_empty():
		return ["no slot growth rows"]
	for i in range(1, rows.size()):
		if int(rows[i]["slots"]) < int(rows[i - 1]["slots"]):
			out.append("slots fall at world %d (%d after %d)"
				% [int(rows[i]["world"]), int(rows[i]["slots"]), int(rows[i - 1]["slots"])])
	var last_slots := int(rows[-1]["slots"])
	if last_slots != UpgradeTree.DEPTHS:
		out.append("last milestone has %d slots, declared maximum %d" % [last_slots, UpgradeTree.DEPTHS])
	for row in rows:
		if not row["pair_available"]:
			continue
		var m := float(row["margin"])
		if m < SLOT_MARGIN_MIN - EPS or m > SLOT_MARGIN_MAX + EPS:
			out.append("world %d paired margin %.1f%% outside %d%% to %d%%"
				% [int(row["world"]), 100.0 * m, int(100.0 * SLOT_MARGIN_MIN), int(100.0 * SLOT_MARGIN_MAX)])
	if rows.size() >= 2:
		var ratio := float(rows[-1]["best"]) / maxf(float(rows[0]["best"]), EPS)
		if ratio > SLOT_RATIO_MAX + EPS:
			out.append("last best %.2fx the first milestone's, over %sx" % [ratio, SLOT_RATIO_MAX])
	return out


static func print_slot_table(rows: Array) -> void:
	print("slot_growth | world | slots | pair | paired dps | unpaired dps (partner missing) | margin (band %d%% to %d%%) | pair row | any-legal dps (report only) | best dps"
		% [int(100.0 * SLOT_MARGIN_MIN), int(100.0 * SLOT_MARGIN_MAX)])
	for row in rows:
		var margin := "n/a" if not row["pair_available"] else "%.1f%%" % (100.0 * float(row["margin"]))
		print("slot_growth | world %d | slots %d | %s | %.1f | %.1f | %s | %s | %.1f | %.1f" % [int(row["world"]),
			int(row["slots"]), "yes" if row["pair_available"] else "no", DUMMY_DPS * float(row["best_paired"]),
			DUMMY_DPS * float(row["best_unpaired"]), margin, row["pair_row"],
			DUMMY_DPS * float(row["unpaired_any"]), DUMMY_DPS * float(row["best"])])
