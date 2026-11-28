# 2026-10-12, W13 smoke triage: class c re-pin for b1679c8.
# loot SHA256 d85b50b76df695396024904cc3a9245d9fa636352144869cc21c8086c73111e3 -> a443c521830c8c6a85bd87e6c153c1b451adac1644056a8f8b4787d5a7ade3fe; Load Dividend added to the catalogue.
extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Build := preload("res://src/build/build.gd")
const RunState := preload("res://src/core/run_state.gd")
const Icons := preload("res://src/ui/icons.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

# Unit V, first half: Riveted Shell's catalogue entry and its gated offer (BUILD-SYSTEMS.md, Two
# hot-wired parts). Since the pass D fold the Warden break puts it at the gates as a rare part
# (its gate card reads the row's verb); the Fit / Recycle screen and its two-row preview are gone.
#   - The entry: name, tag mass, an upside and a downside each with a known icon and at
#     most three words.
#   - The card line derives from Build's fitted-shell constants (2x armour, 25% steering).
#   - The offer leaves the part out with armour mode off (200 seeded calls with random held
#     lists) and includes it with armour mode on; nothing is offered once one is held.
#   - It never enters ids(), rows(), offer_pool() or roll() (seeds 1000-1049 digest below).
# Evidence limit: layout measured headless; how the rows look and read is unjudged.

var _failures := 0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_entry()
	_offer()
	_loot_parity()
	print("hotwire_shell_offer_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(1 if _failures > 0 else 0)


func _entry() -> void:
	var row := Parts.hotwired("riveted_shell")
	_check("entry", row.get("name", "") == "Riveted Shell" and row.get("tags", []) == ["mass"],
		"name %s tags %s" % [row.get("name"), row.get("tags")])
	_check("no other id", Parts.hotwired("hot_rivets").is_empty() and Parts.hotwired("").is_empty(),
		"a catalogue id and an empty id have no hot-wired row")
	for side in ["upside", "downside"]:
		var icon: String = row[side]["icon"]
		var words := WordBudget.words_in(row[side]["words"])
		_check("field " + side, Icons.has(icon) and words >= 1 and words <= 3,
			"icon %s, \"%s\" is %d words" % [icon, row[side]["words"], words])
	var line := String(Parts.def("riveted_shell").verb)
	_check("label", line == "Double armour. Air steering −25%." and Parts.def("riveted_shell").rarity == "rare",
		"gate card line \"%s\"" % line)
	# The numbers come from the constants.
	var mult: float = Build.RIVETED_ARMOUR
	var steer := int(round((1.0 - Build.RIVETED_AIR_FACTOR) * 100.0))
	# The stored words carry placeholders, so a typed "25" or "2x" cannot pass as derived.
	var raw := Parts.hotwired("riveted_shell")
	var templated: bool = "{steer}" in raw["downside"]["words"] and "{armor" in raw["upside"]["words"] \
		and "{steer}" in raw["label"] and "{armor" in raw["label"]
	_check("templated", templated, "upside \"%s\", downside \"%s\", label \"%s\"" % [raw["upside"]["words"], raw["downside"]["words"], raw["label"]])
	_check("derived", is_equal_approx(mult, 2.0) and steer == 25 and "Double" in line and str(steer) in line,
		"multiplier %.1f (Build.RIVETED_ARMOUR), steering %d; card line \"%s\"" % [mult, steer, line])


func _offer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pool := Parts.ids()
	var off_hits := 0
	var on_hits := 0
	var held_hits := 0
	for i in 200:
		var held: Array = []
		for _n in rng.randi_range(0, 4):
			held.append(pool[rng.randi_range(0, pool.size() - 1)])
		if "riveted_shell" in Parts.hotwire_offer(false, held):
			off_hits += 1
		if "riveted_shell" in Parts.hotwire_offer(true, held):
			on_hits += 1
		if "riveted_shell" in Parts.hotwire_offer(true, held + ["riveted_shell"]):
			held_hits += 1
	_check("armour off", off_hits == 0, "200 calls with armour mode off offered it %d times" % off_hits)
	_check("armour on", on_hits > 0, "200 calls with armour mode on offered it %d times" % on_hits)
	_check("one copy", held_hits == 0, "held already: offered %d times in 200 calls (one copy)" % held_hits)


# A digest over ids, rows, offer pools and 50 seeded rolls. The same code run on base
# 39b0f3f printed the same value until 2026-10-03, when RR1 re-pinned it on purpose (rarity
# weights 87/10/3 and the folded ids changed the fixed-seed rolls and the pool list); a hot-wired row in rows() or a pool moves it.
func _loot_parity() -> void:
	var text := "%d|%d|" % [Parts.ids().size(), Parts.rows().size()]
	text += ",".join(Parts.ids())
	for rarities in [["common"], ["rare"], ["relic"], ["common", "rare"], ["rare", "relic"]]:
		text += "|" + ",".join(Parts.offer_pool("sable", rarities))
	for seed_value in range(1000, 1050):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		text += "|" + ",".join(Parts.roll(rng, PartOffers.gate_rarities(seed_value % 3), "sable", [], 2))
	var digest := text.sha256_text()
	_check("loot", not "riveted_shell" in text, "riveted_shell absent from ids, rows, pools and 50 rolls")
	print("[loot digest] ids %d rows %d sha256 %s" % [Parts.ids().size(), Parts.rows().size(), digest])
	# 2026-10-12 SR9 merge: relay_convergence adds one id and one row (98 and 98); it waits on the
	# relay.convergence seam, so pools and rolls are unchanged. Was a443c521 (GP5, 2026-10-08).
	# 2026-10-15 PC-POOL re-pin: five wave 11 verb rows changed (three became class parts, Live Line
	# and Drop Weight changed knob), so the pool list and the seeded rolls moved. Was f45eadc3 (SR9).
	# 2026-10-15 SQ19b re-pin: Tally's winch_pawl adds one id and one row (99 and 99); a diff of
	# this digest's input at base and head shows only the size line and the id list move, with
	# winch_pawl the one new id, and the five sable pools and 50 rolls unchanged. Was 7bb9a5f9 (PC-POOL).
	# 2026-10-22 W19 re-pin: the earned save's spare_frame adds one id and one row (100 and 100). It is
	# rare_plus, so it joins the relic and rare-plus pools and no seeded roll moves. Removing
	# spare_frame from the id list and those two pools and setting both counts to 99 reproduces
	# 4f7ed07d byte for byte. Was 4f7ed07d (SQ19b).
	# 2026-10-27 W20 cobalt rung re-pin: impact_driver becomes rare (tier 2 kept) and four catalogue
	# rares gain a touches verb; ids and row count stay 100 and 100.
	# 2026-11-21 W45-B1 re-pin: six seamless admitted items.gd rows (overcharge_coil, ten_pin,
	# echo_charge, domino_wire, last_word, par_chip) plus seam-gated helix_drill move from rare_plus
	# (relic) to cobalt rare per ruling bn so Spare Frame stays the park table's only relic; ids and
	# row count stay 100 and 100, and those six move from the relic pool into the rare pool. Was a7edaf46 (W20).
	# 2026-11-21 W45-B2 U6 re-pin: Slag Pike and Halo Rig join the catalogue and the alpha table, so
	# ids and rows go from 100 to 102 and the pools and seeded rolls can draw them. Was afa1d8cc (W45-B1).
	# 2026-11-21 W45-B2 U7 re-pin: the five verb items (backwash, barbed_reel, faultline_cap, second_bell,
	# long_leash) join the catalogue and the alpha table, so ids and rows go from 102 to 107. Was b15787f4 (U6).
	# 2026-11-25 W47-W50 re-pin: brass_drum and heavy_breech join Items.TABLE (ids and rows go from 107 to 109),
	# and W50-ISAAC-PARTS adds 8 expansion parts via all_rows() / AlphaDefs.EXPANSION_PARTS to offer_pool() and
	# seeded rolls; riveted_shell remains absent from ids, rows, pools and all 50 rolls. Was 43ea16b3 (W45-B2 U7).
	_check("loot parity", digest == "84cf8b2eafda174f1d7c2c39c31f32b8b4674dcfec6d427b4d79475d653d5b01", "digest matches the W47-W50 pin (2026-11-25: brass_drum + heavy_breech -> 109 ids/rows and 8 W50 expansion parts in pools/rolls; W45-B2 U7 pin was 43ea16b3; U6 pin was b15787f4; W45-B1 pin was afa1d8cc; W20 pin was a7edaf46, W19 pin was afb3d540, SQ19b pin was 4f7ed07d, PC-POOL pin was 7bb9a5f9, SR9 pin was f45eadc3, GP5 pin was a443c521, RR1 pin was e65c5020)")
