# smoke: solo timeout=360s (the alpha share check is a mean over 20 seeds: about 140 s on an idle box)
extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# SQ19 (wave 14, comps/roboquest/classes-and-perks.md:82, comps/gunfire/heroes-and-ascensions.md:87):
# each pilot's offers lean to its own kit by Parts.KIT_SHARE, with a neutral shelf that never
# stalls a build. For every pilot, a greedy and a random bot each see 200 gate draws (10 runs of
# 4 stages, 5 gates a stage, through Parts.roll_gate with the stage's offered counts) and pick
# one part a draw. Checks, on the full authored catalogue:
#   - the weighted share (parts in Parts.in_kit) is inside 60 to 80% for every pilot and bot;
#   - the top-10 most-offered parts of any two pilots overlap under 50% (of the smaller top list);
#   - movement is at most 15% of each pilot's offers;
#   - no neutral shelf part is offered more than Parts.NEUTRAL_REPEAT_CAP times in one stage;
#   - each pilot's two dominant buckets (Parts.bucket_of) are its declared kit pair; the six
#     measured pairs hold at least MIN_DISTINCT_PAIRS different pairs and no pair is held by more
#     than MAX_PILOTS_PER_PAIR pilots (the six kits declare the same, and none declares
#     UNREACHABLE_PAIR); every pilot's kit holds a common part that hits harder;
#   - a draw with every kit part excluded still shows a neutral shelf part, and _keep_a_neutral
#     on its own turns an off-kit draw's plain slot into a shelf part;
#   - no offer is another class's part;
#   - every pilot's upgrade tree reaches a depth-4 endpoint in each of its four slots by the last
#     milestone with both bots.
# On the alpha list (AlphaDefs.PARTS, the parts the default table offers) the same draws run.
# 2026-10-15 (wave 14 SQ19b): the list grew from 19 to 45 parts so every kit has commons on it,
# and the alpha checks are asserted: the weighted share inside 60 to 80% for every pilot and bot,
# movement at most 15%, the repeat cap, the neutral fallback, no other class's part, and top-10
# overlap at most ALPHA_OVERLAP_MAX for any two pilots. Tally's movement share is printed against
# Parts.MOVEMENT_SHARE (12%), and Tally's Winch Pawl must show in Tally's offers and no one else's.
# At 19 parts the share ran 0.12 to 0.69 and any two top-10s overlapped 0.70 to 1.00.
# The alpha pairs are asserted at ALPHA_MIN_PAIRS distinct, not MIN_DISTINCT_PAIRS: the fifth
# pair is Rivet's movement + skill, and on this list Rivet's weapon share stays above its movement
# share. Movement is held to Parts.MOVEMENT_SHARE of a slot, about 0.10 to 0.11 of Rivet's offers,
# and the stage-2 pattern guarantee alone puts about 0.09 in weapon (the greedy bot never picks an
# off-kit pattern, so every stage-2 gate gets one). Measured at SQ19b: weapon 0.113, movement
# 0.106. The full catalogue reaches it because its skill shelf parts lean Rivet's spare slots
# away from weapon and defence; on the alpha list the margin is under one point either way.
# PAIRS (2026-10-15, SQ19, coordinator ruling W8): every two-slot gate draw holds a part that hits
# harder (build_catalogue_test "gate pairs hit harder"), and no common part that hits harder sits
# in the defence bucket, so in every pilot's offers weapon + skill + movement is at least 50%. A
# defence + movement pair needs weapon and skill each below movement, which is at most 15%, so
# under 45% in all: no pilot can hold that pair, which leaves five reachable pairs for six pilots.
# W8 rules the pair line as: at least 5 distinct measured pairs, none held by more than two
# pilots, no pilot declaring defence + movement, and every pilot measuring the pair it declares.
# A kit with no common hitter puts the hitter of every gate pair off-kit (Tally's old kit measured
# a 0.37 share), so each kit must hold one.
# 2026-10-17 (maker sets): the bars above measure the kit lean alone, so these draws run with the
# maker nudge off (Parts.maker_nudge_on). The nudge keeps every group's and bucket's weight in each
# slot (maker_sets_case proves that per slot); it moves which piece of a bucket shows, and so the
# bots' picks and the seeded path. One more pass with it on checks every pilot's bucket shares
# stay within NUDGE_DRIFT of the pass without it (about two standard errors of a 10-run share).
# 2026-10-18 (coordinator ruling on #149, nemesis offer lean at 1.5): the alpha list's weighted-share
# check is the mean over SEEDS seeds (seed 0 is the seed above) against the unchanged SHARE_BAND, with
# the per-seed min and max printed. One seed near the edge decided it: alpha Tally random read 0.807
# on one seed, while the base crosses 0.80 on 7 of 20 seeds. Every other check is unchanged.
# Evidence limit: the offer draw only. Whether each pilot still wins its bot
# runs is bot_six_*_test's claim, and how the lean feels is Andrew's to play.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const BUCKETS := ["weapon", "skill", "defence", "movement"]
const RUNS := 10
const STAGES := 4
const GATES_PER_STAGE := 5
const CHOICES := 2
const SHARE_BAND := [0.60, 0.80]
# 2026-10-17 (Overpowered pays, Parts._swap_stacked_out): a part held at its stack cap is swapped
# out of the draw, so a greedy bot that has stacked out its kit sees off-kit parts and its share
# may sit under the band (Tarn measured 0.573 full, 0.568 alpha) (coordinator ruling (a), 22:54Z).
# The random bot keeps the band.
const GREEDY_SHARE_FLOOR := 0.55
# 2026-10-21 (ruling 11, #149 6274605849): the full list's bar is at most 0.50, as the alpha list's;
# a stacked-out swap (Parts._swap_stacked_out) lands Tarn on exactly 0.50 with Tally and the Cannon.
const OVERLAP_MAX := 0.5
const MOVEMENT_MAX := 0.15
const TOP := 10
const MIN_DISTINCT_PAIRS := 5
const MAX_PILOTS_PER_PAIR := 2
const UNREACHABLE_PAIR := ["defence", "movement"]
# 2026-10-15 SQ19b: the alpha list's own bars (see the header).
# 2026-10-17 (Overpowered pays): 0.50, was 0.40 (coordinator ruling (a), 22:54Z). A stacked-out
# shelf pick swaps for another shelf part (_keep_a_neutral's promise), so on the 45-part alpha list
# Demolitions and the Cannon share five top-10 shelf parts (measured 0.50).
const ALPHA_OVERLAP_MAX := 0.50
const ALPHA_MIN_PAIRS := 4
const TALLY_PART := "winch_pawl"
const NUDGE_DRIFT := 0.03
const SEEDS := 20

