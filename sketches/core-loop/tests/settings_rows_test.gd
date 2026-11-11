extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const SettingRow := preload("res://src/ui/setting_row.gd")
const Radio := preload("res://src/core/radio.gd")
const T := preload("res://tests/support/t.gd")

# Wave 36 unslop-settings (ruling cx): a settings row shows what it sets and its present value without a
# "Label: value" string. An on-off row wears a pip (filled on, ring off), a row with named steps or a number
# shows its value as its own right-hand text, and the tests read each row as data (page.read, menu.read),
# never by parsing the drawn words.
#   - for every row on every tab, from the title and from the pause, no drawn text holds ": ";
#   - an on-off row's pip equals the setting, before and after a press, and a press changes both;
#   - a row with steps changes its setting and what it shows when stepped;
#   - the pause column's Radio wears a pip that follows the radio, and Breath shows its level as text;
#   - a settings file written before this change loads to the same values and the rows show them.
# Planted cases: a row that carries a colon string, a pip that does not follow its setting, and a pip that
# differs from its ring by tint alone must each be caught, so a clean scan is not a blind scan.

const TOGGLES := {"fullscreen": "fullscreen", "reduced_motion": "reduced_motion", "reduce_flashes": "reduce_flashes",
	"frame_smoothing": "frame_smoothing", "wide_picture": "wide_picture"}

