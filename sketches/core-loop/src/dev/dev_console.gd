extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const DevCommands := preload("res://src/dev/dev_commands.gd")
const DevLook := preload("res://src/dev/dev_look.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
const DevFight := preload("res://src/dev/dev_fight.gd")
const TreePick := preload("res://src/ui/tree_pick.gd")

const LAYER := 90
const TOGGLE_KEYS := [KEY_QUOTELEFT, KEY_F10]
const WIDTH := 432.0
const MARGIN := 16.0
const SLIDE_S := 0.18
const LOG_LINES := 7
const STATUS_EVERY := 0.25
const SHOT_DIR := "user://dev_shots"
const SHEET_COLUMNS := 3
const SHEET_SCALE := 0.34
const SETTLE_FRAMES := 4
const HAND := UiTokens.Hand.OLD_WORKS
const TABS := ["Look", "Paint", "Print", "Lens", "Fight", "Bake"]
const LIGHT_KEYS := ["exposure", "saturation", "contrast", "brightness", "ambient", "sun", "sun_pitch", "sun_yaw", "shadow",
	"sun_size", "fog", "fog_sky", "air", "glow", "bloom", "ssao", "white", "ink_width"]
const TONEMAPS := ["Linear", "Reinhard", "Filmic", "ACES", "AgX"]
const LENS_KNOBS := ["fov", "distance", "pitch", "yaw", "size", "lift", "spin", "tilt", "cut"]
const LENS_RANGES := {"fov": [10.0, 120.0, 0.5], "distance": [2.0, 200.0, 0.5], "pitch": [-89.5, 60.0, 0.5],
	"yaw": [-180.0, 180.0, 1.0], "size": [2.0, 300.0, 0.5], "lift": [-5.0, 30.0, 0.1], "spin": [-90.0, 90.0, 1.0], "tilt": [0.0, 1.0, 0.01], "cut": [0.0, 200.0, 0.5]}
const WORLDS := ["all", "1", "2", "3"]

var game
var commands := DevCommands.new()
var look: DevLook
var lens: DevLens
var fight: DevFight
var open := false
var _drawer: PanelContainer
var _page: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Array[Button] = []
var _tab := "Look"
var _log: RichTextLabel
var _line: LineEdit
var _hint: Label
var _status: Label
var _lines: Array[String] = []
var _history_at := -1
var _status_wait := 0.0
var _slide: Tween
var _keyboard_was := true
var _rows := {}
var _spawn_world := "1"
var _spawn_count := 1
var _spawn_affix := ""
var _shots := 0
var _busy := false
var _scripted := false


static func hook(game_ref) -> void:
	if game_ref.test_mode or not game_ref.dev:
		return
	var console := new()
	game_ref.add_child(console)
	console.setup(game_ref)


func setup(game_ref) -> void:
	game = game_ref
	name = "DevConsole"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	look = DevLook.new()
	add_child(look)
	look.setup(game)
	lens = DevLens.new()
	add_child(lens)
	lens.setup(game)
	fight = DevFight.new()
	add_child(fight)
	fight.setup(game)
	_register()
	commands.said.connect(_say)
	_build()
	_drawer.visible = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-run="):
			run_script.call_deferred(arg.trim_prefix("--dev-run="))


func toggle() -> void:
	set_open(not open)


func set_open(on: bool) -> void:
	if on == open:
		return
	open = on
	if _slide != null:
		_slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.set_ignore_time_scale(true)
	if on:
		_drawer.visible = true
		_drawer.position.x = -WIDTH
		_slide.tween_property(_drawer, "position:x", MARGIN, SLIDE_S)
		game.set_menu_held(true)
		game.capture_mouse(false)
		game.set_process_input(false)
		_show_tab(_tab)
		_line.grab_focus.call_deferred()
	else:
		_slide.tween_property(_drawer, "position:x", -WIDTH - MARGIN, SLIDE_S)
		_slide.tween_callback(func(): _drawer.visible = open)
		_line.release_focus()
		_typing(false)
		game.set_process_input(true)
		game.set_menu_held(false)
		game.recapture_mouse()


func run(line: String) -> void:
	_echo(line)
	commands.run(line)
	_refresh_rows()


func run_script(script: String) -> void:
	_scripted = true
	for part in script.split(";", false):
		var text := part.strip_edges()
		if text.begins_with("wait"):
			var frames := DevCommands.whole(text.split(" ", false), 1, 30)
			for i in frames:
				await get_tree().process_frame
			continue
		if text.begins_with("sheet"):
			await contact_sheet()
			continue
		if text.begins_with("shot"):
			await shot(text.trim_prefix("shot").strip_edges())
			continue
		if text == "quit":
			get_tree().quit()
			return
		run(text)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in TOGGLE_KEYS:
			toggle()
			get_viewport().set_input_as_handled()
			return
		if open and event.physical_keycode == KEY_ESCAPE:
			set_open(false)
			get_viewport().set_input_as_handled()
			return
	if not open:
		return
	if lens.live() and not _over_drawer(event) and lens.handle(event):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not open:
		return
	_status_wait -= delta / maxf(Engine.time_scale, 0.05)
	if _status_wait <= 0.0:
		_status_wait = STATUS_EVERY
		_status.text = "%d fps  %s  cam %s  %s" % [Engine.get_frames_per_second(), look.preset_name, lens.mode,
			"frozen" if fight.frozen() else "x%.2f" % fight.time_scale()]


func _over_drawer(event: InputEvent) -> bool:
	if not (event is InputEventMouse):
		return false
	return _drawer.get_global_rect().has_point(event.position)


func _typing(on: bool) -> void:
	var keyboard = game.get("keyboard")
	if keyboard == null:
		return
	if on:
		_keyboard_was = keyboard.enabled
		keyboard.enabled = false
	else:
		keyboard.enabled = _keyboard_was


func _register() -> void:
	commands.add("help", "[command]", "list commands, or show one command's use", func(args: Array[String]):
		if args.is_empty():
			return "commands: " + ", ".join(commands.names())
		return "%s: %s" % [commands.usage(args[0]), commands.help(args[0])] if commands.has(args[0]) else "!no command '%s'" % args[0])
	commands.add("look", "[preset]", "apply a look preset, or describe the current overrides", func(args: Array[String]):
		return look.describe() if args.is_empty() else look.apply_preset(" ".join(args)))
	commands.add("presets", "", "list the look presets", func(_args: Array[String]):
		return ", ".join(look.PRESETS.keys()))
	commands.add("set", "<key> <value>", "override one light, paint or print value", func(args: Array[String]):
		if args.size() < 2 or not args[1].is_valid_float():
			return "!set <key> <value>; keys: " + ", ".join(look.keys())
		return look.set_value(args[0], args[1].to_float()))
	commands.add("reset", "<key|all>", "hand one value, or the whole look, back to the game", func(args: Array[String]):
		var key := DevCommands.word(args, 0, "all")
		return look.clear() if key == "all" else look.release(key))
	commands.add("colour", "<ink|paper|riso_a|riso_b> <#hex>", "set a print colour", func(args: Array[String]):
		if args.size() < 2 or not Color.html_is_valid(args[1]):
			return "!colour <ink|paper|riso_a|riso_b> <#hex>"
		return look.set_colour(args[0], Color(args[1])))
	commands.add("cam", "<mode> | <knob> <value>", "switch the camera, or tune it", func(args: Array[String]):
		if args.is_empty():
			return "cameras: " + ", ".join(DevLens.MODES.keys())
		if args.size() >= 2 and args[1].is_valid_float():
			return lens.set_knob(args[0], args[1].to_float())
		return lens.use(args[0]))
	commands.add("ortho", "[on|off]", "orthographic projection: the flat 2D read", func(args: Array[String]):
		return lens.set_ortho(DevCommands.flag(args, 0, lens.ortho)))
	commands.add("hud", "[on|off]", "show or hide the game HUD for clean stills", func(args: Array[String]):
		var hud = game.get("hud")
		if hud == null:
			return "!no HUD"
		hud.visible = DevCommands.flag(args, 0, hud.visible)
		return "HUD %s" % ("shown" if hud.visible else "hidden"))
	commands.add("spawn", "<kind> [count] [affix]", "summon enemies ahead of the ball", func(args: Array[String]):
		if args.is_empty():
			return "!spawn <kind> [count] [affix]; 'kinds' lists them"
		return fight.spawn(args[0], DevCommands.whole(args, 1, 1), DevCommands.word(args, 2, "")))
	commands.add("kinds", "[world]", "list enemy kinds, optionally for one world", func(args: Array[String]):
		return ", ".join(fight.kinds(DevCommands.whole(args, 0, 0))))
	commands.add("clear", "[hard]", "kill every enemy; hard also removes posture-gated ones", func(args: Array[String]):
		return fight.clear(DevCommands.word(args, 0) == "hard"))
	commands.add("god", "[on|off]", "hits deal nothing and the hull refills", func(args: Array[String]):
		return fight.set_god(DevCommands.flag(args, 0, fight.god)))
	commands.add("heal", "", "refill the hull", func(_args: Array[String]): return fight.heal())
	commands.add("scrap", "<amount>", "add scrap at the ball", func(args: Array[String]):
		return fight.scrap(DevCommands.whole(args, 0, 100)))
	commands.add("cogs", "<amount>", "add cogs", func(args: Array[String]):
		return fight.cogs(DevCommands.whole(args, 0, 100)))
	commands.add("calm", "[on|off]", "stop packs, the Warden and event pushes", func(args: Array[String]):
		return fight.set_calm(DevCommands.flag(args, 0, game.ctx.calm if game.ctx != null else false)))
	commands.add("time", "<scale>", "time scale: 0 freezes, 0.25 slow, 1 normal", func(args: Array[String]):
		return fight.set_time(DevCommands.number(args, 0, 1.0)))
	commands.add("freeze", "", "freeze or resume time (photo mode)", func(_args: Array[String]): return fight.toggle_freeze())
	commands.add("boss", "[phase]", "enter this world's boss, or jump the running boss to a phase", func(args: Array[String]):
		return fight.boss(DevCommands.whole(args, 0, 0)))
	commands.add("run", "[pilot number]", "start a run from the title with a pilot (1 is the first)", func(args: Array[String]):
		var flow = game.flow
		var index := DevCommands.whole(args, 0, 1) - 1
		if flow.state_name() != "title":
			return "!runs start from the title screen"
		if index < 0 or index >= flow.classes.size():
			return "!no pilot %d" % (index + 1)
		flow.launch_from_title(flow.classes[index])
		return "run started")
	commands.add("bake", "<name>", "save the current look to a file", func(args: Array[String]):
		return look.bake(DevCommands.word(args, 0, "look-%d" % Engine.get_frames_drawn())))
	commands.add("load", "<name>", "load a baked look", func(args: Array[String]):
		return look.load_baked(DevCommands.word(args, 0)))
	commands.add("baked", "", "list baked looks", func(_args: Array[String]):
		var found := look.baked()
		return ", ".join(found) if not found.is_empty() else "no baked looks yet: 'bake <name>' saves one")
	commands.add("shot", "[name]", "save a still without the console", func(args: Array[String]):
		shot(DevCommands.word(args, 0))
		return "")
	commands.add("sheet", "", "capture every preset on this frame into one contact sheet", func(_args: Array[String]):
		contact_sheet()
		return "")
	commands.add("pick", "<card>", "take the open kit or start card (1 is the left one)", func(args: Array[String]):
		unpause()
		var index := DevCommands.whole(args, 0, 1) - 1
		for node in game.find_children("*", "", true, false):
			if node.get_script() == TreePick and node.is_open():
				var start: int = node.focused_index()
				node.step_focus(index - maxi(start, 0))
				node.confirm()
				return "kit card %d taken" % (index + 1)
		if game.flow.take_start_pick(index):
			return "start card taken"
		return "!no card is open")
	commands.add("unpause", "", "close the pause menu", func(_args: Array[String]):
		return "pause menu closed" if unpause() else "!the pause menu is not open")
	commands.add("status", "", "enemies, hull, god, calm and time", func(_args: Array[String]): return fight.summary())
	commands.add("cls", "", "clear the console log", func(_args: Array[String]):
		_lines.clear()
		_log.text = ""
		return "")


func unpause() -> bool:
	var menu = game.get_node_or_null("PauseMenu")
	if menu == null or not menu.is_open():
		return false
	menu.close()
	return true


func shot(id := "") -> String:
	if _scripted:
		unpause()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_shots += 1
	var file := (id if id.is_valid_filename() and id != "" else "shot-%03d-%d" % [_shots, Engine.get_frames_drawn()]) + ".png"
	var path := SHOT_DIR.path_join(file)
	var was := _drawer.visible
	_drawer.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_drawer.visible = was
	var err := image.save_png(path)
	var reply := ("still -> %s" % ProjectSettings.globalize_path(path)) if err == OK else "!could not save %s (%d)" % [path, err]
	_say(reply, "warn" if err != OK else "ok")
	return reply


func contact_sheet() -> String:
	if _busy:
		return "!a sheet is already running"
	_busy = true
	var held := look.snapshot()
	if _scripted:
		unpause()
	var was_frozen := fight.frozen()
	var scale := fight.time_scale()
	fight.set_time(0.0)
	var was := _drawer.visible
	_drawer.visible = false
	var ids: Array = look.PRESETS.keys()
	var tiles: Array[Image] = []
	for id in ids:
		look.apply_preset(id)
		for i in SETTLE_FRAMES:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(int(image.get_width() * SHEET_SCALE), int(image.get_height() * SHEET_SCALE), Image.INTERPOLATE_LANCZOS)
		tiles.append(image)
	var w := tiles[0].get_width()
	var h := tiles[0].get_height()
	var rows := ceili(float(tiles.size()) / SHEET_COLUMNS)
	var sheet := Image.create(w * SHEET_COLUMNS, h * rows, false, tiles[0].get_format())
	sheet.fill(Palette.CHARCOAL)
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i((i % SHEET_COLUMNS) * w, (i / SHEET_COLUMNS) * h))
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_shots += 1
	var path := SHOT_DIR.path_join("sheet-%03d-%d.png" % [_shots, Engine.get_frames_drawn()])
	var err := sheet.save_png(path)
	look.clear()
	look.load_snapshot(held)
	fight.set_time(0.0 if was_frozen else scale)
	_drawer.visible = was
	_busy = false
	var reply := ("contact sheet of %d looks (%s) -> %s" % [ids.size(), ", ".join(ids), ProjectSettings.globalize_path(path)]) if err == OK else "!could not save the sheet (%d)" % err
	_say(reply, "warn" if err != OK else "ok")
	return reply


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_drawer = PanelContainer.new()
	_drawer.name = "Drawer"
	_drawer.add_theme_stylebox_override("panel", ScrapFrame.hand_plate(HAND, 52))
	_drawer.position = Vector2(-WIDTH, MARGIN)
	_drawer.custom_minimum_size = Vector2(WIDTH, 0.0)
	_drawer.size = Vector2(WIDTH, get_viewport().get_visible_rect().size.y - MARGIN * 2.0)
	root.add_child(_drawer)
	get_viewport().size_changed.connect(func(): _drawer.size.y = get_viewport().get_visible_rect().size.y - MARGIN * 2.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.GAP_S)
	_drawer.add_child(column)

	var head := HBoxContainer.new()
	column.add_child(head)
	var title := _text("Dev", UiTokens.LABEL, _ink(), UiFonts.face(HAND))
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_status = _text("", UiTokens.CAPTION, _quiet(), UiFonts.mono())
	head.add_child(_status)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", UiTokens.GAP_XS)
	column.add_child(strip)
	var group := ButtonGroup.new()
	for id in TABS:
		var tab := _button(id, func(): _show_tab(id))
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		strip.add_child(tab)
		_tabs.append(tab)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", UiTokens.GAP_XS)
	_scroll.add_child(_page)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0.0, 118.0)
	_log.add_theme_font_override("normal_font", UiFonts.mono())
	_log.add_theme_font_size_override("normal_font_size", UiTokens.CAPTION)
	_log.add_theme_stylebox_override("normal", UiTokens.plate(Color(Palette.CABLE, 0.0), 0, true))
	column.add_child(_log)

	var prompt := HBoxContainer.new()
	column.add_child(prompt)
	prompt.add_child(_text(">", UiTokens.BODY, UiTokens.ACCENT, UiFonts.mono()))
	_line = LineEdit.new()
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.placeholder_text = "help, look graphic press, spawn chaser 5, cam iso"
	_line.add_theme_font_override("font", UiFonts.mono())
	_line.add_theme_font_size_override("font_size", UiTokens.BODY)
	_line.add_theme_color_override("font_color", _ink())
	_line.add_theme_color_override("caret_color", UiTokens.ACCENT)
	_line.add_theme_stylebox_override("normal", UiTokens.plate(UiTokens.LINE))
	_line.add_theme_stylebox_override("focus", UiTokens.plate(UiTokens.ACCENT, UiTokens.FOCUS_EDGE, false))
	_line.text_submitted.connect(_submit)
	_line.text_changed.connect(_hint_for)
	_line.gui_input.connect(_line_keys)
	_line.focus_entered.connect(func(): _typing(true))
	_line.focus_exited.connect(func(): _typing(false))
	prompt.add_child(_line)
	_hint = _text("` or F10 closes. Tab completes, Up/Down recalls.", UiTokens.CAPTION, _quiet(), UiFonts.mono())
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_tabs[0].button_pressed = true