var _t := preload("res://tests/support/t.gd").new("offer_weights_test")


func _initialize() -> void:
	Synergies.set_table(null)
	_t.check("the full catalogue is unlisted", not PartOffers.listed_only(), "")
	_t.check("the kit share is a declared constant inside the band",
		PartOffers.KIT_SHARE >= SHARE_BAND[0] and PartOffers.KIT_SHARE <= SHARE_BAND[1], str(PartOffers.KIT_SHARE))
	_t.check("every pilot declares a kit of two buckets", PILOTS.all(func(p): return PartOffers.KITS.has(p) and PartOffers.KITS[p].size() == 2), "")
	var declared := {}
	for pilot in PILOTS:
		declared[pilot] = _declared(pilot)
		_t.check("%s does not declare the unreachable defence + movement pair" % pilot, declared[pilot] != UNREACHABLE_PAIR, str(declared[pilot]))
		var hitters: Array = Parts.offer_pool(pilot, ["common"]).filter(func(id): return Parts.in_kit(pilot, id) and Parts.def(id).hits_harder())
		_t.check("%s kit holds a common part that hits harder" % pilot, not hitters.is_empty(), str(hitters))
	_pair_spread("declared", declared, true)
	var defence_hitters := {}
	for pilot in PILOTS:
		for id in Parts.offer_pool(pilot, ["common"]):
			if Parts.def(id).hits_harder() and Parts.bucket_of(id) == "defence":
				defence_hitters[id] = true
	# The premise of the PAIRS note: if this goes red, re-measure the pair line before trusting it.
	_t.eq("no common part that hits harder is in the defence bucket (PAIRS premise)", defence_hitters.keys(), [])
	PartOffers.maker_nudge_on = false
	var full := _measure("full")
	_judge("full", full, true)
	PartOffers.maker_nudge_on = true
	_nudge_drift(full, _measure("full nudged"))
	PartOffers.maker_nudge_on = false
	_fallback("full")
	_keep_neutral()
	Synergies.set_table(AlphaDefs)
	_t.check("the alpha table lists its parts", PartOffers.listed_only(), "")
	var alpha := _measure("alpha")
	_judge("alpha", alpha, false)
	_tally_part(alpha)
	_fallback("alpha")
	Synergies.set_table(null)
	PartOffers.maker_nudge_on = true
	_trees()
	quit(_t.verdict())


