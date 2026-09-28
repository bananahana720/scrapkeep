extends SceneTree

const Parts := preload("res://src/build/parts.gd")

# Spike S1 (design-v3, experiment only, never merged): how often a run reaches an
# "evolution pair" -- a shown part stacked to a ripe copy count, plus any other held
# part carrying the pair's tag -- under the game's real offer rules (Parts.roll,
# Parts.roll_gate, Parts.gate_rarities, Parts.offer_pool, Parts._weighted's repeat
# down-weighting). This tool does not boot the game: it drives Parts statically with a
# synthetic pick schedule and never touches src/ or any other named-off-limits file.
#
#   godot --headless --path sketches/core-loop --script res://tools/snowball_sim.gd \
#     -- --seeds=200 [--out=<path>]
#
# Per seed, per stage (1..3), the schedule is: hoops (Parts.roll, uncommon only, take
# it), drop_gates (a common/uncommon mini pair, choose one), one break gate
# (Parts.roll_gate at Parts.gate_rarities(bonus cores), choose one) and shop buys (a
# common/uncommon/rare triple, choose one). offered (the repeat down-weighting dict)
# resets each stage and accumulates every id any roll this stage returned, matching
# build.gd's own _offered bookkeeping. Every taken id is appended to held.
#
# ripe count: a pattern part (spiral_wave, chain_arc, cross_split) is ripe at 2 copies
# (Parts.def(id).patterns is not empty). A row whose own stack_cap is 1 is ripe at 1
# copy (a second copy would never count, per part_def.gd's Stacking.value). Every other
# row is ripe at the --ripe parameter, capped at its own stack_cap when that cap is >=1
# (a linear/capped row; cap 0 on a linear row means no ceiling, so --ripe applies
# uncapped there). A pair is "ripe" when held holds at least that many copies of its
# shown part AND some held part carries its tag: the tag check is literal ("a held
# part"), so a shown part that itself carries the pair's tag (e.g. impact_driver/
# kinetic) is already its own tag-carrier once held.
#
# Chooser: with probability --greedy, prefer an offer that ripens a pair -- the shown
# part while its held count is below ripe, or a part carrying a pair's tag while that
# pair's shown part is already held (any count) -- picked uniformly among qualifying
# offers when more than one qualifies; otherwise (no qualifying offer, or the
# 1-greedy branch) pick uniformly among the whole offer.
#
# Bait (--bait, off by default): a post-roll substitution the tool applies itself,
# never inside parts.gd. After each roll, with probability --bait: if any pair's shown
# part is below its ripe count and sits in the roll's own rarity pool
# (Parts.offer_pool(class_id, rarities)), the LAST offer slot becomes that shown part
# (picked uniformly when more than one pair qualifies, to avoid a fixed table-order
# bias); else if any pair's shown part is held at or above ripe but no held part
# carries its tag, the last slot becomes a random pool part carrying that tag
# (Parts.tags_of), again picked uniformly across qualifying pairs. Only one
# substitution per roll, and only the last slot moves.
#
# Evidence limit: this is a draw simulation of the offer rules against a synthetic pick
# schedule and chooser, not play. It says how often the rules make a pair reachable; it
# says nothing about whether reaching one feels good, whether the schedule matches how
# Andrew or a bot actually spends picks, or how the chooser's greedy/bait knobs compare
# to a real player's judgement.

const CLASS_IDS := ["pylon_engineer", "runner_gunner", "demolitions_caster"]
const SEED_BASE := 20260928
const SEED_STRIDE := 7919
const SEEDS_DEFAULT := 200

const POLICIES := ["lapper", "completionist"]
const RIPES := [2, 3]
const BAITS := [0.0, 0.35, 0.5]
const GREEDIES := [0.0, 0.8]

# policy -> {hoops, drop_gates, shop} per stage; break gate cores are handled in code
# (lapper always 0 bonus cores, completionist rolls 1..2).
const SCHEDULE := {
	"lapper": {"hoops": 1, "drop_gates": 3, "shop": 0},
	"completionist": {"hoops": 2, "drop_gates": 5, "shop": 1},
}