func _show_tab(id: String) -> void:
	_tab = id
	for tab in _tabs:
		tab.set_pressed_no_signal(tab.text == id)
	for child in _page.get_children():
		child.queue_free()
	_rows.clear()
	match id:
		"Look":
			_page_look()
		"Paint":
			_page_filters(DevLook.PAINT, "3D surfaces only. Telegraphs, VFX and the HUD draw over it untouched; it fades out with distance.")
		"Print":
			_page_filters(DevLook.PRINT, "The whole 3D frame, telegraphs included. The HUD stays crisp on top.")
			_page_colours()
		"Lens":
			_page_lens()
		"Fight":
			_page_fight()
		"Bake":
			_page_bake()
	_scroll.scroll_vertical = 0


func _page_look() -> void:
	_section("Presets")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiTokens.GAP_XS)
	grid.add_theme_constant_override("v_separation", UiTokens.GAP_XS)
	_page.add_child(grid)
	for id in DevLook.PRESETS:
		var button := _button(id, func(): run("look %s" % id))
		button.tooltip_text = DevLook.PRESETS[id].blurb
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		if id == look.preset_name:
			button.add_theme_color_override("font_color", UiTokens.ACCENT)
		grid.add_child(button)
	_section("Light")
	var tone := OptionButton.new()
	for i in TONEMAPS.size():
		tone.add_item(TONEMAPS[i], i)
	tone.selected = clampi(int(look.value("tonemap")), 0, TONEMAPS.size() - 1)
	tone.item_selected.connect(func(i: int): run("set tonemap %d" % i))
	tone.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	_page.add_child(_labelled("tonemap", tone))
	for key in LIGHT_KEYS:
		_slider_row(key, look.range_of(key), look.value(key), func(v: float): look.set_value(key, v), "set %s %s" % [key, "%s"], look.touched(key))
	_page.add_child(_button("Back to the game's lighting", func(): run("reset all")))