# pilot -> bot -> stats
func _measure(label: String) -> Dictionary:
	var out := {}
	for pi in PILOTS.size():
		var pilot: String = PILOTS[pi]
		out[pilot] = {}
		for bot in ["greedy", "random"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 19000 + pi * 10 + (0 if bot == "greedy" else 1)
			var pick_rng := RandomNumberGenerator.new()
			pick_rng.seed = 91000 + pi * 10 + (0 if bot == "greedy" else 1)
			var s := {"draws": 0, "slots": 0, "kit": 0, "counts": {}, "buckets": {}, "neutral_max": 0, "foreign": []}
			for b in BUCKETS:
				s["buckets"][b] = 0
			for _run in RUNS:
				var held: Array = []
				for stage in range(1, STAGES + 1):
					var offered := {}
					for _gate in GATES_PER_STAGE:
						var picks: Array = Parts.roll_gate(rng, ["common"], pilot, held, CHOICES, stage, offered)
						s["draws"] += 1
						for id in picks:
							offered[id] = offered.get(id, 0) + 1
							s["slots"] += 1
							s["counts"][id] = s["counts"].get(id, 0) + 1
							s["buckets"][Parts.bucket_of(id)] += 1
							if Parts.in_kit(pilot, id):
								s["kit"] += 1
							var only := String(Parts.row(id).get("class_id", ""))
							if only != "" and only != pilot:
								s["foreign"].append(id)
							if id in PartOffers.NEUTRAL_SHELF and not Parts.in_kit(pilot, id):
								s["neutral_max"] = maxi(s["neutral_max"], offered[id])
						if not picks.is_empty():
							held.append(_pick(bot, pilot, picks, pick_rng))
			out[pilot][bot] = s
			print("[%s %s %s] draws %d slots %d kit share %.3f movement %.3f buckets %s neutral max/stage %d" % [label, pilot, bot,
				s["draws"], s["slots"], _share(s, "kit"), _bucket_share(s, "movement"), _bucket_shares(s), s["neutral_max"]])
	return out


# The maker nudge moves no pilot's bucket share by more than NUDGE_DRIFT.
func _nudge_drift(plain: Dictionary, nudged: Dictionary) -> void:
	for pilot in PILOTS:
		var a := _merged(plain, pilot)
		var b := _merged(nudged, pilot)
		var worst := 0.0
		for bucket in BUCKETS:
			worst = maxf(worst, absf(_bucket_share(a, bucket) - _bucket_share(b, bucket)))
		_t.check("maker nudge %s bucket shares within %.2f of the kit lean alone" % [pilot, NUDGE_DRIFT], worst <= NUDGE_DRIFT,
			"worst %.3f: %s against %s" % [worst, _bucket_shares(b), _bucket_shares(a)])


# The weighted kit share of one pilot and bot on SEEDS seeds; seed 0 reads _measure's own seeds.
func _seed_shares(pilot: String, bot: String) -> Array:
	var pi := PILOTS.find(pilot)
	var out: Array = []
	for k in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 19000 + pi * 10 + (0 if bot == "greedy" else 1) + k * 1000
		var pick_rng := RandomNumberGenerator.new()
		pick_rng.seed = 91000 + pi * 10 + (0 if bot == "greedy" else 1) + k * 1000
		var slots := 0
		var kit := 0
		for _run in RUNS:
			var held: Array = []
			for stage in range(1, STAGES + 1):
				var offered := {}
				for _gate in GATES_PER_STAGE:
					var picks: Array = Parts.roll_gate(rng, ["common"], pilot, held, CHOICES, stage, offered)
					for id in picks:
						offered[id] = offered.get(id, 0) + 1
						slots += 1
						kit += 1 if Parts.in_kit(pilot, id) else 0
					if not picks.is_empty():
						held.append(_pick(bot, pilot, picks, pick_rng))
		out.append(float(kit) / float(maxi(1, slots)))
	return out


func _pick(bot: String, pilot: String, picks: Array, rng: RandomNumberGenerator) -> String:
	if bot == "random":
		return picks[rng.randi_range(0, picks.size() - 1)]
	var best: String = picks[0]
	var best_score := -1.0
	for id in picks:
		var d: Resource = Parts.def(id)
		var score: float = (100.0 if Parts.in_kit(pilot, id) else 0.0) + (d.punch if d != null else 0.0)
		if score > best_score:
			best_score = score
			best = id
	return best


func _share(s: Dictionary, key: String) -> float:
	return float(s[key]) / float(maxi(1, s["slots"]))


func _bucket_share(s: Dictionary, bucket: String) -> float:
	return float(s["buckets"][bucket]) / float(maxi(1, s["slots"]))


func _bucket_shares(s: Dictionary) -> String:
	var parts: Array = []
	for b in BUCKETS:
		parts.append("%s %.3f" % [b, _bucket_share(s, b)])
	return ", ".join(parts)


# Both bots' draws summed per pilot.
func _merged(stats: Dictionary, pilot: String) -> Dictionary:
	var m := {"slots": 0, "kit": 0, "counts": {}, "buckets": {}}
	for b in BUCKETS:
		m["buckets"][b] = 0
	for bot in stats[pilot]:
		var s: Dictionary = stats[pilot][bot]
		m["slots"] += s["slots"]
		m["kit"] += s["kit"]
		for id in s["counts"]:
			m["counts"][id] = m["counts"].get(id, 0) + s["counts"][id]
		for b in BUCKETS:
			m["buckets"][b] += s["buckets"][b]
	return m


func _top(counts: Dictionary) -> Array:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a, b): return counts[a] > counts[b] or counts[a] == counts[b] and String(a) < String(b))
	return ids.slice(0, TOP)


