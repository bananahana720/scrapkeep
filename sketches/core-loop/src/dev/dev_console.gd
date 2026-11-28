extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const DevCommands := preload("res://src/dev/dev_commands.gd")
const DevLook := preload("res://src/dev/dev_look.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
const DevFight := preload("res://src/dev/dev_fight.gd")
const DevOverlay := preload("res://src/dev/dev_overlay.gd")
const DevInspect := preload("res://src/dev/dev_inspect.gd")
const DevAgent := preload("res://src/dev/dev_agent.gd")
const DevCapture := preload("res://src/dev/dev_capture.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const TreePick := preload("res://src/ui/tree_pick.gd")

const LAYER := 90
const TOGGLE_KEYS := [KEY_QUOTELEFT, KEY_F10]
const WIDTH := 456.0
const MARGIN := 16.0
const SLIDE_S := 0.18
const LOG_LINES := 7
const STATUS_EVERY := 0.25
const TAB_PAD := 6
const DOT_PX := 6.0
const RESET_PX := 20.0
const HAND := UiTokens.Hand.OLD_WORKS
const TABS := ["Look", "Paint", "Print", "Lens", "Fight", "Debug", "Bake"]
const OVERLAY_WORDS := ["off", "all", "bounds", "telegraphs", "vel", "perf", "+bounds", "+telegraphs", "+vel", "+perf",
	"-bounds", "-telegraphs", "-vel", "-perf"]
const LIGHT_KEYS := ["exposure", "saturation", "contrast", "brightness", "ambient", "sun", "sun_pitch", "sun_yaw", "shadow",
	"sun_size", "fog", "fog_sky", "air", "glow", "bloom", "ssao", "white", "ink_width"]
const TONEMAPS := ["Linear", "Reinhard", "Filmic", "ACES", "AgX"]
const LENS_KNOBS := DevLens.LENS_KNOBS
const SCRIPT_STEPS := ["wait", "tick", "until", "shot", "qa_pack", "sheet", "quit"]
const WORLDS := ["all", "1", "2", "3"]

var game
var commands := DevCommands.new()
var look: DevLook
var lens: DevLens
var fight: DevFight
var overlay: DevOverlay
var inspect: DevInspect
var agent: DevAgent
var capture: DevCapture
var open := false
var _drawer: PanelContainer
var _page: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Array[Button] = []
var _dots := {}
var _tab := "Look"
var _log: RichTextLabel
var _line: LineEdit
var _hint: Label
var _status: Label
var _lines: Array[String] = []
var _history_at := -1
var _status_wait := 0.0
var _slide: Tween
var _held_input := {}
var _rows := {}
var _spawn_world := "1"
var _spawn_count := 1
var _spawn_affix := ""


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
	overlay = DevOverlay.new()
	add_child(overlay)
	overlay.setup(game, self)
	_register()
	if fight.has_method("register_extra"):
		fight.register_extra(commands)
	inspect = DevInspect.new()
	add_child(inspect)
	inspect.setup(game, self)
	inspect.register(commands)
	overlay.register(commands)
	capture = DevCapture.new()
	agent = DevAgent.new()
	add_child(agent)
	agent.setup(game, self)
	commands.said.connect(_say)
	_build()
	_drawer.visible = false
	add_child(capture)
	capture.setup(game, self, _drawer, _ink())
	capture.said.connect(_say)
	game.events.flow_changed.connect(_on_flow_changed)


func _exit_tree() -> void:
	if open:
		_hold_input(false)
		if is_instance_valid(game):
			game.hold_for_dev(false)
	if get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.disconnect(_on_viewport_resized)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if game != null and game.events.flow_changed.is_connected(_on_flow_changed):
		game.events.flow_changed.disconnect(_on_flow_changed)
	open = false


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
		game.hold_for_dev(true)
		_hold_input(true)
		_show_tab(_tab)
		_focus_line.call_deferred()
	else:
		_slide.tween_property(_drawer, "position:x", -WIDTH - MARGIN, SLIDE_S)
		_slide.tween_callback(func(): _drawer.visible = open)
		var holder := get_viewport().gui_get_focus_owner()
		if holder != null and _drawer.is_ancestor_of(holder):
			holder.release_focus()
		_hold_input(false)
		game.hold_for_dev(false)


func _focus_line() -> void:
	if open and is_instance_valid(_line):
		_line.grab_focus()


func _on_flow_changed(_state: String) -> void:
	if not open:
		return
	_sweep_input.call_deferred()
	_focus_line.call_deferred()


func _hold_input(on: bool) -> void:
	if on:
		_held_input.clear()
		_sweep_input()
		get_tree().node_added.connect(_on_node_added)
		return
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for node in _held_input:
		if not is_instance_valid(node):
			continue
		var flags: Array = _held_input[node]
		if flags[0]:
			node.set_process_input(true)
		if flags[1]:
			node.set_process_unhandled_input(true)
		if flags[2]:
			node.set_process_unhandled_key_input(true)
		if flags[3]:
			node.set_process_shortcut_input(true)
	_held_input.clear()


func _hold_node(node) -> void:
	if not open or not is_instance_valid(node) or not node is Node or node == self or is_ancestor_of(node):
		return
	var flags := [node.is_processing_input(), node.is_processing_unhandled_input(), node.is_processing_unhandled_key_input(), node.is_processing_shortcut_input()]
	if not true in flags:
		return
	var before: Array = _held_input.get(node, [false, false, false, false])
	for i in flags.size():
		flags[i] = flags[i] or before[i]
	_held_input[node] = flags
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	node.set_process_shortcut_input(false)


func _on_node_added(node: Node) -> void:
	_hold_node.call_deferred(node)


func _sweep_input() -> void:
	if not open or not is_inside_tree():
		return
	for node in get_tree().root.find_children("*", "", true, false):
		_hold_node(node)


func held_input() -> Array:
	return _held_input.keys()


func run(line: String, keep := true) -> void:
	_echo(line)
	commands.run(line, keep)
	refresh_rows()
	_sweep_input.call_deferred()


func run_script(script: String, scripted := false) -> void:
	for part in script.split(";", false):
		var text := part.strip_edges()
		if not text.is_empty():
			_echo(text)
	var receipt: Dictionary = await agent.run_scenario([script], {"scripted": scripted, "reset_assertions": false})
	refresh_rows()
	_sync_dots()
	_sweep_input.call_deferred()
	for row in receipt.get("steps", []):
		if row is Dictionary and row.get("data") is Dictionary and bool(row.data.get("quitting", false)):
			if is_inside_tree():
				get_tree().quit(0 if bool(receipt.get("ok", false)) else 1)
			return


static func needs_script(line: String) -> bool:
	for part in line.split(";", false):
		var words := part.strip_edges().split(" ", false)
		if not words.is_empty() and words[0].to_lower() in SCRIPT_STEPS:
			return true
	return false


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
		_sweep_input()
		_sync_dots()
		_status.text = "%d fps  %s  cam %s  %s" % [Engine.get_frames_per_second(), look.preset_name, lens.mode,
			"frozen" if fight.frozen() else "x%.2f" % fight.time_scale()]


func _over_drawer(event: InputEvent) -> bool:
	if not (event is InputEventMouse):
		return false
	return _drawer.get_global_rect().has_point(event.position)


func _register() -> void:
	commands.add("help", "[command|json]", "list commands, show one command's use, or print every command as JSON", func(args: Array[String]):
		if args.is_empty():
			return "commands: " + ", ".join(commands.names())
		if args[0] == "json" and not commands.has("json"):
			var data = commands.schema() if commands.has_method("schema") else commands.names()
			return {"ok": true, "text": JSON.stringify({"ok": true, "text": "commands: " + ", ".join(commands.names()), "data": data}), "data": data}
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
		overlay.hud_shown(hud.visible)
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
		var res = fight.launch_pilot(["1"] if args.is_empty() else args)
		if res is Dictionary and bool(res.get("ok", false)):
			return "run started"
		return res)
	commands.add("bake", "<name>", "save the current look to a file", func(args: Array[String]):
		return look.bake(DevCommands.word(args, 0, "look-%d" % Engine.get_frames_drawn())))
	commands.add("load", "<name>", "load a baked look", func(args: Array[String]):
		return look.load_baked(DevCommands.word(args, 0)))
	commands.add("baked", "", "list baked looks", func(_args: Array[String]):
		var found := look.baked()
		return ", ".join(found) if not found.is_empty() else "no baked looks yet: 'bake <name>' saves one")
	commands.add("shot", "[name]", "save a still without the console", func(args: Array[String]):
		capture.shot(DevCommands.word(args, 0))
		return "")
	commands.add("qa_pack", "[name]", "capture the 4-oracle visual QA pack (1080p RGB, 720p, Rec.709 greyscale, Machado deuteranopia)", func(args: Array[String]):
		capture.qa_pack_detailed(DevCommands.word(args, 0))
		return "")
	commands.add("sheet", "[presets|cams|quality] [name]", "capture this frame once per look, camera or quality level into one labelled sheet", func(args: Array[String]):
		var axis := DevCommands.word(args, 0, "presets").to_lower()
		if not axis in DevCapture.SHEET_AXES:
			return "!sheet takes %s" % ", ".join(DevCapture.SHEET_AXES)
		capture.sheet_detailed(axis, DevCommands.word(args, 1))
		return "")
	commands.add("pick", "<card>", "take the open kit or start card (1 is the left one)", func(args: Array[String]):
		unpause()
		var index := DevCommands.whole(args, 0, 1) - 1
		for node in game.find_children("*", "", true, false):
			if node.get_script() == TreePick and node.is_open():
				var start: int = node.focused_index()
				if start < 0:
					node.step_focus(0)
					start = 0
				node.step_focus(index - start)
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
	get_viewport().size_changed.connect(_on_viewport_resized)
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
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			tab.add_theme_stylebox_override(state, _tab_box(state))
		tab.add_theme_color_override("font_color", _quiet())
		tab.add_theme_color_override("font_hover_color", _ink())
		tab.add_theme_color_override("font_pressed_color", _ink())
		tab.add_theme_color_override("font_hover_pressed_color", _ink())
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var round := StyleBoxFlat.new()
		round.bg_color = UiTokens.ACCENT
		round.set_corner_radius_all(int(DOT_PX))
		dot.add_theme_stylebox_override("panel", round)
		dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -DOT_PX - 2.0
		dot.offset_right = -2.0
		dot.offset_top = 2.0
		dot.offset_bottom = DOT_PX + 2.0
		dot.visible = false
		tab.add_child(dot)
		_dots[id] = dot
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
	prompt.add_child(_line)
	_hint = _text("` or F10 closes. Tab completes, Up/Down recalls.", UiTokens.CAPTION, _quiet(), UiFonts.mono())
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_tabs[0].button_pressed = true


func _on_viewport_resized() -> void:
	_drawer.size.y = get_viewport().get_visible_rect().size.y - MARGIN * 2.0


func _show_tab(id: String) -> void:
	var keep := _scroll.scroll_vertical if id == _tab else 0
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
		"Debug":
			_page_debug()
		"Bake":
			_page_bake()
	_sync_dots()
	_scroll.scroll_vertical = keep
	_keep_scroll(id, keep)


func _keep_scroll(id: String, keep: int) -> void:
	if keep <= 0:
		return
	await get_tree().process_frame
	if is_inside_tree() and _tab == id:
		_scroll.scroll_vertical = keep


func _sync_dots() -> void:
	for id in _dots:
		_dots[id].visible = _tab_live(id)


func _tab_live(id: String) -> bool:
	match id:
		"Look":
			return look.preset_name != "shipped" or LIGHT_KEYS.any(func(k: String): return look.touched(k)) or look.touched("tonemap")
		"Paint", "Print":
			var pass_id := DevLook.PAINT if id == "Paint" else DevLook.PRINT
			return look.passes_live()[pass_id]
		"Lens":
			return lens.live() or lens.tilt_shift > 0.0
		"Fight":
			return fight.god or fight.frozen() or not is_equal_approx(fight.time_scale(), 1.0) or (game.ctx != null and game.ctx.calm)
		"Debug":
			return overlay.any_active()
	return false


func _page_look() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiTokens.GAP_XS)
	grid.add_theme_constant_override("v_separation", UiTokens.GAP_XS)
	_page.add_child(grid)
	var presets := ButtonGroup.new()
	for id in DevLook.PRESETS:
		var button := _choice(id, id == look.preset_name, presets, func():
			run("look %s" % id)
			_show_tab("Look"))
		button.tooltip_text = DevLook.PRESETS[id].blurb
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
	_page.add_child(_button("Reset look", func():
		run("reset all")
		_show_tab("Look")))


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
		picker.color = look.colour(key)
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(0.0, 30.0)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.color_changed.connect(func(c: Color): look.set_colour(key, c))
		picker.popup_closed.connect(func(): _echo("colour %s #%s" % [key, picker.color.to_html(false)]))
		_page.add_child(_labelled(key, picker))


func _page_lens() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", UiTokens.GAP_XS)
	grid.add_theme_constant_override("v_separation", UiTokens.GAP_XS)
	_page.add_child(grid)
	var cams := ButtonGroup.new()
	for id in DevLens.MODES:
		var button := _choice(id, id == lens.mode, cams, func():
			run("cam %s" % id)
			_show_tab("Lens"))
		button.tooltip_text = DevLens.MODES[id].blurb
		grid.add_child(button)
	if lens.live():
		_note("Right-drag the world to orbit, wheel to zoom.")
	var ortho := CheckButton.new()
	ortho.text = "orthographic"
	ortho.button_pressed = lens.ortho
	ortho.toggled.connect(func(on: bool):
		run("ortho %s" % ("on" if on else "off"))
		_show_tab("Lens"))
	_page.add_child(ortho)
	for key in LENS_KNOBS:
		_slider_row(key, DevLens.LENS_RANGES[key], lens.knob(key), func(v: float): lens.set_knob(key, v), "cam %s %s" % [key, "%s"], false)
	_sync_lens_rows()


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
	var worlds := ButtonGroup.new()
	for world in WORLDS:
		var tab := _choice("W%s" % world if world != "all" else "all", world == _spawn_world, worlds, func():
			_spawn_world = world
			_show_tab("Fight"))
		tab.size_flags_horizontal = Control.SIZE_FILL
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
	var row := HBoxContainer.new()
	_page.add_child(row)
	var name_box := LineEdit.new()
	name_box.placeholder_text = "name"
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_font_override("font", UiFonts.mono())
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
	_note(ProjectSettings.globalize_path(capture.shot_dir))


func _page_debug() -> void:
	var layers := overlay.active_layers()
	for key in DevOverlay.LAYERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTokens.GAP_S)
		var check := CheckButton.new()
		check.text = key
		check.button_pressed = layers[key]
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		check.toggled.connect(func(on: bool): run("overlay %s%s" % ["+" if on else "-", key]))
		row.add_child(check)
		if key == "telegraphs":
			row.add_child(_legend())
		_page.add_child(row)
	var perf := OptionButton.new()
	for i in DevOverlay.PERF_MODES.size():
		perf.add_item(DevOverlay.PERF_MODES[i], i)
	perf.selected = maxi(0, DevOverlay.PERF_MODES.find(String(layers.perf)))
	perf.focus_mode = Control.FOCUS_NONE
	perf.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	perf.item_selected.connect(func(i: int): run("overlay perf %s" % DevOverlay.PERF_MODES[i]))
	_page.add_child(_labelled("perf", perf))
	var quality := HBoxContainer.new()
	quality.add_theme_constant_override("separation", UiTokens.GAP_XS)
	var levels := ButtonGroup.new()
	for id in GraphicsPreset.PRESETS:
		quality.add_child(_choice(String(id).capitalize(), id == GraphicsPreset.current, levels, func():
			_set_quality(id)
			_show_tab("Debug")))
	_page.add_child(_labelled("quality", quality))
	var sheets := HBoxContainer.new()
	sheets.add_theme_constant_override("separation", UiTokens.GAP_XS)
	for axis in DevCapture.SHEET_AXES:
		var button := _button(axis, func(): run_script("sheet %s" % axis))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		sheets.add_child(button)
	_page.add_child(_labelled("sheet", sheets))
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", UiTokens.GAP_XS)
	for pair in [["Step +1", "tick 1"], ["+10", "tick 10"]]:
		var line: String = pair[1]
		var button := _button(pair[0], func(): run_script(line))
		button.disabled = agent == null and not fight.has_method("step_physics")
		button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		steps.add_child(button)
	_page.add_child(steps)


func _legend() -> Control:
	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(88.0, 18.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.draw.connect(func():
		var mid := swatch.size.y * 0.5
		var out := DevOverlay.telegraph_style(false, true, true)
		var inside := DevOverlay.telegraph_style(true, true, true)
		swatch.draw_line(Vector2(0.0, mid), Vector2(36.0, mid), out.colour, out.px)
		swatch.draw_line(Vector2(48.0, mid), Vector2(88.0, mid), Palette.CHARCOAL, inside.under)
		swatch.draw_line(Vector2(48.0, mid), Vector2(88.0, mid), inside.colour, inside.px))
	return swatch


func _set_quality(id: String) -> void:
	if commands.has("quality"):
		run("quality %s" % id)
		return
	_echo("quality %s" % id)
	_say("quality %s" % id if GraphicsPreset.apply(id) else "!no quality '%s'" % id, "ok")


func _sync_lens_rows() -> void:
	for key in ["fov", "size", "cut"]:
		if not _rows.has(key) or not is_instance_valid(_rows[key].slider):
			continue
		var applies: bool = lens.ortho if key != "fov" else not lens.ortho
		_rows[key].slider.editable = applies
		_rows[key].row.modulate.a = 1.0 if applies else UiTokens.DISABLED_ALPHA


func _choice(text: String, on: bool, group: ButtonGroup, pressed: Callable) -> Button:
	var button := _button(text, pressed)
	button.toggle_mode = true
	button.button_group = group
	button.set_pressed_no_signal(on)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	var lit := UiTokens.plate(UiTokens.ACCENT, UiTokens.EDGE)
	lit.content_margin_left = TAB_PAD
	lit.content_margin_right = TAB_PAD
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("hover_pressed", lit)
	return button


func _tab_box(state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var hand := UiTokens.hand(HAND)
	box.bg_color = Color(hand.fill, 0.0 if state in ["normal", "focus"] else 0.85)
	box.draw_center = state != "focus"
	box.border_color = UiTokens.ACCENT
	box.border_width_bottom = 2 if state in ["pressed", "hover_pressed"] else 0
	box.content_margin_left = TAB_PAD
	box.content_margin_right = TAB_PAD
	box.content_margin_top = UiTokens.GAP_XS
	box.content_margin_bottom = UiTokens.GAP_XS
	return box


func _reset_icon(pressed: Callable) -> Button:
	var button := _button("", pressed)
	button.custom_minimum_size = Vector2(RESET_PX, RESET_PX)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.flat = true
	button.tooltip_text = "hand back to the game"
	button.draw.connect(func():
		var mid := button.size * 0.5
		var r := RESET_PX * 0.28
		var tone: Color = UiTokens.ACCENT
		button.draw_arc(mid, r, -PI * 0.35, PI * 1.35, 14, tone, 1.5, true)
		var tip := mid + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * r
		button.draw_colored_polygon(PackedVector2Array([tip + Vector2(-3.5, -1.5), tip + Vector2(2.0, -3.0), tip + Vector2(0.5, 2.5)]), tone))
	return button


func _slider_row(key: String, span: Array, current: float, apply: Callable, echo: String, touched: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_S)
	var name_label := _text(key, UiTokens.CAPTION, UiTokens.ACCENT if touched else _ink(), UiFonts.mono())
	name_label.custom_minimum_size = Vector2(112.0, 0.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if key in look.keys():
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
	var undo: Button = null
	if key in look.keys():
		undo = _reset_icon(func():
			run("reset %s" % key)
			_show_tab(_tab))
		undo.visible = touched
		row.add_child(undo)
	slider.value_changed.connect(func(v: float):
		apply.call(v)
		shown.text = _fmt(v)
		name_label.add_theme_color_override("font_color", UiTokens.ACCENT)
		if undo != null:
			undo.visible = look.touched(key))
	slider.drag_ended.connect(func(changed: bool):
		if changed:
			_echo(echo % _fmt(slider.value)))
	if key in look.keys():
		name_label.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.double_click:
				run("reset %s" % key)
				_show_tab(_tab))
	_rows[key] = {"slider": slider, "shown": shown, "label": name_label, "row": row, "undo": undo}
	_page.add_child(row)


func refresh_rows() -> void:
	for key in _rows:
		var row: Dictionary = _rows[key]
		if not is_instance_valid(row.slider):
			continue
		var value := lens.knob(key) if key in LENS_KNOBS else (fight.time_scale() if key == "time" else look.value(key))
		row.slider.set_value_no_signal(value)
		row.shown.text = _fmt(value)
		row.label.add_theme_color_override("font_color", UiTokens.ACCENT if look.touched(key) else _ink())
		if row.undo != null and is_instance_valid(row.undo):
			row.undo.visible = look.touched(key)
	if _tab == "Lens":
		_sync_lens_rows()
	if not _dots.is_empty():
		_sync_dots()


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
	if needs_script(text):
		commands.remember(text.strip_edges())
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
					"overlay", "debug":
						pool = OVERLAY_WORDS
					"sheet":
						pool = DevCapture.SHEET_AXES
					"quality":
						pool = GraphicsPreset.PRESETS.keys()
					"help":
						pool = commands.names() + ["json"]
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
