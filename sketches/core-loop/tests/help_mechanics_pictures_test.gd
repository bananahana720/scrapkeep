# 2026-10-12 FIXTURE-ADAPT: ba3deab added skill-bar controls; keep the controls page inside its 40-word limit.
extends SceneTree

const Game := preload("res://src/game.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const MechanicsDiagram := preload("res://src/ui/mechanics_diagram.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("help_mechanics_pictures_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	# Actives are on by default (24 Oct); this page's off checks run with --actives=off.
	_t.check("actives on by default", game.tuning.option("actives") == "on")
	game.tuning.set_option("actives", "off")
	game.screens.toggle_help()
	await process_frame
	await process_frame
	_t.check("title opens help", game.screens.help_open())
	var help = game.screens._help
	game.screens._content.modulate.a = 1.0
	_t.check("controls open first", help.diagram.visible and not help._mechanics.visible)
	var controls_words: Dictionary = WordBudget.count(game.screens)
	_t.check("controls page fits 40 words", controls_words.hud <= 40, "%d words: %s" % [controls_words.hud, controls_words.items])
	var expected_keys := []
	for row in ControlsDiagram.controls():
		if row.has("caps") and row.has("short"):
			expected_keys.append_array(row["caps"])
	var shown_keys: Array = help.diagram.shown_keys()
	expected_keys.sort()
	shown_keys.sort()
	_t.eq("controls retain every binding", shown_keys, expected_keys)
	for key in shown_keys:
		if key in ["key_a", "key_s", "key_d", "key_2", "key_3"]:
			continue
		_t.check("controls keep action on " + key, help.diagram.label_of(key) != "" or ControlsDiagram.ARROWS.has(key))
	var seen := []
	for p in MechanicsDiagram.PAGES.size():
		help.page_button.pressed.emit()
		await process_frame
		var last: bool = p == MechanicsDiagram.PAGES.size() - 1
		_t.check("picture page %d replaces controls" % (p + 1), not help.diagram.visible and help._mechanics.visible
			and help.page_button.text == ("Rules" if last else "More"))
		game.screens._content.modulate.a = 1.0
		var words: Dictionary = WordBudget.count(game.screens)
		_t.check("picture page %d fits 40 words including drawn labels" % (p + 1), words.hud <= 40, "%d words: %s" % [words.hud, words.items])
		for id in MechanicsDiagram.PAGES[p]:
			seen.append(id)
			if not _t.check(id + " picture exists", help.pictures.has(id)):
				continue
			var picture: Control = help.pictures[id].picture
			var caption: Label = help.pictures[id].caption
			var named_by_drawing: bool = not MechanicsDiagram.CAPTIONS.has(id)
			if named_by_drawing:
				_t.check(id + " has no caption slot", caption == null)
			_t.check(id + " draws its diagram", picture.get_script() == MechanicsDiagram and picture.mechanic == id
				and picture.is_visible_in_tree() and picture.size.x >= MechanicsDiagram.PICTURE_SIZE.x)
			if named_by_drawing:
				_t.eq(id + " leaves mouse to menu", picture.mouse_filter, Control.MOUSE_FILTER_IGNORE)
				continue
			_t.eq(id + " caption", caption.text, MechanicsDiagram.CAPTIONS[id])
			_t.check(id + " caption is a visible single line", caption.is_visible_in_tree() and not caption.text.contains("\n")
				and caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x <= picture.size.x)
			_t.check(id + " fits screen", root.get_visible_rect().encloses(picture.get_global_rect()) and root.get_visible_rect().encloses(caption.get_global_rect()))
			_t.eq(id + " leaves mouse to menu", picture.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_t.eq("every picture is on a page", seen.size(), help.pictures.size())
	# HELP-REFRESH (WHATS-LEFT): wall grip, jam fields, cast times, the radio dial, relay
	# stakes, SPIL-9's next ram and actives each have a picture.
	for id in ["grip", "jam", "cast", "radio", "stake", "halo"]:
		_t.check("the refresh covers " + id, seen.has(id))
	var radio_picture := MechanicsDiagram.new("radio")
	var radio_words: PackedStringArray = radio_picture.drawn_words()
	radio_picture.free()
	_t.eq("the radio picture shows its four keys", radio_words, PackedStringArray([",", ".", "/", ";"]))
	_t.check("Back fits screen", root.get_visible_rect().encloses(help.back.get_global_rect()))
	_t.check("SPIL-9 caption says the next ram calls it in", MechanicsDiagram.CAPTIONS["halo"].contains("next ram calls in SPIL-9"))
	help.page_button.pressed.emit()
	await process_frame
	game.screens._content.modulate.a = 1.0
	_t.check("rules replace pictures", help._rules.visible and not help._mechanics.visible and not help.diagram.visible and help.page_button.text == "Controls")
	var rules_words: Dictionary = WordBudget.count(game.screens)
	_t.check("rules page fits 40 words", rules_words.hud <= 40, "%d words: %s" % [rules_words.hud, rules_words.items])
	# The verbs of HELP-REFRESH, each by a word the rendered page shows (SPIL-9 is the Pictures caption).
	var drawn := PackedStringArray()
	for item in rules_words.items:
		drawn.append(String(item.text).to_lower())
	var shown := " ".join(drawn)
	var rules_in_order := []
	for rule in FieldNotes.FIELD_RULES:
		rules_in_order.append(rule.id)
	# Jam and cast are the picture pages' captions now (ruling cx); the rules keep what a picture cannot say.
	_t.eq("rules cover grip, radio, mast and active", rules_in_order, ["grip", "radio", "stake", "active"])
	for want in ["stay fast against a wall and you climb it", "radio", "relay mast", "hold e"]:
		_t.check("rules page shows \"" + want + "\"", shown.contains(want))
	# Actives off: no F line, and never the dev flag's name.
	_t.check("actives off: no F line", not help.rules["active"].is_visible_in_tree() and not shown.contains("fire your active"), shown)
	_t.check("rules page never names --actives", not shown.contains("--actives"), shown)
	for id in help.rules:
		if id == "active":
			continue
		var line = help.rules[id]
		_t.check(id + " rule is a visible single line on screen", line.is_visible_in_tree() and not line.text().contains("\n")
			and root.get_visible_rect().encloses(line.get_global_rect()))
	# With actives on, the F line shows, inside the same budget, still without the flag's name.
	game.tuning.set_option("actives", "on")
	help._show("rules")
	await process_frame
	game.screens._content.modulate.a = 1.0
	var on_words: Dictionary = WordBudget.count(game.screens)
	var on_drawn := PackedStringArray()
	for item in on_words.items:
		on_drawn.append(String(item.text).to_lower())
	var on_shown := " ".join(on_drawn)
	_t.check("actives on: rules page fits 40 words", on_words.hud <= 40, "%d words: %s" % [on_words.hud, on_words.items])
	_t.check("actives on: F line shows", on_shown.contains("f fire your active") and not on_shown.contains("--actives"), on_shown)
	for id in help.rules:
		var line = help.rules[id]
		_t.check(id + " rule (actives on) is a visible single line on screen", line.is_visible_in_tree() and not line.text().contains("\n")
			and root.get_visible_rect().encloses(line.get_global_rect()))
	game.tuning.set_option("actives", "off")
	_t.check("Rules page keeps Back on screen", root.get_visible_rect().encloses(help.back.get_global_rect()))
	help.page_button.pressed.emit()
	_t.check("Controls returns to the keyboard", help.diagram.visible and not help._mechanics.visible and not help._rules.visible and help.page_button.text == "Pictures")
	help.page_button.pressed.emit()
	help.back.pressed.emit()
	_t.check("Back closes help", not game.screens.help_open())
	game.screens.toggle_help()
	_t.check("reopening help resets to controls", help.diagram.visible and not help.pictures_showing() and help.page_button.text == "Pictures")
	game.free()
	await process_frame
	quit(_t.verdict())