func _page_filters(pass_id: String, note: String) -> void:
	_note(note)
	for key in DevLook.FILTERS:
		if DevLook.FILTERS[key].pass != pass_id:
			continue
		_slider_row(key, DevLook.FILTERS[key].range, look.value(key), func(v: float): look.set_value(key, v), "set %s %s" % [key, "%s"], look.touched(key))


func _page_colours() -> void:
	_section("Inks")
	for key in DevLook.COLOURS:
		var picker := ColorPickerButton.new()
		picker.color = DevLook.COLOURS[key].rest
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(0.0, 30.0)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.color_changed.connect(func(c: Color): look.set_colour(key, c))
		picker.popup_closed.connect(func(): _echo("colour %s #%s" % [key, picker.color.to_html(false)]))
		_page.add_child(_labelled(key, picker))


func _page_lens() -> void:
	_section("Camera")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", UiTokens.GAP_XS)
	grid.add_theme_constant_override("v_separation", UiTokens.GAP_XS)
	_page.add_child(grid)
	for id in DevLens.MODES:
		var button := _button(id, func():
			run("cam %s" % id)
			_show_tab("Lens"))
		button.tooltip_text = DevLens.MODES[id].blurb
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		if id == lens.mode:
			button.add_theme_color_override("font_color", UiTokens.ACCENT)
		grid.add_child(button)
	if lens.live():
		_note("Right-drag the world to orbit, wheel to zoom.")
	var ortho := CheckButton.new()
	ortho.text = "orthographic"
	ortho.button_pressed = lens.ortho
	ortho.toggled.connect(func(on: bool): run("ortho %s" % ("on" if on else "off")))
	_page.add_child(ortho)
	for key in LENS_KNOBS:
		_slider_row(key, LENS_RANGES[key], lens.knob(key), func(v: float): lens.set_knob(key, v), "cam %s %s" % [key, "%s"], false)


