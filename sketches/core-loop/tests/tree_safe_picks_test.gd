extends SceneTree

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Rule: four safe growth picks cannot replace an ability, disable it, lower a knob's
# default, or undo an earlier pick. Validate all 90 distinct nodes plus Tarn's 30
# borrowed rows. Existing tradeoffs are findings, not permission to change content.
# Decision 3 is pending: numerical decreases are conservatively flagged even when
# they help. These tests prove detection, not that the present trees are all safe.
# No Game, wall clock, save writes, or runtime/feel claim is needed for this rule.

const UNSAFE := {
	"pylon_engineer": ["s_face_runner", "s_crater"],
	"runner_gunner": ["r_run_gun", "r_ram_fins", "r_point_blank", "r_skyline"],
	"demolitions_caster": ["k_ghost", "k_heavy_charge", "k_sticky_rain"],
	"tarn": ["r_run_gun", "r_ram_fins", "r_point_blank", "r_skyline"],
}

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	var checked := 0
	var distinct := {}
	var pilots := []
	for def in ClassDef.all():
		pilots.append(def.id)
		var list := UpgradeTree.nodes(def.id)
		var before := list.duplicate(true)
		var flagged := []
		var findings: Array[String] = []
		var safe_routes := 0
		for i in list.size():
			checked += 1
			distinct[list[i]["id"]] = true
			var earlier := _earlier(list, i)
			var issues := UpgradeTree.safe_pick_problems(def.id, list[i], earlier)
			findings.append_array(issues)
			if not issues.is_empty():
				flagged.append(list[i]["id"])
			if UpgradeTree.depth_of(i) == UpgradeTree.DEPTHS:
				var route_ok := issues.is_empty()
				var prior: Array = []
				for n in earlier:
					route_ok = route_ok and UpgradeTree.safe_pick_problems(def.id, n, prior).is_empty()
					prior.append(n)
				if route_ok:
					safe_routes += 1
		_report(def.display_name, list.size() == 30 and flagged == UNSAFE.get(def.id, []),
			"30 nodes; flagged %s; %d four-pick routes preserve swaps/knobs" % [flagged, safe_routes])
		_report("%s whole-tree validator" % def.display_name,
			UpgradeTree.safe_growth_problems(def.id) == findings, "%d findings" % findings.size())
		for finding in findings:
			print("FINDING %s: %s" % [def.display_name, finding])
		var world_one: Array[String] = []
		for i in UpgradeTree.WORLD_ONE_SIZE:
			var profile := UpgradeTree.nodes(def.id, true)
			world_one.append_array(UpgradeTree.safe_pick_problems(def.id, profile[i], _earlier(profile, i)))
		_report("%s world one" % def.display_name,
			UpgradeTree.safe_growth_problems(def.id, true) == world_one, "%d reachable-node findings" % world_one.size())
		_report("%s data preserved" % def.display_name, list == before, "validator never edits nodes")
	_report("all four pilots", pilots == UNSAFE.keys() and checked == 120 and distinct.size() == 90,
		"%d rows, %d distinct nodes, pilots %s" % [checked, distinct.size(), pilots])
	_fixtures()
	print("tree_safe_picks_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _earlier(list: Array, index: int) -> Array:
	var out: Array = []
	var parent: int = (index - 2) / 2 if index >= 2 else -1
	while parent >= 0:
		out.push_front(list[parent])
		parent = (parent - 2) / 2 if parent >= 2 else -1
	return out


func _fixtures() -> void:
	var pilot := "pylon_engineer"
	var bad := {"id": "bad_fixture", "swap": {"movement": "rapid_laser"}, "knob": {"mount_reach": 0.5}}
	var issues := UpgradeTree.safe_pick_problems(pilot, bad)
	_report("bad fixture rejected", issues.size() == 2 and issues[0].contains("replaces ability grapple")
		and issues[1].contains("lowers default"), str(issues))
	_report("additive fixture accepted", UpgradeTree.safe_pick_problems(pilot,
		{"id": "safe_fixture", "swap": {"movement": "grapple"}, "knob": {"mount_reach": 2.0, "vault_air": true}}).is_empty(),
		"identity swap, increased reach, new air jump")
	_report("earlier numeric pick preserved", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"mount_reach": 1.5}}, [{"knob": {"mount_reach": 2.0}}]).is_empty(), "above default still undoes earlier growth")
	_report("earlier ability preserved", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"vault_air": false}}, [{"knob": {"vault_air": true}}]).is_empty(), "false removes the earlier air jump")
	_report("replacement with richer kit rejected", not UpgradeTree.safe_pick_problems("demolitions_caster",
		{"swap": {"movement": "grapple"}}).is_empty(), "more augments cannot compensate for losing blink, glide, rocket and cloak")
	_report("unknown swap rejected", not UpgradeTree.safe_pick_problems(pilot,
		{"swap": {"weapon": "missing_ability"}}).is_empty(), "missing ability row")
	_report("unknown knob rejected", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"missing_knob": 1.0}}).is_empty(), "missing default cannot be certified safe")
	_report("boolean type checked", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"vault_air": 0}}).is_empty(), "numeric zero cannot disguise a disabled boolean")
	_report("numeric type checked", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"mount_reach": "two"}}).is_empty(), "string cannot disguise a lower number")
	_report("finite number checked", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"mount_reach": NAN}}).is_empty(), "NaN cannot evade comparison")
