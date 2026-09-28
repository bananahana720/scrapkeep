extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const VolumeRow := preload("res://src/ui/volume_row.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Screens := preload("res://src/ui/screens.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")

# The pause menu and its settings (DESIGN-V2 section 14.1). P, Esc or a pad's Start
# opens it in play and closes it again. Each row is a ChoiceButton with its key's cap,
# or a volume row, so the mouse, the keys and a pad reach every choice: W/S or the
# arrows move the focus, A/D or left/right step a focused volume, Enter or Space takes
# the focused row. The field notes row pins the notes open until the next key or click.
#
# It pauses through game.toggle_pause() and never opens while the workshop holds the
# player (the game's menu_held meta), so it cannot stack on the pick or the counter.
# Closing restores the tree pause the pick still holds. Volumes go to the mixer through
# audio.set_volume() and are kept per viewer in settings.json (settings_store.gd). The
# comfort rows (v3 W11) step the same way: Screen shake scales every camera shake, kick
# and punch, Hit-stop every freeze, through juice.set_comfort(), saved beside the volumes.
# With --music=ace the Breath row (B) flips the Warden open's held breath, raw, hard or
# gentle, and the open sounding now changes with it, so it can be judged mid-fight.

const LAYER := 6
const FADE_IN := 0.16
const FADE_OUT := 0.12
const WIDTH := 500.0
const ROWS := [
	{"id": "resume", "key": "key_p", "words": "Resume"},
	{"id": "restart", "key": "key_n", "words": "Restart run"},
	{"id": "notes", "key": "key_tab", "words": "Field notes"},
	{"id": "music", "bus": "Music", "glyph": "music", "words": "Music"},
	{"id": "effects", "bus": "SFX", "glyph": "effects", "words": "Effects"},
	{"id": "shake", "comfort": "shake", "glyph": "shake", "words": "Screen shake"},
	{"id": "hitstop", "comfort": "hitstop", "glyph": "hitstop", "words": "Hit-stop"},
	{"id": "ceremony", "key": "key_c", "words": "Ceremonies: full"},
	{"id": "breath", "key": "key_b", "words": "Breath: hard"},
	{"id": "quit", "key": "key_q", "words": "Quit"},
]
# The keys that turn the notes a page while they are pinned; any other key unpins them.
const NOTES_KEYS := [KEY_Q, KEY_E, KEY_TAB]

var game
var store

var _root: Control
var _content: VBoxContainer
var _rows := {}
var _order: Array = []
var _open := false
var _notes_pinned := false
var _tween: Tween


func _init() -> void:
	name = "PauseMenu"


# game.gd adds this layer as its child; it sets itself up from its parent.
func _ready() -> void:
	if game == null:
		setup(get_parent())


func setup(game_ref) -> void:
	game = game_ref
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	store = SettingsStore.new(game.storage_dir)
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
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiFonts.bold())
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Palette.AMBER)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(title)
	for spec in ROWS:
		var row: Control
		if spec.has("bus"):
			row = VolumeRow.new(spec["bus"], spec["words"], spec["glyph"], WIDTH)
			row.changed.connect(_on_volume.bind(spec["bus"]))
		elif spec.has("comfort"):
			row = VolumeRow.new(spec["comfort"], spec["words"], spec["glyph"], WIDTH)
			row.changed.connect(_on_comfort.bind(spec["comfort"]))
		else:
			row = ChoiceButton.new(spec["id"], spec["key"], spec["words"])
			row.custom_minimum_size.x = WIDTH
			row.pressed.connect(press.bind(spec["id"]))
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content.add_child(row)
		_rows[spec["id"]] = row
		_order.append(spec["id"])
	_set_live(false)
	game.events.flow_changed.connect(func(_state: String):
		if _open and not game.flow.in_play():
			close())


# The viewer's saved levels go to the mixer at launch; a level never set keeps its default.
func apply_saved() -> void:
	store.load_saved()
	for bus in store.volumes:
		_set_bus(bus, store.volumes[bus])
	for id in store.comfort:
		_set_comfort(id, store.comfort[id])


func is_open() -> bool:
	return _open


func notes_pinned() -> bool:
	return _notes_pinned


func row(id: String) -> Control:
	return _rows.get(id)


func focused_id() -> String:
	for id in _order:
		if _rows[id].has_focus():
			return id
	return ""


func can_open() -> bool:
	return game.flow.in_play() and not game.get_meta("menu_held", false) and not game.notes_held()


func open() -> void:
	if _open or not can_open():
		return
	_open = true
	if not game.pause_toggled():
		game.toggle_pause()
	game._capture_mouse(false)
	_sync_levels()
	_show_ceremony()
	_show_breath()
	_set_live(true)
	_fade(true)
	_rows["resume"].grab_focus()
	_cue(1.0)


