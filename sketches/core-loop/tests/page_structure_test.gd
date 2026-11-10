extends SceneTree

const Game := preload("res://src/game.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const Picker := preload("res://src/ui/camp_enemy_picker.gd")
const Scrapbook := preload("res://src/ui/camp_scrapbook.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const HelpPage := preload("res://src/ui/help_page.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")
const Lanes := preload("res://src/build/lanes.gd")
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


func _clean(label: String, page: Node) -> void:
	var said := texts(page)
	for gone in REMOVED:
		var hit := ""
		for line in said:
			if line.contains(gone):
				hit = line
		_t.check("%s has no \"%s\"" % [label, gone], hit == "", hit)
	_t.check("%s types no key hint" % label, _typed(said) == "", _typed(said))


func _typed(said: PackedStringArray) -> String:
	for line in said:
		if _hint_rx.search(line) != null:
			return line
	return ""


func _back_is_esc(label: String, back: Button) -> void:
	_t.check("%s Back is a button" % label, back != null and back.text == "Back")
	_t.eq("%s Back wears the Esc keycap" % label, back.key if back != null else "", "key_esc")


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
	_t.check("one SPIL-9 caption", MechanicsCaptions.spil_count() == 1, str(MechanicsCaptions.spil_count()))
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
	_t.eq("Scrapbook counts n/N", book._count.text, "1/1")
	book.free()

	# Customize: no single-row titles, no notice, no tooltip, no word under the drawn "?".
	var camp_menu = screens.camp_page()
	var custom = camp_menu.get_node_or_null("CustomizePage")
	_t.check("the customize page is built on the camp", custom != null)
	if custom != null:
		_back_is_esc("Customize", custom.back)
		custom.refresh()
		_clean("Customize", custom)
		_t.check("PILOT and BAY title no single row", not custom._group_labels.has("PILOT") and not custom._group_labels.has("BAY"))
		_t.check("BALL and SPIL-9 still title their rows", custom._group_labels.has("BALL") and custom._group_labels.has("SPIL-9"))
		_t.eq("no notice stands on the page", custom._notice.text, "")
		_t.check("no row carries a how-to tooltip", custom.rows.values().all(func(r): return r.tooltip_text == ""))
		var hidden := Customize.Card.new("x", "hidden", Color.WHITE, "Secret")
		_t.eq("a hidden card writes nothing under its ?", hidden.caption(), "")
		hidden.free()
		var owned := Customize.Card.new("x", "owned", Color.WHITE, "Dusk")
		_t.eq("an owned card writes its name", owned.caption(), "Dusk")
		_t.eq("hover shows the name only", custom.hover_text(owned), "Dusk.")
		owned.free()

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

	static func spil_count() -> int:
		var n := 0
		for id in Diagram.CAPTIONS:
			if String(Diagram.CAPTIONS[id]).contains("SPIL-9"):
				n += 1
		return n

	static func dotted() -> int:
		var n := 0
		for id in Diagram.CAPTIONS:
			if String(Diagram.CAPTIONS[id]).contains(" · "):
				n += 1
		return n