# shown: the part id that must reach `ripe` copies. tag: the tag any held part
# (including the shown part itself, when it carries the tag) must carry.
const PAIRS := [
	{"shown": "spring_hull", "tag": "speed"},
	{"shown": "ballast_drum", "tag": "kinetic"},
	{"shown": "spiral_wave", "tag": "split"},
	{"shown": "chain_arc", "tag": "anchor"},
	{"shown": "cross_split", "tag": "kinetic"},
	{"shown": "impact_driver", "tag": "kinetic"},
	{"shown": "tumbler_bearing", "tag": "mass"},
	{"shown": "light_frame", "tag": "spiral"},
	{"shown": "magnet_coil", "tag": "mass"},
	{"shown": "static_burr", "tag": "arc"},
	{"shown": "frost_barb", "tag": "frost"},
	{"shown": "hairline_fracture", "tag": "anchor"},
	{"shown": "ring_wave", "tag": "kinetic"},
	{"shown": "cap_relay", "tag": "chain"},
	{"shown": "ten_pin", "tag": "chain"},
	{"shown": "salvage_drone", "tag": "mass"},
]

var _out := ""
var _seeds := SEEDS_DEFAULT
var _lines: Array[String] = []
var _pair_reach_counts := {}


func _initialize() -> void:
	var settings := _parse(OS.get_cmdline_user_args())
	_seeds = int(settings.get("seeds", str(SEEDS_DEFAULT)))
	_out = settings.get("out", "res://design-v3/spikes/S1-snowball-sim.md")
	for pair in PAIRS:
		_pair_reach_counts[_pair_key(pair)] = 0

	var header := "policy       ripe  bait  greedy  by_break1  by_break2  by_break3  mean_ripe_end  distinct_builds  mean_picks"
	print(header)
	_lines.append("| policy | ripe | bait | greedy | share ripe by break 1 | share ripe by break 2 | share ripe by break 3 | mean ripe pairs at end | distinct build ids /200 | mean picks |")
	_lines.append("|---|---|---|---|---|---|---|---|---|---|")

	for policy in POLICIES:
		for ripe in RIPES:
			for bait in BAITS:
				for greedy in GREEDIES:
					_run_cell(policy, ripe, bait, greedy)

	var top := _top_pairs(5)
	print("top 5 most-reached pairs overall (ever ripe at any break, any cell):")
	var top_lines: Array[String] = []
	for entry in top:
		var line := "  %s: %d" % [entry["pair"], entry["count"]]
		print(line)
		top_lines.append("- %s: %d" % [entry["pair"], entry["count"]])

	_write_report(header, top_lines)
	print("snowball_sim: 24 cells, %d seeds each, written to %s" % [_seeds, _out])
	quit(0)


