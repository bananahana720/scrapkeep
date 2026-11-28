extends SceneTree

const Game := preload("res://src/game.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const Picker := preload("res://src/ui/camp_enemy_picker.gd")
const Scrapbook := preload("res://src/ui/camp_scrapbook.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const HelpPage := preload("res://src/ui/help_page.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")
const Lanes := preload("res://src/build/lanes.gd")
const ComicPage := preload("res://src/ui/comic_page.gd")
const SummaryRows := preload("res://src/ui/summary_rows.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const T := preload("res://tests/support/t.gd")

# Ruling cx (no slop): the pages a player opens from the title, pause or camp say each thing once, show
# keys as keycaps and are left with Back on the Esc keycap. Each page is built, then every label,
# button and keycap row on it is read: the Back control wears Esc, no removed string is left, no label
# types a key hint ("hold E", "F:", "Esc to", "Left / Right"), and a count sits in the heading as n/N or
# is drawn as pips. A planted page that types "Esc to close" must trip the typed-hint check.

const REMOVED := ["Records found", "Takes found", "THE CRATE", "Takes found:", "In the yard", "Enemies on the manifest",
	"Hover to try on", "Click to see its items", "Click to wear", "the armour you carry", "Esc to close", "Page 1 of",
	"HULL NOT RETURNED", "RETURN ENTERED", "Opens ", "in the pools", "Grow", "Jam:", "Cast time", "mats lock"]
# A typed key hint: a verb and a key letter, a key and a colon, or a typed key list.
const TYPED_HINT := "hold [A-Z]\\b|\\b[A-Z]: |Esc to |Left / Right|Q / E|Hold E"

var _t := T.new("page_structure_test")
var _game
var _hint_rx := RegEx.new()


func _initialize() -> void:
	_hint_rx.compile(TYPED_HINT)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n := 2) -> void:
	for i in n:
		await process_frame


# Every string a page reads: labels, buttons, keycap rows, rich text, a control's drawn words.
static func texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	elif node is RichTextLabel:
		out.append((node as RichTextLabel).get_parsed_text())
	elif node is CreditsHint:
		# Only the words: a part with a cap is drawn as a keycap, not typed.
		var said := PackedStringArray()
		for part in (node as CreditsHint).parts:
			if not part.has("cap"):
				said.append(String(part["say"]))
		out.append(" ".join(said))
	for child in node.get_children():
		out.append_array(texts(child))
	return out


func _removed_hit(said: PackedStringArray, gone: String) -> String:
	for line in said:
		if line.contains(gone):
			return line
	return ""


func _clean(label: String, page: Node) -> void:
	var said := texts(page)
	for gone in REMOVED:
		var hit := _removed_hit(said, gone)
		_t.check("%s has no \"%s\"" % [label, gone], hit == "", hit)
	_t.check("%s types no key hint" % label, _typed(said) == "", _typed(said))


func _typed(said: PackedStringArray) -> String:
	for line in said:
		if _hint_rx.search(line) != null:
			return line
	return ""


# The one Back check every page runs; `report` false runs it on a planted copy and only answers.
func _back_is_esc(label: String, back: Button, report := true) -> bool:
	var ok: bool = back != null and back.text == "Back" and back.key == "key_esc"
	if report:
		_t.check("%s Back is a button" % label, back != null and back.text == "Back")
		_t.eq("%s Back wears the Esc keycap" % label, back.key if back != null else "", "key_esc")
	return ok


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var screens = _game.screens
	var profile = _game.ctx.profile

	# The check can fail: a page that types its way out must trip it, and a clean one must not.
	var planted := Label.new()
	planted.text = "Left / Right or Q / E to turn the page.  Esc to close."
	root.add_child(planted)
	_t.check("PLANTED a page typing \"Esc to close\" is caught", _typed(texts(planted)) != "")
	var planted_hold := Label.new()
	planted_hold.text = "Stake: hold E at relay mast"
	_t.check("PLANTED a typed \"hold E\" is caught", _typed(texts(planted_hold)) != "")
	var planted_f := Label.new()
	planted_f.text = "F: fire your active"
	_t.check("PLANTED a typed \"F:\" is caught", _typed(texts(planted_f)) != "")
	var clean := Label.new()
	clean.text = "Relay mast: hold to raise the bet"
	_t.check("a clean line passes", _typed(texts(clean)) == "")
	# The removed-string check and the Back check each run on a broken copy and must report it.
	var broken := Label.new()
	broken.text = "Takes found: 2 of 5"
	root.add_child(broken)
	var broken_hits := 0
	for gone in REMOVED:
		if _removed_hit(texts(broken), gone) != "":
			broken_hits += 1
	_t.check("PLANTED a removed string is reported", broken_hits >= 1, str(broken_hits))
	broken.free()
	var wrong_back := ChoiceButton.new("back", "key_h", "Back")
	_t.check("PLANTED a Back on H is reported", not _back_is_esc("planted", wrong_back, false))
	wrong_back.free()
	var right_back := ChoiceButton.new("back", "key_esc", "Back")
	_t.check("a Back on Esc passes", _back_is_esc("planted", right_back, false))
	right_back.free()
	planted.free()
	planted_hold.free()
	planted_f.free()
	clean.free()

	# Help: every page it walks, with actives on so the F rule is built and shown.
	var help = screens._help
	_back_is_esc("Help", help.back)
	_game.tuning.set_option("actives", "on")
	for index in help._rows.size() + 2:
		help.show_page(index)
		_clean("Help page %d" % index, help)
	var rule_ids: Array = help.rules.keys()
	_t.eq("Help rules keep what pictures do not say", rule_ids, ["grip", "radio", "stake", "active"])
	_t.check("Help rules draw their keys as caps", help.rules["stake"].parts.any(func(p): return p.has("cap"))
		and help.rules["active"].parts.any(func(p): return p.has("cap")) and help.rules["radio"].parts.filter(func(p): return p.has("cap")).size() == 3)
	_t.eq("Get heavy leads the goal row", HelpPage.GOAL[0]["words"], "Get heavy")
	_t.check("SPIL-9 is introduced once as your companion", MechanicsCaptions.introduced() == 1, str(MechanicsCaptions.introduced()))
	_t.check("no picture caption is empty", MechanicsCaptions.empty() == 0)
	_t.check("no rule or caption opens with a Label: colon", MechanicsCaptions.colons(help) == 0, str(MechanicsCaptions.colons(help)))
	_t.check("no picture caption is Label · sentence", MechanicsCaptions.dotted() == 0)

	# Achievements: the board line is the count.
	var ach = screens.achievements_page()
	_back_is_esc("Achievements", ach.back)
	ach.refresh(profile, null)
	_clean("Achievements", ach)

	# Jukebox and radio: the count is n/N in the page's heading line.
	var juke = screens.jukebox_page()
	_back_is_esc("Jukebox", juke.back)
	juke.refresh(profile)
	_clean("Jukebox", juke)
	_t.check("Jukebox count is n/N", juke._count.text.contains("/") and not juke._count.text.contains(" of "), juke._count.text)
	var radio_page = screens.radio_page()
	_back_is_esc("Radio", radio_page.back)
	radio_page.refresh(profile, _game.radio_deck.radio)
	_clean("Radio", radio_page)
	_t.check("Radio count is n/N", radio_page._count.text.contains("/") and not radio_page._count.text.contains(" of "), radio_page._count.text)

	# Camp: Back wears Esc; the walk strip keeps its keys on the first walk and only leave camp after it.
	var camp = CampMenu.new()
	root.add_child(camp)
	_back_is_esc("Camp", camp.back)
	_clean("Camp", camp)
	camp.set_walk(true)
	_t.check("the first walk shows the roll keys", camp.walk_words().contains("roll") and camp.walk_words().contains("leave camp"), camp.walk_words())
	camp.set_walk(false)
	camp.set_walk(true)
	_t.eq("a later walk shows only the leave-camp key", camp.walk_words(), "K leave camp")
	_t.eq("the companion toast", CampMenu.NO_PIECES, "No SPIL-9 pieces yet. They turn up in runs.")
	camp.free()

	# Dispatch box: "Met x of y" and the yard as pips.
	var picker := Picker.new()
	root.add_child(picker)
	await _frames(1)
	picker.refresh(["chaser"], 2)
	_back_is_esc("Dispatch box", picker.back_button)
	_clean("Dispatch box", picker)
	_t.check("the manifest reads Met x of y", picker.get_child(1).text.begins_with("Met 1 of "), picker.get_child(1).text)
	_t.eq("the yard is two of four pips", picker.yard_pips(), Vector2i(2, 4))
	picker.free()

	# Scrapbook: keycaps for turn and Esc, n/N for the page.
	var book := Scrapbook.new()
	root.add_child(book)
	book.show_pages([{"run_id": "a", "outcome": "lost", "world_name": "Spillway"}])
	await _frames(1)
	_clean("Scrapbook", book)
	var keys: Control = book.get_node("Keys")
	_t.check("Scrapbook shows [Q] [E] turn and [Esc]", keys.parts.filter(func(p): return p.has("cap")).map(func(p): return p["cap"]) == ["key_q", "key_e", "key_esc"])
	_t.eq("Scrapbook counts n / N", book._count.text, "1 / 1")
	book.free()

	# Customize: no single-row titles, no notice, no tooltip, no word under the drawn "?".
	var camp_menu = screens.camp_page()
	var custom = camp_menu.get_node_or_null("CustomizePage")
	_t.check("the customize page is built on the camp", custom != null)
	if custom != null:
		_back_is_esc("Customize", custom.back)
		custom.refresh()
		_clean("Customize", custom)
		_t.check("all four groups keep their titles", ["BALL", "PILOT", "SPIL-9", "BAY"].all(func(g): return custom._group_labels.has(g)))
		_t.eq("no notice stands on the page", custom._notice.text, "")
		_t.check("no row carries a how-to tooltip", custom.rows.values().all(func(r): return r.tooltip_text == ""))
		var hidden := Customize.Card.new("x", "hidden", Color.WHITE, "Secret")
		_t.eq("a hidden card writes nothing under its ?", hidden.caption(), "")
		hidden.free()
		var owned := Customize.Card.new("x", "owned", Color.WHITE, "Dusk")
		_t.eq("an owned card writes its name", owned.caption(), "Dusk")
		_t.eq("hover shows the name only", custom.hover_text(owned), "Dusk.")
		owned.free()

	# Help rules: the caps come from the live bindings and are refreshed as the page opens.
	var before: Array = help.rules["radio"].parts.filter(func(p): return p.has("cap")).map(func(p): return p["cap"])
	var action := "cl_radio_next"
	var saved: Array = InputMap.action_get_events(action).duplicate()
	InputMap.action_erase_events(action)
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_N
	InputMap.action_add_event(action, rebound)
	help.visible = true
	help.visibility_changed.emit()
	var after: Array = help.rules["radio"].parts.filter(func(p): return p.has("cap")).map(func(p): return p["cap"])
	_t.check("PLANTED a rebind moves the radio cap when Help opens", before != after and after.has(Glyphs.of_action(action, "")), "%s then %s" % [before, after])
	InputMap.action_erase_events(action)
	for event in saved:
		InputMap.action_add_event(action, event)
	help.visible = false

	# Customize: every row sits under the title of its own group.
	if custom != null:
		var order: Array = []
		for child in custom._slot_list.get_children():
			order.append(child)
		var under := true
		for group in Customize.GROUPS:
			var at: int = order.find(custom._group_labels[group[0]])
			for i in group[1].size():
				under = under and at >= 0 and order[at + 1 + i] == custom.rows[group[1][i]]
		_t.check("every customize row sits under its own group's title", under)

	# The comic page: pilot, world and outcome in one plain sentence, even where the loss card is dropped.
	var lost := {"run_id": "l1", "outcome": "lost", "pilot_name": "Rivet", "world_name": "Spillway"}
	var won := {"run_id": "w1", "outcome": "won", "pilot_name": "Rivet", "world_name": "Spillway"}
	_t.eq("a win's subtitle", ComicPage.subtitle_text(won), "Rivet in Spillway.")
	_t.eq("a loss's subtitle", ComicPage.subtitle_text(lost), "Rivet in Spillway. Hull not returned.")
	var panels: Array = []
	for i in 6:
		panels.append({"kind": "beat", "caption": "The pilot did a thing that took a whole sentence to say.", "size": ["wide", "tall", "square"][i % 3], "world": 1})
	lost["panels"] = panels
	var dropped_width := 0.0
	var width := 720.0
	while width >= 280.0:
		var box := Rect2(Vector2.ZERO, Vector2(width, width / ComicPage.ASPECT))
		var kept: Array = ComicPage.fit_rows(box, panels, ComicPage.melodrama(lost))
		if not ComicPage.card_fits(box, panels, kept, ComicPage.melodrama(lost)):
			dropped_width = width
			break
		width -= 8.0
	_t.check("a size exists where the loss card is dropped", dropped_width > 0.0, str(dropped_width))
	for w in [dropped_width, 280.0]:
		var k: float = w / 720.0
		var room: float = w - 22.0 * k * 2.0 - 26.0 * k * 2.0 - 12.0 * k
		for page_dict in [won, lost]:
			var fs := ComicPage.subtitle_font(page_dict, room, k)
			var line := ComicPage.subtitle_text(page_dict)
			var fits: bool = UiFonts.bold().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room
			_t.check("the subtitle states pilot and world and fits at %d px" % int(w), fits and line.contains("Rivet") and line.contains("Spillway"), line)
	_t.check("a small page's subtitle still says how the run ended", ComicPage.subtitle_text(lost).contains("Hull not returned"))

	# The run summary's stat words and the board's "pays" line.
	var stats := {"time": 90.0, "stages": 1, "scrap": 5, "parts": [], "kills": 3, "events_won": 0, "save_used": 0}
	var stat_words := SummaryRows.rows(stats, 6).map(func(r): return r[2])
	_t.check("the summary says clocked out, not kills", "clocked out" in stat_words and not "kills" in stat_words, str(stat_words))
	var pays := ShiftBoard.pays_words({"item": "strike_pocket"})
	_t.check("an item pays as can turn up in runs", pays.ends_with("can turn up in runs") and not pays.contains("pools"), pays)
	var logged := ["mark_sable", "mark_rivet", "mark_tarn", "mark_kest", "mark_tally", "mark_cannon"].all(func(id): return ShiftBoard.RUNGS[id]["stamp"] == "LOGGED")
	_t.check("the six item marks are stamped LOGGED", logged)

	# The word "class" reaches no player in lanes.gd.
	var src := FileAccess.get_file_as_string("res://src/build/lanes.gd")
	var lanes_hit := ""
	for line in src.split("\n"):
		if line.contains("\"") and line.to_lower().contains("class") and not line.strip_edges().begins_with("#") and not line.contains("preload"):
			lanes_hit = line
	_t.check("lanes.gd says tier, not class", lanes_hit == "" and src.contains("next tier."), lanes_hit)
	_t.check("Lanes still loads", Lanes != null)

	_game.free()
	await process_frame
	quit(_t.verdict())


# The picture captions, read from the table the help page draws.
class MechanicsCaptions:
	const Diagram := preload("res://src/ui/mechanics_diagram.gd")

	static func introduced() -> int:
		var n := 0
		for id in Diagram.CAPTIONS:
			if String(Diagram.CAPTIONS[id]).contains("your companion"):
				n += 1
		return n

	static func empty() -> int:
		var n := 0
		for id in Diagram.CAPTIONS:
			if String(Diagram.CAPTIONS[id]).strip_edges() == "":
				n += 1
		return n

	# A "Label: sentence" shape in a caption or a help rule's words.
	static func colons(help) -> int:
		var n := 0
		for id in Diagram.CAPTIONS:
			if String(Diagram.CAPTIONS[id]).contains(": "):
				n += 1
		for id in help.rules:
			if help.rules[id].text().contains(": "):
				n += 1
		return n

	static func dotted() -> int:
		var n := 0
		for id in Diagram.CAPTIONS:
			if String(Diagram.CAPTIONS[id]).contains(" · "):
				n += 1
		return n