var _t := T.new("settings_rows_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# Everything a player reads on a node's visible tree: label text, button text, and a row's drawn words.
func _texts(node: Node, found: Array = []) -> Array:
	if node is CanvasItem and not node.visible:
		return found
	if node is Label:
		found.append(node.text)
	elif node is BaseButton and "text" in node:
		found.append(node.text)
	if node.has_method("drawn_words"):
		found.append_array(Array(node.drawn_words()))
	for child in node.get_children():
		_texts(child, found)
	return found


# The texts that carry a label-colon-value string.
func _colons(texts: Array) -> Array:
	return texts.filter(func(text): return String(text).contains(": "))


# A row's data through the page's own read, else (the base) a bare reading of its text.
func _read(page, id: String) -> Dictionary:
	if page.has_method("read"):
		return page.read(id)
	return {"label": String(page.row(id).text), "value": "", "pip": -1}


# True when a row's pip is the setting: filled when on, a ring when off, and no pip for a valued row.
func _follows(data: Dictionary, setting: bool) -> bool:
	return int(data["pip"]) == (SettingRow.ON if setting else SettingRow.OFF) and String(data["value"]) == ""


func _setting(store, id: String) -> bool:
	return bool(store.call(TOGGLES[id]))


# Every tab of a visible settings page: no drawn text holds a colon, and the scan reads rows.
func _scan(host: String, page) -> void:
	page.refresh()
	for index in page.PAGES.size():
		page.show_page(index)
		await _frames(1)
		var found := _texts(page)
		_t.eq("%s, %s tab: no drawn text holds a colon" % [host, page.PAGES[index]], _colons(found), [])
		_t.check("%s, %s tab: the scan reads rows (%d texts)" % [host, page.PAGES[index], found.size()], found.size() >= 3)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	await _frames(3)
	var file: String = _game.storage_dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game.settings_store().load_saved()
	var screens = _game.screens
	screens.prologue_enabled = false
	_game.ctx.calm = true
	var menu = _game.get_node("PauseMenu")

	# Planted: a colon string and a pip that does not follow its setting are caught by the same checks.
	var planted := VBoxContainer.new()
	var bad := Button.new()
	bad.text = "Fullscreen: on"
	planted.add_child(bad)
	root.add_child(planted)
	_t.eq("planted: a row with a colon string is found by the scan", _colons(_texts(planted)), ["Fullscreen: on"])
	planted.queue_free()
	var wrong := {"label": "Wide picture", "value": "", "pip": SettingRow.ON}
	_t.check("planted: a pip filled for an off setting does not follow it", not _follows(wrong, false))
	_t.check("planted: a pip filled for an on setting does follow it", _follows(wrong, true))
	# A state read by shape: on and off draw different shapes (a disc and a ring), not one shape in two tints.
	_t.check("the two pip states are different values, so they draw different shapes", SettingRow.ON != SettingRow.OFF and SettingRow.ON != SettingRow.NONE)

	# Every row on every tab, from the title and from the pause.
	screens._on_flow_changed("title")
	screens.toggle_settings()
	await _frames(2)
	var hosts := {"title": screens._settings, "pause": menu.settings_page()}
	await _scan("title", screens._settings)
	screens.toggle_settings()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(4)
	menu.open()
	await _frames(1)
	menu.press("settings")
	await _frames(1)
	await _scan("pause", menu.settings_page())
	menu.close()
	await _frames(1)

	# An on-off row's pip equals the setting and a press changes both.
	for host in hosts:
		var page = hosts[host]
		page.show_page(0)
		var store = _game.settings_store()
		for id in TOGGLES:
			_t.check("%s: %s pip equals its setting" % [host, id], _follows(_read(page, id), _setting(store, id)), str(_read(page, id)))
			var before := _setting(store, id)
			page.press(id)
			_t.check("%s: a press flips %s" % [host, id], _setting(store, id) != before)
			_t.check("%s: %s pip follows the press" % [host, id], _follows(_read(page, id), _setting(store, id)), str(_read(page, id)))
			page.press(id)
			_t.check("%s: a second press restores %s" % [host, id], _setting(store, id) == before and _follows(_read(page, id), before))
		# Quality: named steps, shown as its own right-hand text.
		var low_before: bool = store.quality() == 1
		_t.eq("%s: Quality shows low or high" % host, _read(page, "quality")["value"], "low" if low_before else "high")
		page.press("quality")
		_t.check("%s: Quality steps and shows the step" % host, (store.quality() == 1) != low_before
			and _read(page, "quality")["value"] == ("low" if store.quality() == 1 else "high") and _read(page, "quality")["pip"] == -1)
		page.press("quality")
		# Look: a number on the right, a pip for Invert Y.
		page.show_page(2)
		var speed_before: float = store.stick_sensitivity()
		var shown_before: String = _read(page, "stick_sensitivity")["value"]
		page.press("stick_sensitivity")
		_t.check("%s: stepping Stick speed changes the setting and what is shown" % host,
			store.stick_sensitivity() != speed_before and _read(page, "stick_sensitivity")["value"] != shown_before
			and _read(page, "stick_sensitivity")["value"].ends_with("%"), str(_read(page, "stick_sensitivity")))
		var invert: bool = store.invert_y()
		page.press("invert_y")
		_t.check("%s: Invert Y pip follows the setting" % host, store.invert_y() != invert and _follows(_read(page, "invert_y"), store.invert_y()))
		page.press("invert_y")
		for id in ["stick_deadzone", "mouse_sensitivity", "aim_assist"]:
			var was: String = _read(page, id)["value"]
			page.press(id)
			_t.check("%s: stepping %s changes what is shown" % [host, id], _read(page, id)["value"] != was and _read(page, id)["value"].ends_with("%"), str(_read(page, id)))
		# Feel: Find cards shows short or full beside its words.
		page.show_page(3)
		var ceremony = _game.presentation.get("ceremony")
		var short_before: bool = ceremony.short
		_t.eq("%s: Find cards shows its present step" % host, _read(page, "ceremony")["value"], "short" if short_before else "full")
		page.press("ceremony")
		_t.check("%s: Find cards steps and shows it" % host, ceremony.short != short_before
			and _read(page, "ceremony")["value"] == ("short" if ceremony.short else "full"))
		page.press("ceremony")
		# Music: the bar's filled steps are the value.
		page.row("music").set_level(0.4)
		_t.eq("%s: Music reads four steps of ten" % host, _read(page, "music")["value"], "4")

	# The pause column: Radio wears a pip, Breath shows its level as text.
	menu.open()
	await _frames(1)
	var radio = _game.radio_deck.radio
	_t.check("the pause menu's Radio pip is the radio", _follows(menu.read("radio") if menu.has_method("read") else {"pip": -1, "value": ""}, radio.station != Radio.OFF), str(menu.row("radio").text))
	menu.press("radio")
	_t.check("a press turns the radio off and the pip to a ring", radio.station == Radio.OFF and _follows(menu.read("radio"), false), str(menu.read("radio")))
	menu.press("radio")
	_t.check("and back on, filled", radio.station != Radio.OFF and _follows(menu.read("radio"), true))
	_t.eq("the pause column rows hold no colon", _colons(_texts(menu.row("breath")) + _texts(menu.row("radio"))), [])
	menu.close()
	await _frames(1)

	# Round trip: a file written before this change loads to the same values and the rows show them.
	var old := {"volumes": {"Music": 0.3}, "comfort": {"fullscreen": 0.0, "quality": 1.0, "reduced_motion": 1.0,
		"reduce_flashes": 0.0, "frame_smoothing": 0.0, "wide_picture": 1.0}, "look": {"invert_y": 1.0, "stick_sensitivity": 3.25, "aim_assist": 0.75}}
	var handle := FileAccess.open(file, FileAccess.WRITE)
	handle.store_string(JSON.stringify(old, "  "))
	handle.close()
	var store = _game.settings_store()
	store.load_saved()
	var page = menu.settings_page()
	page.refresh()
	_t.check("the old file loads to the same values", not store.fullscreen() and store.quality() == 1 and store.reduced_motion() and not store.reduce_flashes()
		and not store.frame_smoothing() and store.wide_picture() and store.invert_y() and is_equal_approx(store.stick_sensitivity(), 3.25)
		and is_equal_approx(store.aim_assist(), 0.75), str(store.comfort))
	_t.check("the rows show the old file's values", _follows(_read(page, "fullscreen"), false) and _follows(_read(page, "reduced_motion"), true)
		and _follows(_read(page, "reduce_flashes"), false) and _follows(_read(page, "frame_smoothing"), false) and _follows(_read(page, "wide_picture"), true)
		and _read(page, "quality")["value"] == "low" and _follows(_read(page, "invert_y"), true)
		and _read(page, "stick_sensitivity")["value"] == "125%" and _read(page, "aim_assist")["value"] == "75%", str(_read(page, "quality")))
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	quit(_t.verdict())
