extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# SQ19 (wave 14, comps/roboquest/classes-and-perks.md:82, comps/gunfire/heroes-and-ascensions.md:87):
# each pilot's offers lean to its own kit by Parts.KIT_SHARE, with a neutral shelf that never
# stalls a build. For every pilot, a greedy and a random bot each see 200 gate draws (25 runs of
# 4 stages, 2 gates a stage, through Parts.roll_gate with the stage's offered counts) and pick
# one part a draw. Checks, on the full authored catalogue:
#   - the weighted share (parts in Parts.in_kit) is inside 60 to 80% for every pilot and bot;
#   - the top-10 most-offered parts of any two pilots overlap under 50% (of the smaller top list);
#   - each pilot's two dominant buckets (Parts.bucket_of: weapon, skill, defence, movement) are a
#     pair no other pilot has, with the second bucket strictly above the third;
#   - movement is at most 15% of each pilot's offers;
#   - no neutral shelf part is offered more than Parts.NEUTRAL_REPEAT_CAP times in one stage;
#   - a draw with every kit part excluded still shows a neutral shelf part;
#   - no offer is another class's part;
#   - every pilot's upgrade tree reaches a depth-4 endpoint by the last milestone with both bots.
# On the alpha list (the 19 parts the default table offers) the same draws run; movement, the
# repeat cap, the neutral fallback and class parts are checked, and share, overlap and pairs are
# printed as measured. Evidence limit: the offer draw only. Whether each pilot still wins its bot
# runs is bot_six_*_test's claim, and how the lean feels is Andrew's to play.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const BUCKETS := ["weapon", "skill", "defence", "movement"]
const RUNS := 25
const STAGES := 4
const GATES_PER_STAGE := 2
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
	var full := _measure("full")
	_judge("full", full, true)
	_fallback("full")
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
							if id in Parts.NEUTRAL_SHELF:
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
		var score := (100.0 if Parts.in_kit(pilot, id) else 0.0) + (d.punch if d != null else 0.0)
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
			print("[%s %s dominant pair] %s (measured; %s)" % [label, pilot, detail, "its own" if ok else "not its own"])


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


# Every pilot's tree reaches a depth-4 endpoint by the last milestone, picking the first child
# (greedy) or a random child at each of the four picks.
func _trees() -> void:
	var cap := UpgradeTree.depth_cap(3)
	_t.eq("the last milestone opens depth 4", cap, UpgradeTree.DEPTHS)
	for pi in PILOTS.size():
		var pilot: String = PILOTS[pi]
		var list := UpgradeTree.nodes(pilot)
		for bot in ["greedy", "random"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5100 + pi
			var reached := 0
			for _run in RUNS:
				var index := rng.randi_range(0, 1)
				if bot == "greedy":
					index = 0
				for _depth in range(1, cap):
					var kids := UpgradeTree.children_of(index)
					index = kids[0] if bot == "greedy" else kids[rng.randi_range(0, 1)]
				if index < list.size() and UpgradeTree.depth_of(index) == UpgradeTree.DEPTHS \
						and UpgradeTree.children_of(index)[0] >= list.size():
					reached += 1
			_t.check("%s %s bot reaches a tree endpoint by the last milestone" % [pilot, bot], reached == RUNS,
				"%d of %d runs, %d nodes" % [reached, RUNS, list.size()])
