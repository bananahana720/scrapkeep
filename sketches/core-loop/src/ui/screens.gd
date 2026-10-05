extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const HelpPage := preload("res://src/ui/help_page.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Worlds := preload("res://src/core/worlds.gd")

# The screens outside play: title (with its how-to-play page on H), class select,
# death, victory and summary. Each is one glance and one key, and every choice is also
# a button that presses that key through game._screen_key, so a click and a key can
# never disagree. Starting and restarting take a second (principle 2). Screens fade in
# and out with a tween; the fade never holds input or the ball, so play starts under a
# fading veil.

const FADE_IN := 0.3
const FADE_OUT := 0.25
const SLIDE := 14.0
# The death screen ignores clicks for its first beat: a fire button held or mashed as
# the ball died must not pick a choice. Keys work at once.
const CLICK_GUARD := 0.5
const CARD_GAP := 24.0
const CARD_MAX := 420.0
const SIDE := 60.0
# The actions row's gap; a crowded title row tightens it down to ACTION_GAP_MIN so it fits
# the narrowest supported width (int_screen_layout_test's 1280).
const ACTION_GAP := 18
const ACTION_GAP_MIN := 6
# Past the tightest gap, a crowded title row's words step down from the buttons' 22 to this.
const ACTION_FONT_MIN := 16
const NARROW_W := 1280.0
const MENU_STATES := ["title", "class_select", "dead", "victory", "summary"]
const TITLE := "SCRAPKEEP: FIRST RUN"
# A win over the final world's boss opens the summary on the ending page (Worlds.ENDING). For
# its first ENDING_HOLD seconds no key closes it, so a press meant for the fight cannot skip
# it; after that Space, Enter, Esc or any pad button shows the summary beneath.
const ENDING_HOLD := 1.0

var game
var _victory_boss := {}

var _veil: ColorRect
var _content: VBoxContainer
var _title: Label
var _body: Label
var _stats: HBoxContainer
var _choices: HBoxContainer
var _actions: HBoxContainer
var _help
var _achievements
var _settings
var _camp
var _ending: VBoxContainer
var _ending_title: Label
var _ending_body: Label
var _ending_left := 0.0
var _guard := 0.0
var _tween: Tween
var _state := ""


func setup(game_ref) -> void:
	game = game_ref
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(Palette.CHARCOAL, 0.84)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 26)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_title = _label(64)
	_content.add_child(_title)
	_body = _label(22)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(1000.0, 0.0)
	_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(_body)
	_stats = _row(30)
	_content.add_child(_stats)
	_choices = _row(CARD_GAP)
	_content.add_child(_choices)
	_actions = _row(ACTION_GAP)
	_content.add_child(_actions)
	_help = HelpPage.new()
	_help.visible = false
	_help.back.pressed.connect(_press.bind("key_h"))
	_content.add_child(_help)
	_achievements = AchievementsPage.new()
	_achievements.visible = false
	_achievements.back.pressed.connect(_press.bind("key_a"))
	_content.add_child(_achievements)
	_settings = SettingsPages.new()
	_settings.visible = false
	_settings.setup(game, "key_esc")
	_settings.back_requested.connect(toggle_settings)
	_content.add_child(_settings)
	_camp = CampMenu.new()
	_camp.visible = false
	_camp.button_for("launch").pressed.connect(_press.bind("key_space"))
	_camp.button_for("achievements").pressed.connect(_press.bind("key_a"))
	_camp.button_for("settings").pressed.connect(_press.bind("key_s"))
	_camp.back.pressed.connect(_press.bind("key_k"))
	_camp.companion_button().pressed.connect(_camp_companion)
	_content.add_child(_camp)
	_ending = VBoxContainer.new()
	_ending.alignment = BoxContainer.ALIGNMENT_CENTER
	_ending.add_theme_constant_override("separation", 26)
	_ending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending.visible = false
	_ending_title = _label(64)
	_ending.add_child(_ending_title)
	_ending_body = _label(22)
	_ending_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_body.custom_minimum_size = Vector2(1000.0, 0.0)
	_ending_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ending.add_child(_ending_body)
	_content.add_child(_ending)
	game.events.flow_changed.connect(_on_flow_changed)
	game.events.run_started.connect(func(_class_id): _victory_boss = {})


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _on_flow_changed(state: String) -> void:
	_state = state
	_help.visible = false
	_achievements.visible = false
	_settings.visible = false
	_camp.visible = false
	_ending.visible = false
	_ending_left = 0.0
	_title.visible = true
	_stats.visible = true
	_actions.visible = true
	_actions.add_theme_constant_override("separation", ACTION_GAP)
	for row in [_stats, _choices, _actions]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	match state:
		"title":
			# Continue (RS6) leads when a saved run is valid, so a pad's first focus lands on
			# it; a saved file this build cannot use names its cause and leaves New run only.
			game.flow.saved_run()
			var body: String = FieldNotes.OBJECTIVE
			if game.flow.saved_run_cause != "":
				body = "Saved run not loaded (%s): %s\n\n%s" % [game.flow.saved_run_cause, game.flow.saved_run_why, body]
			_show(TITLE, Palette.AMBER, body)
			if game.flow.continue_ready:
				_action("continue", "key_c", "Continue")
			var saved: bool = game.flow.continue_ready or game.flow.saved_run_cause != ""
			_action("start", "key_space", "New run" if saved else "Start")
			_action("help", "key_h", "Help")
			_action("achievements", "key_a", "Achievements")
			_action("settings", "key_s", "Settings")
			if game.ctx.profile != null and not game.ctx.profile.companion().is_empty():
				_companion_action()
			_action("camp", "key_k", "Camp")
			if game.tuning.option(Tuning.MUSIC_KEY) == "ace":
				_action("breath", "key_b", "")
			refresh_lab_row()
			_fit_actions()
		"class_select":
			_show("Choose your class", Palette.SAND, "")
			var classes: Array = game.flow.classes
			var width := minf(CARD_MAX, (_screen().x - 2.0 * SIDE - (classes.size() - 1) * CARD_GAP) / maxf(1.0, classes.size()))
			for i in classes.size():
				var card := ClassCard.new(classes[i], "key_%d" % (i + 1), width)
				card.pressed.connect(_press.bind(card.key))
				_choices.add_child(card)
				card.bind_profile(game.ctx.profile)
				card.set_locked(not game.pilot_unlocked(classes[i]), _unlock_hint(classes[i]))
		"dead":
			_show("SCRAPPED", EventKinds.color("player_died"), game.flow.gap_line())
			_action("retry", "key_r", "Retry the arena" if game.flow.in_arena else "Retry stage %d" % game.ctx.stages.local(game.run.stage))
			_action("new", "key_n", "New run")
			_action("class", "key_c", "Choose class")
			if not game.run.companion.is_empty():
				_companion_action()
			if game.flow.can_replay_final_stage():
				_action("replay", "key_t", "Replay stage %d" % game.ctx.stages.local(game.flow.final_stage()))
			_guard = CLICK_GUARD
		"victory":
			var boss := _beaten_boss()
			_victory_boss = boss
			_show(String(boss.get("title", "BOSS ROUTED")), EventKinds.color("boss_defeated"), String(boss.get("victory", "")))
		"summary":
			var body := String(game.run.summary()["class"])
			var epitaph := String(_victory_boss.get("epitaph", ""))
			if epitaph != "":
				body += "\n" + epitaph
			var ending: bool = game.flow.won_final() and not _victory_boss.is_empty()
			if not ending:
				_victory_boss = {}
			_show("RUN COMPLETE" if game.flow.run_won else "RUN OVER", EventKinds.color("run_ended"), body)
			_summary_stats()
			_action("again", "key_n", "Run again")
			_action("class", "key_space", "Choose class")
			if not game.run.companion.is_empty():
				_companion_action()
			_action("camp", "key_k", "Camp")
			if ending:
				_open_ending()
	_fade(state in MENU_STATES)
	_update_enabled()


