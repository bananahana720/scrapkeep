extends SceneTree

const Gen := preload("res://tools/monster_heft_gen.gd")
const MonsterHeft := preload("res://src/combat/monster_heft.gd")

# The monster-heft threshold per stage is generated from the lib-base index (tools/monster_heft_gen.gd)
# and stored in data/challenge/monster_heft.json; this regenerates it and fails on drift, so the data
# is never hand-tuned (coordinator ruling (B) on #222, 21 Oct).
const TOLERANCE := 0.0005

var _t := preload("res://tests/support/t.gd").new("monster_heft_test")


func _initialize() -> void:
	var index := Gen.load_index()
	_t.check("the lib-base index loads", index.size() == 155, str(index.size()))
	var fresh := Gen.document(index)
	var stored = JSON.parse_string(FileAccess.get_file_as_string(Gen.OUT_PATH))
	_t.check("the stored file parses", stored is Dictionary, "")
	if not stored is Dictionary:
		quit(_t.verdict())
		return
	for level in ["entrances", "wardens"]:
		var want: Dictionary = fresh[level]
		var got: Dictionary = stored.get(level, {}) if stored.get(level) is Dictionary else {}
		_t.eq("%s has every generated stage" % level, got.size(), want.size())
		for key in want:
			_t.check("%s %s matches the regenerated value" % [level, key], absf(float(got.get(key, -1.0)) - float(want[key])) <= TOLERANCE, "stored %s regenerated %.3f" % [got.get(key), float(want[key])])
	for fight in ["waking", "mind"]:
		_t.check("%s matches the regenerated value" % fight, absf(float(stored.get(fight, -1.0)) - float(fresh[fight])) <= TOLERANCE, "stored %s regenerated %.3f" % [stored.get(fight), float(fresh[fight])])
	var entrances: Dictionary = fresh["entrances"]
	_t.check("entrances never fall with the stage", _rises(entrances), str(entrances))
	for stage in range(1, 6):
		_t.check("w%d takes the next entrance s%d" % [stage, stage + 1], fresh["wardens"][str(stage)] == entrances[str(stage + 1)], "")
	_t.check("w6 has no threshold (no s7, none ruled)", not fresh["wardens"].has("6"), str(fresh["wardens"].keys()))
	_t.check("w6 fails closed through MonsterHeft", is_inf(MonsterHeft.threshold_for_stage(6)), str(MonsterHeft.threshold_for_stage(6)))
	_t.check("the Waking takes its own entrance s4", fresh["waking"] == entrances["4"], "")
	_t.check("the Mind takes its own entrance s6", fresh["mind"] == entrances["6"], "")
	for stage in range(1, 6):
		_t.check("w%d loads through MonsterHeft" % stage, absf(MonsterHeft.threshold_for_stage(stage) - float(fresh["wardens"][str(stage)])) <= TOLERANCE, "")
	_t.check("the loader's Waking and Mind match", absf(MonsterHeft.waking_threshold() - float(fresh["waking"])) <= TOLERANCE and absf(MonsterHeft.mind_threshold() - float(fresh["mind"])) <= TOLERANCE, "")
	_t.check("an unknown stage fails closed to INF", is_inf(MonsterHeft.threshold_for_stage(0)) and is_inf(MonsterHeft.threshold_for_stage(7)), "")
	quit(_t.verdict())


func _rises(values: Dictionary) -> bool:
	var last := 0.0
	for stage in range(1, 7):
		if not values.has(str(stage)) or float(values[str(stage)]) < last:
			return false
		last = float(values[str(stage)])
	return true
