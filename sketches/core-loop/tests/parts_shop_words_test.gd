extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")

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


# Numbers the part's text holds that its detail line leaves out.
func _hidden_numbers(text: String, line: String) -> Array:
	var out: Array = []
	for n in _numbers_in(text):
		if not line.contains(n):
			out.append(n)
	return out


func _words(line: String) -> int:
	return line.split(" ", false).size()


func _run() -> void:
	# Planted failures: each check must go red on a broken row, or its green below means nothing.
	var broken := ["Pure cost: Stockpile; rebound", "Wrecking Ball evolved: grapple the enemies", "Hit the pocket, may refund and recharge"]
	_report("plant banned words", _banned_in(broken).size() >= 8, "the banned-word scan found %d hits in a planted row" % _banned_in(broken).size())
	_report("plant hidden number", _hidden_numbers("+4 punch, +12% weapon damage", "Hot Rivets: Hit harder. Punch +4") == ["12"],
		"the number check names %s when the line drops 12" % [_hidden_numbers("+4 punch, +12% weapon damage", "Hot Rivets: Hit harder. Punch +4")])
	_report("plant long line", _words("Third bounce in four seconds strikes the nearest machine for double damage") > MAX_CARD_WORDS, "a planted ten-word line is over the limit")

	var rows: Dictionary = Parts.rows()
	var ids: Array = rows.keys()
	for key in Parts.EVOLVED:
		ids.append(key)
	_report("rows", rows.size() >= 100 and ids.size() >= 104, "%d rows walked (catalogue, items, cells, evolved)" % ids.size())

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
				_report(id + " L%d name first" % level, line.begins_with(Parts.display_name(id) + ". "), "the detail line \"%s\" does not open with the name and a full stop" % line)
			checked_details += 1
		var bad := _banned_in(shown)
		_report(id + " words", bad.is_empty(), "%s" % [bad])
		var card: String = shown[1]
		_report(id + " card length", _words(card) <= MAX_CARD_WORDS, "\"%s\" is %d words" % [card, _words(card)])
		_report(id + " card uncut", card == d.verb, "the reveal row cuts \"%s\" to \"%s\"" % [d.verb, card])
		_report(id + " card line set", card != "", "an empty card line")
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
