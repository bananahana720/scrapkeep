# 2026-10-12, W13 smoke triage: class c re-pin for b1679c8.
# loot SHA256 d85b50b76df695396024904cc3a9245d9fa636352144869cc21c8086c73111e3 -> a443c521830c8c6a85bd87e6c153c1b451adac1644056a8f8b4787d5a7ade3fe; Load Dividend added to the catalogue.
extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Build := preload("res://src/build/build.gd")
const RunState := preload("res://src/core/run_state.gd")
const Icons := preload("res://src/ui/icons.gd")
const HotwireChoice := preload("res://src/ui/hotwire_choice.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# Unit V, first half: Riveted Shell's catalogue entry, its gated offer and its preview
# (BUILD-SYSTEMS.md, Two hot-wired parts). Built here: Parts.hotwired, Parts.hotwire_offer
# and the two-row preview. Not built: Fit or Recycle, cues, wiring into a live gate.
#   - The entry: name, tag mass, an upside and a downside each with a known icon and at
#     most three words.
#   - The words derive from Build and RunState constants (2x armour, 25% steering).
#   - The offer leaves the part out with armour mode off (200 seeded calls with random held
#     lists) and includes it with armour mode on; nothing is offered once one is held.
#   - It never enters ids(), rows(), offer_pool() or roll() (seeds 1000-1049 digest below).
#   - The preview's two rows match in icon size, font size and row height, and the words
#     across both stay at 8 or fewer.
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
	await _preview()
	print("hotwire_shell_offer_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(1 if _failures > 0 else 0)


func _entry() -> void:
	var row := Parts.hotwired("riveted_shell")
	_check("entry", row.get("name", "") == "Riveted Shell" and row.get("tags", []) == ["mass"],
		"name %s tags %s" % [row.get("name"), row.get("tags")])
	_check("no other id", Parts.hotwired("hot_rivets").is_empty() and Parts.hotwired("").is_empty(),
		"a catalogue id and an empty id have no hot-wired row")
	var copy := HotwireChoice.resolve("riveted_shell")
	for side in ["upside", "downside"]:
		var icon: String = copy[side]["icon"]
		var words := WordBudget.words_in(copy[side]["words"])
		_check("field " + side, Icons.has(icon) and words >= 1 and words <= 3,
			"icon %s, \"%s\" is %d words" % [icon, copy[side]["words"], words])
	_check("label", copy["label"] == "Double armour. Air steering −25%.", "label \"%s\"" % copy["label"])
	# The numbers come from the constants.
	var mult := RunState.SCRAP_PER_HP / Build.SHELL_SCRAP_PER_HP
	var steer := int(round((1.0 - Build.SHELL_AIR_FACTOR) * 100.0))
	# The stored words carry placeholders, so a typed "25" or "2x" cannot pass as derived.
	var raw := Parts.hotwired("riveted_shell")
	var templated: bool = "{steer}" in raw["downside"]["words"] and "{armor" in raw["upside"]["words"] \
		and "{steer}" in raw["label"] and "{armor" in raw["label"]
	_check("templated", templated, "upside \"%s\", downside \"%s\", label \"%s\"" % [raw["upside"]["words"], raw["downside"]["words"], raw["label"]])
	_check("derived", is_equal_approx(mult, 2.0) and steer == 25
		and ("Double" in copy["label"] or "2" in copy["upside"]["words"]) and str(steer) in copy["downside"]["words"],
		"multiplier %.1f from %.0f/%.0f, steering %d; upside \"%s\", downside \"%s\"" % [mult,
			RunState.SCRAP_PER_HP, Build.SHELL_SCRAP_PER_HP, steer, copy["upside"]["words"], copy["downside"]["words"]])
	_check("unknown", HotwireChoice.resolve("hot_rivets").is_empty(), "a non-hot-wired id resolves to nothing")


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
		text += "|" + ",".join(Parts.roll(rng, Parts.gate_rarities(seed_value % 3), "sable", [], 2))
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
	_check("loot parity", digest == "afb3d540d0f96e945174cb2d8e40662bae4acdac1d9c88ad3e3f0e9e9422fdef", "digest matches the W19 pin (2026-10-22: spare_frame id and row; SQ19b pin was 4f7ed07d, PC-POOL pin was 7bb9a5f9, SR9 pin was f45eadc3, GP5 pin was a443c521, RR1 pin was e65c5020)")


func _preview() -> void:
	var view := HotwireChoice.new("riveted_shell")
	view.size = Vector2(420.0, 200.0)
	root.add_child(view)
	await process_frame
	await process_frame
	_check("two rows", view.rows.size() == 2 and view.get_child_count() == 2, "%d rows" % view.rows.size())
	var icons: Array = []
	var fonts: Array = []
	var heights: Array = []
	var texts: Array = []
	for row in view.rows:
		var icon: TextureRect = row.get_child(0)
		var label: Label = row.get_child(1)
		icons.append(icon.size)
		fonts.append(label.get_theme_font_size("font_size"))
		heights.append(row.size.y)
		texts.append(label.text)
	print("[measure] upside icon %s font %d row h %.1f | downside icon %s font %d row h %.1f" % [
		icons[0], fonts[0], heights[0], icons[1], fonts[1], heights[1]])
	_check("equal icon", icons[0] == icons[1] and icons[0].x > 0.0, "icons %s and %s" % [icons[0], icons[1]])
	_check("equal font", fonts[0] == fonts[1] and fonts[0] > 0, "font sizes %d and %d" % [fonts[0], fonts[1]])
	_check("equal height", is_equal_approx(heights[0], heights[1]) and heights[0] > 0.0, "row heights %.1f and %.1f" % [heights[0], heights[1]])
	var words := WordBudget.words_in(texts[0]) + WordBudget.words_in(texts[1])
	_check("word budget", words <= 8, "%d words across \"%s\" and \"%s\"" % [words, texts[0], texts[1]])
	_check("shows numbers", ("Double" in texts[0] or "2" in texts[0]) and "25" in texts[1], "rows read \"%s\" / \"%s\"" % [texts[0], texts[1]])
	view.queue_free()