# H on the title swaps its body and actions for the how-to-play page, and back.
func toggle_help() -> void:
	_close_camp_silently()
	if _state != "title" or _achievements.visible or _settings.visible:
		return
	_help.visible = not _help.visible
	_actions.visible = not _help.visible
	if _help.visible:
		_show("HOW TO PLAY", Palette.AMBER, "")
	else:
		_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
	_fade(true)


func help_open() -> bool:
	return _help.visible


# A on the title swaps its body and actions for the achievements page, and back.
func toggle_achievements() -> void:
	_close_camp_silently()
	if _state != "title" or _help.visible or _settings.visible:
		return
	_achievements.visible = not _achievements.visible
	_actions.visible = not _achievements.visible
	if _achievements.visible:
		_achievements.refresh(game.ctx.profile, game.progress)
		_show("ACHIEVEMENTS", Palette.AMBER, "")
	else:
		_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
	_fade(true)


# S on the title swaps its body and actions for the settings page, and back. It never
# pauses the game or touches the mouse; Esc only goes back.
func toggle_settings() -> void:
	_close_camp_silently()
	if _state != "title" or _help.visible or _achievements.visible:
		return
	_settings.visible = not _settings.visible
	_actions.visible = not _settings.visible
	if _settings.visible:
		_settings.refresh()
		_show("SETTINGS", Palette.AMBER, "")
		_settings.focus("fullscreen")
	else:
		_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
	_fade(true)


