extends SceneTree

# Ruling cx. The build popup shows each part as one plain row, with no internal stacking
# vocabulary: no layer words, no "Reads:", no stack-rule sentences, no pool words.
#  - a build with a stacked part, a capped part and an attachment draws none of the banned words;
#  - every part row is at most 9 words, every pool row is a stat and a signed change;
#  - a capped part shows its pips full and no "(at cap)" text;
#  - Esc closes the popup, and the popup has no "Close build" text;
#  - a planted row in the base's old format must fail the banned-word check.
const Parts := preload("res://src/build/parts.gd")
const Attachments := preload("res://src/build/attachments.gd")
const BuildReadout := preload("res://src/ui/build_readout.gd")
const Icons := preload("res://src/core/icons.gd")
const Palette := preload("res://src/core/palette.gd")

const ROW_WORDS := 9
const BANNED := ["weapon-local", "player-global", "Reads:", "multiplying", "shrinks", "no cap", "hyperbolic",
	"linear", "spike", " · ", "(at cap)", "stops at", "Close build"]
# Two Hot Rivets (stacked, levelled), four Cap Relay (capped at three), plus a plain mix.
const HELD := ["hot_rivets", "hot_rivets", "cap_relay", "cap_relay", "cap_relay", "cap_relay",
	"rivet_plating", "quick_spool", "magnet_spool", "crush_guard", "crush_guard"]
# The base's row builder, verbatim in shape: layer word, stack rule, cap and Reads line.
const BASE_ROW := "Cap Relay x4 · player-global · linear, stops at 3 copies (at cap)\nReads: Special charges"

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _banned_in(words: String) -> Array:
	return BANNED.filter(func(word): return word in words)


