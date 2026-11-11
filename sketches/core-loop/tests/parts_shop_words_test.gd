extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")

# Ruling cx, wave 36 (unslop-parts): a reward card, a shop tile and the shop's detail line say what
# the thing does in the words shown, and one thing has one name.
#  - Every part row, item row, evolved row, burden row and relic row: the card line, the name and the
#    shop detail line (every level) hold none of the retired words (BANNED).
#  - Every reward-card line is at most 9 words, is not cut by the reveal row's six-word limit, and no
#    two rows share one.
#  - The shop detail line carries every number the part's own text holds, and names the part first.
#  - Each check runs on a planted broken row first and must fail there.
const BANNED := ["tockpile", " stock", "Stock ", "ebound", "grapple", "scrap mass", "Pure cost", " evolved:", "; ", ": ",
	"may erupt", "refund", "recharge", "hands back", "give back", "enemies", "foes", "Rope", " mass", "Q becomes"]
const MAX_CARD_WORDS := 9

var _failures := 0
var _checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _origin_ok(text: String, synergy_name: String) -> bool:
	return synergy_name != "" and text.ends_with("From %s." % synergy_name)


func _report(label: String, ok: bool, detail: String) -> void:
	_checked += 1
	if not ok:
		_failures += 1
		print("[%s] %s -> FAIL" % [label, detail])


# The detail line for a part at a level: the shop's own line when the build has it, else the label the
# base used (so the same check runs, and fails, on the base).
func _has_shop_line() -> bool:
	var script: Script = Parts
	for m in script.get_script_method_list():
		if m["name"] == "shop_line":
			return true
	return false


func _detail(part_id: String, level: int) -> String:
	if _has_shop_line():
		var script: Script = Parts
		return script.call("shop_line", part_id, level)
	return Parts.headline(part_id, level)


# Problems in one row's shown words. `shown` is every string a player reads for it.
func _banned_in(shown: Array) -> Array:
	var bad: Array = []
	for text in shown:
		for word in BANNED:
			if String(text).to_lower().contains(String(word).to_lower()):
				bad.append("\"%s\" in \"%s\"" % [word, text])
	return bad


func _numbers_in(text: String) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("[0-9]+(\\.[0-9]+)?")
	for m in rx.search_all(text):
		out.append(m.get_string())
	return out


# Numbers the part's text holds that its detail line leaves out. Whole numbers: "4" is not found in "14".
func _hidden_numbers(text: String, line: String) -> Array:
	var out: Array = []
	var have := _numbers_in(line)
	for n in _numbers_in(text):
		if have.has(n):
			have.erase(n)
		else:
			out.append(n)
	return out


# The generator keeps a row's text whole only up to eight words and no cut mark.
func _text_whole(text: String) -> bool:
	return not text.ends_with("...") and ItemGen.word_count(text) <= ItemGen.MAX_WORDS


# Problems with a reward-card line for a part whose verb is `verb`.
func _card_problems(card: String, verb: String) -> Array:
	var out: Array = []
	if card == "":
		out.append("empty")
	if _words(card) > MAX_CARD_WORDS:
		out.append("%d words" % _words(card))
	if card != verb:
		out.append("cut from \"%s\"" % verb)
	return out


# Problems with what a gate draws for a part: "+N punch" when it has punch, never the old "Punch +".
func _gate_problems(drawn: String, punch: float) -> Array:
	var out: Array = []
	if drawn.contains("Punch +"):
		out.append("old \"Punch +\" label")
	if punch > 0.0 and not drawn.contains("+%d punch" % int(punch)):
		out.append("no \"+%d punch\"" % int(punch))
	return out