# K on the title swaps its body and actions for the camp page, and back. A, S and H on the
# camp close it and open their own page, whose Back returns to the title.
func toggle_camp() -> void:
	if _state != "title" or _help.visible or _achievements.visible or _settings.visible:
		return
	_camp.visible = not _camp.visible
	_actions.visible = not _camp.visible
	if _camp.visible:
		_camp.refresh(game)
		_show("CAMP", Palette.AMBER, "")
		_camp.button_for("launch").grab_focus()
	else:
		_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
		get_viewport().gui_release_focus()
	_fade(true)


func _close_camp_silently() -> void:
	if not _camp.visible:
		return
	_camp.visible = false
	_actions.visible = true
	get_viewport().gui_release_focus()


# The camp's Companion button: the camp steps aside first, since open_companion refuses
# under an overlay.
func _camp_companion() -> void:
	_close_camp_silently()
	_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
	game.get_node("Workshop").open_companion()


# The summary's Camp: back to the title, with the camp open.
func open_camp_from_summary() -> void:
	game.flow.show_title()
	toggle_camp()


func camp_open() -> bool:
	return _camp.visible


func camp_page():
	return _camp


func settings_open() -> bool:
	return _settings.visible


func settings_page():
	return _settings


func achievements_open() -> bool:
	return _achievements.visible


func achievements_page():
	return _achievements


# The words on a locked pilot's card: the pilot's reward row text and lifetime count.
func _unlock_hint(def) -> String:
	return ClassCard.unlock_hint(def, game.progress)


# With --music=ace the title's B cycles the Warden open's held breath; the button
# names what the next run plays.
func refresh_lab_row() -> void:
	var breath := button_for("breath")
	if breath != null:
		breath.text = "Breath: %s" % game.tuning.option(Tuning.BREATH_KEY)


func overlay_open() -> bool:
	return _help.visible or _achievements.visible or _camp.visible or _ending.visible


func ending_open() -> bool:
	return _ending.visible


# The summary's title, epitaph, stats and actions are built beneath and wait hidden.
func _open_ending() -> void:
	_ending_title.text = String(Worlds.ENDING["title"])
	_ending_title.add_theme_color_override("font_color", EventKinds.color("run_ended"))
	_ending_body.text = "\n".join(PackedStringArray(Worlds.ENDING["log"])) + "\n\n" + String(Worlds.ENDING["sign"])
	_ending.visible = true
	_ending_left = ENDING_HOLD
	for node in [_title, _body, _stats, _actions]:
		node.visible = false


# The summary beneath takes over with its key guard fresh, so the press that closed the page
# cannot also start a run.
func _close_ending() -> void:
	_ending.visible = false
	_victory_boss = {}
	_title.visible = true
	_body.visible = _body.text != ""
	_stats.visible = true
	_actions.visible = true
	game.summary_guard_left = game.SUMMARY_GUARD
	_fade(true)
	_update_enabled()


func _ending_closes(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]


func _input(event: InputEvent) -> void:
	if _ending.visible:
		if _ending_left <= 0.0 and _ending_closes(event):
			_close_ending()
			get_viewport().set_input_as_handled()
		return
	if _settings.visible:
		if _settings.handle(event):
			get_viewport().set_input_as_handled()
		return
	if _camp.visible:
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			toggle_camp()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			toggle_camp()
			get_viewport().set_input_as_handled()
		return
	if overlay_open() and event is InputEventJoypadButton and event.pressed:
		# B closes the page and A does nothing; both are consumed so neither reaches the title
		# behind. Other pad buttons pass through.
		if event.button_index == JOY_BUTTON_B:
			if _help.visible:
				toggle_help()
			else:
				toggle_achievements()
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
		return
	if _pad_enters_title(event):
		get_viewport().set_input_as_handled()
		return
	if not (_help.visible or _achievements.visible) or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		if _help.visible:
			toggle_help()
		else:
			toggle_achievements()
		get_viewport().set_input_as_handled()


