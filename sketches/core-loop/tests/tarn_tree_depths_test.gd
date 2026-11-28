# 2026-10-11 (PC-TARN): 507 to 511 checks; cover registry ultimate swaps and preserve cooldown/charge slot limits.
extends SceneTree

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeProblems := preload("res://tests/support/tree_problems.gd")
const Tarn := preload("res://src/core/trees/tarn.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Cards := preload("res://src/core/trees/world_one_cards.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Triggers := preload("res://src/build/triggers.gd")
const Registry := preload("res://tests/support/content_registry.gd")
const T := preload("res://tests/support/t.gd")

# PC-TARN, 2026-10-11. Expected: 511 checks. Tree nodes are one-copy capped picks;
# sweep 1..20 attempts per leaf through pick(), not just their metadata. No new loot/proc.
const EXPECTED_CHECKS := 511


func _initialize() -> void:
	var t := T.new("tarn_tree_depths_test")
	var nodes: Array = Tarn.NODES
	t.eq("30 nodes retain heap order", nodes.size(), 30)
	t.eq("Tarn tree has no structural or proc-loop problems", TreeProblems.problems("tarn"), [])
	t.eq("Tarn has no unsafe route", UpgradeTree.safe_growth_problems("tarn"), [])
	t.eq("proc chain cap remains one", Triggers.MAX_CHAIN_DEPTH, 1)
	for n in nodes:
		t.check("%s effect word cap" % n["id"], String(n["effect"]).split(" ", false).size() <= 8)
	for i in range(6, 30):
		var n: Dictionary = nodes[i]
		t.check("%s capped and pilot local" % n["id"], n.get("stack_rule") in PartDef.STACK_RULES and n["stack_rule"] == "capped" and n.get("class_id") == "tarn")
	for i in range(6, 14):
		var n: Dictionary = nodes[i]
		var variant := "rake_run" if i < 10 else "vice_leap"
		t.eq("%s road swaps ultimate" % n["id"], n["swap"], {"ultimate": variant})
		t.eq("%s variant grows base" % variant, AbilityState.ABILITIES[variant]["variant_of"], "redjaw_rend")
		t.check("%s card names set piece" % n["id"], not Cards.set_piece_line(n).is_empty())
	for i in range(14, 30):
		var n: Dictionary = nodes[i]
		t.eq("%s exactly one knob" % n["id"], n["knob"].size(), 1)
		t.check("%s framework ult knob" % n["id"], n["knob"].keys().all(func(k): return String(k).begins_with("ult_") and UpgradeTree.KNOBS.has(k)))
		t.check("%s depth four card line" % n["id"], not Cards.set_piece_line(n).is_empty())
	for i in range(14, 30, 2):
		t.check("%s siblings differ" % nodes[i]["id"], nodes[i]["knob"].keys() != nodes[i + 1]["knob"].keys())
	for i in range(14, 30):
		var leaf: Dictionary = nodes[i]
		var tree := UpgradeTree.new()
		tree.max_depth = 4
		tree.reset("tarn")
		tree.allowed = 4
		var abilities := AbilityState.new()
		abilities.fit(ClassDef.by_id("tarn"))
		var path := UpgradeTree.path_to("tarn", leaf["id"])
		var live := true
		for id in path:
			live = tree.pick(id) and live
			UpgradeTree.apply_pick(abilities, UpgradeTree.node("tarn", id))
		t.check("%s whole route is pickable" % leaf["id"], live and tree.picks.size() == 4)
		var variant: String = nodes[i / 2 - 1]["swap"]["ultimate"]
		t.eq("%s runtime ultimate swaps" % leaf["id"], abilities.ultimate_id, variant)
		var knob: String = leaf["knob"].keys()[0]
		t.eq("%s runtime knob resolves" % leaf["id"], tree.knob(knob), leaf["knob"][knob])
		var before := [tree.path(), tree.knob(knob), abilities.ultimate_id, abilities.cooldown_of("movement")]
		for copies in range(1, 21):
			var accepted := tree.pick(leaf["id"])
			t.check("%s copy %d remains capped" % [leaf["id"], copies], not accepted and before == [tree.path(), tree.knob(knob), abilities.ultimate_id, abilities.cooldown_of("movement")])
	_registry_slots(t)
	t.eq("expected check count", t.checks + 1, EXPECTED_CHECKS)
	quit(t.verdict())


func _registry_slots(t) -> void:
	var tables := Registry.snapshot()
	var rows: Dictionary = tables["upgrade_tree.TREES"]
	t.eq("registry resolves Tarn's ultimate swaps", Registry.validate_table("upgrade_tree.TREES", rows, tables, false), [])
	for op in ["charges", "cooldown"]:
		var changed := rows.duplicate(true)
		changed["tarn"][6][op] = {"ultimate": 1}
		var issues := Registry.validate_table("upgrade_tree.TREES", changed, tables, false)
		t.check("ultimate stays outside registry %s slots" % op, issues.any(func(issue): return issue.rule == "references" and issue.detail.contains("slot 'ultimate'")))
	var changed := rows.duplicate(true)
	changed["tarn"][6]["swap"] = {"missing_slot": "rake_run"}
	var issues := Registry.validate_table("upgrade_tree.TREES", changed, tables, false)
	t.check("registry still rejects unknown swap slots", issues.any(func(issue): return issue.rule == "references" and issue.detail.contains("slot 'missing_slot'")))
