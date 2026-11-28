extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const T := preload("res://tests/support/t.gd")

# The cobalt rung's Warden floor (item ladder, wave 20; card B option 1): every Warden gate
# pair on the world 1 table holds a rare or better at any core count, stage 2's pattern
# guarantee still lands, and a pair that already holds a cobalt is left as rolled. A planted
# all-common pair is lifted, and the lifted pick is never one the pair already offers.
# W1-64: the floor's cobalt changes behaviour (a trigger, a pattern or an element), so a pair
# whose only rare is a stat line has that rare replaced, keeping the pair's harder hitter. A relic
# outranks the floor and is never traded down.
# smoke: timeout=120s

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const SEEDS := 60

var _t := T.new("cobalt_floor_test")


func _initialize() -> void:
	var before = Synergies.table
	Synergies.set_table(ParkDefs)
	_pairs()
	_planted()
	Synergies.set_table(before)
	quit(_t.verdict())


func _pairs() -> void:
	var dry: Array = []
	var flat: Array = []
	var no_hitter: Array = []
	var lost_pattern: Array = []
	var rows := 0
	for pilot in PILOTS:
		for cores in 3:
			for stage in [1, 2, 3]:
				for s in SEEDS:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([pilot, cores, stage, s])
					var picks: Array = PartOffers.roll_gate(rng, PartOffers.gate_rarities(cores), pilot, [], 2, stage, {}, Parts.offer_ops())
					var had_pattern: bool = picks.any(func(key): return key in PartOffers.PATTERN_PARTS)
					var floored: Array = PartOffers.floor_gate(rng, picks, pilot, [], {}, 2, Parts.offer_ops())
					rows += 1
					if not floored.any(func(key): return PartOffers.rung_of(key, Parts.def) >= PartOffers.RUNG_FLOOR):
						dry.append("%s %d cores stage %d seed %d %s" % [pilot, cores, stage, s, floored])
					if not floored.any(func(key): return PartOffers.rung_of(key, Parts.def) > PartOffers.RUNG_FLOOR or PartOffers.rung_of(key, Parts.def) == PartOffers.RUNG_FLOOR and PartOffers.changes_behaviour(key, Parts.def)):
						flat.append("%s %d cores stage %d seed %d %s" % [pilot, cores, stage, s, floored])
					if picks.any(func(key): return Parts.def(key).hits_harder()) and not floored.any(func(key): return Parts.def(key).hits_harder()):
						no_hitter.append("%s stage %d seed %d %s to %s" % [pilot, stage, s, picks, floored])
					if had_pattern and not floored.any(func(key): return key in PartOffers.PATTERN_PARTS):
						lost_pattern.append("%s stage %d seed %d" % [pilot, stage, s])
	_t.check("every gate pair holds a cobalt or better", dry.is_empty(), "%d pairs, dry %s" % [rows, dry.slice(0, 3)])
	_t.check("every gate pair holds a behaviour cobalt or a relic", flat.is_empty(), "%d pairs, flat %s" % [rows, flat.slice(0, 3)])
	_t.check("the floor keeps a pair's harder hitter", no_hitter.is_empty(), str(no_hitter.slice(0, 3)))
	_t.check("the floor never takes stage 2's pattern", lost_pattern.is_empty(), str(lost_pattern.slice(0, 3)))


func _planted() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var commons := ["focus_lens", "hot_rivets"]
	var lifted: Array = PartOffers.floor_gate(rng, commons, "tarn", [], {}, 2, Parts.offer_ops())
	_t.check("an all-common pair is lifted", PartOffers.rung_of(lifted[0], Parts.def) >= PartOffers.RUNG_FLOOR and lifted[1] == "hot_rivets", str(lifted))
	_t.check("the lifted pick is new to the pair", not lifted[0] in commons, str(lifted))
	var with_pattern: Array = PartOffers.floor_gate(rng, ["cross_split", "hot_rivets"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.eq("a pattern in the first slot keeps its place", with_pattern[0], "cross_split")
	var kept := ["focus_lens", "sunforged_core"]
	_t.eq("a pair holding a behaviour cobalt stays as rolled", PartOffers.floor_gate(rng, kept, "tarn", [], {}, 2, Parts.offer_ops()), kept)
	var stat: Array = PartOffers.floor_gate(rng, ["focus_lens", "gatling_heart"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.check("a stat-line cobalt is replaced by a behaviour one", stat[0] == "focus_lens" and stat[1] != "gatling_heart"
		and PartOffers.rung_of(stat[1], Parts.def) >= PartOffers.RUNG_FLOOR and PartOffers.changes_behaviour(stat[1], Parts.def), str(stat))
	var lone_hitter: Array = PartOffers.floor_gate(rng, ["grip_tread", "ram_plow"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.check("the stat cobalt's replacement hits harder when it was the pair's only hitter",
		Parts.def(lone_hitter[1]).hits_harder() and PartOffers.changes_behaviour(lone_hitter[1], Parts.def), str(lone_hitter))
	var relic: Array = PartOffers.floor_gate(rng, ["spare_frame", "gatling_heart"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.check("a relic in the pair is never traded down", relic[0] == "spare_frame" and PartOffers.changes_behaviour(relic[1], Parts.def), str(relic))
	var relic_pattern: Array = PartOffers.floor_gate(rng, ["spare_frame", "cross_split"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.eq("a relic beside a pattern pair stays as rolled", relic_pattern, ["spare_frame", "cross_split"])
	for row in ["sunforged_core", "spare_cell"]:
		_t.check("%s changes behaviour" % row, PartOffers.changes_behaviour(row, Parts.def), row)
	_t.eq("an empty pair stays empty", PartOffers.floor_gate(rng, [], "tarn", [], {}, 2, Parts.offer_ops()), [])
	var short: Array = PartOffers.floor_gate(rng, ["spiral_wave"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.check("a lone pattern keeps its gate and gains a cobalt", short.size() == 2 and short[0] == "spiral_wave"
		and PartOffers.rung_of(short[1], Parts.def) >= PartOffers.RUNG_FLOOR, str(short))
	var patterns: Array = PartOffers.floor_gate(rng, ["spiral_wave", "chain_arc"], "tarn", [], {}, 2, Parts.offer_ops())
	_t.check("a pair of patterns keeps its first", patterns[0] == "spiral_wave" and PartOffers.rung_of(patterns[1], Parts.def) >= PartOffers.RUNG_FLOOR, str(patterns))
