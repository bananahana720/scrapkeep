extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const T := preload("res://tests/support/t.gd")

# The cobalt rung's Warden floor (item ladder, wave 20; card B option 1): every Warden gate
# pair on the world 1 table holds a rare or better at any core count, stage 2's pattern
# guarantee still lands, and a pair that already holds a cobalt is left as rolled. A planted
# all-common pair is lifted, and the lifted pick is never one the pair already offers.
# smoke: timeout=120s

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const SEEDS := 60

var _t := T.new("cobalt_floor_test")


func _initialize() -> void:
	var before = Synergies.table
	Synergies.table = ParkDefs
	_pairs()
	_planted()
	Synergies.table = before
	quit(_t.verdict())


func _pairs() -> void:
	var dry: Array = []
	var lost_pattern: Array = []
	var rows := 0
	for pilot in PILOTS:
		for cores in 3:
			for stage in [1, 2, 3]:
				for s in SEEDS:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([pilot, cores, stage, s])
					var picks: Array = Parts.roll_gate(rng, Parts.gate_rarities(cores), pilot, [], 2, stage)
					var had_pattern: bool = picks.any(func(key): return key in Parts.PATTERN_PARTS)
					var floored: Array = Parts.floor_gate(rng, picks, pilot, [])
					rows += 1
					if not floored.any(func(key): return Parts.rung_of(key) >= Parts.RUNG_FLOOR):
						dry.append("%s %d cores stage %d seed %d %s" % [pilot, cores, stage, s, floored])
					if had_pattern and not floored.any(func(key): return key in Parts.PATTERN_PARTS):
						lost_pattern.append("%s stage %d seed %d" % [pilot, stage, s])
	_t.check("every gate pair holds a cobalt or better", dry.is_empty(), "%d pairs, dry %s" % [rows, dry.slice(0, 3)])
	_t.check("the floor never takes stage 2's pattern", lost_pattern.is_empty(), str(lost_pattern.slice(0, 3)))


func _planted() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var commons := ["focus_lens", "hot_rivets"]
	var lifted: Array = Parts.floor_gate(rng, commons, "tarn", [])
	_t.check("an all-common pair is lifted", Parts.rung_of(lifted[0]) >= Parts.RUNG_FLOOR and lifted[1] == "hot_rivets", str(lifted))
	_t.check("the lifted pick is new to the pair", not lifted[0] in commons, str(lifted))
	var with_pattern: Array = Parts.floor_gate(rng, ["cross_split", "hot_rivets"], "tarn", [])
	_t.eq("a pattern in the first slot keeps its place", with_pattern[0], "cross_split")
	var kept := ["focus_lens", "sunforged_core"]
	_t.eq("a pair holding a cobalt stays as rolled", Parts.floor_gate(rng, kept, "tarn", []), kept)
	_t.eq("an empty pair stays empty", Parts.floor_gate(rng, [], "tarn", []), [])