func _run_cell(policy: String, ripe: int, bait: float, greedy: float) -> void:
	var by_break := [0, 0, 0]
	var ripe_end_total := 0
	var picks_total := 0
	var build_ids := {}

	for seed_i in _seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED_BASE + SEED_STRIDE * seed_i
		var class_id: String = CLASS_IDS[seed_i % 3]
		var held: Array = []
		var first_ripe_break := 0
		var ripe_at_break3: Array = []
		var ever_ripe := {}

		for stage in range(1, 4):
			var offered := {}
			var sched: Dictionary = SCHEDULE[policy]

			for i in int(sched["hoops"]):
				var picks := Parts.roll(rng, ["uncommon"], class_id, held, 1, [], offered)
				picks = _apply_bait(rng, picks, held, ripe, ["uncommon"], class_id, bait)
				_record_offered(offered, picks)
				if not picks.is_empty():
					held.append(picks[0])

			for i in int(sched["drop_gates"]):
				var picks := Parts.roll(rng, ["common", "uncommon"], class_id, held, 2, [], offered)
				picks = _apply_bait(rng, picks, held, ripe, ["common", "uncommon"], class_id, bait)
				_record_offered(offered, picks)
				if not picks.is_empty():
					held.append(_choose(rng, picks, held, ripe, greedy))

			var cores := 0 if policy == "lapper" else rng.randi_range(1, 2)
			var gate_rarities := Parts.gate_rarities(cores)
			var gate_picks := Parts.roll_gate(rng, gate_rarities, class_id, held, 2, stage, offered)
			gate_picks = _apply_bait(rng, gate_picks, held, ripe, gate_rarities, class_id, bait)
			_record_offered(offered, gate_picks)
			if not gate_picks.is_empty():
				held.append(_choose(rng, gate_picks, held, ripe, greedy))

			for i in int(sched["shop"]):
				var picks := Parts.roll(rng, ["common", "uncommon", "rare"], class_id, held, 3, [], offered)
				picks = _apply_bait(rng, picks, held, ripe, ["common", "uncommon", "rare"], class_id, bait)
				_record_offered(offered, picks)
				if not picks.is_empty():
					held.append(_choose(rng, picks, held, ripe, greedy))

			var ripe_now := _ripe_pairs(held, ripe)
			if not ripe_now.is_empty():
				if first_ripe_break == 0:
					by_break[stage - 1] += 1
					first_ripe_break = stage
			for pair_key in ripe_now:
				ever_ripe[pair_key] = true
			if stage == 3:
				ripe_at_break3 = ripe_now

		ripe_end_total += ripe_at_break3.size()
		picks_total += held.size()
		var sorted_held: Array = held.duplicate()
		sorted_held.sort()
		build_ids["+".join(sorted_held)] = true
		for pair_key in ever_ripe:
			_pair_reach_counts[pair_key] = _pair_reach_counts.get(pair_key, 0) + 1

	# by_break currently holds "first became ripe at exactly this break"; turn it into
	# cumulative "ripe by this break or earlier".
	var cum := [by_break[0], by_break[0] + by_break[1], by_break[0] + by_break[1] + by_break[2]]
	var share1 := float(cum[0]) / float(_seeds)
	var share2 := float(cum[1]) / float(_seeds)
	var share3 := float(cum[2]) / float(_seeds)
	var mean_ripe_end := float(ripe_end_total) / float(_seeds)
	var mean_picks := float(picks_total) / float(_seeds)
	var distinct := build_ids.size()

	var line := "%-12s %-5d %-5.2f %-7.2f %-10.3f %-10.3f %-10.3f %-14.3f %-16d %-10.2f" % \
		[policy, ripe, bait, greedy, share1, share2, share3, mean_ripe_end, distinct, mean_picks]
	print(line)
	_lines.append("| %s | %d | %.2f | %.2f | %.3f | %.3f | %.3f | %.3f | %d | %.2f |" % \
		[policy, ripe, bait, greedy, share1, share2, share3, mean_ripe_end, distinct, mean_picks])


func _pair_key(pair: Dictionary) -> String:
	return "%s/%s" % [pair["shown"], pair["tag"]]


func _ripe_count(shown: String, ripe_param: int) -> int:
	var d: Resource = Parts.def(shown)
	if d == null:
		return ripe_param
	if not d.patterns.is_empty():
		return 2
	var cap := int(d.stack_cap)
	if d.stack_rule == "capped" and cap == 1:
		return 1
	if cap >= 1:
		return mini(ripe_param, cap)
	return ripe_param


func _pair_ripe(pair: Dictionary, held: Array, ripe_param: int) -> bool:
	var shown: String = pair["shown"]
	var tag: String = pair["tag"]
	if held.count(shown) < _ripe_count(shown, ripe_param):
		return false
	for part_id in held:
		if Parts.tags_of(part_id).has(tag):
			return true
	return false


func _ripe_pairs(held: Array, ripe_param: int) -> Array:
	var out: Array = []
	for pair in PAIRS:
		if _pair_ripe(pair, held, ripe_param):
			out.append(_pair_key(pair))
	return out


# Chooser: with probability greedy, prefer an offer that ripens a pair.
func _choose(rng: RandomNumberGenerator, offer: Array, held: Array, ripe_param: int, greedy: float) -> String:
	if rng.randf() < greedy:
		var candidates: Array = offer.filter(func(id): return _ripens(id, held, ripe_param))
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
	return offer[rng.randi_range(0, offer.size() - 1)]


func _ripens(part_id: String, held: Array, ripe_param: int) -> bool:
	for pair in PAIRS:
		var shown: String = pair["shown"]
		var tag: String = pair["tag"]
		if part_id == shown and held.count(shown) < _ripe_count(shown, ripe_param):
			return true
		if part_id != shown and Parts.tags_of(part_id).has(tag) and held.has(shown):
			return true
	return false


