extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeCard := preload("res://src/ui/tree_card.gd")
const T := preload("res://tests/support/t.gd")

# The late forced-or-skip offer (W13-INTEGRATION-3 SG8), wave 14 unit SG8, 2026-10-14.
# With UpgradeTree.late_offer on, the depth-4 offer is a take_or_skip offer: the player takes one
# of the two nodes or skips, skip is free, nothing rerolls it, and a skip is final for the run.
# Depths 1 to 3 stay plain pairs, and with the flag off nothing changes.
# 200 seeded draws per pilot: a draw is a fresh run walked to depth 4 by its own random picks.
# Evidence limit: the tree's rules and the card's prompt, headless. The pick screen's skip button
# and the run-level switch live outside this unit's scope, so no full-run win rate is measured here.

const DRAWS := 200
const SEED := 20261014
# The API check, 7 shared checks, 6 pilots x 6 checks, and the count check itself.
const EXPECTED_CHECKS := 1 + 7 + 6 * 6 + 1


class Bus:
	extends RefCounted
	signal tree_offered(class_id: String, depth: int, choices: Array)
	signal tree_picked(class_id: String, node_id: String, depth: int)
	var offers := 0

	func _init() -> void:
		tree_offered.connect(func(_c, _d, _n): offers += 1)


func _fresh(pilot: String, late: bool, bus):
	var tree := UpgradeTree.new(bus)
	if late:
		tree.set("late_offer", true)
	tree.reset(pilot)
	return tree


# Walk to the open depth-4 offer: four checkpoints, a random pick at each of the first three.
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


func _initialize() -> void:
	var t := T.new("late_offer_test")
	var probe := UpgradeTree.new()
	var api := "late_offer" in probe and probe.has_method("skip") and probe.has_method("offer_kind") and probe.has_method("late_skipped")
	t.check("api: late_offer, offer_kind, skip, late_skipped exist", api, "")
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
		not idle.pending() and idle.offered("tarn", 1).is_empty() and not idle.skip(), "pending %s" % idle.pending())
	# The card's skip prompt.
	var take_node = UpgradeTree.nodes("tarn")[14]
	var card_script: Script = TreeCard
	var late_card = card_script.callv("new", [take_node, "key_1", Color.ORANGE, 4, false, false, TreeCard.WorldOneCards.SET_PIECE_LINES, "tarn", "take_or_skip"])
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
	# Per pilot: 200 seeded draws.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for def in ClassDef.all():
		var pilot: String = def.id
		var free_skip := 0
		var final_skip := 0
		var reaches_four := 0
		var refused := 0
		var steady := 0
		var coin_take := 0
		var coin_skip := 0
		for _draw in DRAWS:
			var bus := Bus.new()
			var tree = _fresh(pilot, true, bus)
			var plain = _fresh(pilot, false, Bus.new())
			var path_seed := rng.randi()
			var a := RandomNumberGenerator.new()
			a.seed = path_seed
			var b := RandomNumberGenerator.new()
			b.seed = path_seed
			if not (_to_depth_four(tree, a) and _to_depth_four(plain, b)):
				continue
			var pair_a: Array = tree.offered(pilot, 4).map(func(n): return n["id"])
			var pair_b: Array = plain.offered(pilot, 4).map(func(n): return n["id"])
			# Not rerolled: repeated reads answer the same pair, the flag-off pair, in the same order.
			if pair_a.size() == 2 and pair_a == pair_b and pair_a == tree.offered(pilot, 4).map(func(n): return n["id"]):
				steady += 1
			# The flag off refuses a skip at depth 4; the late flag refuses one at depth 1 to 3.
			var early = _fresh(pilot, true, Bus.new())
			early.open_checkpoint()
			if not plain.skip() and plain.pending() and not early.skip() and early.pending() and early.picks.is_empty():
				refused += 1
			# Take: a coin decides, 50 percent.
			var offers_before: int = bus.offers
			var picks_before: int = tree.picks.size()
			var allowed_before: int = tree.allowed
			if rng.randf() < 0.5:
				coin_take += 1
				if tree.pick(pair_a[rng.randi() % 2]) and tree.picks.size() == 4 and not tree.skip():
					reaches_four += 1
				continue
			coin_skip += 1
			var ok: bool = tree.skip() and tree.picks.size() == picks_before and tree.allowed == allowed_before \
				and bus.offers == offers_before and tree.late_skipped()
			if ok:
				free_skip += 1
			# No offer reappears: more checkpoints, a wrong pick, a second skip, all refused.
			tree.open_checkpoint()
			tree.open_checkpoint()
			if ok and not tree.pending() and tree.offered(pilot, 4).is_empty() and bus.offers == offers_before \
					and not tree.pick(pair_a[0]) and not tree.skip() and tree.picks.size() == 3:
				final_skip += 1
		print("late_offer %s: %d draws, take %.1f%% skip %.1f%% (coin policy), pick-four reached on %d of %d takes, skip free on %d of %d skips"
			% [pilot, DRAWS, 100.0 * coin_take / DRAWS, 100.0 * coin_skip / DRAWS, reaches_four, coin_take, free_skip, coin_skip])
		t.check("%s 1 skip is available and free on every skip draw" % pilot, coin_skip > 0 and free_skip == coin_skip, "%d of %d" % [free_skip, coin_skip])
		t.check("%s 2 no offer reappears after a skip" % pilot, coin_skip > 0 and final_skip == coin_skip, "%d of %d" % [final_skip, coin_skip])
		t.check("%s 3 a take reaches the fourth pick" % pilot, coin_take > 0 and reaches_four == coin_take, "%d of %d" % [reaches_four, coin_take])
		t.check("%s 4 refused at depth 1 to 3 and with the flag off" % pilot, refused == DRAWS, "%d of %d" % [refused, DRAWS])
		t.check("%s 5 the pair is not rerolled and matches the flag-off pair" % pilot, steady == DRAWS, "%d of %d" % [steady, DRAWS])
		t.check("%s 6 take plus skip account for all %d draws" % [pilot, DRAWS], coin_take + coin_skip == DRAWS, "%d + %d" % [coin_take, coin_skip])
	t.eq("expected check count", t.checks, EXPECTED_CHECKS - 1)
	quit(t.verdict())