# The two most-offered buckets, and whether the second is strictly above the third.
func _pair(m: Dictionary) -> Array:
	var order: Array = BUCKETS.duplicate()
	order.sort_custom(func(a, b): return m["buckets"][a] > m["buckets"][b] or m["buckets"][a] == m["buckets"][b] and a < b)
	var pair: Array = [order[0], order[1]]
	pair.sort()
	return [pair, m["buckets"][order[1]] > m["buckets"][order[2]]]


func _judge(label: String, stats: Dictionary, strict: bool) -> void:
	var tops := {}
	var pairs := {}
	for pilot in PILOTS:
		for bot in stats[pilot]:
			var s: Dictionary = stats[pilot][bot]
			_t.check("%s %s %s draws" % [label, pilot, bot], s["draws"] == RUNS * STAGES * GATES_PER_STAGE and s["slots"] > s["draws"], "%d draws, %d slots" % [s["draws"], s["slots"]])
			var share := _share(s, "kit")
			var detail := "%.3f" % share
			if not strict:
				var seeds := _seed_shares(pilot, bot)
				share = 0.0
				for x in seeds:
					share += x
				share /= seeds.size()
				detail = "mean %.3f over %d seeds, min %.3f max %.3f" % [share, seeds.size(), seeds.min(), seeds.max()]
			var floor_share: float = GREEDY_SHARE_FLOOR if bot == "greedy" else SHARE_BAND[0]
			var in_band: bool = share >= floor_share and share <= SHARE_BAND[1]
			_t.check("%s %s %s weighted share inside %d to 80%%" % [label, pilot, bot, roundi(floor_share * 100.0)], in_band, detail)
			_t.check("%s %s %s movement at most 15%%" % [label, pilot, bot], _bucket_share(s, "movement") <= MOVEMENT_MAX, "%.3f" % _bucket_share(s, "movement"))
			_t.check("%s %s %s no neutral part over its repeat cap" % [label, pilot, bot], s["neutral_max"] <= PartOffers.NEUTRAL_REPEAT_CAP,
				"max %d a stage, cap %d" % [s["neutral_max"], PartOffers.NEUTRAL_REPEAT_CAP])
			_t.eq("%s %s %s offers no other class's part" % [label, pilot, bot], s["foreign"], [])
		var m := _merged(stats, pilot)
		tops[pilot] = _top(m["counts"])
		pairs[pilot] = _pair(m)
		print("[%s %s] top %s pair %s (second above third %s) buckets %s" % [label, pilot, tops[pilot], pairs[pilot][0], pairs[pilot][1], _bucket_shares(m)])
	for i in PILOTS.size():
		for j in range(i + 1, PILOTS.size()):
			var a: Array = tops[PILOTS[i]]
			var b: Array = tops[PILOTS[j]]
			var shared := a.filter(func(id): return id in b)
			var overlap := float(shared.size()) / float(maxi(1, mini(a.size(), b.size())))
			var detail := "%.2f (%d of %d: %s)" % [overlap, shared.size(), mini(a.size(), b.size()), shared]
			if strict:
				_t.check("%s top-%d overlap %s and %s at most %.2f" % [label, TOP, PILOTS[i], PILOTS[j], OVERLAP_MAX], overlap <= OVERLAP_MAX + 0.0001, detail)
			else:
				_t.check("%s top-%d overlap %s and %s at most %.2f" % [label, TOP, PILOTS[i], PILOTS[j], ALPHA_OVERLAP_MAX],
					overlap <= ALPHA_OVERLAP_MAX + 0.0001, detail)
	var measured := {}
	for pilot in PILOTS:
		measured[pilot] = pairs[pilot][0]
		var detail := "%s, declared %s" % [pairs[pilot][0], _declared(pilot)]
		if strict:
			_t.check("%s %s second dominant bucket is strictly above the third" % [label, pilot], pairs[pilot][1], detail)
			_t.eq("%s %s dominant pair is its declared kit" % [label, pilot], pairs[pilot][0], _declared(pilot))
		else:
			print("[%s %s dominant pair] %s (measured; second above third %s)" % [label, pilot, detail, pairs[pilot][1]])
	_pair_spread(label, measured, strict)


