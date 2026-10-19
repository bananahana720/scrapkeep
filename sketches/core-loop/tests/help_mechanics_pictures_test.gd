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
	help.page_button.pressed.emit()
	await process_frame
	_t.check("pictures replace controls", not help.diagram.visible and help._mechanics.visible and help.page_button.text == "Rules")
	game.screens._content.modulate.a = 1.0
	_t.check("pictures page fits 40 words including drawn labels", WordBudget.count(game.screens).hud <= 40)
	_t.eq("three pictures", help.pictures.size(), 3)
	for id in ["breach", "lift", "companion"]:
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
	_t.check("Back fits screen", root.get_visible_rect().encloses(help.back.get_global_rect()))
	_t.check("SPIL-9 caption says the next ram calls it in", MechanicsDiagram.CAPTIONS["companion"].contains("Next ram calls it in"))
	help.page_button.pressed.emit()
	await process_frame
	game.screens._content.modulate.a = 1.0
	_t.check("rules replace pictures", help._rules.visible and not help._mechanics.visible and not help.diagram.visible and help.page_button.text == "Controls")
	var rules_words: Dictionary = WordBudget.count(game.screens)
	_t.check("rules page fits 40 words", rules_words.hud <= 40, "%d words: %s" % [rules_words.hud, rules_words.items])
	# The seven verbs of HELP-REFRESH, each by a word the rendered page or picture shows.
	var drawn := PackedStringArray()
	for item in rules_words.items:
		drawn.append(String(item.text).to_lower())
	var shown := " ".join(drawn)
	var rules_in_order := []
	for rule in FieldNotes.FIELD_RULES:
		rules_in_order.append(rule.id)
	_t.eq("rules cover grip, jam, cast, radio, stake and active", rules_in_order, ["grip", "jam", "cast", "radio", "stake", "active"])
	for want in ["wall grip", "jam", "cast time", "radio", "stake", "f:", "--actives", "slots 2, 3", "hold e"]:
		_t.check("rules page shows \"" + want + "\"", shown.contains(want))
	for id in help.rules:
		var line: Label = help.rules[id]
		_t.check(id + " rule is a visible single line on screen", line.is_visible_in_tree() and not line.text.contains("\n")
			and root.get_visible_rect().encloses(line.get_global_rect()))
	_t.check("Rules page keeps Back on screen", root.get_visible_rect().encloses(help.back.get_global_rect()))
	help.page_button.pressed.emit()
	_t.check("Controls returns to the keyboard", help.diagram.visible and not help._mechanics.visible and not help._rules.visible and help.page_button.text == "Pictures")
	help.page_button.pressed.emit()
	help.back.pressed.emit()
	_t.check("Back closes help", not game.screens.help_open())
	game.screens.toggle_help()
	_t.check("reopening help resets to controls", help.diagram.visible and not help._mechanics.visible)
	game.free()
	await process_frame
	quit(_t.verdict())
