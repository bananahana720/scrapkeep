extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const RunState := preload("res://src/core/run_state.gd")
const TreeCard := preload("res://src/ui/tree_card.gd")
const T := preload("res://tests/support/t.gd")

# The late forced-or-skip offer (W13-INTEGRATION-3 SG8), wave 14 unit SG8, round 3, 2026-10-15.
# With UpgradeTree.late_offer on, depth 4 opens with one take_or_skip item: an endpoint from the
# neighbouring depth-3 branch, never one of the run's own depth-4 pair. Take it and it is the
# fourth pick. Skip it (free) and the ordinary depth-4 pair opens, so the run still makes its
# fourth pick (BIBLE.md:538, coordinator ruling L1); the skipped item never returns and nothing
# rerolls it. The skip rides the entrance save beside tree_picks and tree_allowed (L2).
# Two named policies, always-take and always-skip, 200 draws per pilot each (L3); a draw's seeded
# stream only chooses the path to depth 3, never the late decision.
# Evidence limit: the tree's rules, the card's prompt and the save round trip, headless. Win
# rates per policy come from the bot_run --late-offer sweep, not from this file.

const DRAWS := 200
const SEED := 20261014
const POLICIES := ["always-take", "always-skip"]
# The API check, 8 shared checks, 6 pilots x (4 path checks + 2 policies x 3 checks + 4 save
# checks), and the count check itself.
const EXPECTED_CHECKS := 1 + 8 + 6 * (4 + 2 * 3 + 4) + 1


class Bus:
	extends RefCounted
	signal tree_offered(class_id: String, depth: int, choices: Array)
	signal tree_picked(class_id: String, node_id: String, depth: int)
	var offers: Array = []
	var picked := 0

	func _init() -> void:
		tree_offered.connect(func(_c, d, n): offers.append([d, n]))
		tree_picked.connect(func(_c, _n, _d): picked += 1)


func _fresh(pilot: String, late: bool, bus):
	var tree := UpgradeTree.new(bus)
	if late:
		tree.set("late_offer", true)
	tree.reset(pilot)
	return tree


static func _ids(list: Array) -> Array:
	return list.map(func(n): return n["id"])


# Walk to the open depth-4 offer: four checkpoints, a seeded pick at each of the first three.
func _to_depth_four(tree, rng: RandomNumberGenerator) -> bool:
	for depth in range(1, 4):
		tree.open_checkpoint()
		var pair: Array = tree.offered(tree.class_id, depth)
		if pair.size() != 2:
			return false
		if not tree.pick(String(pair[rng.randi() % 2]["id"])):
			return false
	tree.open_checkpoint()
	return tree.pending() and tree.picks.size() == 3


# One draw under one policy. Returns the facts the per-pilot checks count.
func _draw(pilot: String, policy: String, path_seed: int) -> Dictionary:
	var out := {"ok_path": false}
	var bus := Bus.new()
	var tree = _fresh(pilot, true, bus)
	var plain = _fresh(pilot, false, Bus.new())
	var a := RandomNumberGenerator.new()
	a.seed = path_seed
	var b := RandomNumberGenerator.new()
	b.seed = path_seed
	if not (_to_depth_four(tree, a) and _to_depth_four(plain, b)):
		return out
	out["ok_path"] = true
	var pair: Array = _ids(plain.offered(pilot, 4))
	var late: Array = _ids(tree.offered(pilot, 4))
	var late_id: String = late[0] if late.size() == 1 else ""
	var late_index := UpgradeTree.index_of(pilot, late_id)
	# One item, an unheld depth-4 endpoint outside the run's own pair, the same on every read.
	out["single"] = late.size() == 1 and late_id not in pair and late_id not in tree.picks \
		and late_index >= 0 and UpgradeTree.depth_of(late_index) == 4 and tree.offer_kind(4) == "take_or_skip"
	out["steady"] = late == _ids(tree.offered(pilot, 4)) and late_id == String(tree.late_item().get("id", "")) \
		and bus.offers.size() > 0 and bus.offers[-1] == [4, late]
	var early = _fresh(pilot, true, Bus.new())
	early.open_checkpoint()
	out["refused"] = not plain.skip() and plain.pending() and not early.skip() and early.pending() and early.picks.is_empty()
	if policy == "always-take":
		out["took"] = tree.pick(late_id)
		out["four"] = tree.picks.size() == 4 and tree.picks[3] == late_id and not tree.pending()
		out["final"] = not tree.skip() and not tree.late_skipped()
		return out
	var offers_before: int = bus.offers.size()
	var picked_before: int = bus.picked
	var allowed_before: int = tree.allowed
	var skipped: bool = tree.skip()
	out["took"] = false
	# Free: no pick, no charge, the opened count unchanged; the only event is the pair's offer.
	out["free"] = skipped and tree.late_skipped() and tree.picks.size() == 3 and tree.allowed == allowed_before \
		and bus.picked == picked_before and bus.offers.size() == offers_before + 1 and bus.offers[-1] == [4, pair]
	# The ordinary pair is open, the late item is gone for good, nothing rerolls.
	tree.open_checkpoint()
	var after: Array = _ids(tree.offered(pilot, 4))
	out["final"] = after == pair and tree.offer_kind(4) == "pair" and tree.pending() and not tree.skip() \
		and not tree.pick(late_id) and late_id not in after
	# ACCEPTANCE 2: a run through a skip still records four picks.
	out["four"] = tree.pick(String(pair[path_seed % 2])) and tree.picks.size() == 4 and late_id not in tree.picks \
		and not tree.pending()
	return out