# pilot -> sorted pair. At least MIN_DISTINCT_PAIRS distinct, none held by over MAX_PILOTS_PER_PAIR.
func _pair_spread(label: String, pairs: Dictionary, strict: bool) -> void:
	var holders := {}
	for pilot in PILOTS:
		var key := str(pairs[pilot])
		holders[key] = holders.get(key, []) + [pilot]
	var crowded: Array = holders.keys().filter(func(key): return holders[key].size() > MAX_PILOTS_PER_PAIR)
	var detail := "%d distinct: %s" % [holders.size(), holders]
	if strict:
		_t.check("%s pairs hold at least %d distinct" % [label, MIN_DISTINCT_PAIRS], holders.size() >= MIN_DISTINCT_PAIRS, detail)
		_t.eq("%s no pair held by more than %d pilots" % [label, MAX_PILOTS_PER_PAIR], crowded, [])
	else:
		_t.check("%s pairs hold at least %d distinct (target %d, see header)" % [label, ALPHA_MIN_PAIRS, MIN_DISTINCT_PAIRS],
			holders.size() >= ALPHA_MIN_PAIRS, detail)
		print("[%s dominant pairs] %s, crowded %s (measured)" % [label, detail, crowded])


# Tally's Winch Pawl (SQ19b, BIBLE.md Mobility row): a Tally class part, so it shows in Tally's
# alpha offers and in no other pilot's. Tally's movement share is printed against the 12% target.
func _tally_part(stats: Dictionary) -> void:
	_t.eq("%s is a Tally class part on the alpha list" % TALLY_PART,
		[TALLY_PART in AlphaDefs.PARTS, String(Parts.row(TALLY_PART).get("class_id", "")), Parts.bucket_of(TALLY_PART)], [true, "tally", "movement"])
	for pilot in PILOTS:
		var seen := 0
		for bot in stats[pilot]:
			seen += int(stats[pilot][bot]["counts"].get(TALLY_PART, 0))
		if pilot == "tally":
			_t.check("alpha tally is offered %s" % TALLY_PART, seen > 0, "%d offers" % seen)
		else:
			_t.check("alpha %s is never offered %s" % [pilot, TALLY_PART], seen == 0, "%d offers" % seen)
	var m := _merged(stats, "tally")
	# 2026-10-15 SQ19b ruling S2: each class movement row brings its own CLASS_MOVEMENT_SHARE (at
	# most MOVEMENT_SHARE in all). Tally holds two on this list, so its movement share sits at or
	# above 1.5 of one row's share; a flat CLASS_MOVEMENT_SHARE measured 0.072 here.
	var rows: Array = Parts.offer_pool("tally", ["common"]).filter(func(id): return String(Parts.row(id).get("class_id", "")) == "tally" \
		and Parts.bucket_of(id) == "movement")
	_t.eq("alpha tally holds two class movement rows", rows.size(), 2)
	var moved := _bucket_share(m, "movement")
	_t.check("alpha tally movement share is at least 1.5 x CLASS_MOVEMENT_SHARE and at most MOVEMENT_SHARE",
		moved >= 1.5 * PartOffers.CLASS_MOVEMENT_SHARE and moved <= PartOffers.MOVEMENT_SHARE,
		"%.3f, bounds %.3f to %.3f, rows %s" % [moved, 1.5 * PartOffers.CLASS_MOVEMENT_SHARE, PartOffers.MOVEMENT_SHARE, rows])
	print("[alpha tally movement share] %.3f against the %.2f target (cap %.2f)" % [_bucket_share(m, "movement"), PartOffers.MOVEMENT_SHARE, MOVEMENT_MAX])


