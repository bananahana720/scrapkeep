extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const HotwireChoice := preload("res://src/ui/hotwire_choice.gd")
const Icons := preload("res://src/ui/icons.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The offer wears one amber stamp, a tilted plate with a bolt and no word, beside the part's
# name. Amber is the colour law's "the world is offering" row (LEGIBILITY section 1); hazard
# is reserved for what will hurt, and the cost here is a stated trade, not a hit. The stamp
# carries "this is a hot-wired part"; an ordinary offer (reward_view) never draws it. The
# Recycle choice shows its price as the cog icon and the number.
#
# The hot-wired Fit / Recycle choice, in play (BUILD-SYSTEMS.md, Two hot-wired parts). When
# build emits hotwire_offered this screen opens over the paused sim with the part's name, the
# HotwireChoice preview (upside, downside) and two keys:
#   Fit      E or pad Y (cl_interact), hotwire_fit(): the part stands as a striped gate.
#   Recycle  F or pad X, hotwire_recycle(): the stated cogs, once. F is the active's key and X
#            the haul button, both unread while the tree is paused (the recycle releases
#            cl_active so the press never reaches the rack), and neither is the fire button,
#            so a click mashed through the Warden's death cannot recycle by accident.
# Escape, P or Start closes it with the offer still pending. The offer is not lost: the screen
# reopens when the stage's gates open (flow_changed "gates"), or at once if the pause menu or
# the workshop was holding the screen back. hotwire_resolved (build's own signal, not a bus
# event) closes it and the HUD toasts the result in one line.
#
# It pauses through game.toggle_pause() as pause_menu.gd does, and the pause menu stands aside
# while this is open (pause_menu.can_open), so Escape reaches only this screen. With no human at
# the keys (game.bot_driven) it never opens or pauses; the bot driver answers the offer itself.
# It is mounted beside the pause menu, not under the HUD: a modal over the paused sim is not
# the play view, so the HUD word budget never reads it.

const LAYER := 7
const WIDTH := 520.0

var game

var _root: Control
var _stamp: Control
var _name: Label
var _slot: VBoxContainer
var _fit: ChoiceButton
var _recycle: ChoiceButton
var _preview: Control
var _part_id := ""
var _open := false
var _wanted := false
var _paused_here := false
var _wired := false


func _init() -> void:
	name = "HotwireScreen"


func setup(game_ref) -> void:
	game = game_ref
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var veil := ColorRect.new()
	veil.color = Color(Palette.CHARCOAL, 0.8)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 24)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_name = UiDraw.label(UiTokens.DISPLAY, Palette.SAND)
	head.add_child(_name)
	_stamp = Stamp.new()
	head.add_child(_stamp)
	_slot = VBoxContainer.new()
	_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_slot)
	_fit = ChoiceButton.new("fit", "key_e", "Fit")
	_fit.custom_minimum_size.x = WIDTH
	_fit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fit.pressed.connect(choose.bind("fit"))
	column.add_child(_fit)
	_recycle = ChoiceButton.new("recycle", "key_f", "Recycle")
	# The wallet chip's own mark (hud.gd CogChip), so the button and the chip say cogs the same way.
	_recycle.icon = Icons.texture("res_scrap")
	_recycle.expand_icon = true
	_recycle.add_theme_constant_override("icon_max_width", 24)
	_recycle.add_theme_constant_override("h_separation", 8)
	for tone in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		_recycle.add_theme_color_override(tone, Palette.AMBER)
	_recycle.custom_minimum_size.x = WIDTH
	_recycle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_recycle.pressed.connect(choose.bind("recycle"))
	column.add_child(_recycle)
	game.events.flow_changed.connect(_on_flow_changed)
	_set_live(false)
	_wire()


# build is made before the HUD; the guard covers a test that builds the HUD alone.
func _wire() -> void:
	if _wired or game == null or game.build == null:
		return
	_wired = true
	game.build.hotwire_offered.connect(_on_offered)
	game.build.hotwire_resolved.connect(_on_resolved)


func is_open() -> bool:
	return _open


func part_id() -> String:
	return _part_id


# True while the hot-wired stamp stands on an open offer.
func stamp_shown() -> bool:
	return _open and _stamp.is_visible_in_tree()


func choice_button(id: String) -> Button:
	return _fit if id == "fit" else _recycle


func _pending() -> Dictionary:
	if game == null or game.build == null:
		return {}
	var pending: Dictionary = game.build.hotwire_pending()
	return pending if pending.get("state", "") == "open" else {}


func _on_offered(_id: String, _cogs: int) -> void:
	_wanted = true


