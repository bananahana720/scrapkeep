extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const Bindings := preload("res://src/core/bindings.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const BuildStamp := preload("res://src/core/build_stamp.gd")
const VolumeRow := preload("res://src/ui/volume_row.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SettingRow := preload("res://src/ui/setting_row.gd")
const Keycap := preload("res://src/ui/keycap.gd")


signal back_requested

const VERBS := ["jump", "fire", "harpoon", "haul", "boost", "select_1", "select_2", "select_3", "ultimate", "active", "interact"]
const SELECT_ROW := "select_"
const FIXED := ["roll", "look"]
const EXTRA_WORDS := {"cl_retry": "New run", "cl_pause": "Pause", "cl_consumable": "Cartridge",
	"cl_radio_next": "Next track",
	"cl_radio_prev": "Last track", "cl_radio_skip": "Skip track", "cl_radio_pin": "Keep track"}
const PAGES := ["display", "controls", "look", "feel"]
const PAGE_WORDS := {"display": "Display", "controls": "Controls", "look": "Look", "feel": "Feel"}
const FEEL := [
	{"id": "music", "bus": "Music", "words": "Music", "glyph": "music"},
	{"id": "effects", "bus": "SFX", "words": "Effects", "glyph": "effects"},
	{"id": "shake", "comfort": "shake", "words": "Screen shake", "glyph": "shake"},
	{"id": "hitstop", "comfort": "hitstop", "words": "Hit-stop", "glyph": "hitstop"},
]
const CARDS_ROW := "ceremony"
const TOGGLE_WORDS := {"fullscreen": "Fullscreen", "quality": "Quality", "reduced_motion": "Less motion",
	"reduce_flashes": "Fewer flashes", "frame_smoothing": "Frame smoothing", "wide_picture": "Wide picture"}
const TRIGGER_VERBS := ["fire", "harpoon"]
const TRIGGER_PULL := 0.6
const LOOK := [
	{"id": SettingsStore.STICK_SENSITIVITY, "words": "Stick speed", "steps": [1.3, 1.95, 2.6, 3.25, 3.9], "per": 2.6},
	{"id": SettingsStore.INVERT_Y, "words": "Invert Y", "steps": [0.0, 1.0], "per": 0.0},
	{"id": SettingsStore.STICK_DEADZONE, "words": "Dead zone", "steps": [0.1, 0.15, 0.2, 0.25, 0.3], "per": 1.0},
	{"id": SettingsStore.MOUSE_SENSITIVITY, "words": "Mouse speed", "steps": [0.0011, 0.00165, 0.0022, 0.00275, 0.0033], "per": 0.0022},
	{"id": SettingsStore.AIM_ASSIST, "words": "Aim assist", "steps": [0.0, 0.25, 0.5, 0.75, 1.0], "per": 1.0},
]
const WIDTH := 500.0
const PAGE_H := 640.0
const CAP_W := 150.0
const MOUSE_OK := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

static var last_page := 0

var back: Button
var stamp: Label
var rows := {}

var _helper: Label
var _notice: Label
var _scrolls := {}

var _game
var _back_key := "key_esc"
var _order: Array = []
var _page_ids := {}
var _boxes := {}
var _tabs := {}
var _page_index := 0
var _capturing := ""
var _taken := ""


func _init() -> void:
	name = "SettingsPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(game_ref, back_key := "key_esc") -> void:
	_game = game_ref
	_back_key = back_key
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 4)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	for i in PAGES.size():
		var tab := _tab_button(PAGES[i])
		tab.pressed.connect(_tab_pressed.bind(i))
		strip.add_child(tab)
		_tabs[PAGES[i]] = tab
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_BEGIN
		box.add_theme_constant_override("separation", UiTokens.GAP_S)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size.x = WIDTH
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.follow_focus = true
		scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		scroll.custom_minimum_size.x = WIDTH + UiTokens.GAP_L
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		var inset := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, UiTokens.GAP_S)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(box)
		scroll.add_child(inset)
		add_child(scroll)
		_scrolls[PAGES[i]] = scroll
		_boxes[PAGES[i]] = box
		_page_ids[PAGES[i]] = []
	_build_display()
	_build_controls()
	_build_look()
	_build_feel()
	_notice = Label.new()
	_notice.add_theme_font_override("font", UiFonts.bold())
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(WIDTH, 0.0)
	_notice.add_theme_font_size_override("font_size", UiTokens.BODY)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_notice.accessibility_live = AccessibilityServer.LIVE_ASSERTIVE
	_boxes["controls"].add_child(_notice)
	back = ChoiceButton.new("back", _back_key, "Back")
	back.custom_minimum_size = Vector2(WIDTH, UiTokens.TARGET)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows["back"] = back
	add_child(back)
	back.pressed.connect(press.bind("back"))
	stamp = Label.new()
	stamp.text = BuildStamp.label()
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	stamp.add_theme_color_override("font_color", UiTokens.quiet())
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp)
	refresh()