func _declared(pilot: String) -> Array:
	var pair: Array = PartOffers.KITS[pilot].keys()
	pair.sort()
	return pair


# A draw whose kit parts are all excluded still shows a neutral shelf part.
func _fallback(label: String) -> void:
	for pilot in PILOTS:
		var pool: Array = Parts.offer_pool(pilot, ["common"])
		var kit: Array = pool.filter(func(id): return Parts.in_kit(pilot, id))
		var shown := 0
		for seed_value in 50:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7700 + seed_value
			var picks: Array = Parts.roll(rng, ["common"], pilot, [], CHOICES, kit)
			if picks.any(func(id): return id in PartOffers.NEUTRAL_SHELF):
				shown += 1
		_t.check("%s %s a draw with no kit part still shows a neutral choice" % [label, pilot], shown == 50,
			"%d of 50 draws (kit of %d excluded)" % [shown, kit.size()])


# _keep_a_neutral on its own: a two-slot draw of non-kit, non-shelf commons (one hitter, one not)
# with an uncapped shelf part left in the pool turns its non-hitter slot into a shelf part. The
# _fallback draws above exclude the whole kit, so _lean_slot already takes the shelf and they
# cannot tell whether _keep_a_neutral runs; this check can.
func _keep_neutral() -> void:
	for pilot in PILOTS:
		var pool: Array = Parts.offer_pool(pilot, ["common"])
		var off: Array = pool.filter(func(id): return not Parts.in_kit(pilot, id) and not id in PartOffers.NEUTRAL_SHELF)
		var hitter: Array = off.filter(func(id): return Parts.def(id).hits_harder())
		var plain: Array = off.filter(func(id): return not Parts.def(id).hits_harder())
		var shelf: Array = pool.filter(func(id): return id in PartOffers.NEUTRAL_SHELF and not Parts.in_kit(pilot, id))
		if hitter.is_empty() or plain.is_empty() or shelf.is_empty():
			_t.check("%s has an off-kit hitter, an off-kit plain part and a shelf part to test _keep_a_neutral" % pilot, false,
				"%d hitters, %d plain, %d shelf" % [hitter.size(), plain.size(), shelf.size()])
			continue
		var picks: Array = [hitter[0], plain[0]]
		var rest: Array = shelf.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7900
		Parts._keep_a_neutral(rng, pilot, picks, rest, {}, 0)
		_t.check("%s _keep_a_neutral turns the plain slot of an off-kit draw into a shelf part" % pilot,
			picks[0] == hitter[0] and picks[1] in PartOffers.NEUTRAL_SHELF, "%s from %s" % [picks, [hitter[0], plain[0]]])
		var capped := {}
		for id in shelf:
			capped[id] = PartOffers.NEUTRAL_REPEAT_CAP
		var held: Array = [hitter[0], plain[0]]
		Parts._keep_a_neutral(rng, pilot, held, rest, capped, 0)
		_t.eq("%s _keep_a_neutral leaves the draw alone when every shelf part is at its cap" % pilot, held, [hitter[0], plain[0]])