func _page_fight() -> void:
	_section("Rules")
	var toggles := HBoxContainer.new()
	_page.add_child(toggles)
	for pair in [["god", fight.god], ["calm", game.ctx != null and game.ctx.calm], ["freeze", fight.frozen()]]:
		var check := CheckButton.new()
		check.text = pair[0]
		check.button_pressed = pair[1]
		check.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		var id: String = pair[0]
		check.toggled.connect(func(on: bool): run(id if id == "freeze" else "%s %s" % [id, "on" if on else "off"]))
		toggles.add_child(check)
	_slider_row("time", [0.0, 4.0, 0.05], fight.time_scale(), func(v: float): fight.set_time(v), "time %s", false)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", UiTokens.GAP_XS)
	actions.add_theme_constant_override("v_separation", UiTokens.GAP_XS)
	_page.add_child(actions)
	for pair in [["clear", "clear"], ["clear hard", "clear hard"], ["heal", "heal"], ["+500 scrap", "scrap 500"],
			["+200 cogs", "cogs 200"], ["boss", "boss"], ["phase 2", "boss 2"], ["phase 3", "boss 3"], ["status", "status"]]:
		var line: String = pair[1]
		var button := _button(pair[0], func(): run(line))
		button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		actions.add_child(button)
	_section("Summon")
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", UiTokens.GAP_XS)
	_page.add_child(options)
	for world in WORLDS:
		var tab := _button("W%s" % world if world != "all" else "all", func():
			_spawn_world = world
			_show_tab("Fight"))
		tab.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		if world == _spawn_world:
			tab.add_theme_color_override("font_color", UiTokens.ACCENT)
		options.add_child(tab)
	var count := SpinBox.new()
	count.min_value = 1
	count.max_value = DevFight.MAX_COUNT
	count.value = _spawn_count
	count.prefix = "x"
	count.value_changed.connect(func(v: float): _spawn_count = int(v))
	options.add_child(count)
	var affix := OptionButton.new()
	affix.add_item("plain")
	for id in DevFight.EliteAffixes.IDS + [DevFight.EliteAffixes.PLATED]:
		affix.add_item(id)
	affix.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	affix.item_selected.connect(func(i: int): _spawn_affix = "" if i == 0 else affix.get_item_text(i))
	options.add_child(affix)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiTokens.GAP_XS)
	grid.add_theme_constant_override("v_separation", UiTokens.GAP_XS)
	_page.add_child(grid)
	for kind in fight.kinds(0 if _spawn_world == "all" else _spawn_world.to_int()):
		var button := _button(fight.label(kind), func(): run(("spawn %s %d %s" % [kind, _spawn_count, _spawn_affix]).strip_edges()))
		button.tooltip_text = kind
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		grid.add_child(button)


