# smoke: solo timeout=300s (the composition arm rolls 10,000 builds: about 150 s on an idle box)
extends SceneTree

const PartDef := preload("res://src/build/part_def.gd")
const Parts := preload("res://src/build/parts.gd")
const BuildSweep := preload("res://tools/build_sweep.gd")

# SR4 stack sweep (W13-INTEGRATION-3.md, SR4; comps/ror2/items-and-stacking.md:96,
# comps/isaac/items-and-synergies.md:89). Every stacking family stays readable across
# 1 to 20 copies, and the spike family is capped: the big jump, never past
# PartDef.SPIKE_MAX_MULTIPLE times one copy, and at most one spike part per tier.
#
# (a) every ceiling (hyperbolic) row at stack 20 sits at or under its cap, never falls,
#     and its steps never grow; rows that reach the hard clamp before 20 are printed.
# (b) the spike curve, including planted uncapped and over-cap rows, never passes 8x
#     one copy; the live pool holds at most one spike per tier, and a planted pool with
#     two tier-3 spikes or a spike capped at 20x is refused.
# (c) the composition arm: 10,000 random 6-part builds drawn through Parts.roll reach 3
#     or more tags in at least 30% of builds, leave zero unspecified tag pairs, and no
#     single offer shows a part twice; the same seed gives the same numbers. The comps
#     measure, a part repeating within a run, is printed against its target of 1 per
#     10,000 draws and is report-only by ruling. Its counter has a planted control;
#     a known tag pair removed from the independent table must become unspecified.
# Time to kill is printed per stack row (report now; the numbers gate nothing yet).

const EPS := 1e-6
# A runtime script error aborts a check function without failing the run, so every
# check must report: fewer than this many verdicts is itself a failure.
const EXPECTED_REPORTS := 10

var _failures := 0
var _reports := 0


