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
const Tuning := preload("res://src/movement/tuning.gd")

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
const MENU_STATES := ["title", "class_select", "dead", "victory", "summary"]
const TITLE := "SCRAPKEEP: FIRST RUN"

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
	_actions = _row(18)
	_content.add_child(_actions)
	_help = HelpPage.new()
	_help.visible = false
	_help.back.pressed.connect(_press.bind("key_h"))
	_content.add_child(_help)
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
	_actions.visible = true
	for row in [_stats, _choices, _actions]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	match state:
		"title":
			_show(TITLE, Palette.AMBER, FieldNotes.OBJECTIVE)
			_action("start", "key_space", "Start")
			_action("help", "key_h", "Help")
			if game.tuning.option(Tuning.MUSIC_KEY) == "ace":
				_action("breath", "key_b", "")
			refresh_lab_row()
		"class_select":
			_show("Choose your class", Palette.SAND, "")
			var classes: Array = game.flow.classes
			var width := minf(CARD_MAX, (_screen().x - 2.0 * SIDE - (classes.size() - 1) * CARD_GAP) / maxf(1.0, classes.size()))
			for i in classes.size():
				var card := ClassCard.new(classes[i], "key_%d" % (i + 1), width)
				card.pressed.connect(_press.bind(card.key))
				_choices.add_child(card)
		"dead":
			_show("SCRAPPED", EventKinds.color("player_died"), game.flow.gap_line())
			_action("retry", "key_r", "Retry the arena" if game.flow.in_arena else "Retry stage %d" % game.ctx.stages.local(game.run.stage))
			_action("new", "key_n", "New run")
			_action("class", "key_c", "Choose class")
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
			_victory_boss = {}
			_show("RUN COMPLETE", EventKinds.color("run_ended"), body)
			_summary_stats()
			_action("again", "key_n", "Run again")
			_action("class", "key_space", "Choose class")
	_fade(state in MENU_STATES)
	_update_enabled()


# H on the title swaps its body and actions for the how-to-play page, and back.
func toggle_help() -> void:
	if _state != "title":
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


# With --music=ace the title's B cycles the Warden open's held breath; the button
# names what the next run plays.
func refresh_lab_row() -> void:
	var breath := button_for("breath")
	if breath != null:
		breath.text = "Breath: %s" % game.tuning.option(Tuning.BREATH_KEY)


func _input(event: InputEvent) -> void:
	if not _help.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		toggle_help()
		get_viewport().set_input_as_handled()


func _show(title: String, color: Color, body: String) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_body.text = body
	_body.visible = body != ""


func _action(id: String, key: String, words: String) -> void:
	var button := ChoiceButton.new(id, key, words)
	button.pressed.connect(_press.bind(key))
	_actions.add_child(button)


# A button presses its key: the same route, the same guards, the same result.
func _press(key: String) -> void:
	game._screen_key(OS.find_keycode_from_string(Keycap.label(key)))


# The boss row of the world the run is in: on the victory screen, the world whose boss was
# just beaten. The summary reads the row the victory screen showed, so a run that ends with
# no boss beaten (a table with no boss, an unbuilt world) shows no epitaph.
func _beaten_boss() -> Dictionary:
	return game.flow.boss_row(game.ctx.stages.world_of(game.run.stage))


# The summary as icons and numbers: time, stages, scrap, parts, kills, events won and
# retries, each on its own icon.
func _summary_stats() -> void:
	var s: Dictionary = game.run.summary()
	var chips := [
		["res_timer", "%d:%02d" % [int(s["time"]) / 60, int(s["time"]) % 60]],
		["obj_beacon", "%d/%d" % [s["stages"], game.ctx.stages.COUNT]],
		["res_scrap", str(s["scrap"])],
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


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func _process(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)
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
		return _help.back
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