func close() -> void:
	if not _open:
		return
	_open = false
	if _notes_pinned:
		_unpin_notes()
	if game.pause_toggled():
		game.toggle_pause()
	var workshop = game.get_node_or_null("Workshop")
	if workshop != null and workshop.pick.is_open():
		get_tree().paused = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_set_live(false)
	_fade(false)
	game._capture_mouse(game.flow.in_play() and not game.get_meta("menu_held", false))
	_cue(Harmony.ratio(7.0))


func press(id: String) -> void:
	if not _open:
		return
	match id:
		"resume":
			close()
		"restart":
			close()
			game.flow.new_run()
		"notes":
			_notes_pinned = true
			game.hold_notes(true)
			game.notes.show_page(0)
		"quit":
			get_tree().quit()
		"ceremony":
			_toggle_ceremony()
		"breath":
			if _rows["breath"].visible:
				game.cycle_breath()
				_show_breath()
				_rows["breath"].grab_focus()
		_:
			_rows[id].grab_focus()


# v3 W13: C or the row flips reward ceremonies between full and short (every find at the
# rare tier), saved in settings.json as the ceremony's comfort level (1 full, 0 short).
func _toggle_ceremony() -> void:
	var ceremony = game.presentation.get("ceremony") if game.presentation != null else null
	if ceremony != null:
		ceremony.short = not ceremony.short
		store.set_comfort(ceremony.SETTING, 0.0 if ceremony.short else 1.0)
	_show_ceremony()
	_rows["ceremony"].grab_focus()


func _show_breath() -> void:
	var row: Control = _rows["breath"]
	row.visible = game.tuning.option(LoopMode.MUSIC_KEY) == "ace"
	row.text = "Breath: %s" % game.tuning.option(LoopMode.BREATH_KEY)


func _show_ceremony() -> void:
	var ceremony = game.presentation.get("ceremony") if game.presentation != null else null
	_rows["ceremony"].text = "Ceremonies: short" if ceremony != null and ceremony.short else "Ceremonies: full"


func _input(event: InputEvent) -> void:
	if game == null:
		return
	if _open and game.notes_held():
		if _notes_pinned and _unpins(event):
			_unpin_notes()
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
	if _open and _menu_key(event):
		get_viewport().set_input_as_handled()


func _toggles(event: InputEvent) -> bool:
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
		var sideways := {KEY_A: -1, KEY_LEFT: -1, KEY_D: 1, KEY_RIGHT: 1}
		var code: int = event.physical_keycode
		if repeatable.has(code):
			_move(repeatable[code])
			return true
		if sideways.has(code):
			_nudge(sideways[code])
			return true
		if event.echo:
			return false
		match code:
			KEY_N:
				press("restart")
				return true
			KEY_Q:
				press("quit")
				return true
			KEY_C:
				press("ceremony")
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
	for pair in [["ui_left", -1], ["ui_right", 1]]:
		if event.is_action_pressed(pair[0], true):
			_nudge(pair[1])
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


func _nudge(direction: int) -> void:
	var focused := row(focused_id())
	if focused is VolumeRow:
		focused.step(direction)


func _accept() -> void:
	var id := focused_id()
	if id != "":
		press(id)


func _unpin_notes() -> void:
	_notes_pinned = false
	game.hold_notes(false)


func _audio():
	var presentation = game.presentation if game != null else null
	return presentation.get("audio") if presentation != null else null


func _set_bus(bus: String, level: float) -> void:
	var audio = _audio()
	if audio != null and audio.has_method("set_volume"):
		audio.set_volume(bus, level)


func _on_volume(level: float, bus: String) -> void:
	_set_bus(bus, level)
	store.set_volume(bus, level)
	_cue(Harmony.ratio(Harmony.pentatonic_step(int(level * 8.0))))


func _juice():
	var presentation = game.presentation if game != null else null
	return presentation.get("juice") if presentation != null else null


func _set_comfort(id: String, level: float) -> void:
	var juice = _juice()
	if juice != null and juice.has_method("set_comfort"):
		juice.set_comfort(id, level)


func _on_comfort(level: float, id: String) -> void:
	_set_comfort(id, level)
	store.set_comfort(id, level)
	_cue(Harmony.ratio(Harmony.pentatonic_step(int(level * 8.0))))


func _sync_levels() -> void:
	var audio = _audio()
	var juice = _juice()
	for id in _order:
		var spec: Dictionary = ROWS[_order.find(id)]
		if spec.has("comfort"):
			var feel: float = store.comfort.get(spec["comfort"], 1.0)
			if juice != null and juice.has_method("comfort"):
				feel = juice.comfort(spec["comfort"])
			_rows[id].show_level(feel)
			continue
		if not spec.has("bus"):
			continue
		var level: float = store.volumes.get(spec["bus"], 1.0)
		if audio != null and "volumes" in audio:
			level = audio.volumes.get(spec["bus"], level)
		_rows[id].show_level(level)


# A short UI note: open on the root, close a fifth up, a volume step on its rung.
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


func _process(_delta: float) -> void:
	if not _open:
		return
	if _notes_pinned and not game.notes_held():
		_notes_pinned = false
	_root.visible = not game.notes_held()
	_sync_levels()