# L2: save after a skip, load into a fresh run, and replay the loaded picks onto a fresh tree by
# hand. This does not go through flow.gd: its _apply_tree_picks does not call restore_late_skip
# yet (coordinator follow-up), so a live resume with late_offer on would offer the item again.
func _save_resume(t, pilot: String, path_seed: int) -> void:
	var tree = _fresh(pilot, true, Bus.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = path_seed
	_to_depth_four(tree, rng)
	var late_id: String = String(tree.late_item().get("id", ""))
	tree.skip()
	var run := RunState.new(null)
	run._loaded_class_id = pilot
	var doc: Dictionary = run.to_entrance_doc(tree)
	var parsed = JSON.parse_string(JSON.stringify(doc))
	var loaded := RunState.new(null)
	var applied: bool = loaded.from_entrance_doc(parsed)
	t.check("%s save 1 the skip is saved and loads back" % pilot,
		applied and RunState.validate_entrance_doc(doc) == "" and parsed.get("tree_late_skipped", false) == true \
		and loaded.tree_late_skipped and loaded.tree_picks == tree.picks and loaded.tree_allowed == 4,
		"applied %s, doc %s, loaded %s" % [applied, parsed.get("tree_late_skipped"), loaded.tree_late_skipped])
	# Resume by hand: the skip goes onto the fresh tree before the replay, then the owed pick reopens.
	var bus := Bus.new()
	var resumed = _fresh(pilot, true, bus)
	resumed.restore_late_skip(loaded.tree_late_skipped)
	resumed.allowed = loaded.tree_picks.size()
	for id in loaded.tree_picks:
		resumed.pick(id)
	if loaded.tree_allowed > resumed.picks.size():
		resumed.allowed = loaded.tree_allowed - 1
		resumed.open_checkpoint()
	var pair: Array = _ids(_fresh_pair(pilot, loaded.tree_picks))
	var after: Array = _ids(resumed.offered(pilot, 4))
	t.check("%s save 2 resume offers the ordinary pair, not the skipped item" % pilot,
		resumed.picks.size() == 3 and after == pair and pair.size() == 2 and late_id != "" and late_id not in after \
		and not resumed.pick(late_id) and not bus.offers.is_empty() and bus.offers[-1] == [4, pair],
		"offered %s, pair %s, late %s" % [after, pair, late_id])
	t.check("%s save 3 the resumed run reaches its fourth pick" % pilot,
		resumed.pick(String(pair[0])) and resumed.picks.size() == 4, "picks %s" % [resumed.picks])
	# An old save without the field loads as no skip, so its late item is still offered.
	var old: Dictionary = parsed.duplicate(true)
	old.erase("tree_late_skipped")
	var old_run := RunState.new(null)
	t.check("%s save 4 a save without the field means no skip" % pilot,
		old_run.from_entrance_doc(old) and not old_run.tree_late_skipped, "")


func _fresh_pair(pilot: String, picks: Array) -> Array:
	var plain = _fresh(pilot, false, null)
	plain.allowed = picks.size() + 1
	for id in picks:
		plain.pick(id)
	return plain.offered(pilot, 4)


func _initialize() -> void:
	var t := T.new("late_offer_test")
	var probe := UpgradeTree.new()
	var api := "late_offer" in probe and probe.has_method("skip") and probe.has_method("offer_kind") \
		and probe.has_method("late_skipped") and probe.has_method("late_item") and probe.has_method("restore_late_skip") \
		and "tree_late_skipped" in RunState.new(null)
	t.check("api: late_offer, offer_kind, skip, late_skipped, late_item, restore_late_skip, run tree_late_skipped", api, "")
	if not api:
		print("late_offer_test: FAIL (take_or_skip API missing)")
		quit(1)
		return
	# Shared checks.
	var kinds_on := []
	var kinds_off := []
	for depth in range(1, 5):
		var on := UpgradeTree.new()
		on.late_offer = true
		kinds_on.append(on.offer_kind(depth))
		kinds_off.append(probe.offer_kind(depth))
	t.eq("1 depth 4 only: kinds with the flag on", kinds_on, ["pair", "pair", "pair", "take_or_skip"])
	t.eq("2 flag off: every depth is a pair", kinds_off, ["pair", "pair", "pair", "pair"])
	var world_one := UpgradeTree.new()
	world_one.late_offer = true
	world_one.world_one = true
	t.eq("3 world one never offers take_or_skip", world_one.offer_kind(4), "pair")
	t.check("4 no reroll door on the tree", not probe.has_method("reroll") and not probe.has_method("reroll_offer"), "")
	var idle = _fresh("tarn", true, null)
	t.check("5 nothing opens without a checkpoint (no elapsed-time offer)",
		not idle.pending() and not idle.skip() and idle.picks.is_empty(), "pending %s" % idle.pending())
	# The card's skip prompt.
	var take_node = UpgradeTree.nodes("tarn")[14]
	var late_card = TreeCard.new(take_node, "key_1", Color.ORANGE, 4, false, false, TreeCard.WorldOneCards.SET_PIECE_LINES, "tarn", "take_or_skip")
	root.add_child(late_card)
	var pair_card = TreeCard.new(take_node, "key_1", Color.ORANGE, 4)
	root.add_child(pair_card)
	t.check("6 card: take_or_skip shows the skip prompt, a pair card does not",
		late_card.skip_prompt_visible() and late_card.skip_prompt_text() != "" and not pair_card.skip_prompt_visible() \
		and pair_card.skip_prompt_text() == "", "prompt \"%s\"" % late_card.skip_prompt_text())
	await process_frame
	await process_frame
	var box: Control = late_card.get_child(0)
	var sum := 0.0
	var shown := 0
	for label in box.get_children():
		if label.visible:
			sum += label.get_combined_minimum_size().y
			shown += 1
	sum += 6.0 * (shown - 1)
	var room: float = TreeCard.HEIGHT - 14.0 - (box.global_position.y - late_card.global_position.y)
	t.check("7 the prompt fits the card", sum <= room, "%d lines, %.1f of %.1f px" % [shown, sum, room])
	late_card.queue_free()
	pair_card.queue_free()
	var skipper = _fresh("tarn", true, null)
	var walk := RandomNumberGenerator.new()
	walk.seed = SEED
	_to_depth_four(skipper, walk)
	skipper.skip()
	t.eq("8 after a skip depth 4 is a plain pair (the skip declines the item, not the pick)", skipper.offer_kind(4), "pair")
	# Per pilot: two named policies, 200 draws each, on the same 200 seeded paths.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for def in ClassDef.all():
		var pilot: String = def.id
		var seeds: Array[int] = []
		for _draw in DRAWS:
			seeds.append(rng.randi())
		var by_policy := {}
		for policy in POLICIES:
			var tally := {"paths": 0, "single": 0, "steady": 0, "refused": 0, "took": 0, "four": 0, "final": 0, "free": 0}
			for s in seeds:
				var d := _draw(pilot, policy, s)
				if not d["ok_path"]:
					continue
				tally["paths"] += 1
				for key in ["single", "steady", "refused", "took", "four", "final", "free"]:
					if d.get(key, false):
						tally[key] += 1
			by_policy[policy] = tally
		var take: Dictionary = by_policy["always-take"]
		var skip: Dictionary = by_policy["always-skip"]
		for policy in POLICIES:
			var tl: Dictionary = by_policy[policy]
			print("late_offer %s %s: took %d of %d draws (%.1f%%), fourth pick on %d of %d"
				% [pilot, policy, tl["took"], DRAWS, 100.0 * tl["took"] / DRAWS, tl["four"], DRAWS])
		t.check("%s 1 every draw reaches depth 4 under both policies" % pilot,
			take["paths"] == DRAWS and skip["paths"] == DRAWS, "%d, %d" % [take["paths"], skip["paths"]])
		t.check("%s 2 the late offer is one item outside the run's own pair" % pilot,
			take["single"] == DRAWS and skip["single"] == DRAWS, "%d, %d" % [take["single"], skip["single"]])
		t.check("%s 3 the late item is not rerolled" % pilot,
			take["steady"] == DRAWS and skip["steady"] == DRAWS, "%d, %d" % [take["steady"], skip["steady"]])
		t.check("%s 4 refused at depth 1 to 3 and with the flag off" % pilot,
			take["refused"] == DRAWS and skip["refused"] == DRAWS, "%d, %d" % [take["refused"], skip["refused"]])
		t.eq("%s always-take: take rate" % pilot, "%d of %d" % [take["took"], DRAWS], "%d of %d" % [DRAWS, DRAWS])
		t.check("%s always-take: the fourth pick is the late item" % pilot, take["four"] == DRAWS, "%d of %d" % [take["four"], DRAWS])
		t.check("%s always-take: no skip after a take" % pilot, take["final"] == DRAWS, "%d of %d" % [take["final"], DRAWS])
		t.eq("%s always-skip: take rate" % pilot, "%d of %d" % [skip["took"], DRAWS], "0 of %d" % DRAWS)
		t.check("%s always-skip: skip is free and opens the ordinary pair; the item never returns" % pilot,
			skip["free"] == DRAWS and skip["final"] == DRAWS, "free %d, final %d of %d" % [skip["free"], skip["final"], DRAWS])
		t.check("%s always-skip: the run still records four picks" % pilot, skip["four"] == DRAWS, "%d of %d" % [skip["four"], DRAWS])
		_save_resume(t, pilot, seeds[0])
	t.eq("expected check count", t.checks, EXPECTED_CHECKS - 1)
	quit(t.verdict())
