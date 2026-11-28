extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Screens := preload("res://src/ui/screens.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const BuildRead := preload("res://src/ui/build_read.gd")
const SettingRow := preload("res://src/ui/setting_row.gd")


const LAYER := 6
const FADE_IN := 0.16
const FADE_OUT := 0.12
const WIDTH := 500.0
const ROWS := [
	{"id": "resume", "key": "key_p", "words": "Resume"},
	{"id": "restart", "key": "key_n", "words": "New run"},
	{"id": "notes", "key": "key_tab", "words": "Field notes"},
	{"id": "radio", "key": "key_v", "words": "Radio"},
	{"id": "breath", "key": "key_b", "words": "Breath"},
	{"id": "settings", "key": "key_o", "words": "Settings"},
	{"id": "quit", "key": "key_x", "words": "Quit"},
]
const VALUE_ROWS := ["radio", "breath"]
const NOTES_KEYS := [KEY_Q, KEY_E, KEY_TAB]
const QUIT_KEY := KEY_X
const QUIT_HOLD := 0.6
const ARM_WORDS := {"restart": "Scrap this run? Press again", "quit": "Quit to desktop? Press again"}
const ARM_SECONDS := 3.0
const ARM_GUARD := 0.35

signal quit_chosen

var game
var store

var _root: Control
var _content: VBoxContainer
var _note: Label
var _page
var _in_settings := false
var _rows := {}
var _order: Array = []
var _open := false
var _notes_pinned := false
var _tween: Tween
var _quit_down := false
var _quit_held := 0.0
var _quit_ring: Control
var _armed := ""
var _armed_for := 0.0
var build_read


func _init() -> void:
	name = "PauseMenu"


func _ready() -> void:
	if game == null:
		setup(get_parent())


func setup(game_ref) -> void:
	game = game_ref
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	store = game.settings_store()
	apply_saved()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var veil := ColorRect.new()
	veil.color = Color(Palette.CHARCOAL, 0.8)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 12)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	_note = UiDraw.label(UiTokens.LABEL, Palette.SAND)
	_note.visible = false
	_content.add_child(_note)
	for spec in ROWS:
		var row: ChoiceButton = SettingRow.new(spec["id"], spec["key"], spec["words"]) if spec["id"] in VALUE_ROWS \
			else ChoiceButton.new(spec["id"], spec["key"], spec["words"])
		row.custom_minimum_size.x = WIDTH
		row.pressed.connect(press.bind(spec["id"]))
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content.add_child(row)
		_rows[spec["id"]] = row
		_order.append(spec["id"])
	_quit_ring = Control.new()
	_quit_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit_ring.draw.connect(_draw_quit_ring)
	_rows["quit"].add_child(_quit_ring)
	build_read = BuildRead.new()
	_root.add_child(build_read)
	_root.resized.connect(_lay_build)
	_page = SettingsPages.new()
	_page.visible = false
	_page.setup(game, "key_esc")
	_page.back_requested.connect(_leave_settings.bind(true))
	_content.add_child(_page)
	_show_breath()
	_set_live(false)
	game.events.flow_changed.connect(func(_state: String):
		if _open and not game.flow.in_play():
			close())


func apply_saved() -> void:
	SettingsPages.apply_saved(game)


func is_open() -> bool:
	return _open


func notes_pinned() -> bool:
	return _notes_pinned