# Post-roll bait substitution (tool-side only; never in parts.gd). Only the last slot
# ever moves, and at most once per roll.
func _apply_bait(rng: RandomNumberGenerator, picks: Array, held: Array, ripe_param: int, rarities: Array,
		class_id: String, bait: float) -> Array:
	if picks.is_empty() or bait <= 0.0 or rng.randf() >= bait:
		return picks
	var pool: Array = Parts.offer_pool(class_id, rarities)
	var below_in_pool: Array = []
	for pair in PAIRS:
		var shown: String = pair["shown"]
		if held.count(shown) < _ripe_count(shown, ripe_param) and pool.has(shown):
			below_in_pool.append(shown)
	if not below_in_pool.is_empty():
		var out := picks.duplicate()
		out[out.size() - 1] = below_in_pool[rng.randi_range(0, below_in_pool.size() - 1)]
		return out

	var tag_candidates: Array = []
	for pair in PAIRS:
		var shown: String = pair["shown"]
		var tag: String = pair["tag"]
		if not held.has(shown) or held.count(shown) < _ripe_count(shown, ripe_param):
			continue
		var has_tag := false
		for part_id in held:
			if Parts.tags_of(part_id).has(tag):
				has_tag = true
				break
		if has_tag:
			continue
		for key in pool:
			if Parts.tags_of(key).has(tag) and not key in tag_candidates:
				tag_candidates.append(key)
	if not tag_candidates.is_empty():
		var out2 := picks.duplicate()
		out2[out2.size() - 1] = tag_candidates[rng.randi_range(0, tag_candidates.size() - 1)]
		return out2
	return picks


func _record_offered(offered: Dictionary, picks: Array) -> void:
	for part_id in picks:
		offered[part_id] = offered.get(part_id, 0) + 1


func _top_pairs(n: int) -> Array:
	var entries: Array = []
	for key in _pair_reach_counts:
		entries.append({"pair": key, "count": _pair_reach_counts[key]})
	entries.sort_custom(func(a, b): return a["count"] > b["count"])
	return entries.slice(0, n)


func _write_report(header: String, top_lines: Array[String]) -> void:
	var out_path: String = _out
	if out_path.begins_with("res://"):
		out_path = ProjectSettings.globalize_path(out_path)
	var dir := out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var text := "# S1: snowball offer-rule simulator\n\n"
	text += "Tool: `godot --headless --path sketches/core-loop --script res://tools/snowball_sim.gd -- --seeds=%d`\n\n" % _seeds
	text += "Base SHA: 43eeeea\n\n"
	text += "Parameters: policy {lapper, completionist} x ripe {2, 3} x bait {0.0, 0.35, 0.5} x greedy {0.0, 0.8}, 24 cells, 200 seeds each (rng.seed = 20260928 + 7919 * seed).\n\n"
	text += "Ripe count: a pattern part (spiral_wave, chain_arc, cross_split) is ripe at 2 copies; a row whose own stack_cap is 1 is ripe at 1 copy; every other row is ripe at the `ripe` parameter, capped at its own stack_cap when that cap is >= 1. A pair is ripe when held holds at least that many copies of its shown part and some held part (including the shown part itself, when it carries the tag) carries the pair's tag.\n\n"
	text += "Chooser: with probability `greedy`, prefer an offer that ripens a pair (the shown part below its ripe count, or a part carrying a pair's tag when that pair's shown part is already held), picked uniformly among qualifying offers; otherwise pick uniformly among the whole offer.\n\n"
	text += "Bait (`--bait`, off by default): a post-roll substitution the tool applies itself, never inside parts.gd. After each roll, with probability `bait`: if any pair's shown part is below its ripe count and sits in that roll's own rarity pool (`Parts.offer_pool`), the last offer slot becomes that shown part (uniformly among qualifying pairs); else if any pair's shown part is held at or above ripe but no held part carries its tag, the last slot becomes a random pool part carrying that tag (uniformly among qualifying pairs). Only the last slot ever moves, at most once per roll.\n\n"
	text += "Evidence limit: this is a draw simulation of the offer rules against a synthetic pick schedule and chooser, not play. It measures how often the rules make a pair reachable; it says nothing about whether reaching one feels good, whether the schedule matches how Andrew or a bot actually spends picks, or how the chooser's greedy/bait knobs compare to a real player's judgement.\n\n"
	text += "## Results\n\n"
	for line in _lines:
		text += line + "\n"
	text += "\n## Top 5 most-reached pairs overall (ever ripe at any break, any of the 24 cells)\n\n"
	for line in top_lines:
		text += line + "\n"
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out
