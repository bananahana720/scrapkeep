extends SceneTree

const Parts := preload("res://src/build/parts.gd")
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
#   - each pilot's two dominant buckets (Parts.bucket_of) are its declared kit pair, and the six
#     pairs differ (the six kits also declare six different pairs);
#   - a draw with every kit part excluded still shows a neutral shelf part, and _keep_a_neutral
#     on its own turns an off-kit draw's plain slot into a shelf part;
#   - no offer is another class's part;
#   - every pilot's upgrade tree reaches a depth-4 endpoint in each of its four slots by the last
#     milestone with both bots.
# On the alpha list (the 19 parts the default table offers) the same draws run; movement, the
# repeat cap, the neutral fallback and class parts are checked, and share, overlap and pairs are
# printed as measured. Overlap there cannot pass by arithmetic: Kest, Tarn and Cannon have the
# same 10-part common pool (no class part on the list), and the pattern guarantee adds Chain Arc,
# so each one's top-10 holds at least 9 of the same 11 parts and any two overlap at least 0.90.
# Whether SQ19 covers the alpha list is a coordinator ruling (2026-10-15).
# PAIRS (2026-10-15, SQ19): the pair line is asserted. Measured against it: every two-slot gate draw
# holds a part that hits harder (build_catalogue_test "gate pairs hit harder"), and no common part
# that hits harder sits in the defence bucket, so in every pilot's offers weapon + skill + movement
# is at least 50%. A defence + movement pair needs weapon and skill each below movement, which is
# at most 15%, so under 45% in all: no pilot can hold that pair, and six distinct pairs cannot all
# hold while the pair rule and the 15% movement cap stand. Tally declares that pair, so its pair
# checks stay red, and its weighted share with them: no common part that hits harder is in its
# kit, so the hitter in each gate pair is off-kit and its share sits near 0.37. Measured, not
# proven: Rivet's skill + movement pair loses to weapon, because the stage-2 pattern guarantee
# shows an off-kit pattern in each gate until the run holds one, and the greedy bot never takes
# it (weapon 0.215 greedy against movement 0.083). These checks wait on the coordinator's ruling.
# Evidence limit: the offer draw only. Whether each pilot still wins its bot
# runs is bot_six_*_test's claim, and how the lean feels is Andrew's to play.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const BUCKETS := ["weapon", "skill", "defence", "movement"]
const RUNS := 10
const STAGES := 4
const GATES_PER_STAGE := 5
const CHOICES := 2
const SHARE_BAND := [0.60, 0.80]
const OVERLAP_MAX := 0.5
const MOVEMENT_MAX := 0.15
const TOP := 10

var _t := preload("res://tests/support/t.gd").new("offer_weights_test")


