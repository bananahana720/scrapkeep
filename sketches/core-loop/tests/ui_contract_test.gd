extends SceneTree
# F6 2026-10-04: no stage row carries a lesson, so the lesson-row check is removed.

const EventKinds := preload("res://src/core/event_kinds.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Icons := preload("res://src/ui/icons.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Hud := preload("res://src/ui/hud.gd")
const Objectives := preload("res://src/core/objectives.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Parts := preload("res://src/build/parts.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const EventDirector := preload("res://src/world/event_director.gd")
# Every kind the HUD toasts (ruling cx: a Warden break, a rout and a core toast no longer all fire).
const EXPECTED_TOASTS: Array[String] = ["run_ended", "player_died", "milestone_won", "scrap_lost", "core_gained", "event_announced", "event_ended", "boss_phase_changed"]

# The v2 W1 contract holds together:
#   - CONTRACTS.md's Icons section lists exactly the registry's ids, every id resolves
#     to a texture, and every one of the 70 now loads its look-track SVG;
#   - the two Noto faces load from the sketch with their licence beside them;
#   - CONTRACTS.md's Ability slots section names every slot field and state;
#   - every toast the HUD shows fits in 4 words with the longest part and event names,
#     every objective it shows in 5 (the rows' own wording in objectives.gd), every callout in 4, and every UI row
#     is well formed;
#   - a world prompt's parsed title is at most 3 words, with the rest as its detail;
#   - a reward gate's name (its own owner-placed prompt, reward_gates.gd) takes one row or two for every part, never wider
#     than a band prompt, and its rectangle holds its drawn words.

var _failures := 0


func _initialize() -> void:
	_check_icons()
	_check_slots_doc()
	_check_wording()
	_check_prompt_parse()
	_check_gate_prompts_fit()
	print("ui_contract_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


static func _section(doc: String, heading: String) -> String:
	var start := doc.find("\n## " + heading + "\n")
	if start < 0:
		return ""
	var end := doc.find("\n## ", start + 4)
	return doc.substr(start, (end if end > 0 else doc.length()) - start)


func _check_icons() -> void:
	var doc := _section(FileAccess.get_file_as_string("res://CONTRACTS.md"), "Icons")
	var listed := {}
	var regex := RegEx.create_from_string("`((cls|ab|key|cat|el|trg|thr|obj|res|fac)_[a-z0-9_]+)`")
	for m in regex.search_all(doc):
		listed[m.get_string(1)] = true
	var missing := Icons.ids().filter(func(id): return not listed.has(id))
	var extra := listed.keys().filter(func(id): return not Icons.has(id))
	var broken := Icons.ids().filter(func(id): return not Icons.texture(id) is Texture2D or Icons.texture(id).get_width() <= 0)
	_report("icon ids", doc != "" and missing.is_empty() and extra.is_empty() and broken.is_empty() and Icons.ids().size() == 70,
		"%d registry ids, %d in CONTRACTS; not listed %s, listed but unknown %s, no texture %s"
			% [Icons.ids().size(), listed.size(), missing, extra, broken])
	var no_file := Icons.ids().filter(func(id): return not Icons.from_file(id))
	var drawn_keys := ["key_1", "key_2", "key_3", "key_n", "key_c", "key_t"].filter(func(id): return not Icons.from_file(id))
	_report("svg icons", no_file.is_empty(),
		"%d of %d ids load their assets/icons SVG; placeholders still drawn for %s; keycaps drawn from their id for %s"
			% [Icons.ids().size() - no_file.size(), Icons.ids().size(), no_file, drawn_keys])
	_report("fonts vendored", UiFonts.vendored() and FileAccess.file_exists("res://assets/fonts/OFL.txt"),
		"Noto Sans Bold and Mono Bold load from res://assets/fonts beside OFL.txt")
	var fallback: Texture2D = Icons.texture("ab_kest_sticky")
	_report("icon fallback", fallback != null and fallback.get_width() == Icons.SIZE,
		"an ability id outside the list still draws its prefix's placeholder")


func _check_slots_doc() -> void:
	var doc := _section(FileAccess.get_file_as_string("res://CONTRACTS.md"), "Ability slots")
	var missing := (AbilitySlots.FIELDS + AbilitySlots.STATES).filter(func(w): return not doc.contains("`%s`" % w))
	_report("slot contract", doc != "" and missing.is_empty(), "CONTRACTS names every slot field and state; missing %s" % [missing])


func _check_wording() -> void:
	var longest_part := ""
	for id in Parts.ids():
		var shown := String(Parts.display_name(id))
		if WordBudget.words_in(shown) > WordBudget.words_in(longest_part):
			longest_part = shown
	var longest_event := ""
	for id in EventDirector.PARTICIPATORY:
		var shown := String(id).replace("_", " ").capitalize()
		if WordBudget.words_in(shown) > WordBudget.words_in(longest_event):
			longest_event = shown
	var fields := {"stage": 3, "part": longest_part, "event": longest_event, "class": "IV", "name": "Brindle"}
	var long_toasts := []
	for kind in Hud.toast_kinds():
		var text: String = Hud.toast_text(kind, fields)
		if WordBudget.words_in(text) > Hud.TOAST_WORDS or text == "":
			long_toasts.append("%s \"%s\"" % [kind, text])
	var long_objectives := []
	for id in Objectives.ROWS:
		var shown := Objectives.words(id)
		if WordBudget.words_in(shown) == 0 or WordBudget.words_in(shown) > Hud.OBJECTIVE_WORDS or Objectives.glyph(id) == "":
			long_objectives.append(id)
	var bad_rows := []
	for kind in EventKinds.UI_ROWS:
		var row: Dictionary = EventKinds.UI_ROWS[kind]
		var ok: bool = row.get("color") is Color and row.get("shape", "") in EventKinds.SHAPES and String(row.get("sound", "")) != "" \
			and row.get("group", "") in EventKinds.GROUPS
		for field in EventKinds.FIELDS:
			ok = ok and row.has(field)
		if not ok:
			bad_rows.append(kind)
	_report("wording", long_toasts.is_empty() and long_objectives.is_empty() and bad_rows.is_empty() and Hud.toast_kinds() == EXPECTED_TOASTS,
		"%s toast kinds with part \"%s\" and event \"%s\"; over 4 words %s; objectives over 5 %s; malformed UI rows %s"
			% [Hud.toast_kinds(), longest_part, longest_event, long_toasts, long_objectives, bad_rows])


func _check_prompt_parse() -> void:
	var gate: Dictionary = WorldPrompt.parse("Chain Arc (rare)\nArcs jump to two more foes\nCompletes Tesla Pylon")
	var vault: Dictionary = WorldPrompt.parse("Vault: rare part + bonus core (plating 95)")
	var long: Dictionary = WorldPrompt.parse("Roll through the hoop for a part")
	var ok: bool = gate["title"] == "Chain Arc (rare)" and gate["detail"] == "Arcs jump to two more foes\nCompletes Tesla Pylon" \
		and vault["title"] == "Vault" and vault["detail"] == "rare part + bonus core (plating 95)" \
		and long["title"] == "Roll through the" and long["detail"] == "hoop for a part"
	var fab: Dictionary = WorldPrompt.parse("Chain Arc\nArcs jump\nROLL THROUGH: 40 cogs")
	ok = ok and gate["icon"] == "obj_gate" and vault["icon"] == "obj_vault" and fab["icon"] == "obj_fabricator"
	_report("prompt parse", ok, "gate %s; vault %s; long first line %s; fabricator icon %s" % [gate, vault, long, fab["icon"]])


# A reward gate's name is its own prompt (reward_gates.gd _name_prompt, owner_placed): for every part it fits
# one row or two within a band prompt's width, and its rectangle holds its drawn words in both forms.
func _check_gate_prompts_fit() -> void:
	var widest := 0.0
	var widest_name := ""
	var too_wide := []
	var loose := []
	for id in Parts.ids():
		var d: Resource = Parts.offer_def(id, [])
		if d == null:
			continue
		var offer := {"name": Parts.display_name(id), "verb": d.verb, "punch": d.punch, "text": d.text, "mark": "* completes Tesla Pylon *"}
		var probe = RewardGates._name_prompt(offer, Color.WHITE)
		var fit: Dictionary = probe.get_meta("fit")
		var two_rows: bool = float(fit["w1"]) > ScreenRegions.PROMPT_WIDTH
		var width: float = fit["w2"] if two_rows else fit["w1"]
		if width > widest:
			widest = width
			widest_name = probe.parts()["title"]
		if width > ScreenRegions.PROMPT_WIDTH:
			too_wide.append(id)
		probe.name_rows = fit["two"] if two_rows else PackedStringArray([probe.parts()["title"]])
		probe.detail_shown = true
		# The rectangle is as wide as the widest row the font measures, plus the padding, and no wider.
		var measured := 0.0
		for i in probe.shown_lines().size():
			var row_size: int = WorldPrompt.SIGN_NAME_SIZE if i < probe.name_rows.size() else WorldPrompt.SIGN_DETAIL_SIZE
			measured = maxf(measured, UiFonts.bold().get_string_size(probe.shown_lines()[i], HORIZONTAL_ALIGNMENT_LEFT, -1, row_size).x)
		if absf(probe.shown_extent().x - (measured + 2.0 * WorldPrompt.SIGN_PAD)) > 0.01:
			loose.append(id)
		probe.free()
	_report("gate prompts fit", widest > 0.0 and too_wide.is_empty() and loose.is_empty(),
		"widest name %d px (%s); parts wider than %d px on two rows %s; parts whose rectangle does not hold its words %s" % [int(widest), widest_name, int(ScreenRegions.PROMPT_WIDTH), too_wide, loose])