extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Companion := preload("res://src/core/companion.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The interim camp (C7), a title page on K and the summary's Camp action, on the real title:
#   - built synchronously; K, Escape, pad B and Back close it; A, S and Space leave for their page;
#   - it reads ready and locked pilots, companion pieces found and seated, and achievements;
#   - its Companion button shows only with a piece and opens the companion panel;
#   - the summary's Camp (K, pad Y) lands on the title with the camp open;
#   - every camp label is 15 words or fewer.

const LABEL_WORDS := 15
const EARNED_AT := 1790000000.0

var _t := T.new("ui_camp_menu_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _reopen(screens) -> void:
	if screens.camp_open():
		_game._screen_key(KEY_K)
	_game._screen_key(KEY_K)


func _line_with(lines: PackedStringArray, prefix: String) -> String:
	for line in lines:
		if line.begins_with(prefix):
			return line
	return ""


func _run() -> void:
	while _game.flow == null:
		await process_frame
	# Checked in the call that built the screens, before another frame: no deferred add_child.
	var page = _game.screens.camp_page() if _game.screens != null else null
	_t.check("the camp page is built synchronously", page != null and page.is_inside_tree(), "")
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var screens = _game.screens
	var flow = _game.flow
	var profile = _game.ctx.profile
	var camp = screens.camp_page()
	var ws = _game.get_node("Workshop")
	await _settle(0.6)
	_t.eq("the game starts on the title", flow.state_name(), "title")
	var camp_button = screens.button_for("camp")
	_t.check("the title has a Camp button on K", camp_button != null and camp_button.key == "key_k", "")
	var first = screens._actions.get_child(0)
	_t.check("Continue or Start stays first on the title", first.action == "continue" or first.action == "start", first.action)

	# K opens and closes.
	_game._screen_key(KEY_K)
	await _frames(1)
	_t.check("K opens the camp", screens.camp_open() and screens.overlay_open(), "")
	_t.eq("the camp's title reads CAMP", screens._title.text, "CAMP")
	_t.check("the title actions hide under the camp", not screens._actions.visible, "")
	_t.check("focus lands on Launch", root.gui_get_focus_owner() == camp.button_for("launch"), str(root.gui_get_focus_owner()))
	_game._screen_key(KEY_K)
	await _frames(1)
	_t.check("K again closes the camp", not screens.camp_open() and screens._actions.visible, "")
	_t.eq("the title body comes back", screens._body.text, FieldNotes.OBJECTIVE)
	_t.check("nothing keeps focus after closing", root.gui_get_focus_owner() == null, str(root.gui_get_focus_owner()))

	# Escape and pad B close; pad A presses the focused button.
	_game._screen_key(KEY_K)
	Push.key(root, KEY_ESCAPE)
	await _frames(1)
	_t.check("Escape closes the camp", not screens.camp_open(), "")
	_game._screen_key(KEY_K)
	Push.pad(root, JOY_BUTTON_B)
	await _frames(1)
	_t.check("pad B closes the camp", not screens.camp_open(), "")
	_game._screen_key(KEY_K)
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	_t.eq("pad A on the camp is not a title key", _game.pad_screen_key(pad_a), KEY_NONE)
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_t.eq("pad A on focused Launch goes to class select", flow.state_name(), "class_select")
	flow.show_title()
	await _frames(1)

	# Pilots.
	var starters := 0
	var locked_def = null
	for def in flow.classes:
		if def.starter:
			starters += 1
		elif locked_def == null:
			locked_def = def
	var read: Dictionary = CampMenu.reading(_game)
	print("camp lines, fresh profile: %s" % " | ".join(read["lines"]))
	var ready := 0
	for p in read["pilots"]:
		if p["ready"]:
			ready += 1
	_t.eq("a fresh profile has the starters ready", ready, starters)
	_t.eq("the headline counts them", read["lines"][0], "Pilots ready: %d of %d" % [starters, flow.classes.size()])
	_t.check("a non-starter pilot exists", locked_def != null, "")
	var hint := ClassCard.unlock_hint(locked_def, _game.progress)
	var locked_line := _line_with(read["lines"], "%s: " % locked_def.display_name)
	_t.check("a locked pilot's line names how it unlocks", locked_line.contains(hint if hint != "" else "locked"), locked_line)
	profile.unlock_pilot(locked_def.id)
	_reopen(screens)
	read = CampMenu.reading(_game)
	var after := 0
	var now_ready := false
	for p in read["pilots"]:
		if p["ready"]:
			after += 1
		if p["id"] == locked_def.id:
			now_ready = p["ready"]
	_t.check("an unlocked pilot reads ready and the count rises", now_ready and after == starters + 1
		and camp.labels().has("%s: ready" % locked_def.display_name), "ready %s, %d of %d" % [now_ready, after, starters + 1])
	var still_locked = null
	for def in flow.classes:
		if not _game.pilot_unlocked(def):
			still_locked = def
			break
	if still_locked != null:
		var h := ClassCard.unlock_hint(still_locked, _game.progress)
		var line := _line_with(read["lines"], "%s: " % still_locked.display_name)
		_t.check("a still-locked pilot names its unlock", line.contains(h if h != "" else "locked"), line)

	# Companion.
	_t.check("a fresh profile reads no pieces", camp.labels().has(CampMenu.NO_PIECES), "")
	_t.check("no Companion button without pieces", camp.button_for("companion") == null, "")
	profile.set_companion(Companion.with_piece({}, "escape_vent"))
	_reopen(screens)
	_t.check("one piece reads 1 of the table", camp.labels().has("Companion pieces: 1 of %d" % Companion.PIECES.size()), "\n".join(camp.labels()))
	_t.check("nothing seated reads none", camp.labels().has("Seated: none"), "")
	var companion = camp.button_for("companion")
	_t.check("the Companion button shows with a piece", companion != null, "")
	if companion != null:
		companion.pressed.emit()
		await _frames(1)
		_t.check("Companion closes the camp and opens the panel", not screens.camp_open() and ws.companion_panel.is_open(), "camp %s" % screens.camp_open())
		ws.companion_panel.close()
		await _frames(1)

	# Achievements count.
	profile.earn(Achievements.ids()[0], EARNED_AT)
	_reopen(screens)
	_t.check("an earn shows in the count", camp.labels().has("Achievements: 1 of %d earned" % Achievements.ids().size()), "")

	# Pages from the camp.
	_game._screen_key(KEY_A)
	await _frames(1)
	_t.check("A from the camp opens achievements", screens.achievements_open() and not screens.camp_open(), "")
	screens.button_for("back").pressed.emit()
	await _frames(1)
	_t.check("its Back returns to the title", not screens.achievements_open() and screens._actions.visible and not screens.camp_open(), "")
	_game._screen_key(KEY_K)
	_game._screen_key(KEY_S)
	await _frames(1)
	_t.check("S from the camp opens settings", screens.settings_open() and not screens.camp_open(), "")
	screens.toggle_settings()
	await _frames(1)
	_t.check("settings' back returns to the title", not screens.settings_open() and screens._actions.visible and not screens.camp_open(), "")
	_game._screen_key(KEY_K)
	_game._screen_key(KEY_SPACE)
	await _frames(1)
	_t.eq("Space from the camp goes to class select", flow.state_name(), "class_select")
	flow.show_title()
	await _frames(1)

	# Labels.
	_game._screen_key(KEY_K)
	var longest := 0
	for line in camp.labels():
		longest = maxi(longest, WordBudget.words_in(line))
	_t.check("every camp label is %d words or fewer" % LABEL_WORDS, longest <= LABEL_WORDS, "%d words" % longest)
	_game._screen_key(KEY_K)

	# Summary.
	flow._set_state(flow.SUMMARY)
	await _frames(1)
	var summary_camp = screens.button_for("camp")
	_t.check("the summary has a Camp action on K", summary_camp != null and summary_camp.key == "key_k", "")
	_game.summary_guard_left = 0.75
	_game._screen_key(KEY_K)
	_t.eq("K under the summary guard stays on the summary", flow.state_name(), "summary")
	_game.summary_guard_left = 0.0
	var pad_y := InputEventJoypadButton.new()
	pad_y.button_index = JOY_BUTTON_Y
	pad_y.pressed = true
	_t.eq("pad Y on the summary is K", _game.pad_screen_key(pad_y), KEY_K)
	_game._screen_key(KEY_K)
	await _frames(1)
	_t.check("K on the summary lands on the title with the camp open", flow.state_name() == "title" and screens.camp_open(), flow.state_name())
	_t.check("no Continue after a finished run", screens.button_for("continue") == null, "")
	quit(_t.verdict())