# A closed offer comes back with the gates; leaving play drops the screen at once.
func _on_flow_changed(state: String) -> void:
	if _open and not game.flow.in_play():
		close()
	if state == "gates" and not _pending().is_empty():
		_wanted = true


func _can_open() -> bool:
	var menu = game.get_node_or_null("PauseMenu")
	return not game.bot_driven and game.flow.in_play() and not game.menu_held() and not game.notes_held() \
		and not game.pause_toggled() and (menu == null or not menu.is_open())


func open() -> void:
	var pending := _pending()
	if _open or pending.is_empty() or not _can_open():
		return
	var copy := HotwireChoice.resolve(pending["part_id"])
	if copy.is_empty():
		return
	_part_id = pending["part_id"]
	_open = true
	_wanted = false
	_name.text = copy["name"]
	_recycle.text = "Recycle +%d" % int(copy["recycle"])
	if _preview != null:
		_slot.remove_child(_preview)
		_preview.queue_free()
	_preview = HotwireChoice.new(_part_id)
	_slot.add_child(_preview)
	_paused_here = not game.pause_toggled()
	if _paused_here:
		game.toggle_pause()
	game.capture_mouse(false)
	_set_live(true)
	_root.visible = true
	_fit.grab_focus()


# Closing leaves the offer where it was; only choose() resolves it.
func close() -> void:
	if not _open:
		return
	_open = false
	_wanted = false
	if _paused_here and game.pause_toggled():
		game.toggle_pause()
	_paused_here = false
	var workshop = game.get_node_or_null("Workshop")
	if workshop != null and workshop.pick.is_open():
		get_tree().paused = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_set_live(false)
	_root.visible = false
	game.recapture_mouse()
	_cue(1.5)


func choose(choice: String) -> void:
	if not _open:
		return
	if choice == "fit":
		game.build.hotwire_fit()
	else:
		game.build.hotwire_recycle()


func _on_resolved(id: String, choice: String, cogs: int) -> void:
	close()
	var copy := HotwireChoice.resolve(id)
	var part_name: String = copy.get("name", id)
	if choice == "fit":
		game.hud.toast("%s fitted, take it at the gates" % part_name, Palette.BRASS, "diamond", 2)
	else:
		game.hud.toast("%s recycled +%d" % [part_name, cogs], Palette.BRASS, EventKinds.row("cogs_collected").get("shape", "square"), 2)


func _input(event: InputEvent) -> void:
	if not _open or game == null:
		return
	if event.is_action_pressed("cl_pause", false) or event.is_action_pressed("ui_cancel", false):
		close()
	elif event.is_action_pressed("cl_interact", false):
		choose("fit")
	elif (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X):
		choose("recycle")
		Input.action_release("cl_active")
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if game == null:
		return
	_wire()
	if _wanted and not _open:
		if _pending().is_empty():
			_wanted = false
		else:
			open()


# The pause menu's UI note, a fifth-and-a-bit up, on close. Opening is the audio's hotwire_offer cue.
func _cue(pitch: float) -> void:
	var audio = game.audio()
	if audio != null and audio.has_method("play"):
		audio.play("flow_changed", 0.0, pitch, "UI")


func _set_live(live: bool) -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	for button in [_fit, _recycle]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if live else Control.FOCUS_NONE
		button.disabled = not live


# The hot-wired stamp: a tilted amber plate with riveted corners and a charcoal bolt, no word.
class Stamp extends Control:
	const PLATE := Vector2(92.0, 52.0)

	func _init() -> void:
		name = "HotwireStamp"
		custom_minimum_size = PLATE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(PLATE * 0.5, -0.08)
		var r := Rect2(-PLATE * 0.5 + Vector2(3.0, 3.0), PLATE - Vector2(6.0, 6.0))
		draw_rect(r, Palette.AMBER)
		draw_rect(r, Palette.CHARCOAL, false, 2.5)
		for corner in [r.position + Vector2(7.0, 7.0), Vector2(r.end.x - 7.0, r.position.y + 7.0), Vector2(r.position.x + 7.0, r.end.y - 7.0), r.end - Vector2(7.0, 7.0)]:
			draw_circle(corner, 2.2, Palette.CHARCOAL)
		# The bolt is the stamp's own mark, cut in charcoal: not an icon id, so no art file stands behind it.
		draw_colored_polygon(PackedVector2Array([Vector2(3.0, -17.0), Vector2(-9.0, 2.0), Vector2(-1.0, 2.0), Vector2(-4.0, 17.0),
			Vector2(9.0, -3.0), Vector2(1.0, -3.0)]), Palette.CHARCOAL)