func _gate_drawn(d: Resource, id: String) -> String:
	var offer := {"name": Parts.display_name(id), "verb": d.verb, "punch": d.punch, "text": d.text, "mark": ""}
	var parts: Dictionary = RewardGates.prompt_parts(offer)
	var probe := WorldPrompt.new()
	probe.set_parts(parts["title"], parts["detail"], parts["icon"])
	probe.near = true
	probe.visible = true
	var drawn := " | ".join(probe.drawn_words())
	probe.free()
	return drawn


func _words(line: String) -> int:
	return line.split(" ", false).size()


func _run() -> void:
	# Planted failures: each check must go red on a broken row, or its green below means nothing.
	var broken := ["Pure cost: Stockpile; rebound", "Wrecking Ball evolved: grapple the enemies", "Hit the pocket, may refund and recharge"]
	_report("plant banned words", _banned_in(broken).size() >= 8, "the banned-word scan found %d hits in a planted row" % _banned_in(broken).size())
	_report("plant hidden number", _hidden_numbers("+4 punch, +12% weapon damage", "Hot Rivets: Hit harder. Punch +4") == ["12"],
		"the number check names %s when the line drops 12" % [_hidden_numbers("+4 punch, +12% weapon damage", "Hot Rivets: Hit harder. Punch +4")])
	_report("plant whole numbers", _hidden_numbers("+4 punch", "Name. +14 punch, +40% damage") == ["4"],
		"4 is not found inside 14 or 40: %s" % [_hidden_numbers("+4 punch", "Name. +14 punch, +40% damage")])
	var nine := "one two three four five six seven eight nine"
	_report("plant cut text", not _text_whole(ItemGen.clip(nine)) and not _text_whole(nine) and _text_whole("one two three"),
		"the generator's own cut of a nine-word text \"%s\" is refused" % ItemGen.clip(nine))
	var ten := "Third bounce in four seconds strikes the nearest machine for double"
	_report("plant long card line", _card_problems(ten, ten).size() == 1 and _card_problems("", "").size() >= 1,
		"a ten-word card line: %s" % [_card_problems(ten, ten)])
	var seven := "Post-smash knocked machines hit much harder now"
	var cut := " ".join(seven.split(" ").slice(0, 6))
	_report("plant cut card line", _card_problems(cut, seven).size() == 1, "a seven-word verb the reveal row cuts to six: %s" % [_card_problems(cut, seven)])
	_report("plant old gate label", _gate_problems("Hit harder | Punch +4", 4.0).size() == 2 and _gate_problems("+12% damage, +4 punch", 4.0).is_empty(),
		"a gate drawing the old label: %s" % [_gate_problems("Hit harder | Punch +4", 4.0)])

	var rows: Dictionary = Parts.rows()
	var ids: Array = rows.keys()
	for key in Parts.EVOLVED:
		ids.append(key)
	_report("rows", rows.size() >= 100 and ids.size() >= 104, "%d rows walked (catalogue, items, cells, evolved)" % ids.size())

	# An evolved part says which synergy it came from, by that synergy's own name (its first
	# discovery card is the one screen that draws the whole text).
	_report("plant origin", not _origin_ok("+8 punch, +35% weapon damage", "Wrecking Ball") and not _origin_ok("From Pinwheel.", "")
		and _origin_ok("+8 punch. From Wrecking Ball.", "Wrecking Ball"), "the origin checker passes a text with no origin, or fails one that has it")
	for key in Parts.EVOLVED:
		var from_name := String(Synergies.ROWS.get(Synergies.evolution_of(key), {}).get("name", ""))
		var said: String = Parts.def(key).text
		_report(key + " origin", _origin_ok(said, from_name), "evolved from \"%s\", text \"%s\"" % [from_name, said])

	var card_lines := {}
	var checked_details := 0
	for id in ids:
		var d: Resource = Parts.def(id)
		_report(id + " def", d != null, "no def for " + id)
		if d == null:
			continue
		var card_line: String = d.verb
		var shown: Array = [Parts.display_name(id), card_line, d.text, String(Parts.row(id).get("pitch", ""))]
		shown[1] = RewardCeremony.card_words(id)
		var level_count := maxi(1, d.levels.size())
		for level in range(1, level_count + 1):
			var line := _detail(id, level)
			shown.append(line)
			var level_text: String = Parts.def_at(id, level).text
			var hidden := _hidden_numbers(level_text, line)
			_report(id + " L%d numbers" % level, hidden.is_empty(), "the detail line \"%s\" drops %s from \"%s\"" % [line, hidden, level_text])
			if _has_shop_line():
				var after := line.substr(Parts.display_name(id).length() + 2)
				_report(id + " L%d sentence case" % level, after != "" and after.substr(0, 1) == after.substr(0, 1).to_upper(), "the detail line \"%s\" starts its sentence lowercase" % line)
				_report(id + " L%d name first" % level, line.begins_with(Parts.display_name(id) + ". "), "the detail line \"%s\" does not open with the name and a full stop" % line)
			checked_details += 1
		var bad := _banned_in(shown)
		_report(id + " words", bad.is_empty(), "%s" % [bad])
		var card: String = shown[1]
		_report(id + " text kept whole", _text_whole(d.text),
			"the row text \"%s\" is %d words; past eight the generator cuts it and the number is lost" % [d.text, _words(d.text)])
		_report(id + " card line", _card_problems(card, d.verb).is_empty(), "\"%s\": %s" % [card, _card_problems(card, d.verb)])
		var drawn := _gate_drawn(d, id)
		_report(id + " gate prompt", _gate_problems(drawn, d.punch).is_empty(), "the gate draws \"%s\": %s" % [drawn, _gate_problems(drawn, d.punch)])
		if card_lines.has(card):
			_report(id + " card unique", false, "\"%s\" is also the line of %s" % [card, card_lines[card]])
		card_lines[card] = id
	_report("details", checked_details >= ids.size(), "%d detail lines walked" % checked_details)

	# The hot-wired, burden and relic words.
	for key in Parts.HOTWIRED:
		var spec: Dictionary = Parts.HOTWIRED[key]
		var texts: Array = [String(spec.get("label", "")), String(spec.get("name", ""))]
		for side in ["upside", "downside"]:
			texts.append(String(spec.get(side, {}).get("words", "")))
		for k in ["verb", "text"]:
			texts.append(String(spec.get("part", {}).get(k, "")))
		var bad := _banned_in(texts)
		_report(key + " hot-wired words", bad.is_empty(), "%s" % [bad])
	var relic_lines := {}
	for id in Relics.ids():
		var r: Dictionary = Relics.row(id)
		var bad := _banned_in([String(r["name"]), String(r["text"])])
		_report(id + " relic words", bad.is_empty(), "%s" % [bad])
		_report(id + " relic length", _words(String(r["text"])) <= MAX_CARD_WORDS, "\"%s\"" % r["text"])
		var key := "%s|%s" % [r["text"], r["slot"]]
		_report(id + " relic unique", not relic_lines.has(key) or String(r["pilots"]) != String(Relics.row(relic_lines[key])["pilots"]),
			"\"%s\" repeats for the same pilot in %s" % [r["text"], relic_lines.get(key, "")])
		relic_lines[key] = id
	# One name per thing, by name: the player's health part is a hull, and nothing on a card calls scrap mass or a stat ballast.
	_report("rivet hull", Parts.display_name("rivet_plating") == "Rivet Hull" and Parts.rows().has("rivet_plating"),
		"the health part reads \"%s\" under the unchanged id rivet_plating" % Parts.display_name("rivet_plating"))
	var names_plating: Array = []
	for id in ids:
		if "plating" in Parts.display_name(id).to_lower() and id != "tread_plating":
			names_plating.append(id)
	_report("plating is machines'", names_plating.is_empty(), "%s still wear plating in the name" % [names_plating])

	print("%d checks" % _checked)
	print("parts_shop_words_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