func _initialize() -> void:
	_check_family_vocabulary()
	_check_spike_curve()
	_check_spike_pool_rule()
	_check_stack_arm()
	_check_independent_pairs()
	_check_compose_arm()
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("stack_sweep_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	_reports += 1
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _check_family_vocabulary() -> void:
	_report("spike family declared", "spike" in PartDef.STACK_RULES and PartDef.STACK_RULES.size() == 4
		and is_equal_approx(PartDef.SPIKE_MAX_MULTIPLE, 8.0),
		"rules %s, spike ceiling %sx" % [PartDef.STACK_RULES, PartDef.SPIKE_MAX_MULTIPLE])


func _check_spike_curve() -> void:
	var bad: Array = []
	var per := 0.1
	for cap in [0.0, 3.0, 8.0, 20.0, 1000.0]:
		var last := 0.0
		for n in range(1, 21):
			var v := PartDef.Stacking.value("spike", per, n, cap)
			if not is_finite(v) or v > per * PartDef.SPIKE_MAX_MULTIPLE + EPS or v < last - EPS:
				bad.append("cap %s n %d -> %s" % [cap, n, v])
			last = v
	var one := PartDef.Stacking.value("spike", per, 1, 0.0)
	var two := PartDef.Stacking.value("spike", per, 2, 0.0)
	var top := PartDef.Stacking.value("spike", per, 20, 1000.0)
	var none := PartDef.Stacking.value("spike", per, 0, 8.0)
	_report("spike curve capped", bad.is_empty() and is_equal_approx(one, per) and two > 2.0 * per
		and is_equal_approx(top, per * PartDef.SPIKE_MAX_MULTIPLE) and none == 0.0,
		"one copy %s, two %s (a jump past 2x), 20 copies at a planted 1000x cap %s, problems %s" % [one, two, top, bad])


func _check_spike_pool_rule() -> void:
	var live: Array = []
	for part_id in Parts.ids():
		live.append(Parts.def(part_id))
	var live_problems: Array = PartDef.spike_problems(live)
	var planted_tier: Array = PartDef.spike_problems([
		PartDef.from_row("spike_a", {"stack": "spike", "cap": 8.0, "tier": 3}),
		PartDef.from_row("spike_b", {"stack": "spike", "cap": 4.0, "tier": 3}),
		PartDef.from_row("spike_c", {"stack": "spike", "cap": 8.0, "tier": 2})])
	var planted_cap: Array = PartDef.spike_problems([PartDef.from_row("spike_d", {"stack": "spike", "cap": 20.0, "tier": 1})])
	_report("one spike per tier, capped at 8x", live_problems.is_empty() and planted_tier.size() == 1
		and planted_cap.size() == 1,
		"live pool %d rows, problems %s; planted two tier-3 spikes -> %s; planted 20x cap -> %s"
			% [live.size(), live_problems, planted_tier, planted_cap])


func _check_stack_arm() -> void:
	var rows: Array = BuildSweep.stack_arm()
	var families := {}
	var bad: Array = []
	var ceiling := 0
	for row in rows:
		families[row["family"]] = families.get(row["family"], 0) + 1
		if row["values"].size() != BuildSweep.MAX_COPIES or row["ttk"].size() != BuildSweep.MAX_COPIES:
			bad.append("%s columns" % row["id"])
		for v in row["values"] + row["ttk"]:
			if not is_finite(float(v)):
				bad.append("%s non-finite" % row["id"])
				break
		if row["family"] == "hyperbolic":
			ceiling += 1
		bad.append_array(BuildSweep.row_problems(row))
	var missing: Array = PartDef.STACK_RULES.filter(func(rule): return not families.has(rule))
	_report("stack arm rows", rows.size() > 0 and missing.is_empty() and ceiling >= 2 and bad.is_empty(),
		"%d rows by family %s, %d ceiling rows; missing families %s; problems %s" % [rows.size(), families, ceiling, missing, bad])
	# Positive controls: a ceiling row past its cap, one whose steps grow, and a spike past
	# 8x must each be named, or the zero above proves nothing.
	var past_cap := {"id": "planted_past_cap", "family": "hyperbolic", "per": 0.1, "cap": 0.3,
		"values": _ramp(0.31, 0.0), "ttk": _ramp(1.0, 0.0), "real": false}
	var growing := {"id": "planted_growing", "family": "hyperbolic", "per": 0.1, "cap": 0.9,
		"values": _ramp(0.0, 0.001, true), "ttk": _ramp(1.0, 0.0), "real": false}
	var spike := {"id": "planted_spike", "family": "spike", "per": 0.1, "cap": 8.0,
		"values": _ramp(0.81, 0.0), "ttk": _ramp(1.0, 0.0), "real": false}
	var caught := [BuildSweep.row_problems(past_cap).size(), BuildSweep.row_problems(growing).size(),
		BuildSweep.row_problems(spike).size()]
	_report("stack arm controls fire", caught.all(func(c): return c > 0), "problems per planted row %s" % [caught])
	BuildSweep.print_stack_table(rows)


func _ramp(start: float, step: float, accelerate := false) -> Array:
	var out: Array = []
	for i in BuildSweep.MAX_COPIES:
		out.append(start + step * (i * i if accelerate else i))
	return out


func _check_independent_pairs() -> void:
	# Reflection keeps the red test runnable before the explicit table exists.
	var script: Script = load("res://tools/build_sweep.gd")
	var constants: Dictionary = script.get_script_constant_map()
	if not constants.has("INDEPENDENT_PAIRS"):
		var count: int = BuildSweep.unspecified_pairs([["frost"], ["frost"]])
		_report("missing independent pair control fires", false,
			"INDEPENDENT_PAIRS is missing; frost/frost -> %d unspecified pair, expected 1" % count)
		return
	var bad: Array = []
	var checked := 0
	for i in PartDef.TAGS.size():
		for j in range(i, PartDef.TAGS.size()):
			var a: String = PartDef.TAGS[i]
			var b: String = PartDef.TAGS[j]
			var outcome: String = BuildSweep.pair_outcome(a, b)
			checked += 1
			if outcome == "" or outcome != BuildSweep.pair_outcome(b, a):
				bad.append([a, b])
	for pair in constants["INDEPENDENT_PAIRS"]:
		if BuildSweep.pair_outcome(pair[0], pair[1]) != "independent":
			bad.append(pair)
	var reduced: Array = constants["INDEPENDENT_PAIRS"].duplicate(true)
	var removed: bool = reduced.has(["frost", "frost"])
	reduced.erase(["frost", "frost"])
	var unspecified: int = script.call("unspecified_pairs", [["frost"], ["frost"]], reduced)
	var planted := {"tag3_share": 1.0, "unspecified_pairs": unspecified, "offer_repeats": 0}
	var problems: Array = BuildSweep.compose_problems(planted)
	_report("missing independent pair control fires", bad.is_empty() and removed and unspecified == 1 and problems.size() == 1,
		"%d tag pairs checked, problems %s; removed frost/frost -> %d unspecified pair, composition problems %s"
			% [checked, bad, unspecified, problems])


func _check_compose_arm() -> void:
	var stats: Dictionary = BuildSweep.compose_arm(BuildSweep.DEFAULT_SEED, BuildSweep.COMPOSE_BUILDS)
	BuildSweep.print_compose_table(stats)
	_report("composition arm", stats["builds"] == 10000 and stats["draws"] >= 60000 and stats["tag3_share"] >= 0.30
		and stats["unspecified_pairs"] == 0 and stats["offer_repeats"] == 0
		and is_finite(stats["run_repeats_per_10k"]) and stats["run_repeats"] >= 0
		and BuildSweep.compose_problems(stats).is_empty(),
		"%d builds, %d draws, %.1f%% reach 3+ tags, %d unspecified pairs, %d in-offer repeats, %.2f within-run repeats per 10,000 draws (target %.0f, %s)"
			% [stats["builds"], stats["draws"], 100.0 * stats["tag3_share"], stats["unspecified_pairs"],
				stats["offer_repeats"], stats["run_repeats_per_10k"], BuildSweep.REPEAT_TARGET_PER_10K,
				"report-only by ruling"])
	var again: Dictionary = BuildSweep.compose_arm(7, 300)
	var twice: Dictionary = BuildSweep.compose_arm(7, 300)
	var other: Dictionary = BuildSweep.compose_arm(8, 300)
	_report("composition arm reproducible from the seed", again["picks_hash"] == twice["picks_hash"]
		and again["tag3_share"] == twice["tag3_share"] and again["picks_hash"] != other["picks_hash"],
		"seed 7 twice %s / %s, seed 8 %s" % [again["picks_hash"], twice["picks_hash"], other["picks_hash"]])
	var planted_unknown: int = BuildSweep.unspecified_pairs([["frost"], ["not_a_tag"], ["arc", "speed"]])
	var planted_repeat: int = BuildSweep.offer_repeats(["cross_split", "cross_split"])
	_report("composition controls fire", planted_unknown > 0 and planted_repeat == 1
		and BuildSweep.unspecified_pairs([["frost"], ["arc", "speed"]]) == 0,
		"unknown tag -> %d unspecified pairs; duplicate offer -> %d repeat" % [planted_unknown, planted_repeat])
	# Ruling 1 keeps the counter and makes an over-target run report-only.
	var planted_run: int = BuildSweep.run_repeats({"cross_split": 1}, ["cross_split", "fresh_part"])
	var clean_run: int = BuildSweep.run_repeats({"other_part": 2}, ["cross_split", "fresh_part"])
	var over := {"tag3_share": 1.0, "unspecified_pairs": 0, "offer_repeats": 0,
		"run_repeats": 5, "run_repeats_per_10k": 5.0}
	_report("within-run repeat controls fire", planted_run == 1 and clean_run == 0
		and BuildSweep.compose_problems(over).is_empty(),
		"seen part -> %d, fresh parts -> %d; 5.0 per 10,000 -> report-only by ruling" % [planted_run, clean_run])