func note(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


func note_text() -> String:
	return _note.text


func row(id: String) -> Control:
	return _rows.get(id)


func settings_page():
	return _page


func settings_open() -> bool:
	return _in_settings


func focused_id() -> String:
	for id in _order:
		if _rows[id].has_focus():
			return id
	return ""


func can_open() -> bool:
	return game.flow.in_play() and not _screen_holds() and not game.notes_held()


func _screen_holds() -> bool:
	if not game.menu_held():
		return false
	var workshop = game.get_node_or_null("Workshop")
	return workshop == null or not workshop.has_method("card_holds_only") or not workshop.card_holds_only()


func open() -> void:
	if _open or not can_open():
		return
	_open = true
	if not game.pause_toggled():
		game.toggle_pause()
	game.capture_mouse(false)
	_show_build()
	_show_radio()
	_show_breath()
	_set_live(true)
	_fade(true)
	_rows["resume"].grab_focus()
	_cue(1.0)


func close() -> void:
	if not _open:
		return
	_open = false
	_disarm()
	note("")
	_leave_settings(false)
	if _notes_pinned:
		_unpin_notes()
	if game.pause_toggled():
		game.toggle_pause()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_set_live(false)
	_fade(false)
	game.recapture_mouse()
	_cue(Harmony.ratio(7.0))


func press(id: String) -> void:
	if not _open:
		return
	if ARM_WORDS.has(id):
		if not _confirms(id):
			return
	else:
		_disarm()
	confirm(id)


func confirm(id: String) -> void:
	if not _open:
		return
	_disarm()
	match id:
		"resume":
			close()
		"restart":
			if _restart_shut():
				return
			close()
			game.flow.new_run()
		"notes":
			_notes_pinned = true
			game.hold_notes(true)
			game.notes.show_page(0)
		"settings":
			_enter_settings()
		"quit":
			quit_chosen.emit()
			if not game.test_mode:
				get_tree().quit()
		"radio":
			if game.get("radio_deck") != null:
				game.radio_deck.toggle_off()
			_show_radio()
			_rows["radio"].grab_focus()
		"breath":
			if _rows["breath"].visible:
				game.cycle_breath()
				_show_breath()
				_rows["breath"].grab_focus()
		_:
			_rows[id].grab_focus()


func _restart_shut() -> bool:
	return game.flow.store != null and game.flow.state == game.flow.LAP


func _confirms(id: String) -> bool:
	if _armed == id:
		return _armed_for >= ARM_GUARD
	if id == "restart" and _restart_shut():
		return false
	_disarm()
	_armed = id
	_armed_for = 0.0
	var row: ChoiceButton = _rows[id]
	row.text = ARM_WORDS[id]
	row.set_asking(true)
	row.grab_focus()
	_cue(Harmony.ratio(-5.0))
	return false


func _disarm() -> void:
	if _armed == "":
		return
	var row: ChoiceButton = _rows[_armed]
	row.text = _row_words(_armed)
	row.set_asking(false)
	_armed = ""
	_armed_for = 0.0


func _row_words(id: String) -> String:
	return String(ROWS[_order.find(id)]["words"])


func armed() -> String:
	return _armed


func step_arm(delta: float) -> void:
	if _armed == "":
		return
	_armed_for += delta
	if _armed_for >= ARM_SECONDS or not _rows[_armed].has_focus():
		_disarm()


func _enter_settings() -> void:
	_in_settings = true
	for id in _order:
		_rows[id].visible = false
	build_read.visible = false
	_page.refresh()
	_page.visible = true
	_page.focus_first()


func _leave_settings(focus_settings: bool) -> void:
	if not _in_settings:
		return
	_in_settings = false
	_page.visible = false
	for id in _order:
		_rows[id].visible = true
	build_read.visible = true
	_show_breath()
	if focus_settings:
		_rows["settings"].grab_focus()


func _show_build() -> void:
	var build = game.get("build")
	build_read.refresh(game.run, int(build.panel_overflow) if build != null else 0, game.run.class_id() if game.run != null else "",
		build.panel_effective if build != null else {})
	var presentation = game.get("presentation")
	build_read.wear(presentation.hero_assets if presentation != null else null, game.get("player"))
	_lay_build()


func _lay_build() -> void:
	lay_build(_root.size if _root.size != Vector2.ZERO else _root.get_viewport_rect().size)


func lay_build(screen: Vector2) -> void:
	build_read.layout(screen, (screen.x - column_width()) * 0.5)


func column_width() -> float:
	var width := WIDTH
	for id in _order:
		width = maxf(width, _rows[id].get_combined_minimum_size().x)
	return width


func read(id: String) -> Dictionary:
	var node = _rows.get(id)
	if node is SettingRow:
		return node.data()
	return {"label": String(node.text) if node != null else "", "value": "", "pip": SettingRow.NONE}


func _show_breath() -> void:
	var row: SettingRow = _rows["breath"]
	row.visible = game.dev and game.tuning.option(Tuning.MUSIC_KEY) == "ace"
	row.show_row("Breath", String(game.tuning.option(Tuning.BREATH_KEY)))


func _show_radio() -> void:
	var deck = game.get("radio_deck")
	var off: bool = deck != null and deck.radio.station == "off"
	_rows["radio"].show_row("Radio", "", SettingRow.OFF if off else SettingRow.ON)


func _input(event: InputEvent) -> void:
	if game == null:
		return
	if _open and game.notes_held():
		if _notes_pinned and _unpins(event):
			_unpin_notes()
			get_viewport().set_input_as_handled()
		return
	if _open and _in_settings:
		if not _page.capturing() and _toggles(event):
			_leave_settings(true)
			get_viewport().set_input_as_handled()
		elif _page.handle(event):
			get_viewport().set_input_as_handled()
		return
	if _toggles(event):
		if _open:
			close()
		elif can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if _open and _quit_key(event):
		get_viewport().set_input_as_handled()
		return
	if _open and _menu_key(event):
		get_viewport().set_input_as_handled()


func _quit_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.physical_keycode == QUIT_KEY):
		return false
	if event.echo:
		return true
	if event.pressed and _armed == "quit":
		press("quit")
		if _armed == "":
			return true
	_quit_down = event.pressed
	if not event.pressed:
		_quit_held = 0.0
	_quit_ring.queue_redraw()
	return true