func _initialize() -> void:
	Synergies.table = null
	_t.check("the full catalogue is unlisted", not Parts.listed_only(), "")
	_t.check("the kit share is a declared constant inside the band",
		Parts.KIT_SHARE >= SHARE_BAND[0] and Parts.KIT_SHARE <= SHARE_BAND[1], str(Parts.KIT_SHARE))
	_t.check("every pilot declares a kit of two buckets", PILOTS.all(func(p): return Parts.KITS.has(p) and Parts.KITS[p].size() == 2), "")
	var declared := {}
	for pilot in PILOTS:
		declared[str(_declared(pilot))] = pilot
	_t.check("the six kits declare six different bucket pairs", declared.size() == PILOTS.size(), str(declared))
	var defence_hitters := {}
	for pilot in PILOTS:
		for id in Parts.offer_pool(pilot, ["common"]):
			if Parts.def(id).hits_harder() and Parts.bucket_of(id) == "defence":
				defence_hitters[id] = true
	# The premise of the PAIRS note: if this goes red, re-measure the pair line before trusting it.
	_t.eq("no common part that hits harder is in the defence bucket (PAIRS premise)", defence_hitters.keys(), [])
	var full := _measure("full")
	_judge("full", full, true)
	_fallback("full")
	_keep_neutral()
	Synergies.table = AlphaDefs
	_t.check("the alpha table lists its parts", Parts.listed_only(), "")
	var alpha := _measure("alpha")
	_judge("alpha", alpha, false)
	_fallback("alpha")
	Synergies.table = null
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
							if id in Parts.NEUTRAL_SHELF and not Parts.in_kit(pilot, id):
								s["neutral_max"] = maxi(s["neutral_max"], offered[id])
						if not picks.is_empty():
							held.append(_pick(bot, pilot, picks, pick_rng))
			out[pilot][bot] = s
			print("[%s %s %s] draws %d slots %d kit share %.3f movement %.3f buckets %s neutral max/stage %d" % [label, pilot, bot,
				s["draws"], s["slots"], _share(s, "kit"), _bucket_share(s, "movement"), _bucket_shares(s), s["neutral_max"]])
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
			var in_band: bool = share >= SHARE_BAND[0] and share <= SHARE_BAND[1]
			if strict:
				_t.check("%s %s %s weighted share inside 60 to 80%%" % [label, pilot, bot], in_band, "%.3f" % share)
			else:
				print("[%s %s %s weighted share] %.3f (measured; %s the band)" % [label, pilot, bot, share, "inside" if in_band else "outside"])
			_t.check("%s %s %s movement at most 15%%" % [label, pilot, bot], _bucket_share(s, "movement") <= MOVEMENT_MAX, "%.3f" % _bucket_share(s, "movement"))
			_t.check("%s %s %s no neutral part over its repeat cap" % [label, pilot, bot], s["neutral_max"] <= Parts.NEUTRAL_REPEAT_CAP,
				"max %d a stage, cap %d" % [s["neutral_max"], Parts.NEUTRAL_REPEAT_CAP])
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
				_t.check("%s top-%d overlap %s and %s under 50%%" % [label, TOP, PILOTS[i], PILOTS[j]], overlap < OVERLAP_MAX, detail)
			else:
				print("[%s top-%d overlap %s and %s] %s (measured)" % [label, TOP, PILOTS[i], PILOTS[j], detail])
	for pilot in PILOTS:
		var others: Array = PILOTS.filter(func(p): return p != pilot).map(func(p): return pairs[p][0])
		var ok: bool = pairs[pilot][1] and not pairs[pilot][0] in others
		var detail := "%s, others %s" % [pairs[pilot][0], others]
		if strict:
			_t.check("%s %s dominant pair is its own" % [label, pilot], ok, detail)
			_t.eq("%s %s dominant pair is its declared kit" % [label, pilot], pairs[pilot][0], _declared(pilot))
		else:
			print("[%s %s dominant pair] %s, declared %s (measured; %s)" % [label, pilot, detail, _declared(pilot),
				"its own" if ok else "not its own"])
	var distinct := {}
	for pilot in PILOTS:
		distinct[str(pairs[pilot][0])] = true
	if strict:
		_t.check("%s six distinct dominant pairs" % label, distinct.size() == PILOTS.size(), "%d distinct: %s" % [distinct.size(), distinct.keys()])
	else:
		print("[%s dominant pairs] %d distinct of %d pilots (measured)" % [label, distinct.size(), PILOTS.size()])


func _declared(pilot: String) -> Array:
	var pair: Array = Parts.KITS[pilot].keys()
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
			if picks.any(func(id): return id in Parts.NEUTRAL_SHELF):
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
		var off: Array = pool.filter(func(id): return not Parts.in_kit(pilot, id) and not id in Parts.NEUTRAL_SHELF)
		var hitter: Array = off.filter(func(id): return Parts.def(id).hits_harder())
		var plain: Array = off.filter(func(id): return not Parts.def(id).hits_harder())
		var shelf: Array = pool.filter(func(id): return id in Parts.NEUTRAL_SHELF and not Parts.in_kit(pilot, id))
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
			picks[0] == hitter[0] and picks[1] in Parts.NEUTRAL_SHELF, "%s from %s" % [picks, [hitter[0], plain[0]]])
		var capped := {}
		for id in shelf:
			capped[id] = Parts.NEUTRAL_REPEAT_CAP
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
