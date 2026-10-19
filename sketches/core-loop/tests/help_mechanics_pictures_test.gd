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
	for row in FieldNotes.CONTROLS:
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
			and help.page_button.text == ("Controls" if last else "More"))
		game.screens._content.modulate.a = 1.0
		var words: Dictionary = WordBudget.count(game.screens)
		_t.check("picture page %d fits 40 words including drawn labels" % (p + 1), words.hud <= 40, "%d words: %s" % [words.hud, words.items])
		for id in MechanicsDiagram.PAGES[p]:
			seen.append(id)
			if not _t.check(id + " picture exists", help.pictures.has(id)):
				continue
			var picture: Control = help.pictures[id].picture
			var caption: Label = help.pictures[id].caption
			_t.check(id + " draws its diagram", picture.get_script() == MechanicsDiagram and picture.mechanic == id
				and picture.is_visible_in_tree() and picture.size.x >= MechanicsDiagram.PICTURE_SIZE.x)
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
	var radio_words: PackedStringArray = MechanicsDiagram.new("radio").drawn_words()
	_t.eq("the radio picture shows its four keys", radio_words, PackedStringArray([",", ".", "/", ";"]))
	_t.check("Back fits screen", root.get_visible_rect().encloses(help.back.get_global_rect()))
	help.page_button.pressed.emit()
	_t.check("Controls returns to the keyboard", help.diagram.visible and not help.pictures_showing())
	help.page_button.pressed.emit()
	help.back.pressed.emit()
	_t.check("Back closes help", not game.screens.help_open())
	game.screens.toggle_help()
	_t.check("reopening help resets to controls", help.diagram.visible and not help.pictures_showing() and help.page_button.text == "Pictures")
	game.free()
	await process_frame
	quit(_t.verdict())
