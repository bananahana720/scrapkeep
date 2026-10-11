extends SceneTree

const PartDef := preload("res://src/build/part_def.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Synergies := preload("res://src/build/synergies.gd")

# The build sweep (SR4, W13-INTEGRATION-3.md; comps/ror2/items-and-stacking.md:96 and
# comps/isaac/items-and-synergies.md:89). A tool with two arms, headless and pure: no
# game scene, no physics, only the build data and the same Parts.roll the gates use.
#
#   godot --headless --path sketches/core-loop --script res://tools/build_sweep.gd -- --arm=stack
#   godot --headless --path sketches/core-loop --script res://tools/build_sweep.gd -- --arm=compose [--seed=1] [--builds=10000]
#
# stack    every pool row whose effect or charges stack under its rule, plus one
#          synthetic probe per family the pool does not use yet (the spike family has
#          no row today), at 1 to 20 copies: the stat, its step, and time to kill a
#          fixed dummy. Mods-only rows go through BuildSheet.from_parts, the real fold,
#          and are reported (their copies multiply, so the report names any that pass
#          the spike ceiling), not gated here.
# compose  COMPOSE_BUILDS random 6-part builds drawn through Parts.roll, one 2-part offer
#          per pick, one class per build in turn: the share of builds reaching 3 or more
#          distinct tags, tag pairs with no specified outcome, and parts an offer repeats.
#
# Exit 0 when the arm printed nonzero rows and found no problem, else 1. Evidence limit:
# a numbers model; time to kill reads the stat as a damage bonus on a fixed dummy, not
# combat's truth, and nothing here says whether a build feels good.

const MAX_COPIES := 20
const COPIES_SHOWN := [1, 2, 3, 5, 10, 20]
# The dummy for time to kill (a report model, not combat's numbers).
const DUMMY_HP := 1000.0
const DUMMY_DPS := 100.0
const DEFAULT_SEED := 1
const COMPOSE_BUILDS := 10000
const BUILD_SIZE := 6
const OFFER_SIZE := 2
# The comps targets (comps/isaac/items-and-synergies.md:89): at least 30% of builds reach
# 3 or more tags; an offer repeats a part at most once per 10,000 draws.
const TAG3_TARGET := 0.30
const REPEAT_TARGET_PER_10K := 1.0
const EPS := 1e-6
# Families the pool may not use yet get one synthetic probe each, so every family runs.
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
	else:
		print("build_sweep: unknown --arm=%s (stack or compose)" % arm)
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


# One row per stacking number: {id, family, key, per, cap, values, steps, ttk, real}.
# real is false for a synthetic probe.
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


# A mods-only row: copies fold through the real sheet, so the reported value is the
# largest mod product and time to kill reads the sheet's own output estimate.
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


# The copy count at which a ceiling or spike row stops rising, or 0 if it rises to 20.
static func flat_from(row: Dictionary) -> int:
	var values: Array = row["values"]
	for i in range(1, values.size()):
		if absf(float(values[i]) - float(values[i - 1])) <= EPS:
			return i
	return 0


# The gated rules per family; [] is clean. Fold rows are reported, not gated, except
# for finite numbers.
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


# The outcome a tag pair resolves to: "named:<id>", "rule:<id>", "independent" (two
# known tags with no row: each part acts alone, the documented default in
# synergies.gd's header), or "" when a tag is outside PartDef.TAGS and nothing can say.
static func pair_outcome(a: String, b: String) -> String:
	if not a in PartDef.TAGS or not b in PartDef.TAGS:
		return ""
	for key in Synergies.ROWS:
		var tags: Array = Synergies.ROWS[key]["tags"]
		if (tags[0] == a and tags[1] == b) or (tags[0] == b and tags[1] == a):
			return "named:" + key
	for key in Synergies.TAG_RULES:
		var tags: Array = Synergies.TAG_RULES[key]["tags"]
		if (tags[0] == a and tags[1] == b) or (tags[0] == b and tags[1] == a):
			return "rule:" + key
	return "independent"


# Tag pairs across two different held parts whose outcome is unspecified.
static func unspecified_pairs(tag_sets: Array) -> int:
	var count := 0
	for i in tag_sets.size():
		for j in range(i + 1, tag_sets.size()):
			for a in tag_sets[i]:
				for b in tag_sets[j]:
					if pair_outcome(String(a), String(b)) == "":
						count += 1
	return count


# Parts an offer shows more than once.
static func offer_repeats(offer: Array) -> int:
	var seen := {}
	var repeats := 0
	for key in offer:
		if seen.has(key):
			repeats += 1
		seen[key] = true
	return repeats


static func compose_arm(run_seed: int, builds: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var classes := [Items.SABLE, Items.RIVET, Items.KEST]
	var draws := 0
	var tag3 := 0
	var unspecified := 0
	var repeats := 0
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
	if stats["repeats_per_10k"] > REPEAT_TARGET_PER_10K:
		out.append("%.2f offer repeats per 10,000 draws" % stats["repeats_per_10k"])
	return out


static func print_compose_table(stats: Dictionary) -> void:
	print("build_sweep compose | seed %d | builds %d | draws %d | 3+ tags %.1f%% (target %d%%) | distinct tag sets %d | unspecified pairs %d | offer repeats %d (%.2f per 10,000 draws) | picks of a part already held %d | empty offers %d | pair outcomes %s"
		% [stats["seed"], stats["builds"], stats["draws"], 100.0 * stats["tag3_share"], int(TAG3_TARGET * 100),
			stats["distinct_tag_sets"], stats["unspecified_pairs"], stats["offer_repeats"], stats["repeats_per_10k"],
			stats["held_copies"], stats["empty_offers"], stats["outcomes"]])