func step_quit(delta: float) -> void:
	if not _open or not _quit_down:
		return
	_quit_held += delta
	_quit_ring.queue_redraw()
	if _quit_held >= QUIT_HOLD:
		_quit_down = false
		_quit_held = 0.0
		confirm("quit")


func quit_fill() -> float:
	return clampf(_quit_held / QUIT_HOLD, 0.0, 1.0)


func _draw_quit_ring() -> void:
	var fill := quit_fill()
	if fill <= 0.0:
		return
	var row: Control = _rows["quit"]
	var cap := Keycap.size_of("key_x", ChoiceButton.KEY_H)
	var centre := Vector2(ChoiceButton.PAD + cap.x * 0.5, row.size.y * 0.5)
	var radius := maxf(cap.x, cap.y) * 0.5 + 6.0
	_quit_ring.draw_arc(centre, radius, 0.0, TAU, 32, Color(Palette.CHARCOAL, 0.6), 4.0)
	_quit_ring.draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * fill, 32, Palette.AMBER, 3.0)


func _toggles(event: InputEvent) -> bool:
	if InputMap.has_action("cl_pause"):
		return event.is_action_pressed("cl_pause", false)
	if event is InputEventKey:
		return event.pressed and not event.echo and (event.physical_keycode == KEY_P or event.physical_keycode == KEY_ESCAPE)
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_START
	return false


func _unpins(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and not event.physical_keycode in NOTES_KEYS
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.pressed
	return false


func _menu_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		var repeatable := {KEY_W: -1, KEY_UP: -1, KEY_S: 1, KEY_DOWN: 1}
		var code: int = event.physical_keycode
		if repeatable.has(code):
			_move(repeatable[code])
			return true
		if event.echo:
			return false
		match code:
			KEY_TAB:
				press("notes")
				return true
			KEY_N:
				press("restart")
				return true
			KEY_O:
				press("settings")
				return true
			KEY_V:
				press("radio")
				return true
			KEY_B:
				press("breath")
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_accept()
				return true
		return false
	for pair in [["ui_up", -1], ["ui_down", 1]]:
		if event.is_action_pressed(pair[0], true):
			_move(pair[1])
			return true
	if event.is_action_pressed("ui_accept"):
		_accept()
		return true
	if event.is_action_pressed("ui_cancel"):
		close()
		return true
	return false


func _move(direction: int) -> void:
	var index := _order.find(focused_id())
	index = 0 if index < 0 else posmod(index + direction, _order.size())
	while not _rows[_order[index]].visible:
		index = posmod(index + direction, _order.size())
	_rows[_order[index]].grab_focus()


func _accept() -> void:
	var id := focused_id()
	if id != "":
		press(id)


func _unpin_notes() -> void:
	_notes_pinned = false
	game.hold_notes(false)


func _audio():
	return game.audio() if game != null else null


func _cue(pitch: float) -> void:
	var audio = _audio()
	if audio != null and audio.has_method("play"):
		audio.play("flow_changed", 0.0, pitch, "UI")


func _set_live(live: bool) -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	for id in _order:
		var node: Control = _rows[id]
		node.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_ALL if live else Control.FOCUS_NONE
		if node is BaseButton:
			(node as BaseButton).disabled = not live


func _fade(show: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if show:
		visible = true
		_root.modulate.a = 0.0
		_content.position.y = Screens.SLIDE
		_tween.tween_property(_root, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "position:y", 0.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		if not _open:
			visible = false)


func _process(delta: float) -> void:
	if not _open:
		_quit_down = false
		_quit_held = 0.0
		return
	step_quit(delta)
	step_arm(delta)
	if _notes_pinned and not game.notes_held():
		_notes_pinned = false
	_root.visible = not game.notes_held()
