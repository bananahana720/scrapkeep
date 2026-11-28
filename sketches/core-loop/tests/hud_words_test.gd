extends SceneTree

# Wave 36 unit unslop-hudwords (ruling cx, no slop in anything the player meets). The words and
# marks the HUD draws in a run:
#   - the four cards that arrive by the radio and jukebox (record, B-side, take, legend) differ by
#     icon or tint with their words hidden, and a live card draws the mark the table names;
#   - the core toast is true at 0, 1, 2 and 3 cores against parts.gd's own gate rarities and
#     run_state.gd's cap, read at run time and never copied;
#   - no string the HUD owns holds a label colon, a typed key letter or a capitals sentence;
#   - the stat labels carry the player's word for a knocked machine, not "pin".
# Every check runs first on a planted broken copy and must flag it, or its zero means nothing.
# An active's text types no key: the bar slot draws the cap once the active is racked.
# Kept on purpose, so not checked here: "KSSHT!" (radio_dial.gd, a drawn stamp) and the settings
# Breath row (mirrors pause_menu.gd).

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const Hud := preload("res://src/ui/hud.gd")
const Icons := preload("res://src/ui/icons.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const RunState := preload("res://src/core/run_state.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const BuildReadout := preload("res://src/ui/build_readout.gd")
const SummaryRows := preload("res://src/ui/summary_rows.gd")
const Attachments := preload("res://src/build/attachments.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

# Two tints of one icon must sit at least this far apart in RGB to tell the cards apart.
const TINT_GAP := 0.3
# Key letters a rebindable key could carry; "A" and "I" are words.
const KEY_LETTERS := ["Q", "E", "F", "V", "P", "R", "H", "J", "K", "X", "C", "Z"]
const PLANTED_STRINGS := ["F: four rockets steer onto machines", "Hold Tab: notes", "KEPT IN YOUR TOTALS", "SYNERGY: Cable Run",
	"Second mode: Lance Arc, one slow bolt", "Press Q to fire", "Pin damage"]

var _t := T.new("hud_words_test")
var _game


func _initialize() -> void:
	_planted()
	_cards_static()
	_core_toast()
	_strings()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_live.call_deferred()


# A card's mark as {icon key, tint}: an icon id, or "shape:<name>" for a drawn shape.
func _key(mark: Dictionary) -> String:
	return String(mark["id"]) if mark.has("id") else "shape:%s" % mark["shape"]


# The pairs of cards a player could not tell apart with the words covered, and the closest pair.
func _confusable(marks: Dictionary) -> Array:
	var out := []
	var names: Array = marks.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Dictionary = marks[names[i]]
			var b: Dictionary = marks[names[j]]
			if _key(a) == _key(b) and _gap(a["tint"], b["tint"]) < TINT_GAP:
				out.append("%s and %s" % [names[i], names[j]])
	return out


func _gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _marks() -> Dictionary:
	return {"record": Hud.card_mark(true), "b-side": Hud.card_mark(true, "b-side"), "take": Hud.card_mark(true, "take"),
		"legend": Hud.card_mark(true, "legend")}


# The claim a core line makes about the gates: the rarities it names, or "best" when it says the gates gain nothing more.
func _claim(line: String) -> Array:
	var out := []
	if line.contains("relics"):
		out.append("relic")
	if line.contains("rares"):
		out.append("rare")
	if line.contains("best"):
		out.append("best")
	out.sort()
	return out


# What parts.gd and run_state.gd say a gate offers at this many cores held, as the claim a true line makes.
func _truth(count: int) -> Array:
	if count <= 0:
		return []
	var cap: int = RunState.CORE_TIER_CAP
	if count > cap:
		return ["best"] if PartOffers.gate_rarities(count) == PartOffers.gate_rarities(cap) else ["?"]
	var out := []
	for rarity in PartOffers.gate_rarities(count):
		if rarity != "common":
			out.append(rarity)
	out.sort()
	return out


func _core_true(count: int, line: String) -> bool:
	if count <= 0:
		return line == ""
	return _claim(line) == _truth(count)


# The problems one HUD string carries; empty when it is clean.
func _hits(text: String) -> Array:
	var out := []
	if text.contains(": "):
		out.append("label colon")
	for token in text.split(" ", false):
		var bare := token.strip_edges().trim_suffix(",").trim_suffix(".")
		if bare in KEY_LETTERS:
			out.append("typed key %s" % bare)
	var letters := text.replace(" ", "")
	if text.split(" ", false).size() > 2 and letters != "" and letters == letters.to_upper() and letters != letters.to_lower():
		out.append("capitals sentence")
	if text.to_lower().contains("pin "):
		out.append("pin")
	return out


func _planted() -> void:
	for text in PLANTED_STRINGS:
		_t.check("planted: %s is flagged" % text, not _hits(text).is_empty(), str(_hits(text)))
	_t.check("a plain line is not flagged", _hits("Hold {key_tab} for notes").is_empty() and _hits("Kept in your totals").is_empty())
	var same := _marks()
	same["legend"] = same["take"]
	_t.check("planted: two cards with one icon and one tint are caught", not _confusable(same).is_empty(), str(_confusable(same)))
	var near := _marks()
	near["legend"] = {"id": near["take"]["id"], "tint": Color(near["take"]["tint"], 1.0).lightened(0.05), "word": ""}
	_t.check("planted: a tint a hair from the take's is caught", not _confusable(near).is_empty(), str(_confusable(near)))
	_t.check("planted: the base's one core line at 3 cores is caught", not _core_true(3, "Gates offer better parts"))
	_t.check("planted: the one rare line at 2 cores is caught", not _core_true(2, "Gates may offer rares"))
	_t.check("planted: a line with no claim at 1 core is caught", not _core_true(1, "Gates offer better parts"))
	_t.check("planted: a line at 0 cores is caught", not _core_true(0, "Gates may offer rares"))


func _cards_static() -> void:
	var marks := _marks()
	var confusable := _confusable(marks)
	_t.check("the four cards differ by icon or tint with their words hidden", confusable.is_empty(), str(confusable))
	var best := 9.0
	var closest := ""
	var names: Array = marks.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Dictionary = marks[names[i]]
			var b: Dictionary = marks[names[j]]
			if _key(a) == _key(b) and _gap(a["tint"], b["tint"]) < best:
				best = _gap(a["tint"], b["tint"])
				closest = "%s and %s" % [names[i], names[j]]
	print("closest pair sharing an icon: %s, tint gap %.2f (limit %.2f)" % [closest, best, TINT_GAP])
	_t.check("a record wears the wave and a take the knob", _key(marks["record"]) == "shape:wave" and _key(marks["take"]) == "radio_take", str(marks))
	_t.check("the knob has art behind it, not a fallback glyph", Icons.from_file("radio_take") and Icons.EXTRA.has("radio_take") and not Icons.has("radio_take"),
		"from_file %s" % Icons.from_file("radio_take"))
	_t.check("an achievement keeps its star", _key(Hud.card_mark(false)) == "shape:star", "")
	_t.check("only a B-side keeps a word", marks["record"]["word"] == "" and marks["take"]["word"] == "" and marks["legend"]["word"] == "" and marks["b-side"]["word"] == "B-side", str(marks))
	_t.check("a take with an unknown tier reads as a take", Hud.card_mark(true, "nonsense") == Hud.card_mark(true, "take"), "")


func _core_toast() -> void:
	var cap: int = RunState.CORE_TIER_CAP
	_t.check("the cap is two cores, as the line at 2 assumes", cap == 2, str(cap))
	for count in [0, 1, 2, 3, 4, 7]:
		var line := Hud.core_words(count)
		_t.check("the core toast is true at %d cores held" % count, _core_true(count, line), "\"%s\"" % line)
		if line != "":
			_t.check("the core toast at %d cores fits the toast's word limit" % count, WordBudget.words_in(line) <= Hud.TOAST_WORDS, line)
	_t.check("past the cap the toast stops promising a better gate", Hud.core_words(cap + 1) != Hud.core_words(cap) and not Hud.core_words(cap + 1).contains("offer"), Hud.core_words(cap + 1))
	_t.eq("the row's own wording is the one-core line", EventKinds.hud("core_gained"), Hud.core_words(1))


func _strings() -> void:
	var owned := {}
	for kind in Hud.toast_kinds():
		owned["toast %s" % kind] = EventKinds.hud(kind)
	for count in 4:
		owned["core toast %d" % count] = Hud.core_words(count)
	owned["callout notes"] = EventKinds.UI_ROWS["callout_notes"]["hud"]
	owned["synergy"] = EventKinds.hud("synergy_discovered")
	owned["launched"] = EventKinds.hud("launched")
	for kind in EventKinds.ROWS:
		var objective := EventKinds.objective(kind)
		if objective != "":
			owned["objective %s" % kind] = objective
	for pair in SummaryRows.HEADERS:
		owned["summary header %s" % pair[0]] = pair[1]
	for key in BuildReadout.STAT_WORDS:
		owned["stat %s" % key] = BuildReadout.STAT_WORDS[key]
	owned["second mode"] = BuildReadout.preview_tier("arc_caster", Attachments.TOP_TIER)
	for kind in ["b-side", "take", "legend"]:
		owned["take word %s" % kind] = String(Hud.card_mark(true, kind)["word"])
	for id in ActiveDefs.ROWS:
		owned["active %s name" % id] = String(ActiveDefs.ROWS[id]["name"])
		owned["active %s text" % id] = String(ActiveDefs.ROWS[id]["text"])
	for label in owned:
		var hits := _hits(String(owned[label]).replace("{key_tab}", "Tab"))
		_t.check("%s carries no label colon, typed key or capitals sentence" % label, hits.is_empty(), "\"%s\" %s" % [owned[label], hits])
	var pins := 0
	for key in BuildReadout.STAT_WORDS:
		if String(BuildReadout.STAT_WORDS[key]).to_lower().contains("pin"):
			pins += 1
	_t.check("no stat label says pin", pins == 0, str(pins))
	# The lift pulse's line says "tier", the word the player is taught.
	_t.check("no active says heft class", not String(ActiveDefs.ROWS["lift_pulse"]["text"]).contains("class"), String(ActiveDefs.ROWS["lift_pulse"]["text"]))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# A live HUD: a take of each tier and a record, shown through the game's own card path, draw
# the icon, tint and word the table names.
func _live() -> void:
	var hud = _game.hud
	await _frames(5)
	var drawn := {}
	for pair in [["record", ""], ["b-side", "b-side"], ["take", "take"], ["legend", "legend"]]:
		for guard in 600:
			if hud._ach_entry.is_empty() and hud.ach_toasts().is_empty():
				break
			await _frames(1)
		if pair[0] == "record":
			hud.tune_found("Live Record")
		else:
			hud.take_found("Live %s" % pair[0], "KEEP Live", pair[1])
		var seen := false
		for guard in 900:
			await _frames(1)
			if not hud._ach_entry.is_empty() and hud._ach_panel.visible and String(hud._ach_entry["text"]).begins_with("Live"):
				seen = true
				break
		if seen:
			drawn[pair[0]] = {"texture": hud._ach_icon.texture, "tint": hud._ach_icon.modulate, "word": hud._ach_word.text if hud._ach_word.visible else "",
				"detail": hud._ach_detail.text}
		else:
			drawn[pair[0]] = {}
		for guard in 900:
			if hud._ach_entry.is_empty():
				break
			await _frames(1)
	for kind in drawn:
		var row: Dictionary = drawn[kind]
		var mark: Dictionary = _marks()[kind]
		_t.check("the live %s card was drawn" % kind, not row.is_empty(), str(drawn.keys()))
		if row.is_empty():
			continue
		_t.check("the live %s card wears the table's tint" % kind, _gap(row["tint"], mark["tint"]) < 0.01, str(row["tint"]))
		_t.check("the live %s card draws the table's word" % kind, row["word"] == mark["word"], "\"%s\"" % row["word"])
		_t.check("the live %s card has no label colon" % kind, not String(row["detail"]).contains(": "), String(row["detail"]))
	var textures := {}
	for kind in drawn:
		if not drawn[kind].is_empty():
			textures[kind] = drawn[kind]["texture"]
	_t.check("a live take's knob is not the record's wave", textures.has("take") and textures.has("record") and textures["take"] != textures["record"], "")
	# The core toast through the bus: three cores held says the best-gates line.
	for count in [1, 2, 3]:
		_game.events.core_gained.emit("event", Vector3.ZERO, count)
		await _frames(2)
		var shown: Array[String] = hud.toast_texts()
		_t.check("the live core toast at %d cores reads the true line" % count, shown.has(Hud.core_words(count)), str(shown))
	quit(_t.verdict())