func _press(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()


func _over_text(view: Node, id: String) -> String:
	var found: Array = view.find_children("Part_" + id, "HBoxContainer", true, false)[0].find_children("Over", "Label", true, false)
	return found[0].text if found.size() == 1 else ""


func _words_in(words: String) -> int:
	return words.split(" ", false).size()


func _run() -> void:
	var view := BuildReadout.new()
	root.add_child(view)
	var loadout := Attachments.empty("rapid_laser", Attachments.TOP_TIER)
	for id in Attachments.fitting("rapid_laser").slice(0, 2):
		loadout = Attachments.equip(loadout, id)
	view.show_build(HELD, loadout)
	var text: String = view.visible_text()
	var data: Dictionary = view.snapshot()
	print(text)

	_report("planted control: the base's row format is caught", _banned_in(BASE_ROW).size() >= 5, str(_banned_in(BASE_ROW)))
	var old_words: Array = BuildReadout.STAT_WORDS.values().filter(func(word): return "Rebound" in word or "scrap mass" in word.to_lower())
	_report("stat words use bounce and heft", old_words.is_empty(), str(old_words))
	_report("the popup draws none of the banned words", _banned_in(text).is_empty(), "found %s" % [_banned_in(text)])
	var attachments := String(data["attachments"])
	_report("attachments read as a count of the most", attachments.begins_with("Rapid Laser: 2 of 3 attachments"), attachments.get_slice("\n", 0))

	var longest := 0
	var worst := ""
	for row in data["parts"]:
		if _words_in(row["text"]) > longest:
			longest = _words_in(row["text"])
			worst = row["text"]
	_report("every part row is at most 9 words", longest <= ROW_WORDS, "%d words: %s" % [longest, worst])
	var one_line: bool = data["parts"].all(func(row): return not "\n" in row["text"])
	_report("every part row is one line", one_line, "")

	var signed_pools := true
	var shown := 0
	for pool in data["pools"].values():
		if pool["text"] == "":
			continue
		shown += 1
		var change: String = pool.get("change", "")
		signed_pools = signed_pools and (change.begins_with("+") or change.begins_with("-")) and pool["text"].ends_with(change) \
			and pool["text"].begins_with(BuildReadout._stat_words(pool.get("key", "")))
	_report("every pool row is a stat and a signed change", shown > 0 and signed_pools, "%d pool rows" % shown)
	_report("weapon damage reads as its percent", "Weapon damage +" in text and "%" in data["pools"]["weapon_damage"]["text"], data["pools"]["weapon_damage"]["text"])

	var relay: Dictionary = {}
	for row in data["parts"]:
		if row["id"] == "cap_relay":
			relay = row
	_report("a capped part shows its pips full", not relay.is_empty() and relay.get("pips") == {"filled": 3, "total": 3}, str(relay.get("pips")))
	_report("a capped part draws a pip row and no (at cap) text", view.find_children("Pips", "Control", true, false).size() >= 1
		and not "(at cap)" in text and not "max" in String(relay.get("text", "")), String(relay.get("text", "")))
	var hot: Dictionary = {}
	for row in data["parts"]:
		if row["id"] == "hot_rivets":
			hot = row
	var two_rivets: Array = []
	for i in 2:
		two_rivets.append("slag_rounds")
	# Slag Rounds has no copy cap (stack_cap 0), so its copies read as a count; Cap Relay has a cap of
	# 3, so its copies are pips and the name carries no count.
	var slag: String = BuildReadout.describe(two_rivets)["parts"][0]["text"]
	_report("a part with no copy cap shows its count above one", Parts.def("slag_rounds").stack_cap < 1.0 and "x2" in slag, slag)
	var relay_text: String = BuildReadout.describe(["cap_relay", "cap_relay"])["parts"][0]["text"]
	_report("planted control: a capped part does not show a count in its name", Parts.def("cap_relay").stack_cap >= 1.0 and not "x2" in relay_text, relay_text)
	_report("a hot rivets row names its numbers", not hot.is_empty() and ("%" in hot["text"] or "+" in hot["text"]), hot.get("text", ""))

	# Every authored part, alone and at a heavy stack: 9 words, one line, no banned word.
	var over: Array = []
	var dirty: Array = []
	var rows := Parts.rows().duplicate(true)
	rows.merge(Parts.EVOLVED)
	for id in rows:
		for copies in [1, 4]:
			var held: Array = []
			for i in copies:
				held.append(id)
			var made: Dictionary = BuildReadout.describe(held)
			for row in made["parts"]:
				if _words_in(row["text"]) > ROW_WORDS or "\n" in row["text"]:
					over.append("%s x%d: %s" % [id, copies, row["text"]])
				if not _banned_in(row["text"]).is_empty():
					dirty.append("%s: %s" % [id, row["text"]])
			for pool in made["pools"].values():
				if pool["text"] != "" and not (pool["text"].ends_with(pool.get("change", "?")) and String(pool.get("change", "?")).left(1) in "+-") or not _banned_in(pool["text"]).is_empty():
					dirty.append("pool %s" % pool["text"])
	_report("every authored part row is 9 words or fewer", over.is_empty(), "%d over: %s" % [over.size(), over.slice(0, 8)])
	_report("no authored part or pool row carries a banned word", dirty.is_empty(), "%d dirty: %s" % [dirty.size(), dirty.slice(0, 8)])

	# Copies past the cap show as the full pips and a small plus count; at the cap, none.
	_report("four copies of a cap of three show the plus one", relay.get("over") == 1 and _over_text(view, "cap_relay") == "+1", "over %s, mark %s" % [relay.get("over"), _over_text(view, "cap_relay")])
	var held_cap: float = Parts.def("cap_relay").stack_cap
	var three := BuildReadout.new()
	root.add_child(three)
	three.show_build(["cap_relay", "cap_relay", "cap_relay"])
	_report("planted control: copies at the cap draw no plus count", held_cap == 3.0 and three.find_children("Over", "Label", true, false).is_empty()
		and three.snapshot()["parts"][0]["over"] == 0, "three of three")
	# A part with no pip row that reaches its ceiling shows one filled pip; short of it, nothing.
	var guards: Array = []
	for i in 30:
		guards.append("crush_guard")
	var capped := BuildReadout.new()
	root.add_child(capped)
	capped.show_build(guards)
	var short := BuildReadout.new()
	root.add_child(short)
	short.show_build(["crush_guard"])
	_report("a part at its cap with no pip row shows a filled pip", capped.snapshot()["parts"][0]["at_cap"] and capped.snapshot()["parts"][0]["pips"].is_empty()
		and capped.find_children("CapMark", "Control", true, false).size() == 1, "30 Crush Guard")
	_report("planted control: a part short of its cap shows no cap mark", not short.snapshot()["parts"][0]["at_cap"] and short.find_children("CapMark", "Control", true, false).is_empty(), "1 Crush Guard")
	# The icon is the part's own (Parts.icon_of) and wears Icons.tint.
	var box: Node = view.find_children("Part_cap_relay", "HBoxContainer", true, false)[0]
	var icon: TextureRect = box.get_child(0)
	var icon_id := Parts.icon_of("cap_relay")
	_report("the row icon comes from Parts.icon_of and Icons.tint", icon_id != "" and icon.texture == Icons.texture(icon_id) and icon.modulate == Icons.tint(icon_id, Palette.SAND), icon_id)
	var element_id := ""
	for id in rows:
		if Parts.def(id) != null and Parts.def(id).element != "":
			element_id = id
			break
	var element_view := BuildReadout.new()
	root.add_child(element_view)
	element_view.show_build([element_id])
	var element_icon: TextureRect = element_view.find_children("Part_" + element_id, "HBoxContainer", true, false)[0].get_child(0)
	_report("an element part wears its element icon", element_id != "" and element_icon.texture == Icons.texture("el_" + String(Parts.def(element_id).element)), element_id)

	_report("no Close build text on the popup", not "Close build" in text and view._popup.find_children("Back", "Button", true, false).size() == 1, "Back button")
	view._popup.popup_centered()
	await process_frame
	await process_frame
	var opened: bool = view.popup_visible()
	_press(KEY_ESCAPE)
	await process_frame
	_report("Esc closes the popup", opened and not view.popup_visible(), "open before %s, open after %s" % [opened, view.popup_visible()])
	view._popup.popup_centered()
	await process_frame
	await process_frame
	_press(KEY_Q)
	await process_frame
	_report("another key leaves it open", view.popup_visible(), "Q")

	print("build_readout_words_test: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 else 1)