# On the title with nothing focused, a pad's d-pad or stick lands on the first button so A
# can press it. Pad events only: the keyboard's arrows keep doing what they did.
func _pad_enters_title(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or overlay_open():
		return false
	if game.flow.state_name() != "title" or get_viewport().gui_get_focus_owner() != null:
		return false
	for action in ["ui_down", "ui_up", "ui_left", "ui_right"]:
		if event.is_action_pressed(action):
			for child in _actions.get_children():
				if child is Button and child.focus_mode != Control.FOCUS_NONE:
					child.grab_focus()
					return true
	return false


func _show(title: String, color: Color, body: String) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_body.text = body
	_body.visible = body != ""


func _action(id: String, key: String, words: String) -> void:
	var button := ChoiceButton.new(id, key, words)
	button.pressed.connect(_press.bind(key))
	_actions.add_child(button)


# The death screen's, the summary's and the title's way into the companion screen
# (workshop.gd owns the M key); it is offered only when there is something to assemble.
func _companion_action() -> void:
	var button := ChoiceButton.new("companion", "key_m", "Companion")
	button.pressed.connect(func(): game.get_node("Workshop").open_companion())
	_actions.add_child(button)


# A button presses its key: the same route, the same guards, the same result.
func _press(key: String) -> void:
	game._screen_key(OS.find_keycode_from_string(Keycap.label(key)))


# The boss row of the world the run is in: on the victory screen, the world whose boss was
# just beaten. The summary reads the row the victory screen showed, so a run that ends with
# no boss beaten (a table with no boss, an unbuilt world) shows no epitaph.
func _beaten_boss() -> Dictionary:
	return game.flow.boss_row(game.ctx.stages.world_of(game.run.stage))


# The summary as icons and numbers: time, stages, cogs (the cog), scrap taken as mass (the heap), parts, kills, events won and
# retries, each on its own icon.
func _summary_stats() -> void:
	var s: Dictionary = game.run.summary()
	var chips := [
		["res_timer", "%d:%02d" % [int(s["time"]) / 60, int(s["time"]) % 60]],
		["obj_beacon", "%d/%d" % [s["stages"], game.ctx.stages.COUNT]],
		["res_scrap", str(s["cogs"])],
		["res_mass", str(s["scrap"])],
		["cat_transform", str((s["parts"] as Array).size())],
		["thr_instant", str(s["kills"])],
		["obj_event", str(s["events_won"])],
		["key_r", str(s["retries"])],
	]
	for chip in chips:
		var row := _row(8)
		var icon := TextureRect.new()
		icon.texture = Icons.texture(chip[0])
		icon.modulate = Icons.tint(chip[0], Palette.SAND)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30.0, 30.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var value := _label(26)
		value.add_theme_font_override("font", UiFonts.mono())
		value.text = chip[1]
		row.add_child(value)
		_stats.add_child(row)


func _fade(show: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if show:
		visible = true
		_content.modulate.a = 0.0
		_content.position.y = SLIDE
		_tween.tween_property(_veil, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "position:y", 0.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return
	_tween.tween_property(_veil, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_content, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		if not game.flow.state_name() in MENU_STATES:
			visible = false)


func _fit_actions() -> void:
	var gaps: int = _actions.get_child_count() - 1
	var room: float = minf(_screen().x, NARROW_W) - 2.0 * SIDE
	var over: float = _actions.get_combined_minimum_size().x - room
	if gaps > 0 and over > 0.0:
		_actions.add_theme_constant_override("separation", maxi(ACTION_GAP_MIN, ACTION_GAP - ceili(over / gaps)))
	var font := 22
	while font > ACTION_FONT_MIN and _actions.get_combined_minimum_size().x > room:
		font -= 1
		for child in _actions.get_children():
			child.add_theme_font_size_override("font_size", font)


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func _process(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)
	if _ending.visible:
		game.summary_guard_left = maxf(game.summary_guard_left, game.SUMMARY_GUARD)
		_ending_left = maxf(0.0, _ending_left - delta)
		if game.bot_driven and _ending_left <= 0.0:
			_close_ending()
	_update_enabled()


# Buttons take clicks only on a live screen, after its guard, and never while the
# summary still holds its keys (game.summary_guard_left).
func _update_enabled() -> void:
	var live := _state in MENU_STATES and _state != "victory" and _guard <= 0.0
	if _state == "summary" and game != null and game.summary_guard_left > 0.0:
		live = false
	for row in [_choices, _actions]:
		for child in row.get_children():
			(child as BaseButton).disabled = not live


func button_for(action: String) -> Button:
	if action == "back":
		if _settings.visible:
			return _settings.back
		if _camp.visible:
			return _camp.back
		return _achievements.back if _achievements.visible else _help.back
	for child in _actions.get_children():
		if child.action == action:
			return child
	return null


func class_cards() -> Array:
	return _choices.get_children()


# The screen as a player reads it: the body, then each choice as its key and words.
func body_text() -> String:
	var lines := PackedStringArray()
	if _body.text != "":
		lines.append(_body.text)
		lines.append("")
	for card in _choices.get_children():
		lines.append("%s   %s" % [Keycap.label(card.key), card.words().to_lower()])
	for button in _actions.get_children():
		lines.append("%s   %s" % [Keycap.label(button.key), button.text.to_lower()])
	return "\n".join(lines)