func _page_bake() -> void:
	_section("Bake the look")
	_note("A baked look is a small file of every override. Load it later, or hand it to a commit.")
	var row := HBoxContainer.new()
	_page.add_child(row)
	var name_box := LineEdit.new()
	name_box.placeholder_text = "name"
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_font_override("font", UiFonts.mono())
	name_box.focus_entered.connect(func(): _typing(true))
	name_box.focus_exited.connect(func(): _typing(false))
	row.add_child(name_box)
	row.add_child(_button("Bake", func():
		run("bake %s" % name_box.text.strip_edges().replace(" ", "-"))
		_show_tab("Bake")))
	for id in look.baked():
		_page.add_child(_button("load %s" % id, func(): run("load %s" % id)))
	_section("Stills")
	var shots := HBoxContainer.new()
	_page.add_child(shots)
	shots.add_child(_button("Still", func(): run("shot")))
	shots.add_child(_button("Contact sheet", func(): run("sheet")))
	shots.add_child(_button("Toggle HUD", func(): run("hud")))
	_note("The contact sheet freezes this frame and captures it once per preset, side by side.")
	_note("Files land in %s" % ProjectSettings.globalize_path(SHOT_DIR))


func _slider_row(key: String, span: Array, current: float, apply: Callable, echo: String, touched: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_S)
	var name_label := _text(key, UiTokens.CAPTION, UiTokens.ACCENT if touched else _ink(), UiFonts.mono())
	name_label.custom_minimum_size = Vector2(112.0, 0.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.tooltip_text = "double-click to hand back to the game"
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = float(span[0])
	slider.max_value = float(span[1])
	slider.step = float(span[2])
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var shown := _text(_fmt(current), UiTokens.CAPTION, _quiet(), UiFonts.mono())
	shown.custom_minimum_size = Vector2(64.0, 0.0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	slider.value_changed.connect(func(v: float):
		apply.call(v)
		shown.text = _fmt(v)
		name_label.add_theme_color_override("font_color", UiTokens.ACCENT))
	slider.drag_ended.connect(func(changed: bool):
		if changed:
			_echo(echo % _fmt(slider.value)))
	name_label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.double_click:
			run("reset %s" % key)
			_show_tab(_tab))
	_rows[key] = {"slider": slider, "shown": shown, "label": name_label}
	_page.add_child(row)


func _refresh_rows() -> void:
	for key in _rows:
		var row: Dictionary = _rows[key]
		if not is_instance_valid(row.slider):
			continue
		var value := lens.knob(key) if key in LENS_KNOBS else (fight.time_scale() if key == "time" else look.value(key))
		row.slider.set_value_no_signal(value)
		row.shown.text = _fmt(value)
		row.label.add_theme_color_override("font_color", UiTokens.ACCENT if look.touched(key) else _ink())


func _labelled(label: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_S)
	var name_label := _text(label, UiTokens.CAPTION, _ink(), UiFonts.mono())
	name_label.custom_minimum_size = Vector2(112.0, 0.0)
	row.add_child(name_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _section(text: String) -> void:
	var label := _text(text, UiTokens.BODY, UiTokens.hand(HAND).seam, UiFonts.face(HAND))
	label.custom_minimum_size = Vector2(0.0, 30.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_page.add_child(label)


func _note(text: String) -> void:
	var label := _text(text, UiTokens.CAPTION, _quiet(), UiFonts.bold())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(label)


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	return button


func _text(text: String, size: int, colour: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _submit(text: String) -> void:
	_line.clear()
	_history_at = -1
	_hint_for("")
	if text.strip_edges().is_empty():
		return
	if text.strip_edges().begins_with("sheet") or text.strip_edges().begins_with("shot") or text.contains("wait"):
		_echo(text)
		commands.history.append(text.strip_edges())
		run_script(text)
		return
	run(text)
	if _tab != "Bake":
		_show_tab(_tab)


func _line_keys(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var history := commands.history
	match event.keycode:
		KEY_UP:
			if not history.is_empty():
				_history_at = history.size() - 1 if _history_at < 0 else maxi(0, _history_at - 1)
				_line.text = history[_history_at]
				_line.caret_column = _line.text.length()
			_line.accept_event()
		KEY_DOWN:
			if _history_at >= 0:
				_history_at += 1
				_line.text = history[_history_at] if _history_at < history.size() else ""
				if _history_at >= history.size():
					_history_at = -1
				_line.caret_column = _line.text.length()
			_line.accept_event()
		KEY_TAB:
			var text := _line.text
			if not text.contains(" "):
				var found := commands.complete(text)
				if found.size() == 1:
					_line.text = found[0] + " "
				elif found.size() > 1:
					_line.text = _common(found)
			else:
				var head := text.split(" ")[0]
				var tail := text.substr(head.length() + 1)
				var pool: Array = []
				match head:
					"look":
						pool = DevLook.PRESETS.keys()
					"cam":
						pool = DevLens.MODES.keys() + LENS_KNOBS
					"set", "reset":
						pool = look.keys()
					"spawn":
						pool = fight.kinds()
					"load":
						pool = Array(look.baked())
				var hits := pool.filter(func(p: String): return p.begins_with(tail))
				if hits.size() == 1:
					_line.text = "%s %s " % [head, hits[0]]
				elif hits.size() > 1:
					_hint.text = ", ".join(hits.slice(0, 12))
			_line.caret_column = _line.text.length()
			_line.accept_event()


func _hint_for(text: String) -> void:
	var head := text.strip_edges().split(" ", false)
	if head.is_empty():
		_hint.text = "` or F10 closes. Tab completes, Up/Down recalls."
		return
	if commands.has(head[0]):
		_hint.text = "%s  %s" % [commands.usage(head[0]), commands.help(head[0])]
	else:
		var found := commands.complete(head[0])
		_hint.text = ", ".join(found) if not found.is_empty() else "no such command"


func _echo(line: String) -> void:
	_push("[color=#%s]> %s[/color]" % [UiTokens.ACCENT.to_html(false), _escape(line)])


func _say(line: String, tone: String) -> void:
	if line.is_empty():
		return
	var shown := line.trim_prefix("!")
	var colour: Color = UiTokens.ALERT if tone == "warn" else Palette.ANCIENT
	_push("[color=#%s]%s[/color]" % [colour.to_html(false), _escape(shown)])
	print("DEV %s" % shown)


func _push(line: String) -> void:
	_lines.append(line)
	while _lines.size() > LOG_LINES * 6:
		_lines.pop_front()
	_log.text = "\n".join(_lines)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func _common(words: Array[String]) -> String:
	var prefix := words[0]
	for word in words:
		while not word.begins_with(prefix):
			prefix = prefix.left(prefix.length() - 1)
	return prefix


static func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)) and absf(value) >= 1.0:
		return str(int(roundf(value)))
	return ("%.3f" % value).rstrip("0").rstrip(".")


static func _ink() -> Color:
	return UiTokens.hand(HAND).ink


static func _quiet() -> Color:
	return UiTokens.hand(HAND).quiet
