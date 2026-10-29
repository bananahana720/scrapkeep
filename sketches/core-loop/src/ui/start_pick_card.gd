extends Control

signal pick_requested(index: int)
signal reroll_requested
signal tier_requested(tier: int)

const RunTier := preload("res://src/core/run_tier.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Palette := preload("res://src/core/palette.gd")

# The card draws the offer and emits choices. Flow owns the input routes and RunState
# owns grants and the win check. The noninteractive default preserves SG9's draw-only use.

const ICON := 40.0
const KEY := 26.0
const FONT := 24
const GAP := 10.0
const TILE_GAP := 18.0
const PAD := 10.0
const PIP := 5.0
const KEYS := ["key_1", "key_2", "key_3"]
const UNLOCK_WORDS := "Win a run to unlock Tier 1"

var _tiles: Array = []
var _tile_rects: Array[Rect2] = []
var _rerolls := 0
var _color := Palette.SAND
var _interactive := false
var _profile
var _run
var _tier_buttons := {}
# The HARD ladder rung the card shows (0: the selected rung, else the highest unlocked); Next rung steps it.
var _shown_rung := 0
var _shown_for := ""
# Whether a screen over the card owns the input now (flow.gd _start_card_covered); unset, nothing does.
var covered := Callable()
var reroll_button: Button
var rung_button: Button



func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process_input(false)
	set_process_unhandled_input(false)
	# In-run flourishes keep clear of the card while it shows (flourish_player.gd AVOID_GROUP).
	add_to_group("flourish_avoid")


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	set_process_input(enabled)


func show_picks(run, profile = null) -> void:
	if String(run.run_id) != _shown_for:
		_shown_for = String(run.run_id)
		_shown_rung = 0
	_run = run
	_profile = profile
	_tiles = []
	var taken := String(run.start_pick.get("taken", ""))
	var pilot: String = run.class_id()
	if taken == "" and int(run.stage) == 1:
		var options: Array = run.start_pick_options()
		for i in mini(options.size(), KEYS.size()):
			var row := StartPicks.row(pilot, String(options[i]))
			if row.is_empty():
				continue
			_tiles.append({"key": KEYS[i], "icon": row["icon"], "name": row["name"], "id": row["id"]})
	_rerolls = int(run.start_pick.get("rerolls_left", 0))
	if run.class_def != null:
		_color = run.class_def.color
	visible = _tiles.size() == StartPicks.OFFERED
	custom_minimum_size = extent()
	size = extent()
	_layout_tiles()
	_controls()
	queue_redraw()


func hide_card() -> void:
	visible = false


func showing() -> bool:
	return visible


# Whether the card needs the cursor: only while it offers a choice the mouse alone can make, the
# run tier before stage 1's Warden closes it on a profile with a rung unlocked. Picks and the
# reroll have keys, so a fresh profile's card, or one holding its tier, leaves the mouse to aim
# (w22 first-timer red team: a freed cursor had left mouse look dead until a pick).
func wants_pointer() -> bool:
	return _interactive and visible and _run != null and _run.run_tier_open() and offered_tiers().size() > 1


func tiles() -> Array:
	return _tiles.duplicate(true)


func tile_rects() -> Array[Rect2]:
	return _tile_rects.duplicate()


func _layout_tiles() -> void:
	var widths := []
	var total := TILE_GAP * maxf(0.0, _tiles.size() - 1)
	for tile in _tiles:
		var width := _tile_width(tile)
		widths.append(width)
		total += width
	_tile_rects.clear()
	var x := (size.x - total) * 0.5
	for width in widths:
		_tile_rects.append(Rect2(x, 0.0, width, ICON + PAD * 2.0))
		x += width + TILE_GAP


func rerolls_left() -> int:
	return _rerolls


func _tile_width(tile: Dictionary) -> float:
	return PAD + KEY + GAP + ICON + GAP + UiDraw.width(String(tile["name"]), FONT) + PAD


func extent() -> Vector2:
	var w := 0.0
	for tile in _tiles:
		w += _tile_width(tile)
	w += TILE_GAP * maxf(0.0, _tiles.size() - 1)
	return Vector2(maxf(w, 780.0) if _interactive else w, ICON + PAD * 2.0 + PIP * 3.0 + (120.0 if _interactive else 0.0))


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if visible:
		for tile in _tiles:
			out.append(String(tile["name"]))
		if _interactive and not ladder_open():
			out.append(UNLOCK_WORDS)
		elif _interactive and not _run.run_tier_open():
			out.append(_held_words())
		elif _interactive:
			out.append(RunTier.threat_text(shown_rung()))
			out.append(RunTier.pay_text(shown_rung()))
	return out


# A fresh profile has no rung to pick, so the card names only how to open one: HARD's threat, pay
# and held tier wait for the first unlock (w22 first-timer red team watch 6).
func ladder_open() -> bool:
	return RunTier.top_unlocked(_profile) >= RunTier.HARD


func _held_words() -> String:
	return "Tier %d held for this run" % _run.selected_run_tier()


# The rung whose threat and pay the card discloses and whose button it offers: the one Next rung stepped
# to, else the run's selected rung, else the highest the profile has opened (rung 1 while HARD is locked).
func shown_rung() -> int:
	var top := RunTier.top_unlocked(_profile)
	if _shown_rung >= RunTier.HARD and _shown_rung <= top:
		return _shown_rung
	if _run != null and _run.selected_run_tier() >= RunTier.HARD:
		return _run.selected_run_tier()
	return maxi(RunTier.HARD, top)


# With a rung selected, Next rung selects the next one too, so the card always shows the run's tier.
# Under a covering screen it steps nothing, so the shown rung never leaves the run's.
func step_rung() -> void:
	var top := RunTier.top_unlocked(_profile)
	if top < 2 or (covered.is_valid() and covered.call()):
		return
	_shown_rung = shown_rung() % top + 1
	if _run != null and _run.selected_run_tier() >= RunTier.HARD:
		tier_requested.emit(_shown_rung)
	_controls()


func offered_tiers() -> Array:
	return StartPicks.offered_tiers(_profile)


func tier_button(tier: int) -> Button:
	return _tier_buttons.get(tier)


func _button(at: Vector2, extent_value: Vector2, words: String, action: Callable) -> Button:
	var button := Button.new()
	button.position = at
	button.size = extent_value
	button.text = words
	button.pressed.connect(action)
	add_child(button)
	return button


func _label(words: String, y: float) -> void:
	var label := Label.new()
	label.text = words
	label.position = Vector2(0.0, y)
	label.size = Vector2(size.x, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)


func _reroll(y: float) -> void:
	reroll_button = _button(Vector2(size.x * 0.5 + 100.0, y + 60.0), Vector2(160.0, 38.0), "Reroll (V)", func(): reroll_requested.emit())
	reroll_button.disabled = _rerolls <= 0


func _controls() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tier_buttons.clear()
	reroll_button = null
	rung_button = null
	if not _interactive or not visible:
		return
	for index in _tiles.size():
		var rect := _tile_rects[index]
		var button := _button(rect.position, rect.size, "", func(): pick_requested.emit(index))
		button.flat = true
		button.tooltip_text = "Take " + String(_tiles[index].name)
	var y := ICON + PAD * 2.0 + PIP * 3.0
	if not ladder_open():
		_label(UNLOCK_WORDS, y)
		_reroll(y)
		return
	if not _run.run_tier_open():
		# Closed when stage 1's Warden engages (run_state.gd _tier_closed): the card names the tier the run holds.
		_label(_held_words(), y)
		_reroll(y)
		return
	var rung := shown_rung()
	_label(RunTier.threat_text(rung), y)
	_label(RunTier.pay_text(rung), y + 28.0)
	var tiers := offered_tiers()
	var top := tiers.size() - 1
	var x := size.x * 0.5 - 250.0
	# The base tier and one ladder rung; Next rung steps the rung through the ones the profile has opened.
	for tier_value in [0, rung]:
		if not tier_value in tiers:
			continue
		var words := "Tier %d%s" % [tier_value, " (selected)" if _run.selected_run_tier() == tier_value else ""]
		_tier_buttons[tier_value] = _button(Vector2(x, y + 60.0), Vector2(160.0, 38.0), words, func(): tier_requested.emit(tier_value))
		x += 170.0
	if top < RunTier.TOP:
		_label("Win a run on Tier %d to unlock Tier %d" % [top, top + 1], y + 96.0)
	_reroll(y)
	if top >= 2:
		rung_button = _button(Vector2(size.x * 0.5 + 270.0, y + 60.0), Vector2(110.0, 38.0), "Next rung", step_rung)


func _input(event: InputEvent) -> void:
	if not _interactive or not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if covered.is_valid() and covered.call():
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key >= KEY_1 and key <= KEY_3:
		pick_requested.emit(key - KEY_1)
	elif key == KEY_V:
		reroll_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	var h := ICON + PAD * 2.0
	for index in _tiles.size():
		var tile: Dictionary = _tiles[index]
		var rect := _tile_rects[index]
		UiDraw.panel(self, rect)
		var mid := h * 0.5
		var cx := rect.position.x + PAD
		draw_texture_rect(Icons.texture(tile["key"]), Rect2(Vector2(cx, mid - KEY * 0.5), Vector2(KEY, KEY)), false, Palette.SAND)
		cx += KEY + GAP
		draw_texture_rect(Icons.texture(tile["icon"]), Rect2(Vector2(cx, mid - ICON * 0.5), Vector2(ICON, ICON)), false,
			Icons.tint(tile["icon"], _color))
		cx += ICON + GAP
		UiDraw.text(self, cx, mid, String(tile["name"]), FONT, _color)
	# One pip per reroll left, centred under the tiles: a spent reroll leaves an outline.
	for i in StartPicks.REROLLS:
		var at := Vector2(size.x * 0.5 + (i - (StartPicks.REROLLS - 1) * 0.5) * PIP * 3.0, h + PIP * 1.5)
		if i < _rerolls:
			draw_circle(at, PIP, _color)
		else:
			draw_arc(at, PIP, 0.0, TAU, 16, Color(_color, 0.5), 1.5)