func _build_display() -> void:
	for id in ["fullscreen", "quality", "reduced_motion", "reduce_flashes", "frame_smoothing", "wide_picture"]:
		_add_plain(id, "display")
		if SettingsStore.HELPERS.has(id):
			rows[id].focus_entered.connect(_show_helper.bind(String(SettingsStore.HELPERS[id])))
			rows[id].focus_exited.connect(_show_helper.bind(""))
	_helper = Label.new()
	_helper.add_theme_font_override("font", UiFonts.bold())
	_helper.custom_minimum_size = Vector2(WIDTH, 0.0)
	_helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_helper.add_theme_font_size_override("font_size", UiTokens.BODY)
	_helper.add_theme_color_override("font_color", UiTokens.TEXT)
	_helper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_helper.visible = false
	_boxes["display"].add_child(_helper)


func _show_helper(words: String) -> void:
	_helper.text = words
	_helper.visible = words != ""
	if words != "":
		_place_under(_helper, focused_id())


func helper_text() -> String:
	return _helper.text


func notice_text() -> String:
	return _notice.text if _notice.visible else ""


func _build_controls() -> void:
	for verb in VERBS:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 0)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boxes["controls"].add_child(group)
		var name_label := Label.new()
		name_label.text = _caption(verb)
		name_label.custom_minimum_size = Vector2(WIDTH, SettingRow.LABEL_H)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		name_label.add_theme_font_override("font", UiFonts.bold())
		name_label.add_theme_font_size_override("font_size", UiTokens.BODY)
		name_label.add_theme_color_override("font_color", UiTokens.TEXT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(name_label)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", UiTokens.GAP_S)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(pair)
		for id in [verb, "pad_" + verb]:
			var button := _bind_button(id)
			button.custom_minimum_size = Vector2(CAP_W, UiTokens.TARGET)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows[id] = button
			_page_ids["controls"].append(id)
			pair.add_child(button)
	_add_plain("reset", "controls")
	for verb in FIXED:
		_add_fixed(verb)


func _build_look() -> void:
	for spec in LOOK:
		_add_plain(String(spec["id"]), "look")


func _build_feel() -> void:
	for spec in FEEL:
		var row := VolumeRow.new(spec["bus"] if spec.has("bus") else spec["comfort"], spec["words"], spec["glyph"], WIDTH)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.stack(SettingRow.LABEL_H)
		row.changed.connect(_on_feel.bind(spec))
		rows[spec["id"]] = row
		_page_ids["feel"].append(spec["id"])
		_boxes["feel"].add_child(row)
	_add_plain(CARDS_ROW, "feel")


static func apply_saved(game) -> void:
	var store = game.settings_store()
	store.load_saved()
	for bus in store.volumes:
		_set_bus(game, bus, store.volumes[bus])
	for id in store.comfort:
		_set_comfort(game, id, store.comfort[id])


static func _set_bus(game, bus: String, level: float) -> void:
	var audio = game.audio()
	if audio != null and audio.has_method("set_volume"):
		audio.set_volume(bus, level)


static func _juice(game):
	var presentation = game.presentation
	return presentation.get("juice") if presentation != null else null


static func _set_comfort(game, id: String, level: float) -> void:
	var juice = _juice(game)
	if juice != null and juice.has_method("set_comfort"):
		juice.set_comfort(id, level)


func _on_feel(level: float, spec: Dictionary) -> void:
	if spec.has("bus"):
		_set_bus(_game, spec["bus"], level)
		_store().set_volume(spec["bus"], level)
	else:
		_set_comfort(_game, spec["comfort"], level)
		_store().set_comfort(spec["comfort"], level)
	var audio = _game.audio()
	if audio != null and audio.has_method("play"):
		audio.play("flow_changed", 0.0, Harmony.ratio(Harmony.pentatonic_step(int(level * 8.0))), "UI")


func _show_feel() -> void:
	var audio = _game.audio()
	var juice = _juice(_game)
	for spec in FEEL:
		var level: float = 1.0
		if spec.has("bus"):
			level = _store().volumes.get(spec["bus"], 1.0)
			if audio != null and "volumes" in audio:
				level = audio.volumes.get(spec["bus"], level)
		else:
			level = _store().comfort.get(spec["comfort"], 1.0)
			if juice != null and juice.has_method("comfort"):
				level = juice.comfort(spec["comfort"])
		rows[spec["id"]].show_level(level)
	var ceremony = _game.presentation.get("ceremony") if _game.presentation != null else null
	rows[CARDS_ROW].show_row("Find cards", "short" if ceremony != null and ceremony.short else "full")


func _toggle_cards() -> void:
	var ceremony = _game.presentation.get("ceremony") if _game.presentation != null else null
	if ceremony != null:
		ceremony.short = not ceremony.short
		_store().set_comfort(ceremony.SETTING, 0.0 if ceremony.short else 1.0)
	_show_feel()


func _tab_button(page: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = PAGE_WORDS[page]
	button.add_theme_font_override("font", UiFonts.bold())
	button.add_theme_font_size_override("font_size", UiTokens.BODY)
	button.add_theme_stylebox_override("normal", ChoiceButton.plate(UiTokens.LINE, 2, ChoiceButton.PAD))
	button.add_theme_stylebox_override("hover", ChoiceButton.plate(Palette.SAND, 2, ChoiceButton.PAD))
	button.add_theme_stylebox_override("pressed", ChoiceButton.plate(Palette.AMBER, 3, ChoiceButton.PAD))
	button.custom_minimum_size = Vector2(WIDTH / PAGES.size() - 3.0, UiTokens.TARGET)
	return button


func _store():
	return _game.settings_store()


func row(id: String) -> Control:
	return rows.get(id)


func capturing() -> bool:
	return _capturing != ""


func current_page() -> String:
	return PAGES[_page_index]


func page_ids() -> Array:
	return _order.duplicate()


func show_page(index: int) -> void:
	_clear_notice()
	_capture_end()
	_helper.text = ""
	_helper.visible = false
	_page_index = posmod(index, PAGES.size())
	last_page = _page_index
	for i in PAGES.size():
		var id: String = PAGES[i]
		_boxes[id].visible = i == _page_index
		_scrolls[id].visible = i == _page_index
		var tab: Button = _tabs[id]
		var tint := Palette.AMBER if i == _page_index else Palette.SAND
		tab.add_theme_color_override("font_color", tint)
		tab.add_theme_color_override("font_hover_color", UiTokens.TEXT)
	_order = _page_ids[PAGES[_page_index]].duplicate()
	_order.append("back")
	_hold_height()


func _hold_height() -> void:
	var tallest := 0.0
	for id in PAGES:
		var box: VBoxContainer = _boxes[id]
		var shown := box.visible
		box.visible = true
		tallest = maxf(tallest, box.get_combined_minimum_size().y + UiTokens.GAP_S * 2)
		box.visible = shown
	for id in PAGES:
		_scrolls[id].custom_minimum_size.y = minf(tallest, PAGE_H)


func focused_id() -> String:
	for id in _order:
		if rows[id].has_focus():
			return id
	return ""


func focus(id: String) -> void:
	if not is_visible_in_tree():
		return
	if not id in _order:
		id = _order[0]
	rows[id].grab_focus()


func focus_first() -> void:
	focus(_order[0])


func _tab_pressed(index: int) -> void:
	show_page(index)
	focus_first()


static func action_of(row: String) -> String:
	var bare := row_of(row)
	var n := _select_number(bare)
	if n > 0:
		return String(Bindings.SELECT_ACTIONS[n - 1])
	return String(Bindings.VERBS[bare]["actions"].keys()[0])


static func row_of(id: String) -> String:
	return id.trim_prefix("pad_")


static func verb_of(id: String) -> String:
	var bare := row_of(id)
	return "select" if _select_number(bare) > 0 else bare


static func _select_number(row: String) -> int:
	if not row.begins_with(SELECT_ROW):
		return 0
	var n := row.substr(SELECT_ROW.length()).to_int()
	return n if n >= 1 and n <= Bindings.SELECT_ACTIONS.size() else 0


static func pad_cap(button: int) -> String:
	return String(Glyphs.PAD_BUTTONS.get(button, ""))


func glyph_of(verb: String) -> String:
	for event in InputMap.action_get_events(action_of(verb)):
		if event is InputEventKey:
			return "key_" + OS.get_keycode_string(event.physical_keycode).to_lower().replace(" ", "")
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return "key_lmb"
				MOUSE_BUTTON_RIGHT:
					return "key_rmb"
			return "key_m%d" % event.button_index
	var n := _select_number(row_of(verb))
	return "key_%d" % n if n > 0 else Bindings.glyph(verb_of(verb))


func pad_glyph_of(verb: String) -> String:
	var saved := []
	for event in _store().binding_events(action_of(verb)):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			saved.append(event)
	if not saved.is_empty():
		var last: InputEvent = saved[-1]
		if last is InputEventJoypadButton:
			return pad_cap(last.button_index) if pad_cap(last.button_index) != "" else "pad_a"
		return String(Glyphs.PAD_TRIGGERS.get(last.axis, "pad_rt"))
	var record: Dictionary = Bindings.VERBS[verb_of(verb)]["actions"][action_of(verb)]
	if record.has("pad"):
		return String(Glyphs.PAD_BUTTONS.get(record["pad"], "pad_a"))
	if record.has("axis"):
		return String(Glyphs.PAD_TRIGGERS.get(record["axis"][0], "pad_rt"))
	return "pad_a"


func refresh() -> void:
	_capturing = ""
	_taken = ""
	stamp.text = BuildStamp.label() + (" · sitting" if _game.tuning != null and _game.tuning.sitting() else "")
	var store = _store()
	_show_toggle("fullscreen", store.fullscreen())
	_show_quality(store.quality() == 1)
	_show_toggle("reduced_motion", store.reduced_motion())
	_show_toggle("reduce_flashes", store.reduce_flashes())
	_show_toggle("frame_smoothing", store.frame_smoothing())
	_show_toggle("wide_picture", store.wide_picture())
	for verb in VERBS:
		_rebuild(verb)
		_rebuild("pad_" + verb)
	for spec in LOOK:
		_show_look(spec)
	_show_feel()
	show_page(last_page)


func _add_plain(id: String, page: String) -> void:
	var button := SettingRow.new(id, "", "Reset keys" if id == "reset" else id.capitalize())
	button.custom_minimum_size = Vector2(WIDTH, UiTokens.TARGET)
	if id != "reset":
		button.stack()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(press.bind(id))
	rows[id] = button
	_page_ids[page].append(id)
	_boxes[page].add_child(button)


func _bind_button(id: String) -> Button:
	var row := row_of(id)
	var glyph := pad_glyph_of(row) if id.begins_with("pad_") else glyph_of(row)
	var button := ChoiceButton.new(id, glyph, "")
	button.accessibility_name = "%s, %s %s" % [_caption(id), "pad" if id.begins_with("pad_") else "key", Keycap.label(glyph)]
	button.pressed.connect(press.bind(id))
	return button


func _add_fixed(verb: String) -> void:
	var button := SettingRow.new(verb, "", "")
	button.show_row(verb.capitalize(), Bindings.label(verb))
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows[verb] = button
	button.custom_minimum_size = Vector2(WIDTH, UiTokens.TARGET)
	button.stack()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boxes["controls"].add_child(button)


func _rebuild(id: String) -> void:
	var old: Button = rows[id]
	var had_focus := old.has_focus()
	var parent := old.get_parent()
	var fresh := _bind_button(id)
	fresh.custom_minimum_size = Vector2(CAP_W, UiTokens.TARGET)
	fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(fresh)
	parent.move_child(fresh, old.get_index())
	parent.remove_child(old)
	old.queue_free()
	rows[id] = fresh
	if had_focus:
		focus(id)


func _look_spec(id: String) -> Dictionary:
	for spec in LOOK:
		if spec["id"] == id:
			return spec
	return {}


func _show_toggle(id: String, on: bool) -> void:
	rows[id].show_row(TOGGLE_WORDS[id], "", SettingRow.ON if on else SettingRow.OFF)


func _show_quality(low: bool) -> void:
	rows["quality"].show_row(TOGGLE_WORDS["quality"], "low" if low else "high")


func read(id: String) -> Dictionary:
	var node = rows.get(id)
	if node is SettingRow:
		return node.data()
	if node is VolumeRow:
		return {"label": node.words, "value": "%d" % node.steps_filled(), "pip": SettingRow.NONE}
	return {"label": "", "value": "", "pip": SettingRow.NONE}


func _show_look(spec: Dictionary) -> void:
	var value := float(_store().look.get(spec["id"], SettingsStore.LOOK_DEFAULTS[spec["id"]]))
	if float(spec["per"]) <= 0.0:
		rows[spec["id"]].show_row(spec["words"], "", SettingRow.ON if value >= 0.5 else SettingRow.OFF)
	else:
		rows[spec["id"]].show_row(spec["words"], "%d%%" % roundi(value / float(spec["per"]) * 100.0))


func _step_look(id: String, direction: int, wrap: bool) -> void:
	var spec := _look_spec(id)
	var steps: Array = spec["steps"]
	var value := float(_store().look.get(id, SettingsStore.LOOK_DEFAULTS[id]))
	var at := 0
	for i in steps.size():
		if absf(float(steps[i]) - value) < absf(float(steps[at]) - value):
			at = i
	at = posmod(at + direction, steps.size()) if wrap else clampi(at + direction, 0, steps.size() - 1)
	_store().set_look(id, float(steps[at]))
	_game.apply_look()
	_show_look(spec)


func press(id: String) -> void:
	_clear_notice()
	if _capturing != "":
		return
	match id:
		"fullscreen":
			var on: bool = not _store().fullscreen()
			_store().set_comfort(SettingsStore.FULLSCREEN, 1.0 if on else 0.0)
			_game.set_fullscreen(on)
			_show_toggle("fullscreen", on)
		"quality":
			var level: int = 1 - _store().quality()
			_store().set_comfort(SettingsStore.QUALITY, float(level))
			_game.set_quality(level)
			_show_quality(level == 1)
		"reduced_motion":
			var calm: bool = not _store().reduced_motion()
			_store().set_comfort(SettingsStore.REDUCED_MOTION, 1.0 if calm else 0.0)
			_game.set_reduced_motion(calm)
			_show_toggle("reduced_motion", calm)
		"reduce_flashes":
			var dim: bool = not _store().reduce_flashes()
			_store().set_comfort(SettingsStore.REDUCE_FLASHES, 1.0 if dim else 0.0)
			_game.set_reduce_flashes(dim)
			_show_toggle("reduce_flashes", dim)
		"frame_smoothing":
			var smooth: bool = not _store().frame_smoothing()
			_store().set_comfort(SettingsStore.FRAME_SMOOTHING, 1.0 if smooth else 0.0)
			_game.set_frame_smoothing(smooth)
			_show_toggle("frame_smoothing", smooth)
		"wide_picture":
			var wide: bool = not _store().wide_picture()
			_store().set_comfort(SettingsStore.WIDE_PICTURE, 1.0 if wide else 0.0)
			_game.set_wide_picture(wide)
			_show_toggle("wide_picture", wide)
		"reset":
			_game.reset_bindings()
			refresh()
		CARDS_ROW:
			_toggle_cards()
		"back":
			back_requested.emit()
			return
		_:
			if not _look_spec(id).is_empty():
				_step_look(id, 1, true)
			elif row_of(id) in VERBS:
				_capturing = id
				rows[id].set_waiting(true)
				_say(id, _ask_words(id), false)
	focus(id)


func _caption(id: String) -> String:
	var n := _select_number(row_of(id))
	return "Pick %d" % n if n > 0 else verb_of(id).capitalize()


func _clear_notice() -> void:
	if _taken != "":
		var id := _taken
		_taken = ""
		rows[id].text = ""
		rows[id].set_alert(false)
	_notice.visible = false


func _capture_end() -> void:
	if _capturing != "":
		rows[_capturing].text = ""
		rows[_capturing].set_waiting(false)
		_capturing = ""
		_notice.visible = false


func _ask_words(id: String) -> String:
	if id.begins_with("pad_"):
		return "Press a pad button for %s." % _caption(id)
	return "Press a key or mouse button for %s." % _caption(id)


func _say(id: String, words: String, refused: bool) -> void:
	_notice.text = words
	_notice.add_theme_color_override("font_color", UiTokens.ALERT if refused else UiTokens.TEXT)
	_notice.visible = true
	_place_under(_notice, id)


func _place_under(line: Label, id: String) -> void:
	var node: Node = rows.get(id)
	if node == null:
		return
	var box: Node = null
	for page in PAGES:
		if _boxes[page].is_ancestor_of(node):
			box = _boxes[page]
	if box == null:
		return
	while node.get_parent() != box:
		node = node.get_parent()
	if line.get_parent() != null:
		line.get_parent().remove_child(line)
	box.add_child(line)
	box.move_child(line, node.get_index() + 1)
	_scroll_to.call_deferred(line, box)


func _scroll_to(line: Control, box: Node) -> void:
	if line.is_inside_tree() and line.visible:
		for page in PAGES:
			if _boxes[page] == box:
				_scrolls[page].ensure_control_visible(line)


func _holder_words(row: String, event: InputEvent) -> String:
	var own := action_of(row)
	for action in Bindings.actions():
		if action == own:
			continue
		for held in InputMap.action_get_events(action):
			if (event is InputEventKey and held is InputEventKey and held.physical_keycode == event.physical_keycode) \
					or (event is InputEventMouseButton and held is InputEventMouseButton and held.button_index == event.button_index) \
					or (event is InputEventJoypadButton and held is InputEventJoypadButton and held.button_index == event.button_index):
				return _action_words(action)
	return ""


func _action_words(action: String) -> String:
	for verb in VERBS:
		if action_of(verb) == action:
			return _caption(verb)
	var verb := Bindings.verb_of_action(action)
	if verb != "":
		return verb.capitalize()
	return EXTRA_WORDS.get(action, String(action).trim_prefix("cl_").capitalize())


func handle(event: InputEvent) -> bool:
	if _capturing != "":
		return _capture(event)
	if event is InputEventKey:
		if not event.pressed:
			return false
		var code: int = event.physical_keycode
		if code == KEY_W or code == KEY_UP:
			_move(-1)
		elif code == KEY_S or code == KEY_DOWN:
			_move(1)
		elif event.echo:
			pass
		elif code == KEY_Q:
			_tab_pressed(_page_index - 1)
		elif code == KEY_E:
			_tab_pressed(_page_index + 1)
		elif code == KEY_A or code == KEY_LEFT:
			_nudge(-1)
		elif code == KEY_D or code == KEY_RIGHT:
			_nudge(1)
		elif code == KEY_ESCAPE:
			_clear_notice()
			back_requested.emit()
		elif code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
			_accept()
		return true
	if event is InputEventJoypadMotion:
		for pair in [["ui_up", -1], ["ui_down", 1]]:
			if event.is_action_pressed(pair[0], true):
				_move(pair[1])
				return true
		for pair in [["ui_left", -1], ["ui_right", 1]]:
			if event.is_action_pressed(pair[0], true):
				_nudge(pair[1])
				return true
		return false
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_tab_pressed(_page_index - 1)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_tab_pressed(_page_index + 1)
		elif event.is_action_pressed("ui_up", true):
			_move(-1)
		elif event.is_action_pressed("ui_down", true):
			_move(1)
		elif event.is_action_pressed("ui_left"):
			_nudge(-1)
		elif event.is_action_pressed("ui_right"):
			_nudge(1)
		elif event.is_action_pressed("ui_accept"):
			_accept()
		elif event.is_action_pressed("ui_cancel"):
			_clear_notice()
			back_requested.emit()
		return true
	return false


func _capture(event: InputEvent) -> bool:
	var id := _capturing
	var pad_row := id.begins_with("pad_")
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_cancel()
			elif not pad_row:
				var key := InputEventKey.new()
				key.physical_keycode = event.physical_keycode
				_commit(id, key)
		return true
	if event is InputEventMouseButton:
		if event.pressed and not pad_row and event.button_index in MOUSE_OK:
			var click := InputEventMouseButton.new()
			click.button_index = event.button_index
			_commit(id, click)
			return true
		return event.pressed
	if event is InputEventJoypadButton:
		if event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_cancel()
			elif pad_row and pad_cap(event.button_index) != "":
				var pad := InputEventJoypadButton.new()
				pad.button_index = event.button_index
				_commit(id, pad)
		return true
	if event is InputEventJoypadMotion:
		if pad_row and verb_of(id) in TRIGGER_VERBS and event.axis in Bindings.TRIGGER_AXES and event.axis_value >= TRIGGER_PULL:
			var trigger := InputEventJoypadMotion.new()
			trigger.axis = event.axis
			trigger.axis_value = 1.0
			_commit(id, trigger)
			return true
	return false


func _cancel() -> void:
	_capture_end()


func _held_elsewhere(row: String, event: InputEvent) -> bool:
	return _holder_words(row, event) != ""


func _commit(id: String, event: InputEvent) -> void:
	_capturing = ""
	var verb := verb_of(id)
	if _held_elsewhere(row_of(id), event):
		_taken = id
		rows[id].refuse()
		var holder := _holder_words(row_of(id), event)
		var kind := "key" if event is InputEventKey else "button"
		var line := "%s uses that %s. Press the cap again for another" % [holder, kind]
		if VERBS.any(func(other): return _caption(other) == holder):
			line += ", or move %s first" % holder
		_say(id, line + ".", true)
		return
	var action := action_of(row_of(id))
	if event is InputEventJoypadMotion:
		_hand_over_trigger(verb, event.axis)
	_store().merge_binding(action, [event])
	_game.apply_binding(action, _store().binding_events(action))
	_notice.visible = false
	_rebuild(id)


func _trigger_axis(action: String) -> int:
	for held in InputMap.action_get_events(action):
		if held is InputEventJoypadMotion and held.axis in Bindings.TRIGGER_AXES:
			return held.axis
	return -1


func _hand_over_trigger(verb: String, axis: int) -> void:
	var leaving := _trigger_axis(action_of(verb))
	for other in TRIGGER_VERBS:
		var other_action := action_of(other)
		if other == verb or leaving == -1 or _trigger_axis(other_action) != axis:
			continue
		var moved := InputEventJoypadMotion.new()
		moved.axis = leaving
		moved.axis_value = 1.0
		_store().merge_binding(other_action, [moved])
		_game.apply_binding(other_action, [moved])
		_rebuild("pad_" + other)


func _move(direction: int) -> void:
	var index := _order.find(focused_id())
	index = 0 if index < 0 else posmod(index + direction, _order.size())
	rows[_order[index]].grab_focus()


func _nudge(direction: int) -> void:
	var id := focused_id()
	if not _look_spec(id).is_empty():
		_step_look(id, direction, false)
	elif rows.get(id) is VolumeRow:
		rows[id].step(direction)


func _accept() -> void:
	var id := focused_id()
	if id != "":
		press(id)