# Every pilot's tree reaches a depth-4 endpoint in each of the four slots (weapon, movement,
# special, smash) by the last milestone, with both bots. Tree picks do not read part offers:
# UpgradeTree.offered() (src/core/upgrade_tree.gd:455) builds each pair from the tree and the
# run's earlier picks, and upgrade_tree.gd never calls Parts, so the weighted offers cannot move
# this result; the walk is over the tree itself. A bot aiming at a slot picks, at each depth, a
# child whose subtree holds a depth-4 node of that slot: greedy the first such child, random a
# random one. A positive control: a slot no depth-4 node carries ("line") is never reached.
const TREE_SLOTS := ["weapon", "movement", "special", "smash"]


func _trees() -> void:
	var cap := UpgradeTree.depth_cap(3)
	_t.eq("the last milestone opens depth 4", cap, UpgradeTree.DEPTHS)
	for pi in PILOTS.size():
		var pilot: String = PILOTS[pi]
		var list := UpgradeTree.nodes(pilot)
		for bot in ["greedy", "random"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5100 + pi
			for slot in TREE_SLOTS:
				var reached := 0
				for _run in RUNS:
					if _walk(list, slot, cap, bot, rng):
						reached += 1
				_t.check("%s %s bot reaches a %s endpoint by the last milestone" % [pilot, bot, slot], reached == RUNS,
					"%d of %d runs, %d nodes" % [reached, RUNS, list.size()])
			_t.check("%s %s bot never reaches a line endpoint (control)" % [pilot, bot], not _walk(list, "line", cap, bot, rng), "")


# One run's walk of cap picks toward slot; true when it ends on a depth-4 leaf of that slot.
func _walk(list: Array, slot: String, cap: int, bot: String, rng: RandomNumberGenerator) -> bool:
	var choices: Array = [0, 1]
	var index := -1
	for _pick in cap:
		var aimed: Array = choices.filter(func(i): return _holds(list, i, slot))
		var from: Array = aimed if not aimed.is_empty() else choices
		index = from[0] if bot == "greedy" else from[rng.randi_range(0, from.size() - 1)]
		choices = UpgradeTree.children_of(index).filter(func(i): return i < list.size())
	return index >= 0 and index < list.size() and UpgradeTree.depth_of(index) == UpgradeTree.DEPTHS \
		and choices.is_empty() and String(list[index].get("key", "")) == slot


# True when the subtree under index holds a depth-4 node of slot.
func _holds(list: Array, index: int, slot: String) -> bool:
	if index >= list.size():
		return false
	if UpgradeTree.depth_of(index) == UpgradeTree.DEPTHS:
		return String(list[index].get("key", "")) == slot
	return UpgradeTree.children_of(index).any(func(i): return _holds(list, i, slot))
