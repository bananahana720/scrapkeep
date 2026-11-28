extends SceneTree

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeProblems := preload("res://tests/support/tree_problems.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")

# The three upgrade trees as data, with no game running: 30 sound nodes each (ids,
# names of at most 3 words, effects of at most 8, a key, an existing ab_ icon, known ops,
# procs on real bus facts that cannot loop within a build), 2, 4, 8 and 16 nodes by
# depth, every one of the 16 leaves reached by four picks through the pick API, the API
# refusing picks it did not offer, no cooldown or repeat under the 0.4 s floor on any
# build, and branch_tags read-only.
#
# Evidence limit: data and API only. tree_apply_test checks the effects in a live game.
# Re-pinned 2026-10-10 for the skill bar (design-v3/SKILL-BAR.md sections 1 and 12, wave P-B
# unit B1): a node's key may be line or ultimate, a swap may name the ultimate, the
# validators read SWAPPABLE (the five slots plus the ultimate), a swap that replaces the
# held ultimate with an unrelated row is still refused, and apply_pick puts a swapped
# ultimate in Q's place without touching a slot.

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	for def in ClassDef.all():
		_structure(def)
		_leaves(def)
		_floors(def)
	_guards()
	_skill_bar()
	print("tree_data_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _structure(def) -> void:
	var list := UpgradeTree.nodes(def.id)
	var problems := TreeProblems.problems(def.id)
	_report("%s nodes" % def.display_name, list.size() == 30 and problems.is_empty(),
		"%d nodes; problems %s" % [list.size(), problems])
	var by_depth := [0, 0, 0, 0, 0]
	var keys := {}
	var missing := []
	for i in list.size():
		by_depth[UpgradeTree.depth_of(i)] += 1
		keys[list[i]["key"]] = true
		if not FileAccess.file_exists("res://assets/icons/%s.svg" % list[i]["icon"]):
			missing.append(list[i]["icon"])
	_report("%s depths" % def.display_name, by_depth == [0, 2, 4, 8, 16], "nodes by depth 1 to 4: %s" % [by_depth.slice(1)])
	_report("%s keys" % def.display_name, keys.size() == 4, "keys touched: %s" % [keys.keys()])
	_report("%s icons" % def.display_name, missing.is_empty(), "icons without an SVG: %s" % [missing])
	var number_only := []
	for n in list:
		var behaviour: bool = n.has("swap") or n.has("knob") or n.has("proc") or n.has("charges")
		for w in n.get("pattern", {}):
			behaviour = behaviour or n["pattern"][w].has("add")
		if not behaviour:
			number_only.append(n["id"])
	_report("%s picks change play" % def.display_name, number_only.is_empty(),
		"nodes that only scale a number: %s" % [number_only])


# Every combination of four left-or-right picks, through offered() and pick().
func _leaves(def) -> void:
	var reached := {}
	var off_offer := 0
	var events_ok := true
	for combo in 16:
		var tree := UpgradeTree.new()
		tree.reset(def.id)
		for depth in range(1, 5):
			tree.open_checkpoint()
			var pair: Array = tree.offered(def.id, depth)
			if pair.size() != 2:
				off_offer += 1
				break
			var choice: Dictionary = pair[(combo >> (depth - 1)) & 1]
			if not tree.pick(choice["id"]):
				off_offer += 1
		var path := tree.path()
		events_ok = events_ok and path.size() == 4 and UpgradeTree.path_to(def.id, path[3]) == path
		reached[UpgradeTree.index_of(def.id, path[3]) if path.size() == 4 else -1] = true
	var leaves := range(14, 30)
	var all_leaves: bool = reached.size() == 16 and leaves.all(func(i): return reached.has(i))
	_report("%s 16 leaves" % def.display_name, all_leaves and off_offer == 0 and events_ok,
		"%d distinct leaves from 16 pick sequences, %d refused picks, paths match path_to: %s"
			% [reached.size(), off_offer, events_ok])


# No build takes a cooldown, a timed repeat or a proc gap under the 0.4 s floor.
func _floors(def) -> void:
	var lowest := INF
	var where := ""
	for leaf in range(14, 30):
		var tree := UpgradeTree.new()
		tree.reset(def.id)
		var abilities := AbilityState.new()
		abilities.fit(def)
		for id in UpgradeTree.path_to(def.id, UpgradeTree.nodes(def.id)[leaf]["id"]):
			tree.open_checkpoint()
			tree.pick(id)
			UpgradeTree.apply_pick(abilities, UpgradeTree.node(def.id, id))
		for slot in AbilityState.SLOTS:
			var cd: float = abilities.cooldown_of(slot)
			if abilities.slot(slot).cooldown > 0.0 and cd < lowest:
				lowest = cd
				where = "%s cooldown on %s" % [slot, tree.path()]
		for k in UpgradeTree.KNOBS:
			var v = tree.knob(k)
			if UpgradeTree.KNOBS[k].get("time", false) and float(v) > 0.0 and float(v) < lowest:
				lowest = float(v)
				where = "%s on %s" % [k, tree.path()]
		for p in tree.procs():
			if float(p["gap"]) < lowest:
				lowest = float(p["gap"])
				where = "%s gap on %s" % [p["node"], tree.path()]
	_report("%s cooldown floor" % def.display_name, lowest >= AbilityState.COOLDOWN_FLOOR,
		"lowest repeat across the 16 builds %.2f s (%s), floor %.1f s" % [lowest, where, AbilityState.COOLDOWN_FLOOR])


func _skill_bar() -> void:
	_report("keys gain line and ultimate", UpgradeTree.KEYS.has("line") and UpgradeTree.KEYS.has("ultimate"), str(UpgradeTree.KEYS))
	_report("SWAPPABLE is the five slots plus the ultimate", AbilityState.SWAPPABLE == AbilityState.SLOTS + ["ultimate"]
		and AbilityState.SLOTS.size() == 5 and not AbilityState.SLOTS.has("ultimate"), str(AbilityState.SWAPPABLE))
	# The held ultimate comes from Sable's class row, so the fixture holds after her kit ships one.
	var held_ult: String = ClassDef.by_id("pylon_engineer").ultimate_id
	var held := UpgradeTree.safe_pick_problems("pylon_engineer", {"id": "fixture_keep", "swap": {"ultimate": held_ult}})
	var replaced := UpgradeTree.safe_pick_problems("pylon_engineer", {"id": "fixture_replace", "swap": {"ultimate": "line_reel"}})
	_report("an ultimate swap is checked against the held ultimate", held.is_empty() and replaced.size() == 1,
		"keep %s, replace %s" % [held, replaced])
	var a := AbilityState.new()
	a.fit(ClassDef.by_id("pylon_engineer"))
	var before: Array = AbilityState.SLOTS.map(func(s): return a.id_of(s))
	UpgradeTree.apply_pick(a, {"swap": {"ultimate": "line_reel"}})
	_report("apply_pick swaps the ultimate in Q's place only", a.ultimate_id == "line_reel"
		and AbilityState.SLOTS.map(func(s): return a.id_of(s)) == before, "ultimate %s" % a.ultimate_id)


func _guards() -> void:
	var tree := UpgradeTree.new()
	tree.reset("runner_gunner")
	var closed: bool = not tree.pick("r_gunline")
	tree.open_checkpoint()
	var wrong: bool = not tree.pick("r_tracer") and not tree.pick("s_cannonball")
	var other_class: bool = tree.offered("pylon_engineer", 1).is_empty()
	var took: bool = tree.pick("r_juggernaut")
	var one_only: bool = not tree.pick("r_ram_fins")
	var tags := tree.branch_tags()
	tags.append("changed")
	var read_only: bool = not tree.branch_tags().has("changed") and tree.branch_tags().has("close")
	tree.open_checkpoint()
	var left_child: bool = not tree.pick("r_tracer") and tree.pick("r_second_wind")
	tree.reset("runner_gunner")
	var cleared: bool = tree.path().is_empty() and tree.branch_tags().is_empty() and tree.procs().is_empty() \
		and tree.knob("sprint_no_rebound") == false
	_report("pick guards", closed and wrong and other_class and took and one_only and read_only and left_child and cleared,
		"refused before a checkpoint %s, off-offer %s, other class offers nothing %s, took the offer %s, one per checkpoint %s, tags read-only %s, depth 2 offers only the pick's children %s, reset clears %s"
			% [closed, wrong, other_class, took, one_only, read_only, left_child, cleared])
	var bus = GameEvents.new()
	var offers := []
	bus.tree_offered.connect(func(_c: String, depth: int, ids: Array): offers.append([depth, ids]))
	var late := UpgradeTree.new(bus)
	late.reset("demolitions_caster")
	late.open_checkpoint()
	late.open_checkpoint()
	var caught_up: bool = late.pick("k_ghost") and late.pending() and late.pick("k_ambush") and not late.pending()
	_report("skipped pick", caught_up and offers == [[1, ["k_trapper", "k_ghost"]], [1, ["k_trapper", "k_ghost"]], [2, ["k_smoke_trail", "k_ambush"]]],
		"start pick skipped, then two open at the first workshop: offers %s, both taken %s" % [offers, caught_up])
	bus.free()
