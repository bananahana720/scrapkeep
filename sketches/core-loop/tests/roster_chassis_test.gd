extends SceneTree

const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# SQ4, the roster's chassis column (W13-INTEGRATION-3, comps/roboquest/enemy-design-grammar.md
# "A family is a chassis class plus a movement class plus one read"): every roster row names
# its chassis class, its movement class and one threat feature that is also its warning.
# - the three fields exist on the 21 base rows (19 plus the Linker and the jolt layer) and on every declared later-world row;
# - chassis and movement class come from the closed vocabularies in roster.gd;
# - a blank threat feature fails the check (a planted blank row proves it);
# - no two rows share a threat feature, the no-reskins rule at the silhouette level.
# The blind still test (20 stills, three reviewers) is a human pass; this file holds the data.

const BASE_ROW_COUNT := 21
const MIN_FEATURE_CHARS := 12

var _t := T.new("roster_chassis_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _run() -> void:
	_t.eq("base rows", Roster.BASE_ROWS.size(), BASE_ROW_COUNT)
	var kinds := {}
	var features := {}
	var bad := []
	for id in Roster.ROWS:
		var problems: Array = Roster.chassis_problems(Roster.ROWS[id])
		if not problems.is_empty():
			bad.append("%s: %s" % [id, ", ".join(problems)])
		var feature := String(Roster.ROWS[id].get("threat_feature", "")).strip_edges()
		_t.check("feature length %s" % id, feature.length() >= MIN_FEATURE_CHARS, feature)
		features[feature] = int(features.get(feature, 0)) + 1
		var chassis := String(Roster.ROWS[id].get("chassis", ""))
		kinds[chassis] = int(kinds.get(chassis, 0)) + 1
	_t.check("every row names chassis, move class and threat feature", bad.is_empty(), "; ".join(bad))
	for id in Roster.BASE_ROWS:
		_t.check("base row has fields %s" % id, Roster.ROWS.has(id) and Roster.chassis_problems(Roster.ROWS[id]).is_empty())
	_t.eq("no two rows share a threat feature", features.size(), Roster.ROWS.size())
	print("chassis counts: %s" % var_to_str(kinds))
	# Positive control: the validator must flag a blank feature and an unknown class.
	var blank: Dictionary = Roster.ROWS["chaser"].duplicate()
	blank["threat_feature"] = "  "
	_t.check("blank threat feature fails", not Roster.chassis_problems(blank).is_empty())
	var odd: Dictionary = Roster.ROWS["chaser"].duplicate()
	odd["chassis"] = "tank"
	odd["move_class"] = "teleport"
	_t.check("unknown chassis and move class fail", Roster.chassis_problems(odd).size() == 2)
	var missing: Dictionary = Roster.ROWS["chaser"].duplicate()
	missing.erase("chassis")
	_t.check("missing chassis fails", not Roster.chassis_problems(missing).is_empty())
